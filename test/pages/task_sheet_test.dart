import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:the_app/core/theme.dart';
import 'package:the_app/pages/planner/add_task_sheet.dart';
import 'package:the_app/providers/planner_provider.dart';

import '../helpers.dart';

/// The add / edit sheet (Round 9): it follows reach mode, only closes with
/// its Close button or back, and asks before dropping changes.
void main() {
  late ProviderContainer container;

  final titleField = find.byKey(const Key('taskTitle'));
  final sheet = find.byType(TaskSheet);
  final addButton = find.widgetWithText(FilledButton, 'Add');

  Future<void> openAddSheet(WidgetTester tester) async {
    container = await pumpApp(tester, clock: () => DateTime(2026, 10, 8, 12));
    await openTab(tester, 'Planner');
    // A task before now, so the free time's label is in view.
    container
        .read(plannerProvider.notifier)
        .addTask(DateTime(2026, 10, 8), 'Gym', start: 11 * 60, end: 12 * 60);
    await tester.pump();
    await tester.tap(find.text('Free · 12:00–24:00'));
    await tester.pumpAndSettle();
    expect(sheet, findsOneWidget);
  }

  Future<void> close(WidgetTester tester) async {
    await tester.tap(find.byTooltip('Close'));
    await tester.pumpAndSettle();
  }

  testWidgets('pulling down shifts the form; it does not close the sheet',
      (tester) async {
    await openAddSheet(tester);
    final before = tester.getTopLeft(titleField).dy;

    final gesture = await tester.startGesture(tester.getCenter(titleField));
    for (var i = 0; i < 10; i++) {
      await gesture.moveBy(const Offset(0, 30));
      await tester.pump();
    }
    expect(tester.getTopLeft(titleField).dy, greaterThan(before),
        reason: 'the form comes down towards the thumb');
    await gesture.up();
    await tester.pumpAndSettle();

    expect(sheet, findsOneWidget);
    expect(addButton, findsOneWidget, reason: 'the action row stays put');
  });

  testWidgets('dragging the sheet down by its action row leaves it open',
      (tester) async {
    await openAddSheet(tester);
    // Between Close and Add: outside the scrolling form.
    final close = tester.getCenter(find.byTooltip('Close'));
    final add = tester.getCenter(addButton);
    await tester.dragFrom(
      Offset((close.dx + add.dx) / 2, add.dy),
      const Offset(0, 500),
    );
    await tester.pumpAndSettle();

    expect(sheet, findsOneWidget);
  });

  testWidgets('Close without changes closes straight away', (tester) async {
    await openAddSheet(tester);
    await close(tester);

    expect(find.text('Discard changes?'), findsNothing);
    expect(sheet, findsNothing);
  });

  testWidgets('back without changes closes straight away', (tester) async {
    await openAddSheet(tester);
    await pressBack(tester);

    expect(find.text('Discard changes?'), findsNothing);
    expect(sheet, findsNothing);
  });

  testWidgets('a block is at least 5 minutes, and it says so', (tester) async {
    await openAddSheet(tester);
    // Pick 12:02 as the end of a block starting at 12:00.
    await tester.tap(find.widgetWithText(OutlinedButton, '13:00'));
    await tester.pumpAndSettle();
    await tester.tap(find.byIcon(Icons.keyboard_outlined));
    await tester.pumpAndSettle();
    final fields = find.byType(TextFormField);
    await tester.enterText(fields.at(0), '12');
    await tester.enterText(fields.at(1), '02');
    await tester.tap(find.text('OK'));
    await tester.pumpAndSettle();

    expect(find.widgetWithText(OutlinedButton, '12:05'), findsOneWidget);
    expect(
      tester.widget<Text>(find.byKey(const Key('timeAdjusted'))).data,
      'Ends at 12:05: it takes at least 5 minutes.',
    );
  });

  testWidgets('Add is greyed out until there is a title (P15)', (tester) async {
    await openAddSheet(tester);
    bool enabled() => tester.widget<FilledButton>(addButton).onPressed != null;
    expect(enabled(), isFalse);
    await tester.enterText(titleField, '   ');
    await tester.pump();
    expect(enabled(), isFalse, reason: 'spaces are not a title');
    await tester.enterText(titleField, 'Lunch');
    await tester.pump();
    expect(enabled(), isTrue);
    // Its label takes its colour at once, with the fill (no flash, U8).
    expect(
      DefaultTextStyle.of(tester.element(find.text('Add'))).style.color,
      Theme.of(tester.element(addButton)).colorScheme.onPrimary,
    );
  });

  testWidgets('adding focuses the title; editing does not (P15)',
      (tester) async {
    await openAddSheet(tester);
    expect(tester.widget<TextField>(titleField).autofocus, isTrue);
    await close(tester);

    await tester.tap(find.text('Gym'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Edit'));
    await tester.pumpAndSettle();
    expect(tester.widget<TextField>(titleField).autofocus, isFalse);
  });

  group('default colours (P19)', () {
    BlockColor? picked(WidgetTester tester) => BlockColor.values
        .where((c) => tester
            .getSemantics(find.bySemanticsLabel('Colour: ${c.label}'))
            .hasFlag(SemanticsFlag.isSelected))
        .firstOrNull;

    testWidgets('a new task is blue; set to repeat it turns purple',
        (tester) async {
      await openAddSheet(tester);
      expect(picked(tester), BlockColor.blue);
      await tester.ensureVisible(find.text('Every day'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Every day'));
      await tester.pump();
      expect(picked(tester), BlockColor.purple);
      await tester.tap(find.text('Once'));
      await tester.pump();
      expect(picked(tester), BlockColor.blue);
    });

    testWidgets('a picked colour stays when it is set to repeat',
        (tester) async {
      await openAddSheet(tester);
      await tester.tap(find.bySemanticsLabel('Colour: Teal'));
      await tester.pump();
      await tester.ensureVisible(find.text('Every day'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Every day'));
      await tester.pump();
      expect(picked(tester), BlockColor.teal);
    });

    testWidgets('more colours to pick from', (tester) async {
      await openAddSheet(tester);
      for (final name in ['Teal', 'Pink', 'Brown', 'Grey']) {
        expect(find.bySemanticsLabel('Colour: $name'), findsOneWidget);
      }
    });
  });

  group('with changes', () {
    Future<void> edit(WidgetTester tester) async {
      await tester.enterText(titleField, 'Lunch');
      await tester.pump();
    }

    testWidgets('Close asks; Cancel keeps editing', (tester) async {
      await openAddSheet(tester);
      await edit(tester);
      await close(tester);
      expect(find.text('Discard changes?'), findsOneWidget);

      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();

      expect(sheet, findsOneWidget);
      expect(find.text('Lunch'), findsOneWidget);
    });

    testWidgets('Close asks; Discard closes and adds nothing', (tester) async {
      await openAddSheet(tester);
      await edit(tester);
      await close(tester);
      await tester.tap(find.text('Discard'));
      await tester.pumpAndSettle();

      expect(sheet, findsNothing);
      expect(container.read(plannerProvider), hasLength(1));
    });

    testWidgets('a changed time counts as a change', (tester) async {
      await openAddSheet(tester);
      await tester.tap(find.text('30 min'));
      await tester.pump();
      await close(tester);

      expect(find.text('Discard changes?'), findsOneWidget);
    });

    testWidgets('back asks; back again counts as Discard (Nikola)',
        (tester) async {
      await openAddSheet(tester);
      await edit(tester);

      await pressBack(tester);
      expect(find.text('Discard changes?'), findsOneWidget);
      expect(sheet, findsOneWidget);

      await pressBack(tester);
      expect(sheet, findsNothing);
      expect(container.read(plannerProvider), hasLength(1));
    });

    testWidgets('tapping outside the dialog does nothing', (tester) async {
      await openAddSheet(tester);
      await edit(tester);
      await close(tester);

      await tester.tapAt(const Offset(5, 5));
      await tester.pumpAndSettle();

      expect(find.text('Discard changes?'), findsOneWidget);
    });
  });
}
