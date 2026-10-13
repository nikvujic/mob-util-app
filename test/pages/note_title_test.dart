import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:the_app/providers/notes_provider.dart';
import 'package:the_app/widgets/text_input_sheet.dart';

import '../helpers.dart';

/// Editing the title from the bottom of the editor (N11).
void main() {
  late ProviderContainer container;

  final titleField = find.byKey(const Key('noteTitleField'));
  final sheetField = find.descendant(
    of: find.byType(TextInputSheet),
    matching: find.byType(TextField),
  );

  String title(WidgetTester tester) =>
      tester.widget<TextField>(titleField).controller!.text;

  Future<String> openNote(WidgetTester tester) async {
    container = await pumpApp(tester);
    final id = container
        .read(notesProvider.notifier)
        .addNote(title: 'Shopping', content: 'milk');
    await tester.pump();
    await tester.tap(find.text('Shopping'));
    await tester.pumpAndSettle();
    return id;
  }

  Future<void> openEditTitle(WidgetTester tester) async {
    await tester.tap(find.byTooltip('Edit title'));
    await tester.pumpAndSettle();
  }

  testWidgets('Edit title: a sheet at the bottom, the title changes live',
      (tester) async {
    final id = await openNote(tester);
    await openEditTitle(tester);

    expect(sheetField, findsOneWidget);
    final screen = tester.view.physicalSize / tester.view.devicePixelRatio;
    expect(tester.getCenter(sheetField).dy, greaterThan(screen.height / 2),
        reason: 'within thumb reach');
    expect(tester.widget<TextField>(sheetField).controller!.text, 'Shopping');

    await tester.enterText(sheetField, 'Groceries');
    await tester.pump();
    expect(title(tester), 'Groceries', reason: 'live, before Done');

    await tester.tap(find.text('Done'));
    await tester.pumpAndSettle();
    expect(find.byType(TextInputSheet), findsNothing);
    await tester.pump(const Duration(seconds: 1)); // autosave
    expect(
      container.read(notesProvider).firstWhere((n) => n.id == id).title,
      'Groceries',
    );

    await tester.tap(find.byTooltip('Undo'));
    await tester.pump();
    expect(title(tester), 'Shopping');
  });

  testWidgets('an empty title is fine there; saved as Untitled on leaving',
      (tester) async {
    final id = await openNote(tester);
    await openEditTitle(tester);
    await tester.enterText(sheetField, '');
    await tester.pump();
    expect(title(tester), '');

    await tester.tap(find.text('Done'));
    await tester.pumpAndSettle();
    await tester.pageBack();
    await tester.pumpAndSettle();
    if (find.text('Save changes?').evaluate().isNotEmpty) {
      await tester.tap(find.text('Save'));
      await tester.pumpAndSettle();
    }
    expect(
      container.read(notesProvider).firstWhere((n) => n.id == id).title,
      'Untitled',
    );
  });

  testWidgets(
      'a default title comes selected, to be typed over; a real one '
      "doesn't (Round 27)", (tester) async {
    container = await pumpApp(tester);
    container.read(notesProvider.notifier)
      ..addNote() // "New Note"
      ..addNote(title: 'Shopping', content: 'milk');
    await tester.pump();
    TextSelection selection() =>
        tester.widget<TextField>(sheetField).controller!.selection;

    await tester.tap(find.text(NotesNotifier.defaultTitle));
    await tester.pumpAndSettle();
    await openEditTitle(tester);
    expect(selection(), const TextSelection(baseOffset: 0, extentOffset: 8));
    await tester.tap(find.text('Done'));
    await tester.pumpAndSettle();
    await tester.pageBack();
    await tester.pumpAndSettle();

    await tester.tap(find.text('Shopping'));
    await tester.pumpAndSettle();
    await openEditTitle(tester);
    expect(selection().isCollapsed, isTrue);
    expect(selection().baseOffset, 'Shopping'.length);
  });
}
