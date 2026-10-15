import 'package:flutter_test/flutter_test.dart';
import 'package:the_app/models/date_entry.dart';

/// Birthdays & dates (Round 57): when a date falls, what's coming, how
/// many years, 29 February, and the JSON.
void main() {
  DateEntry date(
    String id,
    int day,
    int month, {
    int? year,
    bool yearly = true,
    DateType type = DateType.birthday,
    String? title,
  }) =>
      DateEntry(
        id: id,
        title: title ?? id,
        type: type,
        day: day,
        month: month,
        year: year,
        yearly: yearly,
      );

  test('every year: on its day each year; next from a day', () {
    final ana = date('Ana', 24, 10, year: 1995);
    expect(ana.on(DateTime(2026, 10, 24)), isTrue);
    expect(ana.on(DateTime(2030, 10, 24)), isTrue);
    expect(ana.on(DateTime(2026, 10, 25)), isFalse);
    expect(ana.nextFrom(DateTime(2026, 10, 15)), DateTime(2026, 10, 24));
    expect(ana.nextFrom(DateTime(2026, 10, 24)), DateTime(2026, 10, 24),
        reason: 'today counts');
    expect(ana.nextFrom(DateTime(2026, 10, 25)), DateTime(2027, 10, 24));
  });

  test('a one-off: only its year; gone by, never again', () {
    final exam =
        date('Exam', 3, 11, year: 2026, yearly: false, type: DateType.event);
    expect(exam.on(DateTime(2026, 11, 3)), isTrue);
    expect(exam.on(DateTime(2027, 11, 3)), isFalse);
    expect(exam.nextFrom(DateTime(2026, 10, 1)), DateTime(2026, 11, 3));
    expect(exam.nextFrom(DateTime(2026, 11, 4)), isNull);
  });

  test('29 February: on the 28th in a year without it', () {
    final leap = date('Leap', 29, 2, year: 2004);
    expect(leap.on(DateTime(2027, 2, 28)), isTrue);
    expect(leap.on(DateTime(2028, 2, 28)), isFalse);
    expect(leap.on(DateTime(2028, 2, 29)), isTrue);
    expect(leap.nextFrom(DateTime(2027, 1, 1)), DateTime(2027, 2, 28));
  });

  test('years: with a year known, from the year after', () {
    final ana = date('Ana', 24, 10, year: 1995);
    expect(ana.yearsOn(DateTime(2026, 10, 24)), 31);
    expect(ana.yearsOn(DateTime(1995, 10, 24)), isNull, reason: 'that year');
    expect(date('Bo', 1, 1).yearsOn(DateTime(2026, 1, 1)), isNull,
        reason: 'no year');
  });

  test('upcoming: soonest first, the same day by title, within days', () {
    final book = DateBook([
      date('zed', 20, 10),
      date('Ana', 24, 10),
      date('bob', 20, 10),
      date('Past', 1, 10, year: 2026, yearly: false),
      date('Far', 14, 10), // next year: just inside a year
    ]);
    final today = DateTime(2026, 10, 15, 13, 30);
    expect(book.upcoming(today).map((u) => u.date.id),
        ['bob', 'zed', 'Ana', 'Far']);
    expect(book.upcoming(today).first.on, DateTime(2026, 10, 20));
    expect(book.upcoming(today, days: 6).map((u) => u.date.id), ['bob', 'zed']);
    expect(book.on(DateTime(2026, 10, 20)).map((d) => d.id), ['zed', 'bob']);
  });

  test('a birthday on a day (not another type)', () {
    final book = DateBook([
      date('Ana', 24, 10),
      date('Wed', 25, 10, type: DateType.anniversary),
    ]);
    expect(book.birthdayOn(DateTime(2026, 10, 24)), isTrue);
    expect(book.birthdayOn(DateTime(2026, 10, 25)), isFalse);
  });

  test('a new date reminds the day before at 09:00; types every year or not',
      () {
    expect(date('x', 1, 1).reminders, [DateReminder.standard]);
    expect(
        DateReminder.standard, const DateReminder(daysBefore: 1, minutes: 540));
    expect([
      for (final t in DateType.values)
        if (t.yearly) t.name
    ], [
      'birthday',
      'anniversary',
      'holiday'
    ]);
  });

  test('JSON round trip; unknown type: other; no year left out', () {
    final d = DateEntry(
      id: 'd1',
      title: 'Ana 🎂',
      type: DateType.anniversary,
      day: 24,
      month: 10,
      year: 1995,
      note: 'gift: a book',
      reminders: const [
        DateReminder(daysBefore: 0, minutes: 480),
        DateReminder(daysBefore: 7, minutes: 1200),
      ],
    );
    final back = DateBook.fromJson(DateBook([d]).toJson()).dates.single;
    expect(back.toJson(), d.toJson());
    expect(date('n', 1, 1).toJson().containsKey('year'), isFalse);
    expect(
        DateEntry.fromJson({'id': 'a', 'type': 'nameDay', 'day': 1, 'month': 2})
            .type,
        DateType.other);
  });
}
