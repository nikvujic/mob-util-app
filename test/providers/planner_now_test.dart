import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:the_app/data/reminder_scheduler.dart';
import 'package:the_app/models/notification_target.dart';
import 'package:the_app/models/planner_task.dart';
import 'package:the_app/models/preferences.dart';
import 'package:the_app/models/routine.dart';
import 'package:the_app/providers/notification_log_provider.dart';
import 'package:the_app/providers/planner_provider.dart';
import 'package:the_app/providers/preferences_provider.dart';
import 'package:the_app/providers/reminders_provider.dart';
import 'package:the_app/providers/routines_provider.dart';

import '../helpers.dart';

/// The planner's notification that stays while a block is on (Round 72):
/// from its start till its end, counting down, with Done to tick it.
void main() {
  /// Thursday 8 October 2026, 12:00.
  final now = DateTime(2026, 10, 8, 12);
  final today = DateTime(2026, 10, 8);
  int at(num hours) => (hours * 60).round();

  PlannerTask task(String title,
          {required num from, num? to, bool done = false}) =>
      PlannerTask(
        id: title,
        title: title,
        day: today,
        start: at(from),
        end: at(to ?? from + 1),
        done: done,
      );

  List<Reminder> nowOnes(List<Reminder> reminders) => [
        for (final r in reminders)
          if (r.kind == ReminderKind.plannerNow) r
      ];

  test(
      'every block not ticked, from its start to its end; one on now shows '
      'at once', () {
    final reminders = nowOnes(planReminders(
      now: now,
      tasks: [
        task('Work', from: 11, to: 13),
        task('Lunch', from: 13, to: 14),
        task('Done', from: 15, done: true),
        task('Gone by', from: 9, to: 10),
      ],
      routines: RoutineBook.empty,
      onNow: true,
    ));
    expect(reminders.map((r) => (r.title, r.at, r.until, r.onNow)), [
      ('Work', DateTime(2026, 10, 8, 11), DateTime(2026, 10, 8, 13), true),
      ('Lunch', DateTime(2026, 10, 8, 13), DateTime(2026, 10, 8, 14), false),
    ]);
    expect(reminders.last.body, 'Now · 13:00–14:00');
    expect(
        NotificationTarget.parse(reminders.last.target),
        PlannerNowTarget(
            routine: false, id: 'Lunch', day: today, minutes: at(13)));
  });

  test('routines too (not ticked); none while it\'s off; private: no names',
      () {
    final gym = Routine(
      id: 'gym',
      title: 'Gym',
      start: at(18),
      end: at(19),
      weekdays: {DateTime.thursday},
      from: today,
      until: today,
    );
    final book = RoutineBook(routines: [gym], days: const {});
    final on = nowOnes(
        planReminders(now: now, tasks: const [], routines: book, onNow: true));
    expect(on.single.title, 'Gym');
    expect(
        (NotificationTarget.parse(on.single.target) as PlannerNowTarget)
            .routine,
        isTrue);
    // Round 78: nothing to tick off: no Done button; an old tick (from
    // before) changes nothing.
    expect(on.single.done, isFalse);
    expect(
        NotificationReminderScheduler.detailsFor(on.single).actions, isEmpty);
    final ticked = RoutineDay(routineId: 'gym', day: today, done: true);
    expect(
        nowOnes(planReminders(
            now: now,
            tasks: const [],
            routines: RoutineBook(routines: [gym], days: {ticked.key: ticked}),
            onNow: true)),
        hasLength(1));
    expect(nowOnes(planReminders(now: now, tasks: const [], routines: book)),
        isEmpty,
        reason: 'off');
    final private = nowOnes(planReminders(
        now: now,
        tasks: const [],
        routines: book,
        onNow: true,
        hideTitles: true));
    expect((private.single.title, private.single.body),
        ('Planner', 'A block is on · 18:00–19:00'));
  });

  test('what it carries: the block, and Done', () {
    final target =
        PlannerNowTarget(routine: true, id: 'gym', day: today, minutes: at(18));
    expect(target.payload, 'now|routine|gym|2026-10-08|1080');
    expect(NotificationTarget.parse(target.payload), target);
    final done = NotificationTarget.parse('${target.payload}|done');
    expect((done as PlannerNowTarget).done, isTrue);
    expect(done.at, PlannerTarget(today, at(18)));
    expect(NotificationTarget.parse('now|thing|x|2026-10-08|60'), isNull);
    expect(NotificationTarget.parse('now|task|x|2026-10-08|60|later'), isNull);
  });

  test('on Android: stays, quiet, counts down, gone at its end, with Done', () {
    final reminder = Reminder(
      at: DateTime(2026, 10, 8, 13),
      title: 'Lunch',
      body: 'Now',
      kind: ReminderKind.plannerNow,
      until: DateTime(2026, 10, 8, 14),
    );
    final details = NotificationReminderScheduler.detailsFor(reminder);
    expect(details.channelId, 'planner-now');
    expect((details.ongoing, details.autoCancel, details.playSound),
        (true, false, false));
    expect(details.importance, Importance.low);
    expect(details.timeoutAfter, const Duration(hours: 1).inMilliseconds);
    expect(
        (details.usesChronometer, details.chronometerCountDown), (true, true));
    expect(details.when, DateTime(2026, 10, 8, 14).millisecondsSinceEpoch);
    expect(
        details.actions!.single.id, NotificationReminderScheduler.doneAction);
    final already = NotificationReminderScheduler.detailsFor(
        Reminder(
          at: DateTime(2026, 10, 8, 11),
          title: 'Work',
          body: 'Now',
          kind: ReminderKind.plannerNow,
          until: DateTime(2026, 10, 8, 13),
          onNow: true,
        ),
        now: now);
    expect(already.timeoutAfter, const Duration(hours: 1).inMilliseconds,
        reason: 'shown now: what\'s left of it');
  });

  group('in the app', () {
    late ProviderContainer container;
    late FakeReminderScheduler scheduler;

    Future<void> start(WidgetTester tester, {bool on = true}) async {
      scheduler = FakeReminderScheduler();
      container = await pumpApp(tester,
          clock: () => now,
          reminders: scheduler,
          preferences: Preferences(plannerNow: on));
      await tester.pumpAndSettle();
    }

    testWidgets(
        'planned with the rest, not in the history; Notifications turns it '
        'off', (tester) async {
      await start(tester);
      container
          .read(plannerProvider.notifier)
          .addTask(today, 'Lunch', start: at(13), end: at(14));
      await tester.pumpAndSettle();
      expect(nowOnes(scheduler.scheduled).single.title, 'Lunch');
      final log = container.read(notificationLogProvider);
      expect(log.scheduled.where((n) => n.kind == 'plannerNow'), isEmpty);

      await openMenu(tester);
      await tester.tap(find.text('Notifications'));
      await tester.pumpAndSettle();
      final setting = find.byKey(const Key('notifyNow-planner'));
      await tester.ensureVisible(setting);
      await tester.tap(setting);
      await tester.pumpAndSettle();
      expect(container.read(preferencesProvider).plannerNow, isFalse);
      expect(nowOnes(scheduler.scheduled), isEmpty);
      expect(
          Preferences.fromJson(container.read(preferencesProvider).toJson())
              .plannerNow,
          isFalse);
    });

    testWidgets('its Done ticks the block, and opens the planner at it',
        (tester) async {
      await start(tester);
      container
          .read(plannerProvider.notifier)
          .addTask(today, 'Work', start: at(11), end: at(13));
      await tester.pumpAndSettle();
      final id = container.read(plannerProvider).single.id;
      final target = nowOnes(scheduler.scheduled).single.target!;
      // Tapped: only opens it.
      scheduler.taps.add(target);
      await tester.pumpAndSettle();
      expect(container.read(plannerProvider).single.done, isFalse);
      expect(find.text('Work'), findsWidgets);
      // Done: ticked, and its notification no longer planned.
      scheduler.taps.add('$target|done');
      await tester.pumpAndSettle();
      expect(container.read(plannerProvider).single.done, isTrue);
      expect(nowOnes(scheduler.scheduled), isEmpty);
      // Done again (an old tap): still ticked, not unticked.
      scheduler.taps.add('$target|done');
      await tester.pumpAndSettle();
      expect(
          container.read(plannerProvider).singleWhere((t) => t.id == id).done,
          isTrue);
    });

    testWidgets(
        'Round 78: an old routine notification\'s Done just opens the '
        'planner (routines aren\'t ticked off)', (tester) async {
      await start(tester);
      container.read(routinesProvider.notifier).replaceAll(RoutineBook(
            routines: [
              Routine(
                id: 'gym',
                title: 'Gym',
                start: at(18),
                end: at(19),
                weekdays: {DateTime.thursday},
                from: today,
              ),
            ],
            days: const {},
          ));
      await tester.pumpAndSettle();
      final target = nowOnes(scheduler.scheduled).first.target!;
      scheduler.taps.add('$target|done');
      await tester.pumpAndSettle();
      expect(container.read(routinesProvider).days, isEmpty);
      expect(find.text('Gym'), findsWidgets);
    });
  });
}
