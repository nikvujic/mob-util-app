import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:the_app/core/clock.dart';
import 'package:the_app/data/app_storage.dart';
import 'package:the_app/data/reminder_scheduler.dart';
import 'package:the_app/providers/medicine_provider.dart';
import 'package:the_app/providers/reminders_provider.dart';

import '../helpers.dart';

/// Reminders are planned two weeks ahead (E1, Round 23): when they'd run
/// on past that, a notice asks to open the app before they stop.
void main() {
  /// Tuesday 13 October 2026, 10:00.
  final now = DateTime(2026, 10, 13, 10);

  Reminder at(DateTime when) =>
      Reminder(at: when, title: 'Dentist', body: 'In 10 minutes');

  List<Reminder> notices(List<Reminder> plan) => [
        for (final r in withKeepGoing(plan, now: now))
          if (r.kind == ReminderKind.notice) r,
      ];

  test('daily ones up to the end: the evening before the last', () {
    final daily = [
      for (var d = 0; d <= reminderDays; d++)
        at(DateTime(2026, 10, 13 + d, 20)),
    ];
    final notice = notices(daily).single;
    expect(notice.at, DateTime(2026, 10, 26, 19));
    expect(notice.target, isNull, reason: 'opening the app is enough');
    final all = withKeepGoing(daily, now: now);
    expect(all, hasLength(daily.length + 1));
    expect(
        all.map((r) => r.at), orderedEquals([...all.map((r) => r.at)]..sort()));
  });

  test('nothing near the end of the two weeks: none', () {
    expect(notices([at(DateTime(2026, 10, 15, 9))]), isEmpty);
    expect(notices(const []), isEmpty);
  });

  test('too many to schedule: cut, with the notice before the last kept', () {
    final many = [
      for (var i = 0; i < maxReminders + 20; i++)
        at(now.add(Duration(minutes: 30 * (i + 1)))),
    ];
    final planned = withKeepGoing(many, now: now);
    expect(planned, hasLength(maxReminders), reason: 'Android allows so many');
    final notice = notices(many).single;
    final lastKept = many[maxReminders - 2].at;
    expect(notice.at,
        DateTime(lastKept.year, lastKept.month, lastKept.day - 1, 19));
  });

  test('a daily medicine: the notice is planned with it', () async {
    final scheduler = FakeReminderScheduler();
    final container = ProviderContainer(overrides: [
      appStorageProvider.overrideWithValue(AppStorage.inMemory()),
      reminderSchedulerProvider.overrideWithValue(scheduler),
      clockProvider.overrideWithValue(() => now),
    ]);
    addTearDown(container.dispose);
    container
        .read(medicineProvider.notifier)
        .add('Iron', times: [20 * 60], from: DateTime(2026, 10, 1));
    await container.read(reminderPlannerProvider).refresh();
    expect(
      scheduler.scheduled.where((r) => r.kind == ReminderKind.notice),
      hasLength(1),
    );
  });
}
