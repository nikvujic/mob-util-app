import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:the_app/core/clock.dart';
import 'package:the_app/data/app_storage.dart';
import 'package:the_app/data/reminder_scheduler.dart';
import 'package:the_app/models/notification_log.dart';
import 'package:the_app/providers/notification_log_provider.dart';
import 'package:the_app/providers/planner_provider.dart';
import 'package:the_app/providers/reminders_provider.dart';

import '../helpers.dart';

/// The notifications' history (Round 31): what was scheduled, once its
/// time has come.
void main() {
  LoggedNotification n(DateTime at, String title) =>
      LoggedNotification(at: at, title: title, body: '', kind: 'planner');

  group('the log', () {
    final now = DateTime(2026, 10, 13, 12);
    final log = NotificationLog().planned([
      n(DateTime(2026, 10, 13, 9), 'Not yet when planned'),
    ], DateTime(2026, 10, 11, 8)).planned([
      n(DateTime(2026, 10, 11, 9), 'The day before yesterday'),
      n(DateTime(2026, 10, 12, 9), 'Yesterday'),
      n(DateTime(2026, 10, 13, 11), 'This morning'),
      n(DateTime(2026, 10, 13, 15), 'Later today'),
    ], DateTime(2026, 10, 10));

    test('history: today and yesterday, come already, newest first', () {
      expect(log.historyAt(now).map((x) => x.title),
          ['This morning', 'Yesterday']);
    });

    test('planned again: what was shown stays, the old plan goes', () {
      final again = log.planned([
        n(DateTime(2026, 10, 13, 18), 'New this evening'),
      ], now);
      expect(again.scheduled.map((x) => x.title),
          ['Yesterday', 'This morning', 'New this evening']);
      expect(again.historyAt(DateTime(2026, 10, 13, 19)).map((x) => x.title),
          ['New this evening', 'This morning', 'Yesterday']);
    });

    test('cleared: nothing from before, new ones show', () {
      final cleared = log.clearedAtTime(now);
      expect(cleared.historyAt(now), isEmpty);
      expect(cleared.historyAt(DateTime(2026, 10, 13, 16)).map((x) => x.title),
          ['Later today']);
    });

    test('kept as JSON', () {
      final back = NotificationLog.fromJson(log.clearedAtTime(now).toJson());
      expect(back.scheduled.map((x) => (x.at, x.title)),
          log.scheduled.map((x) => (x.at, x.title)));
      expect(back.clearedAt, now);
    });
  });

  group('kept by the reminder planner', () {
    var now = DateTime(2026, 10, 13, 10);
    late FakeReminderScheduler scheduler;
    late ProviderContainer container;

    setUp(() {
      now = DateTime(2026, 10, 13, 10);
      scheduler = FakeReminderScheduler();
      container = ProviderContainer(overrides: [
        appStorageProvider.overrideWithValue(AppStorage.inMemory()),
        reminderSchedulerProvider.overrideWithValue(scheduler),
        clockProvider.overrideWithValue(() => now),
      ]);
      addTearDown(container.dispose);
    });

    List<String> history() => [
          for (final x
              in container.read(notificationLogProvider).historyAt(now))
            x.title,
        ];

    test('shown once its time has come; stays when its task goes', () async {
      container.read(plannerProvider.notifier).addTask(
          DateTime(2026, 10, 13), 'Dentist',
          start: 11 * 60, end: 12 * 60, remind: 0);
      await container.read(reminderPlannerProvider).refresh();
      expect(history(), isEmpty, reason: 'not yet');

      now = DateTime(2026, 10, 13, 11, 30);
      expect(history(), ['Dentist']);
      final task = container.read(plannerProvider).single;
      container.read(plannerProvider.notifier).removeTasks({task.id});
      await container.read(reminderPlannerProvider).refresh();
      expect(history(), ['Dentist'], reason: 'it was shown');
    });

    test('notifications not allowed: nothing kept', () async {
      scheduler.allowed = false;
      await container.read(notificationsAllowedProvider.future);
      container.read(plannerProvider.notifier).addTask(
          DateTime(2026, 10, 13), 'Dentist',
          start: 11 * 60, end: 12 * 60, remind: 0);
      await container.read(reminderPlannerProvider).refresh();
      now = DateTime(2026, 10, 13, 11, 30);
      expect(history(), isEmpty);
    });
  });
}
