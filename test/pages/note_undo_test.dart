import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:the_app/providers/notes_provider.dart';

import '../helpers.dart';

/// Undo / redo in the note editor (N8).
void main() {
  late ProviderContainer container;
  late DateTime now;

  final contentField = find.byKey(const Key('noteContentField'));
  final titleField = find.byKey(const Key('noteTitleField'));

  String content(WidgetTester tester) =>
      tester.widget<TextField>(contentField).controller!.text;

  bool enabled(WidgetTester tester, String tooltip) =>
      tester
          .widget<FloatingActionButton>(
            find.ancestor(
              of: find.byTooltip(tooltip),
              matching: find.byType(FloatingActionButton),
            ),
          )
          .onPressed !=
      null;

  Future<String> openNote(WidgetTester tester) async {
    now = DateTime(2026, 10, 10, 12);
    container = await pumpApp(tester, clock: () => now);
    final id = container
        .read(notesProvider.notifier)
        .addNote(title: 'Shopping', content: 'milk');
    await tester.pump();
    await tester.tap(find.text('Shopping'));
    await tester.pumpAndSettle();
    return id;
  }

  /// Types [text] as one step (a later one than the last).
  Future<void> type(WidgetTester tester, String text) async {
    now = now.add(const Duration(seconds: 2));
    await tester.enterText(contentField, text);
    await tester.pump();
  }

  Future<void> press(WidgetTester tester, String tooltip) async {
    await tester.tap(find.byTooltip(tooltip));
    await tester.pump();
  }

  testWidgets('both buttons are there, greyed out until there is history',
      (tester) async {
    await openNote(tester);
    expect(find.byTooltip('Undo'), findsOneWidget);
    expect(find.byTooltip('Redo'), findsOneWidget);
    expect(enabled(tester, 'Undo'), isFalse);
    expect(enabled(tester, 'Redo'), isFalse);

    await type(tester, 'milk, eggs');
    expect(enabled(tester, 'Undo'), isTrue);
    expect(enabled(tester, 'Redo'), isFalse);
  });

  testWidgets('undo and redo step through the edits, and are saved',
      (tester) async {
    final id = await openNote(tester);
    await type(tester, 'milk, eggs');
    await type(tester, 'milk, eggs, bread');

    await press(tester, 'Undo');
    expect(content(tester), 'milk, eggs');
    await press(tester, 'Undo');
    expect(content(tester), 'milk');
    expect(enabled(tester, 'Undo'), isFalse);

    await press(tester, 'Redo');
    expect(content(tester), 'milk, eggs');
    expect(enabled(tester, 'Redo'), isTrue);

    await tester.pump(const Duration(seconds: 1)); // autosave
    expect(
      container.read(notesProvider).firstWhere((n) => n.id == id).content,
      'milk, eggs',
    );
  });

  testWidgets('the title is part of the same history', (tester) async {
    await openNote(tester);
    await type(tester, 'milk, eggs');
    now = now.add(const Duration(seconds: 2));
    await tester.enterText(titleField, 'Groceries');
    await tester.pump();

    await press(tester, 'Undo');
    expect(find.text('Groceries'), findsNothing);
    expect(content(tester), 'milk, eggs');
  });

  testWidgets('Discard changes can be undone', (tester) async {
    await openNote(tester);
    await type(tester, 'milk, eggs');

    await tester.tap(find.byTooltip('Discard changes'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilledButton, 'Discard'));
    await tester.pumpAndSettle();
    expect(content(tester), 'milk');

    await press(tester, 'Undo');
    expect(content(tester), 'milk, eggs');
  });
}
