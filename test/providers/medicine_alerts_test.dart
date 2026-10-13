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
    // The red dot is for important ones only (Round 24).
    important: true,
  );

  /// The same, reminding again [minutes] after each dose (Round 16).
  Medicine pillsAgain(int minutes) => Medicine(
        id: 'p',
        name: 'Pills',
        times: pills.times,
        from: pills.from,
        until: pills.until,
        followUp: minutes,
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

  test('a medicine with a follow-up: a second one later if still not marked',
      () {
    final reminders = plan(MedicineBook(medicines: [pillsAgain(240)]));
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
      plan(MedicineBook(medicines: [pillsAgain(60)])).first,
      '12 20:0 Pills: Time to take it · 20:00',
    );
  });

  test('off: none at all', () {
    expect(
      plan(
        MedicineBook(medicines: [pillsAgain(60)]),
        preferences: const Preferences(medicineReminders: false),
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
        MedicineBook(medicines: [pillsAgain(60)]),
        hideNames: true,
      ).take(2),
      [
        '12 20:0 Medicine: A dose is due at 20:00',
        '12 21:0 Medicine: A dose at 20:00 is not taken yet',
      ],
    );
  });

  group('at the same moment: one notification (Round 23)', () {
    Medicine at(String id, String name, List<int> times, {int? followUp}) =>
        Medicine(
          id: id,
          name: name,
          times: times,
          from: DateTime(2026, 10, 1),
          until: tomorrow,
          followUp: followUp,
        );

    test('two medicines at 20:00: one, naming both', () {
      final book = MedicineBook(medicines: [
        at('a', 'Iron', [20 * 60]),
        at('b', 'Vitamin D', [20 * 60]),
      ]);
      expect(plan(book).first,
          '12 20:0 Iron, Vitamin D: Time to take them · 20:00');
      expect(plan(book, hideNames: true).first,
          '12 20:0 Medicine: 2 doses are due at 20:00');
      expect(plan(book), hasLength(2), reason: 'today and tomorrow');
    });

    test("one's dose and another's follow-up: both said", () {
      final book = MedicineBook(medicines: [
        at('a', 'Iron', [16 * 60], followUp: 240),
        at('b', 'Zinc', [20 * 60]),
      ]);
      expect(plan(book)[1],
          '12 20:0 Iron, Zinc: Iron not taken yet · 16:00; Zinc 20:00');
      expect(plan(book, hideNames: true)[1],
          '12 20:0 Medicine: 2 doses are due or not taken yet');
    });
  });

  group('a dose due', () {
    test('its time has come today and it is not marked', () {
      final book = MedicineBook(medicines: [pills]);
      expect(doseDue(book, DateTime(2026, 10, 12, 7, 59)), isFalse);
      expect(doseDue(book, DateTime(2026, 10, 12, 8)), isTrue);
    });

    test('only important medicines count (Round 24)', () {
      final plain = Medicine(
        id: 'v',
        name: 'Vitamin C',
        times: [8 * 60],
        from: DateTime(2026, 10, 1),
      );
      expect(doseDue(MedicineBook(medicines: [plain]), now), isFalse);
      expect(Medicine.fromJson(plain.toJson()).important, isFalse);
      expect(plain.toJson().containsKey('important'), isFalse);
      expect(Medicine.fromJson(pills.toJson()).important, isTrue);
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
        important: true,
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

    test("only yesterday's from 22:00 (Round 17)", () {
      // Nikola at 00:50: doses from 11:00 to 21:00 kept the dot.
      final day = Medicine(
        id: 'd',
        name: 'Day',
        times: [11 * 60, 21 * 60 + 59],
        from: DateTime(2026, 10, 1),
        important: true,
      );
      final at = DateTime(2026, 10, 13, 0, 50);
      expect(doseDue(MedicineBook(medicines: [day]), at), isFalse);
      // 22:00 itself counts.
      final ten = Medicine(
        id: 't',
        name: 'Ten',
        times: [22 * 60],
        from: DateTime(2026, 10, 1),
        important: true,
      );
      expect(doseDue(MedicineBook(medicines: [ten]), at), isTrue);
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

  test('a medicine keeps its follow-up (medicine.json 3)', () {
    expect(Medicine.fromJson(pillsAgain(120).toJson()).followUp, 120);
    expect(pills.toJson().containsKey('followUp'), isFalse);
  });

  test('settings are kept in preferences, older files read as defaults', () {
    final preferences = Preferences(
      medicineReminders: false,
      medicinePausedUntil: tomorrow,
    );
    final read = Preferences.fromJson(preferences.toJson());
    expect(read.medicineReminders, isFalse);
    expect(read.medicinePausedUntil, tomorrow);

    final old = Preferences.fromJson({'theme': 'clay'});
    expect(old.medicineReminders, isTrue);
    expect(old.medicinePausedUntil, isNull);
  });

  test('paused through a day, not after it', () {
    final preferences = Preferences(medicinePausedUntil: today);
    expect(preferences.medicinePausedOn(DateTime(2026, 10, 12, 23)), isTrue);
    expect(preferences.medicinePausedOn(tomorrow), isFalse);
    expect(const Preferences().medicinePausedOn(today), isFalse);
  });
}
