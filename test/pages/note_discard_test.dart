import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:the_app/models/note.dart';
import 'package:the_app/providers/notes_provider.dart';

import '../helpers.dart';

void main() {
  late ProviderContainer container;

  final titleField = find.byKey(const Key('noteTitleField'));
  final contentField = find.byKey(const Key('noteContentField'));

  Note noteById(String id) =>
      container.read(notesProvider).firstWhere((n) => n.id == id);

  /// Seeds a note, opens it, and returns its id.
  Future<String> openExistingNote(WidgetTester tester) async {
    container = await pumpApp(tester);
    final id = container
        .read(notesProvider.notifier)
        .addNote(title: 'Shopping', content: 'milk');
    await tester.pump();
    await tester.tap(find.text('Shopping'));
    await tester.pumpAndSettle();
    return id;
  }

  Future<void> openNewNote(WidgetTester tester) async {
    container = await pumpApp(tester);
    await tester.tap(find.byTooltip('New note'));
    await tester.pumpAndSettle();
  }

  group('back from an edited note', () {
    testWidgets('without changes leaves without asking', (tester) async {
      await openExistingNote(tester);
      await leaveNote(tester);

      expect(find.text('Save changes?'), findsNothing);
      expect(appBarTitle('Notes'), findsOneWidget);
    });

    testWidgets('Yes keeps the changes', (tester) async {
      final id = await openExistingNote(tester);
      await tester.enterText(contentField, 'milk, eggs');

      await tester.pump();
      await tester.pageBack();
      await tester.pumpAndSettle();
      expect(find.text('Save changes?'), findsOneWidget);
      await tester.tap(find.text('Save'));
      await tester.pumpAndSettle();

      expect(appBarTitle('Notes'), findsOneWidget);
      expect(noteById(id).content, 'milk, eggs');
    });

    testWidgets('tapping outside the dialog stays in the note (Nikola)',
        (tester) async {
      await openExistingNote(tester);
      await tester.enterText(contentField, 'milk, eggs');

      await leaveNote(tester);
      await tester.tapAt(const Offset(5, 5)); // outside the dialog
      await tester.pumpAndSettle();

      expect(find.text('Save changes?'), findsNothing);
      expect(appBarTitle('Notes'), findsNothing, reason: 'still editing');
      expect(find.text('milk, eggs'), findsOneWidget);

      // Back asks again, as before.
      await leaveNote(tester);
      expect(find.text('Save changes?'), findsOneWidget);
    });

    testWidgets('back on the dialog keeps the changes and leaves',
        (tester) async {
      final id = await openExistingNote(tester);
      await tester.enterText(contentField, 'milk, eggs');

      await leaveNote(tester);
      await pressBack(tester);

      expect(appBarTitle('Notes'), findsOneWidget);
      expect(noteById(id).content, 'milk, eggs');
    });

    testWidgets('No restores the note exactly, even after autosave',
        (tester) async {
      final id = await openExistingNote(tester);
      final original = noteById(id);
      await tester.enterText(titleField, 'Groceries');
      await tester.enterText(contentField, 'milk, eggs');
      await tester.pump(const Duration(seconds: 1)); // autosave runs
      expect(noteById(id).content, 'milk, eggs');

      await leaveNote(tester, save: false);

      expect(appBarTitle('Notes'), findsOneWidget);
      final restored = noteById(id);
      expect(restored.title, 'Shopping');
      expect(restored.content, 'milk');
      expect(restored.modifiedAt, original.modifiedAt);
    });

    testWidgets('No is not undone by a pending autosave', (tester) async {
      final id = await openExistingNote(tester);
      await tester.enterText(contentField, 'milk, eggs'); // timer pending

      await leaveNote(tester, save: false);
      await tester.pump(const Duration(seconds: 2));

      expect(noteById(id).content, 'milk');
    });
  });

  group('back from a new note', () {
    testWidgets('untouched: removed without asking', (tester) async {
      await openNewNote(tester);
      await leaveNote(tester);

      expect(find.text('Save new note?'), findsNothing);
      expect(container.read(notesProvider), isEmpty);
    });

    testWidgets('Yes keeps it', (tester) async {
      await openNewNote(tester);
      await tester.enterText(contentField, 'Some text');

      await tester.pump();
      await tester.pageBack();
      await tester.pumpAndSettle();
      expect(find.text('Save new note?'), findsOneWidget);
      await tester.tap(find.text('Save'));
      await tester.pumpAndSettle();

      expect(container.read(notesProvider).single.content, 'Some text');
    });

    testWidgets('No deletes it, even after autosave', (tester) async {
      await openNewNote(tester);
      await tester.enterText(contentField, 'Some text');
      await tester.pump(const Duration(seconds: 1));

      await leaveNote(tester, save: false);

      expect(container.read(notesProvider), isEmpty);
      expect(find.text('No notes'), findsOneWidget);
    });

    testWidgets('its Discard changes is there, greyed out (Round 20)',
        (tester) async {
      await openNewNote(tester);
      await tester.enterText(contentField, 'milk');
      await tester.pump();
      final button = find.ancestor(
        of: find.byTooltip('Discard changes'),
        matching: find.byType(FloatingActionButton),
      );
      expect(tester.widget<FloatingActionButton>(button).onPressed, isNull,
          reason: 'a new note has nothing to go back to');
    });
  });

  group('Discard changes in an edited note', () {
    final discardButton = find.byTooltip('Discard changes');

    testWidgets(
        'always there, greyed out until something changed (Round 20), '
        'at the bottom, not as ↶', (tester) async {
      await openExistingNote(tester);
      VoidCallback? pressed() => tester
          .widget<FloatingActionButton>(find.ancestor(
            of: discardButton,
            matching: find.byType(FloatingActionButton),
          ))
          .onPressed;
      expect(discardButton, findsOneWidget, reason: 'its place kept');
      expect(pressed(), isNull);

      await tester.enterText(contentField, 'milk, eggs');
      await tester.pump();
      expect(pressed(), isNotNull);
      expect(
        find.descendant(of: discardButton, matching: find.byIcon(Icons.undo)),
        findsNothing,
        reason: '↶ is for undo (N8)',
      );
      expect(
        find.descendant(of: find.byType(AppBar), matching: discardButton),
        findsNothing,
        reason: 'no actions in the top bar',
      );
    });

    testWidgets('restores the note but stays in the editor', (tester) async {
      final id = await openExistingNote(tester);
      final original = noteById(id);
      await tester.enterText(contentField, 'milk, eggs');
      await tester.pump(const Duration(seconds: 1)); // autosaved

      await tester.tap(find.byTooltip('Discard changes'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Discard'));
      await tester.pumpAndSettle();

      expect(appBarTitle('Note'), findsOneWidget, reason: 'still editing');
      expect(find.text('milk'), findsOneWidget);
      expect(noteById(id).content, 'milk');
      expect(noteById(id).modifiedAt, original.modifiedAt);
      expect(
          tester
              .widget<FloatingActionButton>(find.ancestor(
                of: discardButton,
                matching: find.byType(FloatingActionButton),
              ))
              .onPressed,
          isNull,
          reason: 'nothing left to discard');

      // Nothing changed any more, so back leaves without asking.
      await leaveNote(tester);
      expect(appBarTitle('Notes'), findsOneWidget);
      expect(noteById(id).modifiedAt, original.modifiedAt);
    });

    testWidgets('cancel keeps the changes', (tester) async {
      final id = await openExistingNote(tester);
      await tester.enterText(contentField, 'milk, eggs');
      await tester.pump();

      await tester.tap(find.byTooltip('Discard changes'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();

      expect(find.text('milk, eggs'), findsOneWidget);
      await leaveNote(tester, save: true);
      expect(noteById(id).content, 'milk, eggs');
    });
  });

  testWidgets('system back with changes asks too, once out of editing',
      (tester) async {
    await openExistingNote(tester);
    await tester.enterText(contentField, 'milk, eggs');
    await tester.pump();

    await pressBack(tester); // stops editing (N13)
    expect(find.text('Save changes?'), findsNothing);
    await pressBack(tester);

    expect(find.text('Save changes?'), findsOneWidget);
  });
}
