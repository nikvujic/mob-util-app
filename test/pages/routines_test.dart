import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:the_app/providers/planner_provider.dart';
import 'package:the_app/pages/planner/add_task_sheet.dart';
import 'package:the_app/pages/planner/timeline.dart';
import 'package:the_app/providers/routines_provider.dart';
import 'package:the_app/widgets/day_strip.dart';

import '../helpers.dart';

/// Planner routines in the app (P8).
void main() {
  late ProviderContainer container;

  /// Thursday, 8 October 2026, noon.
  final now = DateTime(2026, 10, 8, 12);
  final today = DateTime(2026, 10, 8);
  final tomorrow = DateTime(2026, 10, 9);
  int at(num hours) => (hours * 60).round();

  Future<void> openPlanner(WidgetTester tester) async {
    container = await pumpApp(tester, clock: () => now);
    await openTab(tester, 'Planner');
  }

  RoutinesNotifier routines() => container.read(routinesProvider.notifier);

  /// Gym every day 18–19 from today.
  String addGym() => routines().add(
        title: 'Gym',
        start: at(18),
        end: at(19),
        weekdays: {1, 2, 3, 4, 5, 6, 7},
        from: today,
      )!;

  /// Taps [finder], scrolling to it first (e.g. inside the task sheet).
  Future<void> tapIn(WidgetTester tester, Finder finder) async {
    // Let typing's "keep the cursor in view" scroll happen first.
    await tester.pumpAndSettle();
    await tester.ensureVisible(finder);
    await tester.pumpAndSettle();
    await tester.tap(finder);
    await tester.pumpAndSettle();
  }

  Future<void> tapText(WidgetTester tester, String text) async {
    await tester.ensureVisible(find.text(text).first);
    await tester.pumpAndSettle();
    await tester.tap(find.text(text).first);
    await tester.pumpAndSettle();
  }

  Future<void> showDay(WidgetTester tester, String label) async {
    final cell = find.descendant(
      of: find.byType(DayStrip),
      matching: find.bySemanticsLabel(RegExp(label)),
    );
    await tester.tap(cell.first);
    await tester.pumpAndSettle();
  }

  testWidgets('a task set to repeat becomes a routine, shown with ↻',
      (tester) async {
    await openPlanner(tester);
    await tapText(tester, 'Free · 00:00–24:00');
    await tester.enterText(find.byKey(const Key('taskTitle')), 'Read');
    await tester.pump();
    await tapIn(tester, find.text('Every day'));
    await tester.pump();
    await tapIn(tester, find.widgetWithText(FilledButton, 'Add'));
    await tester.pumpAndSettle();

    expect(container.read(plannerProvider), isEmpty, reason: 'no one-off');
    final routine = container.read(routinesProvider).routines.single;
    expect((routine.title, routine.weekdays.length, routine.from),
        ('Read', 7, today));

    await showDay(tester, 'Friday 9 October');
    expect(find.text('Read'), findsOneWidget);
    // Off-screen blocks aren't read out (a scrolling list): bring it in.
    await tester.ensureVisible(find.text('Read'));
    await tester.pumpAndSettle();
    expect(find.bySemanticsLabel(RegExp('Routine')), findsWidgets);
  });

  testWidgets('skip this day, with undo', (tester) async {
    await openPlanner(tester);
    final id = addGym();
    await tester.pump();

    await tapText(tester, 'Gym');
    await tapText(tester, 'Skip this day');
    expect(find.text('Gym'), findsNothing);
    expect(container.read(routinesProvider).dayOf(id, today)!.skipped, isTrue);

    await tester.tap(find.text('Undo'));
    await tester.pumpAndSettle();
    expect(find.text('Gym'), findsOneWidget);
  });

  testWidgets('change just this day: a one-off takes its place',
      (tester) async {
    await openPlanner(tester);
    final id = addGym();
    await tester.pump();

    await tapText(tester, 'Gym');
    await tapText(tester, 'Change just this day');
    await tester.enterText(find.byKey(const Key('taskTitle')), 'Gym (short)');
    await tester.pump();
    await tester.tap(find.text('30 min'));
    await tester.pump();
    await tapIn(tester, find.widgetWithText(FilledButton, 'Save'));
    await tester.pumpAndSettle();

    final task = container.read(plannerProvider).single;
    expect((task.title, task.start, task.end), ('Gym (short)', at(18), 1110));
    expect(container.read(routinesProvider).dayOf(id, today)!.skipped, isTrue);
    expect(routinesOn(tomorrow, container.read(routinesProvider)), hasLength(1),
        reason: 'other days keep it');
  });

  testWidgets('edit routine from a day changes every day', (tester) async {
    await openPlanner(tester);
    addGym();
    await tester.pump();

    await tapText(tester, 'Gym');
    await tapText(tester, 'Edit routine');
    await tester.enterText(find.byKey(const Key('taskTitle')), 'Run');
    await tester.pump();
    await tapIn(tester, find.widgetWithText(FilledButton, 'Save'));
    await tester.pumpAndSettle();

    expect(container.read(routinesProvider).routines.single.title, 'Run');
    await showDay(tester, 'Friday 9 October');
    expect(find.text('Run'), findsOneWidget);
  });

  testWidgets('editing: Delete on the left, Save right at the edge',
      (tester) async {
    await openPlanner(tester);
    addGym();
    await tester.pump();
    await tapText(tester, 'Gym');
    await tapText(tester, 'Edit routine');

    final sheet = tester.getRect(find.byType(TaskSheet));
    final save = tester.getRect(find.widgetWithText(FilledButton, 'Save'));
    final delete = tester.getRect(find.text('Delete'));
    expect(save.right, moreOrLessEquals(sheet.right - 16, epsilon: 1));
    expect(delete.left, lessThan(sheet.left + 64));
  });

  testWidgets('editing: a newly ticked day that clashes keeps the times',
      (tester) async {
    await openPlanner(tester);
    addGym(); // every day 18–19
    routines().add(
      title: 'Swim',
      start: at(8),
      end: at(9),
      weekdays: {DateTime.thursday},
      from: today,
    );
    routines().add(
      title: 'Run',
      start: at(8.5),
      end: at(9.5),
      weekdays: {DateTime.friday},
      from: today,
    );
    await showDay(tester, 'Friday 9 October');

    await tapText(tester, 'Run');
    await tapText(tester, 'Edit routine');
    await tapIn(tester, find.widgetWithText(FilterChip, 'Thu'));
    await tester.pump();
    // Not moved by itself (Nikola): red, Save off, a button to fit it.
    expect(find.widgetWithText(OutlinedButton, '08:30'), findsOneWidget);
    expect(find.byKey(const Key('timeClash')), findsOneWidget);
    final save = find.widgetWithText(FilledButton, 'Save');
    expect(tester.widget<FilledButton>(save).onPressed, isNull);

    await tapIn(tester, find.byKey(const Key('fitTime')));
    expect(find.widgetWithText(OutlinedButton, '09:00'), findsOneWidget);
    expect(
      tester.widget<Text>(find.byKey(const Key('timeAdjusted'))).data,
      'Now 09:00–10:00: a routine was there.',
    );
    await tapIn(tester, save);
    await tester.pumpAndSettle();

    final run = container
        .read(routinesProvider)
        .routines
        .firstWhere((r) => r.title == 'Run');
    expect(run.start, at(9), reason: 'saved, not lost to a clash');
    expect(run.weekdays, {DateTime.thursday, DateTime.friday});
  });

  // Nikola's case (Mon/Wed/Fri 23:30–23:59, a Tuesday one at the same
  // time, then Wednesday ticked), on days the strip shows: Thursday today,
  // Friday tomorrow.
  testWidgets('ticking a day another routine has there: time stays, Save off',
      (tester) async {
    await openPlanner(tester);
    routines().add(
      title: 'Late',
      start: at(23.5),
      end: at(23.5) + 29,
      weekdays: {1, 3, 5},
      from: today,
    );
    routines().add(
      title: 'Tue',
      start: at(23.5),
      end: at(23.5) + 29,
      weekdays: {DateTime.thursday},
      from: today,
    );
    await tester.pump();
    await tapText(tester, 'Tue');
    await tapText(tester, 'Edit routine');
    await tapIn(tester, find.widgetWithText(FilterChip, 'Fri'));
    await tester.pump();

    expect(find.widgetWithText(OutlinedButton, '23:30'), findsOneWidget);
    expect(find.widgetWithText(OutlinedButton, '23:59'), findsOneWidget);
    expect(find.byKey(const Key('timeClash')), findsOneWidget);
    expect(
      tester
          .widget<FilledButton>(find.widgetWithText(FilledButton, 'Save'))
          .onPressed,
      isNull,
    );
    // Unticking Friday again clears it.
    await tapIn(tester, find.widgetWithText(FilterChip, 'Fri'));
    await tester.pump();
    expect(find.byKey(const Key('timeClash')), findsNothing);
  });

  testWidgets('a clash line that appears doesn\'t move the chip just tapped',
      (tester) async {
    await openPlanner(tester);
    routines().add(
      title: 'Late',
      start: at(23.5),
      end: at(23.5) + 29,
      weekdays: {DateTime.friday},
      from: today,
    );
    routines().add(
      title: 'Mine',
      start: at(23.5),
      end: at(23.5) + 29,
      weekdays: {DateTime.thursday},
      from: today,
    );
    await tester.pump();
    await tapText(tester, 'Mine');
    await tapText(tester, 'Edit routine');
    final fri = find.widgetWithText(FilterChip, 'Fri');
    await tester.ensureVisible(fri);
    await tester.pumpAndSettle();
    final before = tester.getCenter(fri);

    await tester.tap(fri);
    await tester.pump(); // the line appears
    await tester.pump(); // and the form makes up for it
    expect(find.byKey(const Key('timeClash')), findsOneWidget);
    expect(tester.getCenter(fri).dy, moreOrLessEquals(before.dy, epsilon: 1),
        reason: 'still under the finger (Nikola)');

    // The line: red, with its icon; the button at the form's left.
    expect(find.byIcon(Icons.error_outline), findsOneWidget);
    final button = find.byKey(const Key('fitTime'));
    expect(tester.widget(button), isA<OutlinedButton>());
    await tester.ensureVisible(button);
    await tester.pumpAndSettle();
    expect(
        tester.getTopLeft(button).dx,
        moreOrLessEquals(
            tester.getTopLeft(find.byKey(const Key('taskTitle'))).dx,
            epsilon: 1));
  });

  testWidgets('a routine has nothing to tick off (Round 78)', (tester) async {
    await openPlanner(tester);
    addGym();
    await tester.pump();

    // Off-screen blocks aren't in the screen reader's tree: scroll first.
    await tester.ensureVisible(find.text('Gym'));
    await tester.pumpAndSettle();
    expect(find.bySemanticsLabel('Done: Gym'), findsNothing);
    expect(find.byType(Checkbox), findsNothing);
  });

  group('the Routines screen', () {
    Future<void> openRoutines(WidgetTester tester) async {
      await openPlanner(tester);
      await tester.tap(find.byTooltip('Routines'));
      await tester.pumpAndSettle();
    }

    testWidgets('opens on today\'s weekday; days are picked below',
        (tester) async {
      await openRoutines(tester);
      routines().add(
        title: 'Swim',
        start: at(7),
        end: at(8),
        weekdays: {DateTime.tuesday},
        from: today,
      );
      await tester.pump();
      expect(find.text('Every Thursday'), findsOneWidget);
      expect(find.text('Swim'), findsNothing);

      await tester.tap(find.bySemanticsLabel('Tuesday'));
      await tester.pumpAndSettle();
      expect(find.text('Every Tuesday'), findsOneWidget);
      expect(find.text('Swim', skipOffstage: false), findsOneWidget);
    });

    testWidgets('free time adds a routine on that weekday', (tester) async {
      await openRoutines(tester);
      await tapText(tester, 'Free · 00:00–24:00');
      await tester.enterText(find.byKey(const Key('taskTitle')), 'Walk');
      await tester.pump();
      await tapIn(tester, find.widgetWithText(FilterChip, 'Sat'));
      await tester.pump();
      await tapIn(tester, find.widgetWithText(FilledButton, 'Add'));
      await tester.pumpAndSettle();

      final walk = container.read(routinesProvider).routines.single;
      expect(walk.weekdays, {DateTime.thursday, DateTime.saturday});
      expect(walk.from, today);
      expect(find.text('Walk'), findsOneWidget);
    });

    testWidgets('a routine is deleted everywhere, after asking',
        (tester) async {
      await openRoutines(tester);
      addGym();
      await tester.pump();

      await tapText(tester, 'Gym');
      await tapIn(tester, find.text('Delete'));
      await tester.pumpAndSettle();
      expect(find.text('Delete routine?'), findsOneWidget);
      await tapIn(tester, find.widgetWithText(FilledButton, 'Delete'));
      await tester.pumpAndSettle();

      expect(container.read(routinesProvider).routines, isEmpty);
      expect(find.text('Gym'), findsNothing);
    });

    testWidgets('a new routine is purple unless another colour is picked',
        (tester) async {
      await openRoutines(tester);
      await tapText(tester, 'Free · 00:00–24:00');
      await tester.enterText(find.byKey(const Key('taskTitle')), 'Walk');
      await tester.pump();
      await tapIn(tester, find.widgetWithText(FilledButton, 'Add'));
      await tester.pumpAndSettle();
      expect(container.read(routinesProvider).routines.single.color, 'purple');
    });

    testWidgets(
        'ticking a day another routine has: red until a free time is found',
        (tester) async {
      await openRoutines(tester);
      routines().add(
        title: 'Swim',
        start: 0,
        end: at(1),
        weekdays: {DateTime.friday},
        from: today,
      );
      await tester.pump();

      // Thursday's free time starts at 00:00; with Friday ticked too, the
      // new routine (00:00–01:00) would meet Swim there.
      await tapText(tester, 'Free · 00:00–24:00');
      await tester.enterText(find.byKey(const Key('taskTitle')), 'Walk');
      await tester.pump();
      await tapIn(tester, find.widgetWithText(FilterChip, 'Fri'));
      await tester.pump();
      expect(find.byKey(const Key('timeClash')), findsOneWidget);
      await tapIn(tester, find.byKey(const Key('fitTime')));
      expect(
        tester.widget<Text>(find.byKey(const Key('timeAdjusted'))).data,
        'Now 01:00–02:00: a routine was there.',
      );
      await tapIn(tester, find.widgetWithText(FilledButton, 'Add'));
      await tester.pumpAndSettle();

      final walk = container
          .read(routinesProvider)
          .routines
          .firstWhere((r) => r.title == 'Walk');
      expect((walk.start, walk.end), (at(1), at(2)));
    });
  });

  testWidgets('Routines screen: reach mode, as on the planner (Round 17)',
      (tester) async {
    await openPlanner(tester);
    await tester.tap(find.byTooltip('Routines'));
    await tester.pumpAndSettle();
    final midnight = find.text('00:00');
    final free = find.textContaining('Free · ').first;
    await tester.ensureVisible(midnight);
    await tester.pumpAndSettle();
    await tester.drag(free, const Offset(0, 300));
    await tester.pumpAndSettle();
    final atTop = tester.getTopLeft(midnight).dy;

    await tester.drag(free, const Offset(0, 200));
    await tester.pumpAndSettle();
    expect(tester.getTopLeft(midnight).dy, greaterThan(atTop + 100));

    await tester.drag(free, const Offset(0, -40));
    await tester.pumpAndSettle();
    expect(tester.getTopLeft(midnight).dy, moreOrLessEquals(atTop));
  });

  group('Round 16', () {
    testWidgets('Routines screen: a routine starts where free time is tapped',
        (tester) async {
      await openPlanner(tester);
      await tester.tap(find.byTooltip('Routines'));
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.text('14:00').first);
      await tester.pumpAndSettle();
      final timeline = find.byType(PlannerTimeline);
      final scale = PlannerTimeline.scaleFor(
          tester.widget<PlannerTimeline>(timeline).blocks);
      final top = tester.getTopLeft(timeline).dy;
      await tester.tapAt(
          Offset(150, top + PlannerTimeline.offsetOf(14 * 60 + 40, scale)));
      await tester.pumpAndSettle();
      expect(find.widgetWithText(OutlinedButton, '14:30'), findsOneWidget);
      expect(find.widgetWithText(OutlinedButton, '15:30'), findsOneWidget);
    });

    testWidgets('End of day sets the end to midnight', (tester) async {
      await openPlanner(tester);
      addGym();
      await tester.pump();
      await tapText(tester, 'Gym');
      await tapText(tester, 'Edit routine');
      await tapIn(tester, find.byKey(const Key('endOfDay')));
      // Past nothing: no clash; the end reads 24:00 (or 00:00).
      expect(find.byKey(const Key('timeClash')), findsNothing);
      expect(
        tester.widget<ChoiceChip>(find.byKey(const Key('endOfDay'))).selected,
        isTrue,
      );
    });

    testWidgets('End of day past another block shows the clash',
        (tester) async {
      await openPlanner(tester);
      addGym(); // 18–19
      routines().add(
        title: 'Read',
        start: at(21),
        end: at(22),
        weekdays: {1, 2, 3, 4, 5, 6, 7},
        from: today,
      );
      await tester.pump();
      await tapText(tester, 'Gym');
      await tapText(tester, 'Edit routine');
      await tapIn(tester, find.byKey(const Key('endOfDay')));
      expect(find.byKey(const Key('timeClash')), findsOneWidget);
    });
  });
}
