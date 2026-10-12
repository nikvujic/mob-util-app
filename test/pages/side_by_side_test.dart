import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:the_app/pages/planner/timeline.dart';
import 'package:the_app/providers/planner_provider.dart';
import 'package:the_app/providers/routines_provider.dart';
import 'package:the_app/widgets/selection.dart';

import '../helpers.dart';

/// A one-off task and a routine at the same time (P12): side by side, the
/// task left and the routine right; alone, a block takes the full width.
void main() {
  int at(num hours) => (hours * 60).round();

  group('blockPieces', () {
    TimelineBlock block(num from, num to, {bool routine = false}) =>
        TimelineBlock(
          id: '$from',
          title: '$from',
          start: at(from),
          end: at(to),
          repeats: routine,
          onTap: () {},
        );

    test('alone: one full-width piece', () {
      final work = block(10, 12);
      expect(blockPieces(work, [work, block(12, 13)]), [
        (start: at(10), end: at(12), shared: false),
      ]);
    });

    test('a routine inside a task: the task narrows there only', () {
      final work = block(10, 12);
      final pills = block(11, 11.5, routine: true);
      final blocks = [work, pills];
      expect(blockPieces(work, blocks), [
        (start: at(10), end: at(11), shared: false),
        (start: at(11), end: at(11.5), shared: true),
        (start: at(11.5), end: at(12), shared: false),
      ]);
      expect(blockPieces(pills, blocks), [
        (start: at(11), end: at(11.5), shared: true),
      ]);
    });

    test('overlapping ends: each is shared where the other is', () {
      final call = block(9, 11);
      final gym = block(10, 12, routine: true);
      final blocks = [call, gym];
      expect(blockPieces(call, blocks), [
        (start: at(9), end: at(10), shared: false),
        (start: at(10), end: at(11), shared: true),
      ]);
      expect(blockPieces(gym, blocks), [
        (start: at(10), end: at(11), shared: true),
        (start: at(11), end: at(12), shared: false),
      ]);
    });

    test('two routines beside one long task, one after the other', () {
      final work = block(9, 17);
      final a = block(10, 11, routine: true);
      final b = block(11, 12, routine: true);
      expect(blockPieces(work, [work, a, b]), [
        (start: at(9), end: at(10), shared: false),
        (start: at(10), end: at(12), shared: true),
        (start: at(12), end: at(17), shared: false),
      ]);
    });
  });

  group('on the planner', () {
    late ProviderContainer container;

    /// Thursday, 8 October 2026.
    final today = DateTime(2026, 10, 8);

    Future<void> openPlanner(WidgetTester tester) async {
      container = await pumpApp(tester, clock: () => DateTime(2026, 10, 8, 9));
      await openTab(tester, 'Planner');
    }

    PlannerNotifier planner() => container.read(plannerProvider.notifier);

    /// Medicine every day 11:00–11:30.
    String addMedicine() => container.read(routinesProvider.notifier).add(
          title: 'Medicine',
          start: at(11),
          end: at(11.5),
          weekdays: {1, 2, 3, 4, 5, 6, 7},
          from: today,
        )!;

    Future<void> tapText(WidgetTester tester, String text) async {
      await tester.ensureVisible(find.text(text).first);
      await tester.pumpAndSettle();
      await tester.tap(find.text(text).first);
      await tester.pumpAndSettle();
    }

    Rect cardOf(WidgetTester tester, String title) => tester.getRect(
          find.ancestor(
            of: find.text(title),
            matching: find.byType(SelectableCard),
          ),
        );

    /// The y of [minutes] on the timeline, from where [title]'s block
    /// starts ([from]).
    double yIn(Rect card, int from, int minutes) =>
        card.top -
        PlannerTimeline.gap / 2 +
        (minutes - from) * PlannerTimeline.hourHeight / 60;

    testWidgets('side by side where they share time, full width elsewhere',
        (tester) async {
      await openPlanner(tester);
      addMedicine();
      planner().addTask(today, 'Work', start: at(10), end: at(12));
      await tester.pump();

      final work = cardOf(tester, 'Work');
      final medicine = cardOf(tester, 'Medicine');
      final middle = work.center.dx;
      final shared = yIn(work, at(10), at(11.25));
      final alone = yIn(work, at(10), at(10.5));

      // The routine's title is on the right half, the task's on the left.
      expect(tester.getTopLeft(find.text('Medicine')).dx, greaterThan(middle));
      expect(tester.getTopLeft(find.text('Work')).dx, lessThan(middle));
      expect(medicine.left, work.left);

      // Taps go to the block that's there.
      await tester.tapAt(Offset(work.right - 60, shared));
      await tester.pumpAndSettle();
      expect(find.text('Change just this day'), findsOneWidget,
          reason: 'the right half there is the routine');
      await pressBack(tester);

      await tester.tapAt(Offset(work.left + 30, shared));
      await tester.pumpAndSettle();
      expect(find.text('Edit'), findsOneWidget,
          reason: 'the left half is the task (its menu)');
      await pressBack(tester);

      await tester.tapAt(Offset(work.right - 60, alone));
      await tester.pumpAndSettle();
      expect(find.text('Edit'), findsOneWidget,
          reason: 'alone, the task takes the full width');
    });

    testWidgets('each ticks off on its own', (tester) async {
      await openPlanner(tester);
      final id = addMedicine();
      planner().addTask(today, 'Work', start: at(10), end: at(12));
      await tester.pump();

      await tester.tap(find.bySemanticsLabel('Done: Medicine'));
      await tester.pump();
      expect(container.read(routinesProvider).dayOf(id, today)!.done, isTrue);
      expect(container.read(plannerProvider).single.done, isFalse);
    });

    testWidgets('a task added in free time can reach over a routine',
        (tester) async {
      await openPlanner(tester);
      addMedicine();
      planner().addTask(today, 'Lunch', start: at(13), end: at(14));
      await tester.pump();

      await tester.ensureVisible(find.text('Free · 00:00–11:00'));
      await tester.pumpAndSettle();
      // Without a point: from its own rules (a finger picks its time).
      await tapAsScreenReader(tester, find.text('Free · 00:00–11:00'));
      expect(find.widgetWithText(OutlinedButton, '10:00'), findsOneWidget,
          reason: 'an hour by default, within the free time');
      await tester.enterText(find.byKey(const Key('taskTitle')), 'Work');
      await tester.pump();
      await tester.tap(find.text('Until the next task'));
      await tester.pump();
      await tester.tap(find.widgetWithText(FilledButton, 'Add'));
      await tester.pumpAndSettle();

      final work =
          container.read(plannerProvider).firstWhere((t) => t.title == 'Work');
      expect((work.start, work.end), (at(9), at(13)));
      expect(find.text('Medicine'), findsOneWidget, reason: 'still there');
    });

    testWidgets('set to repeat over a routine: red, until a free time is found',
        (tester) async {
      await openPlanner(tester);
      addMedicine();
      planner().addTask(today, 'Lunch', start: at(13), end: at(14));
      await tester.pump();

      await tester.ensureVisible(find.text('Free · 00:00–11:00'));
      await tester.pumpAndSettle();
      await tapAsScreenReader(tester, find.text('Free · 00:00–11:00'));
      await tester.tap(find.text('Until the next task'));
      await tester.pump();
      await tester.ensureVisible(find.text('Every day'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Every day'));
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('timeClash')), findsOneWidget);
      await tester.ensureVisible(find.byKey(const Key('fitTime')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('fitTime')));
      await tester.pumpAndSettle();
      expect(find.widgetWithText(OutlinedButton, '11:00'), findsOneWidget);
      expect(
        tester.widget<Text>(find.byKey(const Key('timeAdjusted'))).data,
        'Now 09:00–11:00: a routine was there.',
      );
      expect(find.text('Until the next routine'), findsOneWidget);
    });

    testWidgets('a task alongside a routine, from the routine', (tester) async {
      await openPlanner(tester);
      addMedicine();
      await tester.pump();

      await tapText(tester, 'Medicine');
      await tapText(tester, 'Add a task alongside');
      expect(find.widgetWithText(OutlinedButton, '11:00'), findsOneWidget);
      expect(find.widgetWithText(OutlinedButton, '11:30'), findsOneWidget);
      await tester.enterText(find.byKey(const Key('taskTitle')), 'Call');
      await tester.pump();
      await tester.tap(find.widgetWithText(FilledButton, 'Add'));
      await tester.pumpAndSettle();

      final call = container.read(plannerProvider).single;
      expect((call.title, call.start, call.end), ('Call', at(11), at(11.5)));
      expect(find.text('Medicine'), findsOneWidget);
      expect(find.text('Call'), findsOneWidget);
    });

    testWidgets('change just this day fits around a task already there',
        (tester) async {
      await openPlanner(tester);
      addMedicine();
      planner().addTask(today, 'Call', start: at(10), end: at(11.25));
      await tester.pump();

      await tapText(tester, 'Medicine');
      await tapText(tester, 'Change just this day');

      expect(find.widgetWithText(OutlinedButton, '11:15'), findsOneWidget);
      expect(
        tester.widget<Text>(find.byKey(const Key('timeAdjusted'))).data,
        'Now 11:15–11:30: a task is there too.',
      );
    });

    testWidgets('no task alongside where tasks fill the routine\'s time',
        (tester) async {
      await openPlanner(tester);
      addMedicine();
      planner().addTask(today, 'Work', start: at(10), end: at(12));
      await tester.pump();

      await tapText(tester, 'Medicine');

      for (final label in ['Add a task alongside', 'Change just this day']) {
        final tile = tester.widget<ListTile>(
          find.ancestor(of: find.text(label), matching: find.byType(ListTile)),
        );
        expect(tile.enabled, isFalse, reason: label);
      }
      expect(find.text('Tasks fill that time'), findsNWidgets(2));
    });
  });
}
