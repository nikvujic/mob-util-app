import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:the_app/providers/planner_provider.dart';
import 'package:the_app/widgets/day_strip.dart';

import '../helpers.dart';

/// The planner (P2): a to-do list per day, picked with the day strip.
void main() {
  late ProviderContainer container;

  /// Thursday, 8 October 2026.
  final now = DateTime(2026, 10, 8, 12);
  final today = DateTime(2026, 10, 8);
  final tomorrow = DateTime(2026, 10, 9);

  Future<void> openPlanner(WidgetTester tester) async {
    container = await pumpApp(tester, clock: () => now);
    await openTab(tester, 'Planner');
  }

  PlannerNotifier planner() => container.read(plannerProvider.notifier);
  Finder dayCell(String label) => find.descendant(
        of: find.byType(DayStrip),
        matching: find.bySemanticsLabel(RegExp(label)),
      );

  Future<void> addTasks(WidgetTester tester, List<String> titles) async {
    await tester.tap(find.byTooltip('Add task'));
    await tester.pumpAndSettle();
    for (final title in titles) {
      await tester.enterText(find.byType(TextField), title);
      await tester.tap(find.text('Add'));
      await tester.pump();
    }
    await tester.tapAt(const Offset(10, 10)); // close the sheet
    await tester.pumpAndSettle();
  }

  testWidgets('opens on today, with nothing planned', (tester) async {
    await openPlanner(tester);

    expect(find.text('Today · Thu, 8 Oct'), findsOneWidget);
    expect(find.text('Nothing planned'), findsOneWidget);
  });

  testWidgets('+ adds tasks to the shown day, in order', (tester) async {
    await openPlanner(tester);
    await addTasks(tester, ['Gym', 'Groceries']);

    expect(
      container.read(plannerProvider).map((t) => (t.title, t.day)),
      [('Gym', today), ('Groceries', today)],
    );
    expect(
      tester.getTopLeft(find.text('Gym')).dy,
      lessThan(tester.getTopLeft(find.text('Groceries')).dy),
    );
  });

  testWidgets('tapping a day shows its tasks', (tester) async {
    await openPlanner(tester);
    planner()
      ..addTask(today, 'Gym')
      ..addTask(tomorrow, 'Dentist');
    await tester.pump();

    await tester.tap(dayCell('Friday 9 October 2026'));
    await tester.pumpAndSettle();
    expect(find.text('Tomorrow · Fri, 9 Oct'), findsOneWidget);
    expect(find.text('Dentist'), findsOneWidget);
    expect(find.text('Gym'), findsNothing);

    await addTasks(tester, ['Call mum']);
    expect(
      container.read(plannerProvider).last.day,
      tomorrow,
      reason: 'added to the shown day',
    );

    await tester.tap(dayCell('Thursday 8 October 2026'));
    await tester.pumpAndSettle();
    expect(find.text('Today · Thu, 8 Oct'), findsOneWidget);
    expect(find.text('Gym'), findsOneWidget);
    expect(find.text('Dentist'), findsNothing);
  });

  testWidgets('swiping the strip selects the day that lands in the middle',
      (tester) async {
    await openPlanner(tester);
    final cell = tester.getSize(dayCell('Thursday 8 October 2026')).width;

    // Two days to the left: the day after tomorrow comes to the middle.
    await tester.drag(find.byType(DayStrip), Offset(-2 * cell - 4, 0));
    await tester.pumpAndSettle();

    expect(find.text('Sat, 10 Oct'), findsOneWidget);
  });

  testWidgets('days with tasks are marked', (tester) async {
    await openPlanner(tester);
    planner().addTask(tomorrow, 'Dentist');
    await tester.pump();

    expect(dayCell('Friday 9 October 2026, has tasks'), findsOneWidget);
    expect(dayCell('Thursday 8 October 2026, has tasks'), findsNothing);
  });

  testWidgets('tapping a task marks it done, and back', (tester) async {
    await openPlanner(tester);
    planner().addTask(today, 'Gym');
    await tester.pump();

    await tester.tap(find.text('Gym'));
    await tester.pump();
    expect(container.read(plannerProvider).single.done, isTrue);
    expect(
      tester.widget<Text>(find.text('Gym')).style!.decoration,
      TextDecoration.lineThrough,
    );

    await tester.tap(find.text('Gym'));
    await tester.pump();
    expect(container.read(plannerProvider).single.done, isFalse);
  });

  testWidgets('long-press selects; delete removes after confirming',
      (tester) async {
    await openPlanner(tester);
    planner()
      ..addTask(today, 'Gym')
      ..addTask(today, 'Groceries')
      ..addTask(tomorrow, 'Dentist');
    await tester.pump();

    await tester.longPress(find.text('Gym'));
    await tester.pumpAndSettle();
    expect(find.text('1 selected'), findsOneWidget);

    await tester.tap(find.byTooltip('Delete'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilledButton, 'Delete'));
    await tester.pumpAndSettle();

    expect(
      container.read(plannerProvider).map((t) => t.title),
      ['Groceries', 'Dentist'],
    );
  });

  testWidgets('changing the day ends selection mode', (tester) async {
    await openPlanner(tester);
    planner().addTask(today, 'Gym');
    await tester.pump();
    await tester.longPress(find.text('Gym'));
    await tester.pumpAndSettle();

    await tester.tap(dayCell('Friday 9 October 2026'));
    await tester.pumpAndSettle();

    expect(find.text('1 selected'), findsNothing);
  });

  testWidgets('there is no Today button', (tester) async {
    await openPlanner(tester);
    await tester.tap(dayCell('Friday 9 October 2026'));
    await tester.pumpAndSettle();
    expect(find.widgetWithText(TextButton, 'Today'), findsNothing);
  });

  testWidgets('a fast swipe travels many days, and back to the start',
      (tester) async {
    await openPlanner(tester);

    await tester.fling(
      find.byType(DayStrip),
      const Offset(-300, 0),
      3000,
    );
    await tester.pumpAndSettle();
    final header = tester
        .widgetList<Text>(find.textContaining(', '))
        .map((t) => t.data!)
        .firstWhere((t) => RegExp(r'^\w{3}, \d+ \w{3}').hasMatch(t));
    // Far beyond the week that's visible at once.
    final shownDay =
        int.parse(RegExp(r', (\d+) ').firstMatch(header)!.group(1)!);
    final shownMonth = header.contains('Oct') ? 10 : 11;
    final distance =
        DateTime(2026, shownMonth, shownDay).difference(today).inDays;
    expect(distance, greaterThan(7));

    // And a fast swipe the other way comes back to the start: today.
    await tester.fling(find.byType(DayStrip), const Offset(300, 0), 3000);
    await tester.pumpAndSettle();
    await tester.fling(find.byType(DayStrip), const Offset(300, 0), 3000);
    await tester.pumpAndSettle();
    expect(find.text('Today · Thu, 8 Oct'), findsOneWidget);
  });

  group('the past (P6)', () {
    testWidgets('only 3 greyed-out past days, which cannot be selected',
        (tester) async {
      await openPlanner(tester);

      expect(dayCell('Wednesday 7 October 2026'), findsNothing,
          reason: 'greyed-out days are not offered to screen readers');
      expect(find.text('7'), findsOneWidget, reason: 'but shown');
      expect(find.text('5'), findsOneWidget);
      expect(find.text('4'), findsNothing, reason: 'only 3 of them');

      await tester.tap(find.text('7'));
      await tester.pumpAndSettle();
      await tester.drag(find.byType(DayStrip), const Offset(300, 0));
      await tester.pumpAndSettle();
      expect(find.text('Today · Thu, 8 Oct'), findsOneWidget);
    });

    testWidgets('reaches back to the oldest unfinished task', (tester) async {
      await openPlanner(tester);
      planner()
        ..addTask(DateTime(2026, 10, 3), 'Unfinished')
        ..addTask(DateTime(2026, 10, 1), 'Done long ago');
      planner().toggleDone(
        container
            .read(plannerProvider)
            .firstWhere((t) => t.title == 'Done long ago')
            .id,
      );
      await tester.pump();

      // Back as far as it goes.
      await tester.fling(find.byType(DayStrip), const Offset(300, 0), 3000);
      await tester.pumpAndSettle();

      expect(find.text('Sat, 3 Oct'), findsOneWidget);
      expect(find.text('Unfinished'), findsOneWidget);
      expect(dayCell('Friday 2 October 2026'), findsNothing, reason: 'greyed');

      // Done: the past closes again, back to today.
      planner().toggleDone(
        container
            .read(plannerProvider)
            .firstWhere((t) => t.title == 'Unfinished')
            .id,
      );
      await tester.pumpAndSettle();
      expect(find.text('Today · Thu, 8 Oct'), findsOneWidget);
    });
  });
}
