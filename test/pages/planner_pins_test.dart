import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:the_app/providers/pins_provider.dart';
import 'package:the_app/providers/planner_provider.dart';
import 'package:the_app/widgets/day_strip.dart';
import 'package:the_app/widgets/selection.dart';

import 'package:the_app/pages/planner/timeline.dart';

import '../helpers.dart';

/// Planner reminders (P14): a title at a time, no end, shown as a mark on
/// the timeline's left edge; ticked off, they're gone.
void main() {
  late ProviderContainer container;
  late FakeReminderScheduler scheduler;

  /// Thursday 8 October 2026, 10:20.
  final today = DateTime(2026, 10, 8);
  int at(num hours) => (hours * 60).round();

  Future<void> openPlanner(WidgetTester tester) async {
    scheduler = FakeReminderScheduler();
    container = await pumpApp(
      tester,
      clock: () => DateTime(2026, 10, 8, 10, 20),
      reminders: scheduler,
    );
    await openTab(tester, 'Planner');
  }

  PinsNotifier pins() => container.read(pinsProvider.notifier);

  /// The mark of the reminder [title].
  Finder mark(String title) =>
      find.bySemanticsLabel(RegExp('Reminder: $title'));

  /// Taps the mark of [title]: its menu opens.
  Future<void> openMark(WidgetTester tester, String title) async {
    await tester.tap(mark(title));
    await tester.pumpAndSettle();
  }

  testWidgets('the bell button adds one, from the next full hour',
      (tester) async {
    await openPlanner(tester);
    await tester.tap(find.byTooltip('Reminders'));
    await tester.pumpAndSettle();

    expect(find.text('At'), findsOneWidget);
    expect(find.widgetWithText(OutlinedButton, '11:00'), findsOneWidget);
    expect(find.text('to'), findsNothing, reason: 'no end');
    expect(find.text('Remind'), findsNothing, reason: 'it is the reminder');
    await tester.enterText(find.byKey(const Key('taskTitle')), 'Call mum');
    await tester.pump();
    await tester.tap(find.widgetWithText(FilledButton, 'Add'));
    await tester.pumpAndSettle();

    final pin = container.read(pinsProvider).single;
    expect((pin.title, pin.day, pin.time), ('Call mum', today, at(11)));
    expect(mark('Call mum at 11:00'), findsOneWidget);
    expect(container.read(plannerProvider), isEmpty, reason: 'not a task');
    expect(
      scheduler.scheduled.map((r) => r.title),
      ['Call mum'],
      reason: 'it notifies at its time',
    );
  });

  testWidgets('it can be at any minute, 23:59 too', (tester) async {
    await openPlanner(tester);
    await tester.tap(find.byTooltip('Reminders'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(OutlinedButton, '11:00'));
    await tester.pumpAndSettle();
    await tester.tap(find.byIcon(Icons.keyboard_outlined));
    await tester.pumpAndSettle();
    final fields = find.byType(TextFormField);
    await tester.enterText(fields.at(0), '23');
    await tester.enterText(fields.at(1), '59');
    await tester.tap(find.text('OK'));
    await tester.pumpAndSettle();

    expect(find.widgetWithText(OutlinedButton, '23:59'), findsOneWidget);
    expect(find.byKey(const Key('timeAdjusted')), findsNothing,
        reason: 'a reminder has no length');
  });

  testWidgets('it takes no time: free time and tasks stay as they are',
      (tester) async {
    await openPlanner(tester);
    container
        .read(plannerProvider.notifier)
        .addTask(today, 'Work', start: at(10), end: at(12));
    pins().add(today, 'Call mum', time: at(11));
    await tester.pump();

    expect(find.text('Free · 12:00–24:00'), findsOneWidget);
    // A task can still go right where it is.
    container
        .read(plannerProvider.notifier)
        .addTask(today, 'Lunch', start: at(12), end: at(13));
    // A mark on the left edge at its time: it covers nothing.
    final pin = tester.getRect(mark('Call mum'));
    final work = tester.getRect(find.ancestor(
      of: find.text('Work'),
      matching: find.byType(SelectableCard),
    ));
    expect(pin.right, lessThanOrEqualTo(work.left));
    expect(pin.center.dy, greaterThan(work.top));
    expect(pin.center.dy, lessThan(work.bottom));
  });

  testWidgets('ticking it off deletes it, with undo', (tester) async {
    await openPlanner(tester);
    pins().add(today, 'Call mum', time: at(11));
    await tester.pump();

    await openMark(tester, 'Call mum');
    expect(find.text('Reminder at 11:00'), findsOneWidget);
    await tester.tap(find.bySemanticsLabel('Done: Call mum'));
    await tester.pumpAndSettle();
    expect(container.read(pinsProvider), isEmpty);
    expect(find.text('Call mum: done'), findsOneWidget);

    await tester.tap(find.text('Undo'));
    await tester.pumpAndSettle();
    expect(container.read(pinsProvider).single.title, 'Call mum');
  });

  testWidgets('tapping it edits it, or deletes it', (tester) async {
    await openPlanner(tester);
    pins().add(today, 'Call mum', time: at(11));
    await tester.pump();

    await openMark(tester, 'Call mum');
    await tester.tap(find.text('Call mum'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const Key('taskTitle')), 'Call dad');
    await tester.pump();
    await tester.tap(find.widgetWithText(FilledButton, 'Save'));
    await tester.pumpAndSettle();
    expect(container.read(pinsProvider).single.title, 'Call dad');

    await openMark(tester, 'Call dad');
    await tester.tap(find.text('Call dad'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Delete'));
    await tester.pumpAndSettle();
    expect(container.read(pinsProvider), isEmpty);
    expect(find.text('Call dad: deleted'), findsOneWidget);
  });

  testWidgets('unticked, it stays on its day, which stays reachable',
      (tester) async {
    await openPlanner(tester);
    pins().add(DateTime(2026, 10, 1), 'Old one', time: at(9));
    await tester.pump();

    expect(
      tester.widget<DayStrip>(find.byType(DayStrip)).firstDay,
      DateTime(2026, 10, 1),
      reason: 'the strip reaches back to it',
    );
    expect(mark('Old one'), findsNothing, reason: 'not carried over');
  });

  testWidgets('close together they share a mark that lists them',
      (tester) async {
    await openPlanner(tester);
    pins()
      ..add(today, 'One', time: at(11))
      ..add(today, 'Two', time: at(11) + 5)
      ..add(today, 'Later', time: at(12));
    await tester.pump();

    final both = find.bySemanticsLabel('2 reminders from 11:00');
    expect(both, findsOneWidget);
    expect(mark('Later'), findsOneWidget, reason: 'far enough: its own');
    await tester.tap(both);
    await tester.pumpAndSettle();
    expect(find.text('One'), findsOneWidget);
    expect(find.text('Two'), findsOneWidget);

    await tester.tap(find.bySemanticsLabel('Done: Two'));
    await tester.pumpAndSettle();
    expect(container.read(pinsProvider).map((p) => p.title), ['One', 'Later']);
    expect(mark('One at 11:00'), findsOneWidget, reason: 'alone again');
  });

  group('marks (Round 19)', () {
    testWidgets('20 minutes apart: a mark each (they used to merge)',
        (tester) async {
      await openPlanner(tester);
      pins()
        ..add(today, 'One', time: at(11))
        ..add(today, 'Two', time: at(11) + 20);
      await tester.pump();
      expect(mark('One at 11:00'), findsOneWidget);
      expect(mark('Two at 11:20'), findsOneWidget);
      expect(find.byKey(const Key('pinCount')), findsNothing);
    });

    testWidgets('close marks: a tap goes to the nearer one', (tester) async {
      await openPlanner(tester);
      pins()
        ..add(today, 'One', time: at(11))
        ..add(today, 'Two', time: at(11) + 20);
      await tester.pump();
      await tester.ensureVisible(mark('One at 11:00'));
      await tester.pumpAndSettle();
      final one = tester.getCenter(mark('One at 11:00'));
      final two = tester.getCenter(mark('Two at 11:20'));
      expect(two.dy - one.dy, lessThan(48), reason: 'their targets overlap');

      // In the overlap, just above halfway: One.
      final half = (two.dy - one.dy) / 2;
      expect(one.dy + half - 3, greaterThan(two.dy - 24),
          reason: 'inside Two\'s target too');
      await tester.tapAt(one + Offset(0, half - 3));
      await tester.pumpAndSettle();
      expect(find.text('One'), findsOneWidget);
      expect(find.text('Two'), findsNothing);
      await tester.tapAt(const Offset(5, 5)); // close the menu
      await tester.pumpAndSettle();

      // In the overlap, just below halfway: Two.
      await tester.tapAt(two - Offset(0, half - 3));
      await tester.pumpAndSettle();
      expect(find.text('Two'), findsOneWidget);
      expect(find.text('One'), findsNothing);
    });

    testWidgets('the bell a bit bigger', (tester) async {
      await openPlanner(tester);
      pins().add(today, 'One', time: at(11));
      await tester.pump();
      final bell = find.descendant(
        of: find.byType(PlannerTimeline),
        matching: find.byIcon(Icons.notifications),
      );
      expect(tester.getSize(bell).height, 20);
    });
  });

  group('the reminders list (Round 70)', () {
    final list = find.text('Reminders');

    Future<void> openList(WidgetTester tester) async {
      await tester.tap(find.byTooltip('Reminders'));
      await tester.pumpAndSettle();
    }

    String subtitleOf(WidgetTester tester, String title) {
      final tile = tester.widget<CheckboxListTile>(find.ancestor(
          of: find.text(title), matching: find.byType(CheckboxListTile)));
      return (tile.subtitle! as Text).data!;
    }

    testWidgets('every one, the next first with its day and time; gone by last',
        (tester) async {
      await openPlanner(tester);
      pins()
        ..add(today.add(const Duration(days: 3)), 'Dentist', time: at(9))
        ..add(today, 'Call mum', time: at(18.5))
        ..add(today, 'Tea', time: at(11))
        ..add(today.add(const Duration(days: 1)), 'Bins', time: at(7))
        ..add(today.subtract(const Duration(days: 1)), 'Old', time: at(20))
        ..add(today, 'Missed', time: at(8));
      await openList(tester);
      expect(list, findsOneWidget);
      final titles = tester
          .widgetList<CheckboxListTile>(find.byType(CheckboxListTile))
          .map((t) => (t.title as Text).data)
          .toList();
      expect(titles, ['Tea', 'Call mum', 'Bins', 'Dentist', 'Missed', 'Old']);
      expect(subtitleOf(tester, 'Tea'), 'Next · Today · 11:00');
      expect(subtitleOf(tester, 'Call mum'), 'Today · 18:30');
      expect(subtitleOf(tester, 'Bins'), 'Tomorrow · 07:00');
      expect(subtitleOf(tester, 'Dentist'), 'Sun, 11 Oct · 09:00');
      expect(subtitleOf(tester, 'Missed'), 'Today · 08:00');
      expect(subtitleOf(tester, 'Old'), 'Yesterday · 20:00');
      expect(find.text('Gone by, not ticked off'), findsOneWidget);
    });

    testWidgets('several ticked and deleted at once, with Undo',
        (tester) async {
      await openPlanner(tester);
      pins()
        ..add(today, 'Tea', time: at(11))
        ..add(today, 'Call mum', time: at(18))
        ..add(today, 'Bins', time: at(20));
      await openList(tester);
      expect(find.byKey(const Key('remindersDelete')), findsNothing);
      await tester.tap(find.text('Tea'));
      await tester.tap(find.text('Bins'));
      await tester.pump();
      expect(find.text('Delete 2'), findsOneWidget);
      await tester.tap(find.text('Bins'));
      await tester.pump();
      expect(find.text('Delete 1'), findsOneWidget);
      await tester.tap(find.text('Bins'));
      await tester.pump();
      await tester.tap(find.byKey(const Key('remindersDelete')));
      await tester.pumpAndSettle();
      expect(list, findsNothing);
      expect(container.read(pinsProvider).map((p) => p.title), ['Call mum']);
      expect(find.text('2 reminders deleted'), findsOneWidget);
      await tester.tap(find.text('Undo'));
      await tester.pumpAndSettle();
      expect(container.read(pinsProvider).map((p) => p.title),
          unorderedEquals(['Tea', 'Call mum', 'Bins']));
    });

    testWidgets('one deleted: its name in the toast', (tester) async {
      await openPlanner(tester);
      pins().add(today, 'Tea', time: at(11));
      await openList(tester);
      await tester.tap(find.text('Tea'));
      await tester.pump();
      await tester.tap(find.byKey(const Key('remindersDelete')));
      await tester.pumpAndSettle();
      expect(find.text('Tea: deleted'), findsOneWidget);
      expect(container.read(pinsProvider), isEmpty);
    });

    testWidgets('Add reminder from the list; with none, straight to adding',
        (tester) async {
      await openPlanner(tester);
      await openList(tester);
      expect(list, findsNothing);
      expect(find.text('At'), findsOneWidget, reason: 'the add sheet');
      await pressBack(tester);

      pins().add(today, 'Tea', time: at(11));
      await openList(tester);
      expect(list, findsOneWidget);
      await tester.tap(find.byKey(const Key('remindersAdd')));
      await tester.pumpAndSettle();
      expect(list, findsNothing);
      expect(find.text('At'), findsOneWidget);
    });
  });
}
