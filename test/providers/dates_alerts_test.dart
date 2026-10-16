import 'package:flutter_test/flutter_test.dart';
import 'package:the_app/data/reminder_scheduler.dart';
import 'package:the_app/models/date_entry.dart';
import 'package:the_app/models/preferences.dart';
import 'package:the_app/providers/dates_alerts_provider.dart';

/// Birthdays & dates' reminders (Round 57).
void main() {
  // Thursday 15 October 2026, 13:20.
  final now = DateTime(2026, 10, 15, 13, 20);

  DateEntry date(
    String title,
    int day,
    int month, {
    int? year,
    DateType type = DateType.birthday,
    bool yearly = true,
    List<DateReminder> reminders = const [DateReminder.standard],
  }) =>
      DateEntry(
        id: title,
        title: title,
        type: type,
        day: day,
        month: month,
        year: year,
        yearly: yearly,
        reminders: reminders,
      );

  List<Reminder> plan(
    List<DateEntry> dates, {
    Preferences preferences = const Preferences(),
    bool hideNames = false,
  }) =>
      planDateReminders(
        now: now,
        book: DateBook(dates),
        preferences: preferences,
        days: 14,
        hideNames: hideNames,
      );

  String show(Reminder r) =>
      '${r.at.month}/${r.at.day} ${r.at.hour}:${r.at.minute} ${r.title}: '
      '${r.body}';

  test('the day before at 09:00 (a new date): what, how soon, the age', () {
    final r = plan([date('Ana', 24, 10, year: 1995)]);
    expect(r.map(show), ['10/23 9:0 Ana: Birthday tomorrow · turns 31']);
    expect(r.single.kind, ReminderKind.dates);
    expect(r.single.target, 'dates');
  });

  test(
      'planned when its time is within the days ahead (a reminder 30 days '
      'before a date further off, too)', () {
    const month = DateReminder(daysBefore: 30, minutes: 600);
    final r = plan([
      date('Near', 20, 11, reminders: const [month]), // fires 21 Oct
      date('Far', 10, 12, reminders: const [month]), // fires 10 Nov
    ]);
    expect(r.map(show), ['10/21 10:0 Near: Birthday in 30 days']);
  });

  test('times gone by: none; later today: yes; next year\'s once due', () {
    final r = plan([
      date('Today', 15, 10, reminders: const [
        DateReminder(daysBefore: 0, minutes: 9 * 60), // this morning
        DateReminder(daysBefore: 0, minutes: 20 * 60), // tonight
      ]),
      // Tomorrow, but a week's notice already gone by; next year's is far.
      date('Tomorrow', 16, 10,
          reminders: const [DateReminder(daysBefore: 7, minutes: 540)]),
    ]);
    expect(r.map(show), ['10/15 20:0 Today: Birthday today']);
  });

  test('two at the same time come as one', () {
    final r = plan([
      date('Ana', 24, 10),
      date('Mama i tata', 24, 10, year: 2016, type: DateType.anniversary),
    ]);
    expect(r.map(show), [
      '10/23 9:0 Ana, Mama i tata: Birthday tomorrow, '
          'Anniversary tomorrow · 10 years',
    ]);
  });

  test('without names (locked or private)', () {
    expect(plan([date('Ana', 24, 10)], hideNames: true).map(show),
        ['10/23 9:0 Dates: A birthday tomorrow']);
    expect(
        plan([date('Ana', 24, 10), date('Bo', 24, 10)], hideNames: true)
            .map(show),
        ['10/23 9:0 Dates: 2 dates']);
  });

  test('off, or paused that day: none', () {
    final dates = [date('Ana', 24, 10), date('Bo', 30, 10)];
    expect(plan(dates, preferences: const Preferences(datesReminders: false)),
        isEmpty);
    final paused = plan(dates,
        preferences: Preferences(datesPausedUntil: DateTime(2026, 10, 23)));
    expect(paused.map((r) => r.title), ['Bo']);
  });

  test('a one-off gone by never reminds', () {
    expect(
        plan([
          date('Exam', 10, 10, year: 2026, yearly: false, type: DateType.event)
        ]),
        isEmpty);
  });

  test('when (Round 59): its days if it lasts; on now; the last day; gone', () {
    final today = DateTime(2026, 8, 6);
    const holiday = DateEntry(
      id: 'h',
      title: 'Ljetovanje',
      type: DateType.holiday,
      day: 1,
      month: 8,
      days: 10,
    );
    expect(whenLabel(holiday, DateTime(2026, 8, 1), today),
        'Sat, 1 Aug – Mon, 10 Aug  ·  on now');
    expect(whenLabel(holiday, DateTime(2026, 8, 1), DateTime(2026, 8, 10)),
        'Sat, 1 Aug – Mon, 10 Aug  ·  last day today');
    expect(whenLabel(holiday, DateTime(2026, 8, 1), DateTime(2026, 7, 29)),
        'Sat, 1 Aug – Mon, 10 Aug  ·  in 3 days');
    expect(whenLabel(holiday, DateTime(2026, 8, 1), DateTime(2026, 8, 11)),
        'Sat, 1 Aug – Mon, 10 Aug  ·  yesterday');
    const ana = DateEntry(
      id: 'a',
      title: 'Ana',
      type: DateType.birthday,
      day: 3,
      month: 8,
      year: 1995,
    );
    expect(whenLabel(ana, DateTime(2026, 8, 3), today),
        'Mon, 3 Aug  ·  3 days ago  ·  turns 31');
    expect(whenLabel(ana, DateTime(2026, 8, 3), DateTime(2026, 8, 3)),
        'Mon, 3 Aug  ·  today  ·  turns 31');
  });

  test('a holiday that lasts: reminded before its first day only', () {
    const holiday = DateEntry(
      id: 'h',
      title: 'Ljetovanje',
      type: DateType.holiday,
      day: 10,
      month: 8,
      days: 5,
      reminders: [DateReminder(daysBefore: 1, minutes: 540)],
    );
    final planned = planDateReminders(
      now: DateTime(2026, 8, 1, 12),
      book: const DateBook([holiday]),
      preferences: const Preferences(),
      days: 14,
    );
    expect(planned.map((r) => r.at), [DateTime(2026, 8, 9, 9)]);
    // On now: nothing more this time.
    expect(
        planDateReminders(
          now: DateTime(2026, 8, 11, 12),
          book: const DateBook([holiday]),
          preferences: const Preferences(),
          days: 14,
        ),
        isEmpty);
  });

  test('details (Round 61): kind, days, year, reminders, shortly', () {
    expect(beforeLabel(0), 'on the day');
    expect(beforeLabel(1), '1 day');
    expect(beforeLabel(3), '3 days');
    expect(beforeLabel(7), '1 week');
    expect(beforeLabel(14), '2 weeks');
    expect(beforeLabel(30), '1 month');
    const wed = DateEntry(
      id: 'w',
      title: 'Wedding',
      type: DateType.anniversary,
      day: 1,
      month: 6,
      year: 2016,
      reminders: [
        DateReminder(daysBefore: 30, minutes: 540),
        DateReminder(daysBefore: 0, minutes: 540),
      ],
    );
    expect(dateDetails(wed), ['since 2016', 'on the day, 1 month before']);
    expect(dateDetails(wed.copyWith(type: DateType.birthday, reminders: [])),
        ['born 2016']);
    expect(
        dateDetails(wed.copyWith(
            type: DateType.other, reminders: [], year: () => null)),
        isEmpty);
    expect(
        dateDetails(const DateEntry(
          id: 'b',
          title: 'Beach',
          type: DateType.holiday,
          kind: DateKind.beach,
          day: 1,
          month: 8,
          year: 2027,
          yearly: false,
          days: 7,
          reminders: [],
        )),
        ['Beach', '7 days'],
        reason: 'a one-off: its year is in its date');
    // A one-off in another year: its year in its date; every year: none.
    expect(
        whenLabel(wed.copyWith(yearly: false, year: () => 2027),
            DateTime(2027, 6, 1), DateTime(2026, 10, 16)),
        startsWith('Tue, 1 Jun 2027'));
    expect(whenLabel(wed, DateTime(2027, 6, 1), DateTime(2026, 10, 16)),
        startsWith('Tue, 1 Jun  ·'));
  });
}
