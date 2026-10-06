import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:the_app/main.dart';
import 'package:the_app/providers/notes_provider.dart';

void main() {
  late ProviderContainer container;

  Future<void> pumpApp(WidgetTester tester) async {
    container = ProviderContainer();
    addTearDown(container.dispose);
    await tester.pumpWidget(
      UncontrolledProviderScope(container: container, child: const MyApp()),
    );
  }

  NotesNotifier notes() => container.read(notesProvider.notifier);

  testWidgets('creating a note with a title adds it to the top',
      (tester) async {
    await pumpApp(tester);
    notes().addNote(title: 'Older');
    await tester.pump();

    await tester.tap(find.byTooltip('New note'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const Key('noteTitleField')), 'Groceries');
    await tester.pageBack();
    await tester.pumpAndSettle();

    expect(container.read(notesProvider).map((n) => n.title),
        ['Groceries', 'Older']);
  });

  testWidgets('an empty new note is discarded', (tester) async {
    await pumpApp(tester);
    await tester.tap(find.byTooltip('New note'));
    await tester.pumpAndSettle();
    await tester.pageBack();
    await tester.pumpAndSettle();

    expect(container.read(notesProvider), isEmpty);
    expect(find.text('No notes'), findsOneWidget);
  });

  testWidgets('the title of an existing note can be edited', (tester) async {
    await pumpApp(tester);
    notes().addNote(title: 'Old title');
    await tester.pump();

    await tester.tap(find.text('Old title'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const Key('noteTitleField')), 'New title');
    await tester.pageBack();
    await tester.pumpAndSettle();

    expect(find.text('New title'), findsOneWidget);
    expect(find.text('Old title'), findsNothing);
  });

  testWidgets('long-press selects; delete asks for confirmation',
      (tester) async {
    await pumpApp(tester);
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
    await pumpApp(tester);
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
    await pumpApp(tester);
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
