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
}
