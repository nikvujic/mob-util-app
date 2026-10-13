import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:the_app/core/clock.dart';
import 'package:the_app/data/reminder_scheduler.dart';
import 'package:the_app/models/notification_target.dart';
import 'package:the_app/models/preferences.dart';
import 'package:the_app/providers/preferences_provider.dart';

/// The time of day a backup reminder comes, in minutes past midnight: in
/// the evening, when there's time for it.
const backupReminderAt = 19 * 60;

/// How often it comes again while no backup is made.
const backupNudgeEvery = 3;

/// The backup reminders (D8) after [now] for the next [days] days: the
/// first evening (at [backupReminderAt]) once a backup is due, then every
/// [backupNudgeEvery] days until one is made. None while it's off.
List<Reminder> planBackupReminders({
  required DateTime now,
  required Preferences preferences,
  required int days,
}) {
  final due = preferences.backupDueAt;
  if (due == null) return const [];
  // The first evening at or after it's due, then every few days.
  DateTime evening(DateTime day, int plusDays) =>
      DateTime(day.year, day.month, day.day + plusDays, 0, backupReminderAt);
  var at = evening(due, 0);
  if (at.isBefore(due)) at = evening(due, 1);
  final until = now.add(Duration(days: days));
  final reminders = <Reminder>[];
  for (; !at.isAfter(until); at = evening(at, backupNudgeEvery)) {
    if (!at.isAfter(now)) continue;
    reminders.add(
      Reminder(
        at: at,
        kind: ReminderKind.backup,
        target: const BackupTarget().payload,
        title: 'Time for a backup',
        body: preferences.lastBackupAt == null
            ? 'No backup yet. Export one so nothing is lost with the phone.'
            : 'A week since the last one. Export a new one.',
      ),
    );
  }
  return reminders;
}

/// Whether a backup is due now (D8): a dot on the menu button and on
/// Backup. The home screen looks again every half minute and when the app
/// comes back.
final backupDueProvider = Provider<bool>((ref) {
  final preferences = ref.watch(preferencesProvider);
  return preferences.backupDueBy(ref.watch(clockProvider)());
});
