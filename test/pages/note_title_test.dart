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

  testWidgets('Edit title changes the title in a sheet at the bottom',
      (tester) async {
    final id = await openNote(tester);
    await openEditTitle(tester);

    expect(sheetField, findsOneWidget);
    final screen = tester.view.physicalSize / tester.view.devicePixelRatio;
    expect(tester.getCenter(sheetField).dy, greaterThan(screen.height / 2),
        reason: 'within thumb reach');
    expect(tester.widget<TextField>(sheetField).controller!.text, 'Shopping');

    await tester.enterText(sheetField, '  Groceries ');
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();

    expect(title(tester), 'Groceries');
    await tester.pump(const Duration(seconds: 1)); // autosave
    expect(
      container.read(notesProvider).firstWhere((n) => n.id == id).title,
      'Groceries',
      reason: 'saved like typing in the title',
    );

    await tester.tap(find.byTooltip('Undo'));
    await tester.pump();
    expect(title(tester), 'Shopping');
  });

  testWidgets('closing the sheet, or a blank title, changes nothing',
      (tester) async {
    await openNote(tester);
    await openEditTitle(tester);
    await tester.enterText(sheetField, '   ');
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();
    expect(title(tester), 'Shopping');

    await openEditTitle(tester);
    await tester.tapAt(const Offset(5, 5)); // outside the sheet
    await tester.pumpAndSettle();
    expect(title(tester), 'Shopping');
    expect(find.byTooltip('Discard changes'), findsNothing);
  });
}
