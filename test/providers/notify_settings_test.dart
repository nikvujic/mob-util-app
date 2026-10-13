import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:the_app/core/clock.dart';
import 'package:the_app/core/theme.dart';
import 'package:the_app/data/app_storage.dart';
import 'package:the_app/data/reminder_scheduler.dart';
import 'package:the_app/models/notify_settings.dart';
import 'package:the_app/models/preferences.dart';
import 'package:the_app/providers/medicine_provider.dart';
import 'package:the_app/providers/planner_provider.dart';
import 'package:the_app/providers/preferences_provider.dart';
import 'package:the_app/providers/reminders_provider.dart';

import '../helpers.dart';

/// Each page's notification settings (Round 31).
void main() {
  /// Tuesday 13 October 2026, 10:00.
  final now = DateTime(2026, 10, 13, 10);
  final today = DateTime(2026, 10, 13);

  late FakeReminderScheduler scheduler;
  late ProviderContainer container;

  setUp(() {
    scheduler = FakeReminderScheduler();
    container = ProviderContainer(overrides: [
      appStorageProvider.overrideWithValue(AppStorage.inMemory()),
      reminderSchedulerProvider.overrideWithValue(scheduler),
      clockProvider.overrideWithValue(() => now),
    ]);
    addTearDown(container.dispose);
    // A task with a reminder today and tomorrow; a medicine at 20:00.
    container.read(plannerProvider.notifier)
      ..addTask(today, 'Dentist', start: 15 * 60, end: 16 * 60, remind: 10)
      ..addTask(DateTime(2026, 10, 14), 'Gym',
          start: 18 * 60, end: 19 * 60, remind: 0);
    container
        .read(medicineProvider.notifier)
        .add('Iron', times: [20 * 60], from: today, until: today);
  });

  PreferencesNotifier preferences() =>
      container.read(preferencesProvider.notifier);

  Future<List<Reminder>> planned(ReminderKind kind) async {
    await container.read(reminderPlannerProvider).refresh();
    return [
      for (final r in scheduler.scheduled)
        if (r.kind == kind) r,
    ];
  }

  test('as they were: names shown, no tint', () async {
    final planner = await planned(ReminderKind.planner);
    expect(planner.map((r) => r.title), ['Dentist', 'Gym']);
    expect(planner.map((r) => r.colour), everyElement(isNull));
    expect((await planned(ReminderKind.medicine)).single.title, 'Iron');
  });

  test('the planner off: none from it; Medicine goes on', () async {
    preferences().setPlannerReminders(false);
    expect(await planned(ReminderKind.planner), isEmpty);
    expect(await planned(ReminderKind.medicine), hasLength(1));
  });

  test('the planner paused through today: tomorrow\'s still come', () async {
    preferences().pausePlannerUntil(today);
    expect((await planned(ReminderKind.planner)).map((r) => r.title), ['Gym']);
  });

  test('private: no names (the planner\'s, the medicine\'s)', () async {
    preferences()
      ..setNotifyStyle(NotifyPage.planner, const NotifyStyle(private: true))
      ..setNotifyStyle(NotifyPage.medicine, const NotifyStyle(private: true));
    final planner = await planned(ReminderKind.planner);
    expect(planner.map((r) => '${r.title} ${r.body}'),
        everyElement(isNot(anyOf(contains('Dentist'), contains('Gym')))));
    final medicine = (await planned(ReminderKind.medicine)).single;
    expect('${medicine.title} ${medicine.body}', isNot(contains('Iron')));
  });

  test('a page\'s tint is on its notifications only', () async {
    preferences().setNotifyStyle(
        NotifyPage.medicine, const NotifyStyle(colour: 'green'));
    expect((await planned(ReminderKind.medicine)).single.colour,
        BlockColor.green.stripe);
    expect((await planned(ReminderKind.planner)).map((r) => r.colour),
        everyElement(isNull));
  });

  test('kept in preferences.json; a page from a newer app is skipped', () {
    final saved = Preferences(
      plannerReminders: false,
      plannerPausedUntil: today,
      notifyStyles: const {
        NotifyPage.planner: NotifyStyle(private: true, colour: 'blue'),
        NotifyPage.backup: NotifyStyle(sound: NotifySound.chime),
      },
    ).toJson();
    final back = Preferences.fromJson({
      ...saved,
      'notifyStyles': {
        ...saved['notifyStyles'] as Map<String, dynamic>,
        'weather': {'private': true},
      },
    });
    expect(back.plannerReminders, isFalse);
    expect(back.plannerPausedOn(today), isTrue);
    expect(back.plannerPausedOn(DateTime(2026, 10, 14)), isFalse);
    expect(back.styleOf(NotifyPage.planner),
        const NotifyStyle(private: true, colour: 'blue'));
    expect(back.styleOf(NotifyPage.backup).sound, NotifySound.chime);
    expect(back.styleOf(NotifyPage.medicine), NotifyStyle.plain);
    expect(back.notifyStyles.keys, hasLength(2));
    // Older files: all as before.
    final old = Preferences.fromJson(const {'theme': 'clay'});
    expect(old.plannerReminders, isTrue);
    expect(old.notifyStyles, isEmpty);
  });
}
