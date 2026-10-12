import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:the_app/core/clock.dart';
import 'package:the_app/core/format.dart';
import 'package:the_app/data/reminder_scheduler.dart';
import 'package:the_app/models/medicine.dart';
import 'package:the_app/models/preferences.dart';
import 'package:the_app/providers/medicine_provider.dart';
import 'package:the_app/providers/preferences_provider.dart';

/// The medicine reminders (O13) due after [now] for the next [days] days:
/// one at each dose time not yet marked, and with a follow-up set, another
/// that many minutes later. None while off or paused ([Preferences]). With
/// [hideNames] (the Hub is locked) the medicine's name is left out.
List<Reminder> planMedicineReminders({
  required DateTime now,
  required MedicineBook book,
  required Preferences preferences,
  required int days,
  bool hideNames = false,
}) {
  if (!preferences.medicineReminders) return const [];
  final reminders = <Reminder>[];
  final today = dayOf(now);
  final followUp = preferences.medicineFollowUp;

  void add(DateTime at, Medicine medicine, int time, {required bool again}) {
    if (!at.isAfter(now) || preferences.medicinePausedOn(at)) return;
    final clock = formatMinutes(time);
    reminders.add(
      Reminder(
        at: at,
        kind: ReminderKind.medicine,
        title: hideNames ? 'Medicine' : medicine.name,
        body: switch ((hideNames, again)) {
          (false, false) => 'Time to take it · $clock',
          (false, true) => 'Not taken yet · $clock',
          (true, false) => 'A dose is due at $clock',
          (true, true) => 'A dose at $clock is not taken yet',
        },
      ),
    );
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
        if (followUp != null) {
          add(at.add(Duration(minutes: followUp)), medicine, time, again: true);
        }
      }
    }
  }
  return reminders;
}

/// Whether one of the doses due by [now] today isn't marked (O13).
bool doseDue(MedicineBook book, DateTime now) {
  final today = dayOf(now);
  final minutes = now.hour * 60 + now.minute;
  for (final medicine in book.medicines) {
    if (!medicine.isOn(today)) continue;
    for (final (dose, time) in medicine.times.indexed) {
      if (time <= minutes && book.markFor(medicine.id, today, dose) == null) {
        return true;
      }
    }
  }
  return false;
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
