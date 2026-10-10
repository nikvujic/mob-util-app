import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:the_app/models/planner_task.dart';
import 'package:the_app/providers/planner_provider.dart';
import 'package:the_app/widgets/dashed_border.dart';
import 'package:the_app/widgets/selection.dart';
import 'package:the_app/widgets/day_strip.dart';

import '../helpers.dart';

/// The planner (P2, P7): a timeline per day, picked with the day strip.
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

  /// Adds [title] on [day] from [hour]:00 for an hour, directly.
  void add(DateTime day, String title, {int hour = 12}) =>
      planner().addTask(day, title, start: hour * 60, end: (hour + 1) * 60);

  /// The free-time area showing [range] ("09:00–24:00").
  Finder free(String range) => find.text('Free · $range');

  testWidgets('the 00:00 label is fully visible at the top of the day',
      (tester) async {
    await openPlanner(tester);
    await tester.ensureVisible(find.text('00:00'));
    await tester.drag(find.text('00:00'), const Offset(0, 2000)); // to the top
    await tester.pumpAndSettle();

    final label = tester.getRect(find.text('00:00'));
    final viewport = tester.getRect(find.byType(SingleChildScrollView));
    expect(label.top, greaterThanOrEqualTo(viewport.top));
  });

  testWidgets('opens on today: a whole free day, scrolled to around now',
      (tester) async {
    await openPlanner(tester);

    expect(find.text('Today · Thu, 8 Oct'), findsOneWidget);
    expect(free('00:00–24:00'), findsOneWidget);
    expect(find.text('12:00'), findsOneWidget, reason: 'it is 12:00 now');
    expect(find.byTooltip('Add task'), findsNothing, reason: 'no + button');
  });

  testWidgets('free time is a dotted block, lined up with task blocks',
      (tester) async {
    await openPlanner(tester);
    add(today, 'Lunch', hour: 12); // 12:00–13:00
    add(today, 'Nap', hour: 14); // 14:00–15:00
    await tester.pump();

    final gap = find.ancestor(
      of: free('13:00–14:00'),
      matching: find.byType(DashedBorder),
    );
    expect(gap, findsOneWidget);
    final block = tester.getRect(gap);
    final lunch = tester.getRect(find.ancestor(
      of: find.text('Lunch'),
      matching: find.byType(SelectableCard),
    ));
    final nap = tester.getRect(find.ancestor(
      of: find.text('Nap'),
      matching: find.byType(SelectableCard),
    ));
    expect((block.left, block.right), (lunch.left, lunch.right));
    expect(block.top - lunch.bottom, closeTo(2, 0.5), reason: 'same gaps');
    expect(nap.top - block.bottom, closeTo(2, 0.5));
  });

  testWidgets('a short free gap is just the dotted block, no label',
      (tester) async {
    await openPlanner(tester);
    planner()
      ..addTask(today, 'A', start: 12 * 60, end: 13 * 60)
      ..addTask(today, 'B', start: 13 * 60 + 10, end: 14 * 60);
    await tester.pump();

    expect(free('13:00–13:10'), findsNothing);
    expect(find.bySemanticsLabel('Free time, 13:00–13:10. Add a task'),
        findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('tapping free time adds a task there: from its start, an hour',
      (tester) async {
    await openPlanner(tester);
    add(today, 'Gym', hour: 11); // 11:00–12:00
    await tester.pump();

    await tester.tap(free('12:00–24:00'));
    await tester.pumpAndSettle();
    expect(find.widgetWithText(TextButton, '12:00'), findsOneWidget);
    expect(find.widgetWithText(TextButton, '13:00'), findsOneWidget);

    await tester.enterText(find.byKey(const Key('taskTitle')), 'Lunch');
    await tester.tap(find.text('30 min'));
    await tester.pump();
    await tester.tap(find.widgetWithText(FilledButton, 'Add'));
    await tester.pumpAndSettle();

    final lunch =
        container.read(plannerProvider).firstWhere((t) => t.title == 'Lunch');
    expect((lunch.day, lunch.start, lunch.end), (today, 12 * 60, 12 * 60 + 30));
    // The free time splits around it.
    expect(free('12:30–24:00'), findsOneWidget);
    expect(find.text('Lunch'), findsOneWidget);
    expect(find.text('12:00–12:30'), findsOneWidget);
  });

  testWidgets('quick ends: up to the end of the free time, no further',
      (tester) async {
    await openPlanner(tester);
    add(today, 'Gym', hour: 11); // 11:00–12:00
    planner().addTask(today, 'Call', start: 12 * 60 + 20, end: 13 * 60);
    await tester.pump();

    await tester.tap(free('12:00–12:20'));
    await tester.pumpAndSettle();

    ChoiceChip chip(String label) =>
        tester.widget<ChoiceChip>(find.widgetWithText(ChoiceChip, label));
    expect(chip('15 min').onSelected, isNotNull);
    expect(chip('30 min').onSelected, isNull, reason: 'beyond 12:20');
    expect(chip('1 h').onSelected, isNull);
    expect(
      find.widgetWithText(TextButton, '12:20'),
      findsOneWidget,
      reason: 'the default hour is cut at the end of the free time',
    );

    await tester.tap(find.text('Until free time ends'));
    await tester.enterText(find.byKey(const Key('taskTitle')), 'Coffee');
    await tester.tap(find.widgetWithText(FilledButton, 'Add'));
    await tester.pumpAndSettle();
    final coffee =
        container.read(plannerProvider).firstWhere((t) => t.title == 'Coffee');
    expect((coffee.start, coffee.end), (12 * 60, 12 * 60 + 20));
  });

  testWidgets('tapping a day shows its tasks', (tester) async {
    await openPlanner(tester);
    add(today, 'Gym');
    add(tomorrow, 'Dentist');
    await tester.pump();

    await tester.tap(dayCell('Friday 9 October 2026'));
    await tester.pumpAndSettle();
    expect(find.text('Tomorrow · Fri, 9 Oct'), findsOneWidget);
    expect(find.text('Dentist'), findsOneWidget);
    expect(find.text('Gym'), findsNothing);

    await tester.tap(free('13:00–24:00'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const Key('taskTitle')), 'Call mum');
    await tester.tap(find.widgetWithText(FilledButton, 'Add'));
    await tester.pumpAndSettle();
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

  testWidgets('swiping previews days live, before letting go', (tester) async {
    await openPlanner(tester);
    add(tomorrow, 'Dentist');
    await tester.pump();
    final cell = tester.getSize(dayCell('Thursday 8 October 2026')).width;

    final gesture = await tester.startGesture(
      tester.getCenter(find.byType(DayStrip)),
    );
    for (var i = 0; i < 10; i++) {
      await gesture.moveBy(Offset(-cell / 10, 0));
      await tester.pump();
    }
    // Still holding: tomorrow is in the middle and already shown.
    expect(find.text('Tomorrow · Fri, 9 Oct'), findsOneWidget);
    expect(find.text('Dentist'), findsOneWidget);

    await gesture.up();
    await tester.pumpAndSettle();
    expect(find.text('Tomorrow · Fri, 9 Oct'), findsOneWidget);
  });

  testWidgets('days with tasks are marked', (tester) async {
    await openPlanner(tester);
    add(tomorrow, 'Dentist');
    await tester.pump();

    expect(dayCell('Friday 9 October 2026, has tasks'), findsOneWidget);
    expect(dayCell('Thursday 8 October 2026, has tasks'), findsNothing);
  });

  testWidgets('the checkbox in the corner ticks a task off, and back',
      (tester) async {
    await openPlanner(tester);
    add(today, 'Gym');
    await tester.pump();

    final block = tester.getRect(
      find.ancestor(
          of: find.text('Gym'), matching: find.byType(SelectableCard)),
    );
    final box = tester.getRect(find.byType(Checkbox));
    expect(box.top - block.top, lessThan(12), reason: 'at the top');
    expect(block.right - box.right, lessThan(12), reason: 'at the right');

    await tester.tap(find.byType(Checkbox));
    await tester.pump();
    expect(container.read(plannerProvider).single.done, isTrue);
    expect(
      tester.widget<Text>(find.text('Gym')).style!.decoration,
      TextDecoration.lineThrough,
    );

    await tester.tap(find.byType(Checkbox));
    await tester.pump();
    expect(container.read(plannerProvider).single.done, isFalse);
  });

  testWidgets('tapping a block edits it: title and times', (tester) async {
    await openPlanner(tester);
    add(today, 'Gym'); // 12:00–13:00
    add(today, 'Work', hour: 14); // 14:00–15:00
    await tester.pump();

    await tester.tap(find.text('Gym'));
    await tester.pumpAndSettle();
    expect(find.widgetWithText(FilledButton, 'Save'), findsOneWidget);
    expect(
      tester
          .widget<TextField>(find.byKey(const Key('taskTitle')))
          .controller!
          .text,
      'Gym',
    );
    expect(find.widgetWithText(TextButton, '12:00'), findsOneWidget);
    expect(find.widgetWithText(TextButton, '13:00'), findsOneWidget);
    expect(container.read(plannerProvider).first.done, isFalse,
        reason: 'tapping edits, it does not tick off');

    await tester.enterText(find.byKey(const Key('taskTitle')), 'Gym + sauna');
    // Up to the next task: 14:00.
    await tester.tap(find.text('Until free time ends'));
    await tester.pump();
    await tester.tap(find.widgetWithText(FilledButton, 'Save'));
    await tester.pumpAndSettle();

    final gym = container.read(plannerProvider).first;
    expect((gym.title, gym.start, gym.end), ('Gym + sauna', 12 * 60, 14 * 60));
    expect(find.text('12:00–14:00'), findsOneWidget);
  });

  testWidgets('today, a new task starts at the next full hour, not the past',
      (tester) async {
    container =
        await pumpApp(tester, clock: () => DateTime(2026, 10, 8, 12, 20));
    await openTab(tester, 'Planner');

    await tester.ensureVisible(free('00:00–24:00'));
    await tester.pumpAndSettle();
    await tester.tap(free('00:00–24:00'));
    await tester.pumpAndSettle();
    expect(find.widgetWithText(TextButton, '13:00'), findsOneWidget);
    expect(find.widgetWithText(TextButton, '14:00'), findsOneWidget);
  });

  testWidgets('long-press selects; delete removes after confirming',
      (tester) async {
    await openPlanner(tester);
    add(today, 'Gym');
    add(today, 'Groceries', hour: 13);
    add(tomorrow, 'Dentist');
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
    add(today, 'Gym');
    await tester.pump();
    await tester.longPress(find.text('Gym'));
    await tester.pumpAndSettle();

    await tester.tap(dayCell('Friday 9 October 2026'));
    await tester.pumpAndSettle();

    expect(find.text('1 selected'), findsNothing);
  });

  testWidgets('tasks from the first planner (no time) are marked, deletable',
      (tester) async {
    await openPlanner(tester);
    planner().replaceAll([
      PlannerTask(id: 'old', title: 'Old task', day: today),
    ]);
    await tester.pump();

    expect(find.text('Old task'), findsOneWidget);
    expect(find.text('No time (from the old planner)'), findsOneWidget);

    await tester.longPress(find.text('Old task'));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Delete'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilledButton, 'Delete'));
    await tester.pumpAndSettle();
    expect(container.read(plannerProvider), isEmpty);
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
      add(DateTime(2026, 10, 3), 'Unfinished');
      add(DateTime(2026, 10, 1), 'Done long ago');
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
