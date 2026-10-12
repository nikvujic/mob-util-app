import 'package:flutter_test/flutter_test.dart';
import 'package:the_app/data/reminder_scheduler.dart';
import 'package:the_app/models/medicine.dart';
import 'package:the_app/models/preferences.dart';
import 'package:the_app/providers/medicine_alerts_provider.dart';

/// Medicine reminders and the due dose behind the red dot (O13).
void main() {
  /// Monday 12 October 2026, 09:30.
  final now = DateTime(2026, 10, 12, 9, 30);
  final today = DateTime(2026, 10, 12);
  final tomorrow = DateTime(2026, 10, 13);

  final pills = Medicine(
    id: 'p',
    name: 'Pills',
    times: [8 * 60, 20 * 60],
    from: DateTime(2026, 10, 1),
    until: tomorrow,
  );

  List<String> plan(
    MedicineBook book, {
    Preferences preferences = const Preferences(),
    bool hideNames = false,
  }) =>
      [
        for (final r in planMedicineReminders(
          now: now,
          book: book,
          preferences: preferences,
          days: 14,
          hideNames: hideNames,
        ))
          '${r.at.day} ${r.at.hour}:${r.at.minute} ${r.title}: ${r.body}',
      ];

  test('one at each dose time still ahead, while it is taken', () {
    final reminders = plan(MedicineBook(medicines: [pills]));
    expect(reminders, [
      '12 20:0 Pills: Time to take it · 20:00',
      '13 8:0 Pills: Time to take it · 08:00',
      '13 20:0 Pills: Time to take it · 20:00',
    ]);
    final kinds = planMedicineReminders(
      now: now,
      book: MedicineBook(medicines: [pills]),
      preferences: const Preferences(),
      days: 14,
    ).map((r) => r.kind);
    expect(kinds, everyElement(ReminderKind.medicine));
  });

  test('a dose already marked (any way) does not remind', () {
    final reminders = plan(
      MedicineBook(medicines: [
        pills
      ], taken: [
        DoseTaken(medicine: 'p', day: tomorrow, dose: 0),
        DoseTaken(
          medicine: 'p',
          day: today,
          dose: 1,
          state: DoseState.unsure,
        ),
      ]),
    );
    expect(reminders, ['13 20:0 Pills: Time to take it · 20:00']);
  });

  test('with a follow-up, a second one later if still not marked', () {
    final reminders = plan(
      MedicineBook(medicines: [pills]),
      preferences: const Preferences(medicineFollowUp: 240),
    );
    expect(reminders, [
      // This morning's dose: its time has gone, the follow-up hasn't.
      '12 12:0 Pills: Not taken yet · 08:00',
      '12 20:0 Pills: Time to take it · 20:00',
      '13 0:0 Pills: Not taken yet · 20:00',
      '13 8:0 Pills: Time to take it · 08:00',
      '13 12:0 Pills: Not taken yet · 08:00',
      '13 20:0 Pills: Time to take it · 20:00',
      '14 0:0 Pills: Not taken yet · 20:00',
    ]);
    // A follow-up gone by as well: none.
    expect(
      plan(
        MedicineBook(medicines: [pills]),
        preferences: const Preferences(medicineFollowUp: 60),
      ).first,
      '12 20:0 Pills: Time to take it · 20:00',
    );
  });

  test('off: none at all', () {
    expect(
      plan(
        MedicineBook(medicines: [pills]),
        preferences: const Preferences(
          medicineReminders: false,
          medicineFollowUp: 60,
        ),
      ),
      isEmpty,
    );
  });

  test('paused: none through that day, then as before', () {
    expect(
      plan(
        MedicineBook(medicines: [pills]),
        preferences: Preferences(medicinePausedUntil: today),
      ),
      [
        '13 8:0 Pills: Time to take it · 08:00',
        '13 20:0 Pills: Time to take it · 20:00',
      ],
    );
  });

  test('the Hub locked: no name', () {
    expect(
      plan(
        MedicineBook(medicines: [pills]),
        preferences: const Preferences(medicineFollowUp: 60),
        hideNames: true,
      ).take(2),
      [
        '12 20:0 Medicine: A dose is due at 20:00',
        '12 21:0 Medicine: A dose at 20:00 is not taken yet',
      ],
    );
  });

  group('a dose due', () {
    test('its time has come today and it is not marked', () {
      final book = MedicineBook(medicines: [pills]);
      expect(doseDue(book, DateTime(2026, 10, 12, 7, 59)), isFalse);
      expect(doseDue(book, DateTime(2026, 10, 12, 8)), isTrue);
    });

    test('marked any way: not due', () {
      for (final state in DoseState.values) {
        final book = MedicineBook(
          medicines: [pills],
          taken: [
            DoseTaken(medicine: 'p', day: today, dose: 0, state: state),
          ],
        );
        expect(doseDue(book, now), isFalse, reason: state.name);
      }
    });

    test("yesterday's still count until 02:00 (Round 15)", () {
      final late = Medicine(
        id: 'l',
        name: 'Late',
        times: [23 * 60 + 30],
        from: DateTime(2026, 10, 1),
      );
      final book = MedicineBook(medicines: [late]);
      expect(doseDue(book, DateTime(2026, 10, 13, 1, 59)), isTrue);
      expect(doseDue(book, DateTime(2026, 10, 13, 2)), isFalse);
      final marked = MedicineBook(medicines: [
        late
      ], taken: [
        DoseTaken(medicine: 'l', day: today, dose: 0),
      ]);
      expect(doseDue(marked, DateTime(2026, 10, 13, 1)), isFalse);
    });

    test('only for medicines on today', () {
      final ended = Medicine(
        id: 'e',
        name: 'Ended',
        times: [8 * 60],
        from: DateTime(2026, 9, 1),
        until: DateTime(2026, 10, 11),
      );
      expect(doseDue(MedicineBook(medicines: [ended]), now), isFalse);
    });
  });

  test('settings are kept in preferences, older files read as defaults', () {
    final preferences = Preferences(
      medicineReminders: false,
      medicineFollowUp: 180,
      medicineDot: false,
      medicinePausedUntil: tomorrow,
    );
    final read = Preferences.fromJson(preferences.toJson());
    expect(read.medicineReminders, isFalse);
    expect(read.medicineFollowUp, 180);
    expect(read.medicineDot, isFalse);
    expect(read.medicinePausedUntil, tomorrow);

    final old = Preferences.fromJson({'theme': 'clay'});
    expect(old.medicineReminders, isTrue);
    expect(old.medicineFollowUp, isNull);
    expect(old.medicineDot, isTrue);
    expect(old.medicinePausedUntil, isNull);
  });

  test('paused through a day, not after it', () {
    final preferences = Preferences(medicinePausedUntil: today);
    expect(preferences.medicinePausedOn(DateTime(2026, 10, 12, 23)), isTrue);
    expect(preferences.medicinePausedOn(tomorrow), isFalse);
    expect(const Preferences().medicinePausedOn(today), isFalse);
  });
}
