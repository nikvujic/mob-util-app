import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:the_app/providers/notes_provider.dart';

import '../helpers.dart';

void main() {
  late ProviderContainer container;

  NotesNotifier notes() => container.read(notesProvider.notifier);

  testWidgets('creating a note with a title adds it to the top',
      (tester) async {
    container = await pumpApp(tester);
    notes().addNote(title: 'Older');
    await tester.pump();

    await tester.tap(find.byTooltip('New note'));
    await tester.pumpAndSettle();
    await tester.enterText(
        find.byKey(const Key('noteTitleField')), 'Groceries');
    await leaveNote(tester, save: true);

    expect(container.read(notesProvider).map((n) => n.title),
        ['Groceries', 'Older']);
  });

  testWidgets('a new note exists immediately with the default title',
      (tester) async {
    container = await pumpApp(tester);
    await tester.tap(find.byTooltip('New note'));
    await tester.pumpAndSettle();

    expect(container.read(notesProvider).single.title, 'New Note');
    expect(find.text('New Note'), findsOneWidget); // title field

    await tester.enterText(
        find.byKey(const Key('noteContentField')), 'Body only');
    await leaveNote(tester, save: true);

    final note = container.read(notesProvider).single;
    expect(note.title, 'New Note');
    expect(note.content, 'Body only');
  });

  testWidgets('edits are autosaved while typing', (tester) async {
    container = await pumpApp(tester);
    final id = notes().addNote(title: 'Draft');
    await tester.pump();

    await tester.tap(find.text('Draft'));
    await tester.pumpAndSettle();
    await tester.enterText(
        find.byKey(const Key('noteContentField')), 'Typed text');
    await tester.pump(const Duration(seconds: 1));

    final note = container.read(notesProvider).firstWhere((n) => n.id == id);
    expect(note.content, 'Typed text');

    // Clearing the title is not autosaved as "Untitled".
    await tester.enterText(find.byKey(const Key('noteTitleField')), '');
    await tester.pump(const Duration(seconds: 1));
    expect(
      container.read(notesProvider).firstWhere((n) => n.id == id).title,
      'Draft',
    );

    await leaveNote(tester, save: true);
  });

  testWidgets('a new note joins the list only once the editor covers it',
      (tester) async {
    container = await pumpApp(tester);
    container.read(notesProvider.notifier).addNote(title: 'Older');
    await tester.pump();

    Finder inList(String text, {bool skipOffstage = true}) => find.descendant(
          of: find.byType(ReorderableListView, skipOffstage: skipOffstage),
          matching: find.text(text, skipOffstage: skipOffstage),
          skipOffstage: skipOffstage,
        );

    await tester.tap(find.byTooltip('New note'));
    await tester.pump(); // first frame of the slide-in
    await tester.pump(const Duration(milliseconds: 100));

    // Saved immediately, but not shown in the still-visible list.
    expect(container.read(notesProvider).first.title, 'New Note');
    expect(inList('New Note'), findsNothing);
    expect(inList('Older'), findsOneWidget);

    await tester.pumpAndSettle(); // editor fully open
    expect(inList('New Note', skipOffstage: false), findsOneWidget);

    await tester.enterText(find.byKey(const Key('noteContentField')), 'x');
    await leaveNote(tester, save: true);
    expect(inList('New Note'), findsOneWidget);
  });

  testWidgets('an untouched new note is discarded', (tester) async {
    container = await pumpApp(tester);
    await tester.tap(find.byTooltip('New note'));
    await tester.pumpAndSettle();
    await leaveNote(tester);

    expect(container.read(notesProvider), isEmpty);
    expect(find.text('No notes'), findsOneWidget);
  });

  testWidgets('an existing empty note is not discarded', (tester) async {
    container = await pumpApp(tester);
    notes().addNote();
    await tester.pump();

    await tester.tap(find.text('New Note'));
    await tester.pumpAndSettle();
    await leaveNote(tester);

    expect(container.read(notesProvider), hasLength(1));
  });

  testWidgets('the title of an existing note can be edited', (tester) async {
    container = await pumpApp(tester);
    notes().addNote(title: 'Old title');
    await tester.pump();

    await tester.tap(find.text('Old title'));
    await tester.pumpAndSettle();
    await tester.enterText(
        find.byKey(const Key('noteTitleField')), 'New title');
    await leaveNote(tester, save: true);

    expect(find.text('New title'), findsOneWidget);
    expect(find.text('Old title'), findsNothing);
  });

  testWidgets('long-press selects; delete asks for confirmation',
      (tester) async {
    container = await pumpApp(tester);
    notes()
      ..addNote(title: 'A')
      ..addNote(title: 'B')
      ..addNote(title: 'C');
    await tester.pump();

    await tester.longPress(find.text('A'));
    await tester.pump();
    expect(find.text('1 selected'), findsOneWidget);
    expect(container.read(notesProvider), hasLength(3),
        reason: 'long-press must not delete');

    await tester.tap(find.text('B'));
    await tester.pump();
    expect(find.text('2 selected'), findsOneWidget);

    // Cancel keeps everything and stays in selection mode.
    await tester.tap(find.byTooltip('Delete'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();
    expect(container.read(notesProvider), hasLength(3));
    expect(find.text('2 selected'), findsOneWidget);

    await tester.tap(find.byTooltip('Delete'));
    await tester.pumpAndSettle();
    expect(find.text('Delete 2 notes?'), findsOneWidget);
    await tester.tap(find.text('Delete'));
    await tester.pumpAndSettle();

    expect(container.read(notesProvider).map((n) => n.title), ['C']);
    expect(find.text('Notes'), findsWidgets);
    expect(find.textContaining('selected'), findsNothing);
  });

  testWidgets('deselecting the last item or back exits selection mode',
      (tester) async {
    container = await pumpApp(tester);
    notes().addNote(title: 'A');
    await tester.pump();

    await tester.longPress(find.text('A'));
    await tester.pump();
    await tester.tap(find.text('A'));
    await tester.pump();
    expect(find.textContaining('selected'), findsNothing);

    await tester.longPress(find.text('A'));
    await tester.pump();
    final popped = await tester.binding.handlePopRoute();
    await tester.pump();
    expect(popped, isTrue);
    expect(find.textContaining('selected'), findsNothing);
  });

  testWidgets('dragging the handle reorders notes', (tester) async {
    container = await pumpApp(tester);
    notes()
      ..addNote(title: 'C')
      ..addNote(title: 'B')
      ..addNote(title: 'A');
    await tester.pump();

    final handle = find.byIcon(Icons.drag_handle).first; // A's handle
    final gesture = await tester.startGesture(tester.getCenter(handle));
    for (var i = 0; i < 10; i++) {
      await gesture.moveBy(const Offset(0, 20));
      await tester.pump(const Duration(milliseconds: 16));
    }
    await gesture.up();
    await tester.pumpAndSettle();

    expect(container.read(notesProvider).first.title, 'B');
  });
}
