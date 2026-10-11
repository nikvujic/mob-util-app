import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:the_app/providers/pins_provider.dart';
import 'package:the_app/providers/planner_provider.dart';
import 'package:the_app/widgets/day_strip.dart';

import '../helpers.dart';

/// Planner reminders (P14): a title at a time, no end, floating over the
/// timeline; ticked off, they're gone.
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

  testWidgets('the bell button adds one, from the next full hour',
      (tester) async {
    await openPlanner(tester);
    await tester.tap(find.byTooltip('Add reminder'));
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
    expect(find.text('Call mum'), findsOneWidget);
    expect(container.read(plannerProvider), isEmpty, reason: 'not a task');
    expect(
      scheduler.scheduled.map((r) => r.title),
      ['Call mum'],
      reason: 'it notifies at its time',
    );
  });

  testWidgets('it can be at any minute, 23:59 too', (tester) async {
    await openPlanner(tester);
    await tester.tap(find.byTooltip('Add reminder'));
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
    expect(find.text('Call mum'), findsOneWidget);
    // Drawn over the task, at its time.
    final pin = tester.getRect(find.text('Call mum'));
    final work = tester.getRect(find.text('Work'));
    expect(pin.top, greaterThan(work.top));
  });

  testWidgets('ticking it off deletes it, with undo', (tester) async {
    await openPlanner(tester);
    pins().add(today, 'Call mum', time: at(11));
    await tester.pump();

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

    await tester.tap(find.text('Call mum'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const Key('taskTitle')), 'Call dad');
    await tester.pump();
    await tester.tap(find.widgetWithText(FilledButton, 'Save'));
    await tester.pumpAndSettle();
    expect(container.read(pinsProvider).single.title, 'Call dad');

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
    expect(find.text('Old one'), findsNothing, reason: 'not carried over');
  });

  testWidgets('two at about the same time don\'t cover each other',
      (tester) async {
    await openPlanner(tester);
    pins()
      ..add(today, 'One', time: at(11))
      ..add(today, 'Two', time: at(11) + 5);
    await tester.pump();

    final one = tester.getRect(find.text('One'));
    final two = tester.getRect(find.text('Two'));
    expect(two.top - one.top, greaterThanOrEqualTo(48));
  });
}
