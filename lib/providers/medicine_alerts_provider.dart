import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:the_app/core/clock.dart';
import 'package:the_app/core/format.dart';
import 'package:the_app/data/reminder_scheduler.dart';
import 'package:the_app/models/medicine.dart';
import 'package:the_app/models/notification_target.dart';
import 'package:the_app/models/preferences.dart';
import 'package:the_app/providers/medicine_provider.dart';
import 'package:the_app/providers/preferences_provider.dart';

/// The medicine reminders (O13) due after [now] for the next [days] days:
/// one at each dose time not yet marked, and for a medicine with a
/// follow-up (Round 16), another that many minutes later. None while off
/// or paused ([Preferences]). With [hideNames] (the Hub or the Medicine
/// page is locked) the medicine's name is left out.
///
/// Doses due at the same moment come as one notification (Round 23):
/// Android holds back alarms that follow each other closely while the
/// phone is idle, so a second one could come many minutes late.
List<Reminder> planMedicineReminders({
  required DateTime now,
  required MedicineBook book,
  required Preferences preferences,
  required int days,
  bool hideNames = false,
}) {
  if (!preferences.medicineReminders) return const [];
  final due = <DateTime, List<_Due>>{};
  final today = dayOf(now);

  void add(DateTime at, Medicine medicine, int time, {required bool again}) {
    if (!at.isAfter(now) || preferences.medicinePausedOn(at)) return;
    (due[at] ??= []).add((name: medicine.name, time: time, again: again));
  }

  for (var i = 0; i <= days; i++) {
    final day = addDays(today, i);
    for (final medicine in book.medicines) {
      if (!medicine.isOn(day)) continue;
      for (final (dose, time) in medicine.times.indexed) {
        // Marked already (taken, or set missed / not sure): nothing to
        // remind of.
        if (book.markFor(medicine.id, day, dose) != null) continue;
        final at = DateTime(day.year, day.month, day.day, 0, time);
        add(at, medicine, time, again: false);
        final followUp = medicine.followUp;
        if (followUp != null) {
          add(at.add(Duration(minutes: followUp)), medicine, time, again: true);
        }
      }
    }
  }
  return [
    for (final MapEntry(key: at, value: doses) in due.entries)
      Reminder(
        at: at,
        kind: ReminderKind.medicine,
        target: const MedicineTarget().payload,
        title:
            hideNames ? 'Medicine' : {for (final d in doses) d.name}.join(', '),
        body: _body(doses, hideNames: hideNames),
      ),
  ]..sort((a, b) => a.at.compareTo(b.at));
}

/// A dose to remind of: its medicine's name, its time, and whether it's
/// the follow-up.
typedef _Due = ({String name, int time, bool again});

String _body(List<_Due> doses, {required bool hideNames}) {
  final first = doses.first;
  final clock = formatMinutes(first.time);
  final alike =
      doses.every((d) => d.time == first.time && d.again == first.again);
  if (doses.length == 1 || alike) {
    final n = doses.length;
    return switch ((hideNames, first.again)) {
      (false, false) => 'Time to take ${n == 1 ? 'it' : 'them'} · $clock',
      (false, true) => 'Not taken yet · $clock',
      (true, false) =>
        n == 1 ? 'A dose is due at $clock' : '$n doses are due at $clock',
      (true, true) => n == 1
          ? 'A dose at $clock is not taken yet'
          : '$n doses at $clock are not taken yet',
    };
  }
  // Some due now, some from earlier not taken yet.
  if (hideNames) return '${doses.length} doses are due or not taken yet';
  return [
    for (final d in doses)
      '${d.name} ${d.again ? 'not taken yet · ' : ''}'
          '${formatMinutes(d.time)}',
  ].join('; ');
}

/// Until when, in minutes past midnight, a late dose of the day before
/// still counts as due (Round 15): one at 23:30 that's missed still shows
/// when going to bed.
const dueOverMidnight = 120;

/// Only the day before's doses from this time on (minutes past midnight,
/// 22:00 itself included) count after midnight (Round 17: at 00:50, the
/// day's earlier doses had kept the dot).
const lateDoseFrom = 22 * 60;

/// Whether one of the doses due by [now] isn't marked (O13): today's whose
/// time has come, and before [dueOverMidnight] also yesterday's late ones
/// (from [lateDoseFrom], 22:00).
bool doseDue(MedicineBook book, DateTime now) {
  final today = dayOf(now);
  final minutes = now.hour * 60 + now.minute;
  bool unmarked(DateTime day, bool Function(int time) due) {
    for (final medicine in book.medicines) {
      if (!medicine.isOn(day)) continue;
      for (final (dose, time) in medicine.times.indexed) {
        if (due(time) && book.markFor(medicine.id, day, dose) == null) {
          return true;
        }
      }
    }
    return false;
  }

  return unmarked(today, (time) => time <= minutes) ||
      (minutes < dueOverMidnight &&
          unmarked(addDays(today, -1), (time) => time >= lateDoseFrom));
}

/// The red dot on the Medicine tile and the Hub tab (O13): a dose due and
/// not marked, unless the dot is off or paused. The home screen looks
/// again every half minute and when the app comes back (a dose comes due
/// with no change to anything here).
final medicineDotProvider = Provider<bool>((ref) {
  final book = ref.watch(medicineProvider);
  final preferences = ref.watch(preferencesProvider);
  final now = ref.watch(clockProvider)();
  return preferences.medicineDot &&
      !preferences.medicinePausedOn(dayOf(now)) &&
      doseDue(book, now);
});
