import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:the_app/models/note.dart';
import 'package:the_app/providers/notes_provider.dart';

import '../helpers.dart';

void main() {
  late ProviderContainer container;

  Note noteById(String id) =>
      container.read(notesProvider).firstWhere((n) => n.id == id);

  IconButton discardButton(WidgetTester tester) =>
      tester.widget<IconButton>(find.widgetWithIcon(IconButton, Icons.undo));

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

  Future<void> tapDiscard(WidgetTester tester, {required bool confirm}) async {
    await tester.pump(); // let the button rebuild as enabled after typing
    await tester.tap(find.byTooltip('Discard changes'));
    await tester.pumpAndSettle();
    await tester.tap(find.text(confirm ? 'Discard' : 'Cancel'));
    await tester.pumpAndSettle();
  }

  testWidgets('is disabled until something changes', (tester) async {
    await openExistingNote(tester);
    expect(discardButton(tester).onPressed, isNull);

    await tester.enterText(
        find.byKey(const Key('noteContentField')), 'milk, eggs');
    await tester.pump();
    expect(discardButton(tester).onPressed, isNotNull);
  });

  testWidgets('restores the note exactly, even after autosave', (tester) async {
    final id = await openExistingNote(tester);
    final original = noteById(id);

    await tester.enterText(
        find.byKey(const Key('noteTitleField')), 'Groceries');
    await tester.enterText(
        find.byKey(const Key('noteContentField')), 'milk, eggs');
    await tester.pump(const Duration(seconds: 1)); // autosave runs
    expect(noteById(id).content, 'milk, eggs');

    await tapDiscard(tester, confirm: true);

    expect(appBarTitle('Notes'), findsOneWidget, reason: 'editor closed');
    final restored = noteById(id);
    expect(restored.title, 'Shopping');
    expect(restored.content, 'milk');
    expect(restored.modifiedAt, original.modifiedAt);
  });

  testWidgets('cancel keeps editing with the changes', (tester) async {
    final id = await openExistingNote(tester);
    await tester.enterText(
        find.byKey(const Key('noteContentField')), 'milk, eggs');

    await tapDiscard(tester, confirm: false);

    expect(appBarTitle('Note'), findsOneWidget);
    expect(find.text('milk, eggs'), findsOneWidget);

    await tester.pageBack();
    await tester.pumpAndSettle();
    expect(noteById(id).content, 'milk, eggs');
  });

  testWidgets('discarding a new note removes it', (tester) async {
    container = await pumpApp(tester);
    await tester.tap(find.byTooltip('New note'));
    await tester.pumpAndSettle();
    await tester.enterText(
        find.byKey(const Key('noteContentField')), 'Some text');
    await tester.pump(const Duration(seconds: 1));
    expect(container.read(notesProvider), hasLength(1));

    await tester.tap(find.byTooltip('Discard changes'));
    await tester.pumpAndSettle();
    expect(find.text('Discard this note?'), findsOneWidget);
    await tester.tap(find.text('Discard'));
    await tester.pumpAndSettle();

    expect(container.read(notesProvider), isEmpty);
    expect(find.text('No notes'), findsOneWidget);
  });

  testWidgets('a pending autosave does not undo the discard', (tester) async {
    final id = await openExistingNote(tester);
    // Typed just now: the autosave timer is still pending when discarding.
    await tester.enterText(
        find.byKey(const Key('noteContentField')), 'milk, eggs');

    await tapDiscard(tester, confirm: true);
    await tester.pump(const Duration(seconds: 2));

    expect(noteById(id).content, 'milk');
  });
}
