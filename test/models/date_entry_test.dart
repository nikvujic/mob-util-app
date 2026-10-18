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

  group('lasting days (Round 59)', () {
    const holiday = DateEntry(
      id: 'h',
      title: 'Ljetovanje',
      type: DateType.holiday,
      day: 1,
      month: 8,
      days: 10,
    );

    test('a holiday or an event can last; other types are a day', () {
      expect(DateType.values.where((t) => t.lasts),
          {DateType.holiday, DateType.event});
      expect(holiday.span, 10);
      final asBirthday = holiday.copyWith(type: DateType.birthday);
      expect(asBirthday.span, 1);
      expect(asBirthday.days, 10, reason: 'kept, for if it comes back');
      expect(asBirthday.on(DateTime(2026, 8, 2)), isFalse);
    });

    test('on every one of its days, from its first', () {
      expect(holiday.on(DateTime(2026, 7, 31)), isFalse);
      expect(holiday.on(DateTime(2026, 8, 1)), isTrue);
      expect(holiday.on(DateTime(2026, 8, 10)), isTrue);
      expect(holiday.on(DateTime(2026, 8, 11)), isFalse);
      expect(holiday.startCovering(DateTime(2026, 8, 6)), DateTime(2026, 8, 1));
      expect(holiday.endFrom(DateTime(2026, 8, 1)), DateTime(2026, 8, 10));
    });

    test('next from a day it is on: its first day, before it', () {
      expect(holiday.nextFrom(DateTime(2026, 8, 6)), DateTime(2026, 8, 1));
      expect(holiday.nextFrom(DateTime(2026, 8, 11)), DateTime(2027, 8, 1));
      final book = DateBook([holiday]);
      expect(
          book.upcoming(DateTime(2026, 8, 6)).single.on, DateTime(2026, 8, 1));
    });

    test('into the new year, every year or once', () {
      const fair = DateEntry(
        id: 'f',
        title: 'Sajam',
        type: DateType.event,
        day: 30,
        month: 12,
        year: 2026,
        yearly: false,
        days: 4,
      );
      expect(fair.on(DateTime(2027, 1, 2)), isTrue);
      expect(fair.on(DateTime(2027, 1, 3)), isFalse);
      expect(fair.startCovering(DateTime(2027, 1, 1)), DateTime(2026, 12, 30));
      expect(fair.nextFrom(DateTime(2027, 1, 2)), DateTime(2026, 12, 30));
      expect(fair.nextFrom(DateTime(2027, 1, 3)), isNull);
      final yearly = fair.copyWith(yearly: true, type: DateType.holiday);
      expect(yearly.on(DateTime(2028, 1, 1)), isTrue);
    });

    test('kept between 1 and 31 days; written only when not 1', () {
      expect(holiday.copyWith(days: 0).days, 1);
      expect(holiday.copyWith(days: 40).days, DateEntry.mostDays);
      expect(holiday.toJson()['days'], 10);
      expect(holiday.copyWith(days: 1).toJson().containsKey('days'), isFalse);
      expect(DateEntry.fromJson(holiday.toJson()).days, 10);
      expect(
          DateEntry.fromJson({
            'id': 'a',
            'type': 'event',
            'day': 1,
            'month': 2,
            'days': 99
          }).days,
          DateEntry.mostDays);
    });
  });

  group('kinds (Round 61)', () {
    test('a holiday or an event has kinds; others none', () {
      expect(DateType.holiday.kinds,
          [DateKind.skiing, DateKind.beach, DateKind.trip]);
      expect(DateType.event.kinds, [DateKind.wedding]);
      expect(DateType.birthday.kinds, isEmpty);
      expect(DateType.values.where((t) => t.choosesYearly), [DateType.other]);
    });

    test('kept with another type, unused; written by name', () {
      const ski = DateEntry(
          id: 's',
          title: 'Ski',
          type: DateType.holiday,
          day: 1,
          month: 2,
          kind: DateKind.skiing);
      expect(ski.kindNow, DateKind.skiing);
      final asEvent = ski.copyWith(type: DateType.event);
      expect(asEvent.kind, DateKind.skiing);
      expect(asEvent.kindNow, isNull);
      expect(ski.toJson()['kind'], 'skiing');
      expect(
          ski.copyWith(kind: () => null).toJson().containsKey('kind'), isFalse);
      expect(DateEntry.fromJson(ski.toJson()).kind, DateKind.skiing);
      expect(
          DateEntry.fromJson({
            'id': 'a',
            'type': 'holiday',
            'day': 1,
            'month': 2,
            'kind': 'sailing'
          }).kind,
          isNull,
          reason: 'from a newer app: none');
    });

    test('a wedding reminds a week and a month before', () {
      expect(DateKind.wedding.reminders, DateReminder.weddingDefaults);
      expect(DateReminder.weddingDefaults.map((r) => r.daysBefore), [7, 30]);
      expect(DateKind.skiing.reminders, isNull);
    });
  });

  group('a ski trip\'s travel (Round 67)', () {
    const ski = DateEntry(
      id: 'ski',
      title: 'Jahorina',
      type: DateType.holiday,
      day: 20,
      month: 1,
      year: 2027,
      yearly: false,
      days: 5,
      kind: DateKind.skiing,
      travelHours: 6,
    );

    test(
        'there on the first day at 06:00; back the day after the last, at '
        '11:00', () {
      final trips = ski.tripsFrom(DateTime(2027, 1, 20))!;
      expect(trips.there, DateTime(2027, 1, 20, 6));
      expect(trips.back, DateTime(2027, 1, 25, 11));
      expect(trips.length, const Duration(hours: 6));
    });

    test('only for Skiing, with hours set', () {
      expect(ski.copyWith(travelHours: 0).hasTravel, isFalse);
      expect(ski.copyWith(kind: () => DateKind.beach).hasTravel, isFalse);
      expect(
          ski.copyWith(travelHours: 99).travelHours, DateEntry.mostTravelHours);
    });

    test('kept in its JSON; none without travel', () {
      final json = ski.copyWith(leaveAt: 7 * 60, backAt: 10 * 60).toJson();
      expect(json['travel'], {'hours': 6, 'leave': 420, 'back': 600});
      final back = DateEntry.fromJson(json);
      expect((back.travelHours, back.leaveAt, back.backAt), (6, 420, 600));
      expect(
          ski.copyWith(travelHours: 0).toJson().containsKey('travel'), isFalse);
    });
  });
}
