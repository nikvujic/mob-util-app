import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:the_app/models/date_entry.dart';
import 'package:the_app/pages/hub/dates.dart';
import 'package:the_app/pages/hub/dates_calendar.dart';
import 'package:the_app/providers/dates_provider.dart';
import 'package:the_app/widgets/app_dialog.dart';

import '../helpers.dart';

/// Hub → Dates, birthdays & dates (Round 57).
void main() {
  late ProviderContainer container;
  // Thursday 15 October 2026, 13:20.
  final now = DateTime(2026, 10, 15, 13, 20);

  DateBook book() => container.read(datesProvider);

  DateEntry date(
    String id,
    int day,
    int month, {
    int? year,
    bool yearly = true,
    DateType type = DateType.birthday,
  }) =>
      DateEntry(
        id: id,
        title: id,
        type: type,
        day: day,
        month: month,
        year: year,
        yearly: yearly,
      );

  Future<void> openDates(WidgetTester tester, {List<DateEntry>? start}) async {
    container = await pumpApp(tester, clock: () => now);
    if (start != null) {
      container.read(datesProvider.notifier).replaceAll(DateBook(start));
    }
    await openTab(tester, 'Hub');
    await tester.tap(find.byTooltip('Dates'));
    await tester.pumpAndSettle();
  }

  Future<void> tap(WidgetTester tester, Finder finder) async {
    // Rows further down (or back up) aren't built: the page's list moved
    // down until found, then up.
    if (finder.evaluate().isEmpty) {
      final list = find
          .descendant(
              of: find.byType(CustomScrollView).last,
              matching: find.byType(Scrollable))
          .first;
      final position = tester.state<ScrollableState>(list).position;
      var by = 150.0;
      for (var i = 0; i < 60 && finder.evaluate().isEmpty; i++) {
        if (by > 0 && position.pixels >= position.maxScrollExtent) by = -by;
        position.jumpTo((position.pixels + by)
            .clamp(position.minScrollExtent, position.maxScrollExtent));
        await tester.pump();
      }
    }
    await tester.ensureVisible(finder);
    await tester.pumpAndSettle();
    await tester.tap(finder);
    await tester.pumpAndSettle();
  }

  String whenOf(WidgetTester tester, String id) =>
      tester.widget<Text>(find.byKey(Key('dateWhen-$id'))).data!;

  testWidgets('empty: the calendar on this month, no dates', (tester) async {
    await openDates(tester);
    expect(find.text('October 2026'), findsOneWidget);
    expect(find.text('UPCOMING'), findsOneWidget);
    expect(find.text('No dates'), findsOneWidget);
  });

  testWidgets(
      'upcoming: soonest first, how soon, turns N, N years; gone-by '
      'one-offs left out', (tester) async {
    await openDates(tester, start: [
      date('Mama i tata', 20, 10, year: 2016, type: DateType.anniversary),
      date('Ana', 24, 10, year: 1995),
      date('Exam', 1, 10, year: 2026, yearly: false, type: DateType.event),
      date('Bo', 15, 10),
    ]);
    final bo = tester.getTopLeft(find.text('Bo')).dy;
    final mama = tester.getTopLeft(find.text('Mama i tata')).dy;
    final ana = tester.getTopLeft(find.text('Ana')).dy;
    expect(bo < mama && mama < ana, isTrue);
    expect(whenOf(tester, 'Bo'), 'Thu, 15 Oct  ·  today');
    expect(whenOf(tester, 'Mama i tata'),
        'Tue, 20 Oct  ·  in 5 days  ·  10 years');
    expect(whenOf(tester, 'Ana'), 'Sat, 24 Oct  ·  in 9 days  ·  turns 31');
    expect(find.text('Exam'), findsNothing, reason: 'gone by');
  });

  testWidgets(
      'the calendar: a dot per date in its colour; a tap shows the day '
      '(again: what is coming); a month ahead', (tester) async {
    await openDates(tester, start: [
      date('Ana', 24, 10),
      date('Wed', 24, 10, type: DateType.anniversary),
      date('Nov', 3, 11, type: DateType.holiday),
    ]);
    DateMarkPainter mark(String day) =>
        tester.widget<CustomPaint>(find.byKey(Key('datesMark-$day'))).painter!
            as DateMarkPainter;
    // Round 60: the circle in their colours, split; a border for several
    // of one colour.
    expect(mark('2026-10-24').colours,
        [DateType.birthday.colour, DateType.anniversary.colour]);
    expect(mark('2026-10-24').several, isFalse);
    expect(mark('2026-10-23').colours, isEmpty);
    await tester.tap(find.byKey(const Key('datesDay-2026-10-24')));
    await tester.pumpAndSettle();
    expect(find.text('SAT, 24 OCT'), findsOneWidget);
    expect(find.text('Ana'), findsOneWidget);
    expect(find.text('Nov'), findsNothing);
    await tester.tap(find.byKey(const Key('datesDay-2026-10-23')));
    await tester.pumpAndSettle();
    expect(find.text('Nothing on this day'), findsOneWidget);
    await tester.tap(find.byKey(const Key('datesDay-2026-10-23')));
    await tester.pumpAndSettle();
    expect(find.text('UPCOMING'), findsOneWidget);
    await tap(tester, find.byKey(const Key('datesMonthAfter')));
    expect(find.text('November 2026'), findsOneWidget);
    expect(mark('2026-11-3').colours, [DateType.holiday.colour]);
  });

  testWidgets(
      '+ on a picked day: a new date there, saved once titled; year '
      'not known; reminders (Round 61): a day and a week before at 09:00, '
      'another added, one removed', (tester) async {
    await openDates(tester);
    await tester.tap(find.byKey(const Key('datesDay-2026-10-24')));
    await tester.pumpAndSettle();
    await tap(tester, find.byTooltip('Add a date'));
    expect(appBarTitle('New date'), findsOneWidget);
    expect(find.text('24 October 2026'), findsOneWidget);
    expect(find.text('1 day before  ·  09:00'), findsOneWidget);
    expect(book().dates, isEmpty, reason: 'no title yet');
    await tester.enterText(find.byKey(const Key('dateTitle')), 'Ana');
    await tester.pumpAndSettle();
    expect(book().dates.single.title, 'Ana');
    expect(book().dates.single.reminders, DateReminder.defaults);
    expect(DateReminder.defaults.map((r) => (r.daysBefore, r.minutes)),
        [(1, 540), (7, 540)]);
    await tap(tester, find.byKey(const Key('dateYearKnown')));
    expect(find.text('24 October'), findsOneWidget);
    await tap(tester, find.byKey(const Key('dateAddReminder')));
    await tap(tester, find.byKey(const Key('reminderDays-14')));
    await tap(tester, find.byKey(const Key('reminderDone')));
    await tap(tester, find.byKey(const Key('dateReminderRemove-0')));
    await tester.enterText(find.byKey(const Key('dateNote')), 'a book');
    await tester.pumpAndSettle();
    final saved = book().dates.single;
    expect(saved.year, isNull);
    expect(saved.yearly, isTrue);
    expect(saved.type, DateType.birthday);
    expect(saved.note, 'a book');
    expect(saved.reminders, const [
      DateReminder(daysBefore: 7, minutes: 540),
      DateReminder(daysBefore: 14, minutes: 540),
    ]);
    // Only three.
    await tap(tester, find.byKey(const Key('dateAddReminder')));
    await tap(tester, find.byKey(const Key('reminderDone')));
    expect(book().dates.single.reminders, hasLength(3));
    // Down to the note, past where it was: no Add.
    await tap(tester, find.byKey(const Key('dateNote')));
    expect(find.byKey(const Key('dateReminder-2')), findsOneWidget);
    expect(find.byKey(const Key('dateAddReminder')), findsNothing);
    await pressBack(tester);
    expect(whenOf(tester, saved.id), 'Sat, 24 Oct  ·  in 9 days');
  });

  testWidgets('a new date left without a title is dropped', (tester) async {
    await openDates(tester);
    await tap(tester, find.byTooltip('Add a date'));
    await tap(tester, find.byKey(const Key('dateType-anniversary')));
    await pressBack(tester);
    expect(book().dates, isEmpty);
    expect(find.text('No dates'), findsOneWidget);
  });

  testWidgets(
      'each type its form (Round 61): a birthday every year, Year known '
      'for the age; an event once, with kinds; Other chooses', (tester) async {
    await openDates(tester);
    await tap(tester, find.byTooltip('Add a date'));
    await tester.enterText(find.byKey(const Key('dateTitle')), 'Exam');
    await tester.pumpAndSettle();
    DateEntry saved() => book().dates.single;
    // A birthday: no Every year; Year known, for the age.
    expect(find.byKey(const Key('dateYearly')), findsNothing);
    expect(find.text('For the age'), findsOneWidget);
    expect(find.byKey(const Key('dateKind-none')), findsNothing);
    await tap(tester, find.byKey(const Key('dateYearKnown')));
    expect(saved().year, isNull);
    expect(saved().yearly, isTrue);
    // An anniversary: for which one.
    await tap(tester, find.byKey(const Key('dateType-anniversary')));
    expect(find.text('For which anniversary'), findsOneWidget);
    // An event: once, this year; neither switch; its kinds.
    await tap(tester, find.byKey(const Key('dateType-event')));
    expect(saved().yearly, isFalse);
    expect(saved().year, 2026);
    expect(find.byKey(const Key('dateYearKnown')), findsNothing);
    expect(find.byKey(const Key('dateYearly')), findsNothing);
    expect(find.byKey(const Key('dateKind-wedding')), findsOneWidget);
    // A wedding: its own reminders, a week and a month before (they
    // were the usual); just an event again, the usual back.
    await tap(tester, find.byKey(const Key('dateKind-wedding')));
    expect(saved().kind, DateKind.wedding);
    expect(saved().reminders, DateReminder.weddingDefaults);
    await tap(tester, find.byKey(const Key('dateKind-none')));
    expect(saved().kind, isNull);
    expect(saved().reminders, DateReminder.defaults);
    // A wedding turned into a holiday: the usual reminders back.
    await tap(tester, find.byKey(const Key('dateKind-wedding')));
    await tap(tester, find.byKey(const Key('dateType-holiday')));
    expect(saved().reminders, DateReminder.defaults);
    await tap(tester, find.byKey(const Key('dateType-event')));
    await tap(tester, find.byKey(const Key('dateKind-none')));
    // Reminders changed by hand stay as they are.
    await tap(tester, find.byKey(const Key('dateReminderRemove-0')));
    await tap(tester, find.byKey(const Key('dateKind-wedding')));
    expect(saved().reminders, [DateReminder.defaults.last]);
    // A holiday's kinds.
    await tap(tester, find.byKey(const Key('dateType-holiday')));
    expect(saved().kindNow, isNull, reason: 'a wedding is no holiday');
    await tap(tester, find.byKey(const Key('dateKind-skiing')));
    expect(saved().kind, DateKind.skiing);
    // Other: it chooses.
    await tap(tester, find.byKey(const Key('dateType-other')));
    expect(find.byKey(const Key('dateYearly')), findsOneWidget);
    await tap(tester, find.byKey(const Key('dateYearly')));
    expect(saved().yearly, isTrue);
    expect(find.text('For how many years'), findsOneWidget);
  });

  testWidgets(
      'a ski trip\'s travel (Round 67): only on Skiing; hours each way, '
      'leaving at 06:00 the first day, back at 11:00 the day after',
      (tester) async {
    await openDates(tester);
    await tap(tester, find.byTooltip('Add a date'));
    await tester.enterText(find.byKey(const Key('dateTitle')), 'Jahorina');
    await tester.pumpAndSettle();
    DateEntry saved() => book().dates.single;
    await tap(tester, find.byKey(const Key('dateType-holiday')));
    expect(find.byKey(const Key('dateTravel')), findsNothing);
    await tap(tester, find.byKey(const Key('dateKind-skiing')));
    expect(find.byKey(const Key('dateTravel')), findsOneWidget);
    expect(find.text('None'), findsOneWidget);
    expect(find.byKey(const Key('dateLeaves')), findsNothing);
    await tap(tester, find.byKey(const Key('dateTravelMore')));
    await tap(tester, find.byKey(const Key('dateTravelMore')));
    expect(saved().travelHours, 2);
    expect(find.text('2 hours'), findsOneWidget);
    expect(find.text('06:00'), findsOneWidget);
    expect(find.text('11:00'), findsOneWidget);
    await tap(tester, find.byKey(const Key('dateTravelLess')));
    expect(saved().travelHours, 1);
    // Another kind: no travel.
    await tap(tester, find.byKey(const Key('dateKind-beach')));
    expect(find.byKey(const Key('dateTravel')), findsNothing);
    expect(saved().hasTravel, isFalse);
  });

  testWidgets(
      'a card says it all (Round 61): its day (no year for one every '
      'year), how soon, the age; its kind, days, year, reminders',
      (tester) async {
    await openDates(tester, start: [
      const DateEntry(
        id: 'ana',
        title: 'Ana',
        type: DateType.birthday,
        day: 10,
        month: 10,
        year: 1995,
      ),
      const DateEntry(
        id: 'ski',
        title: 'Jahorina',
        type: DateType.holiday,
        kind: DateKind.skiing,
        day: 20,
        month: 1,
        year: 2027,
        yearly: false,
        days: 5,
        reminders: [],
      ),
    ]);
    // Ana's next is in 2027: no year for it (it read as her birth year).
    expect(whenOf(tester, 'ana'), 'Sun, 10 Oct  ·  in 360 days  ·  turns 32');
    String details(String id) =>
        tester.widget<Text>(find.byKey(Key('dateDetails-$id'))).data!;
    expect(details('ana'), 'born 1995  ·  1 day before');
    expect(whenOf(tester, 'ski'),
        'Wed, 20 Jan 2027 – Sun, 24 Jan 2027  ·  in 97 days');
    expect(details('ski'), 'Skiing  ·  5 days');
    // Its kind's icon: skis.
    expect(find.byIcon(Icons.downhill_skiing), findsOneWidget);
  });

  testWidgets('opened; deleted once confirmed (Round 58), with Undo',
      (tester) async {
    await openDates(tester, start: [date('Ana', 24, 10, year: 1995)]);
    await tap(tester, find.text('Ana'));
    expect(appBarTitle('Date'), findsOneWidget);
    expect(find.byKey(const Key('dateNext')), findsOneWidget);
    expect(find.text('Sat, 24 Oct  ·  in 9 days  ·  turns 31'), findsOneWidget);
    await tap(tester, find.byKey(const Key('deleteDate')));
    expect(find.text('Delete Ana?'), findsOneWidget);
    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();
    expect(book().dates, hasLength(1), reason: 'not confirmed');
    expect(appBarTitle('Date'), findsOneWidget);
    await tap(tester, find.byKey(const Key('deleteDate')));
    await tester.tap(find.widgetWithText(DialogButton, 'Delete'));
    await tester.pumpAndSettle();
    expect(book().dates, isEmpty);
    expect(find.text('Ana deleted'), findsOneWidget);
    await tester.tap(find.text('Undo'));
    await tester.pumpAndSettle();
    expect(book().dates, hasLength(1));
    expect(find.text('Ana'), findsOneWidget);
  });

  testWidgets('+ on the right (Round 59), even opened from a tile on the left',
      (tester) async {
    container = await pumpApp(tester, clock: () => now);
    await openTab(tester, 'Hub');
    // A touch on the left first: the hand can't be told from it here.
    await tester.tapAt(const Offset(20, 300));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Dates'));
    await tester.pumpAndSettle();
    final width = tester.view.physicalSize.width / tester.view.devicePixelRatio;
    expect(tester.getCenter(find.byTooltip('Add a date')).dx,
        greaterThan(width / 2));
  });

  testWidgets(
      'a holiday lasts (Round 59): days picked; on each of them in the '
      'calendar; its days on its card', (tester) async {
    await openDates(tester);
    await tester.tap(find.byKey(const Key('datesDay-2026-10-24')));
    await tester.pumpAndSettle();
    await tap(tester, find.byTooltip('Add a date'));
    await tester.enterText(find.byKey(const Key('dateTitle')), 'Odmor');
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('dateLasts')), findsNothing,
        reason: 'a birthday is a day');
    await tap(tester, find.byKey(const Key('dateType-holiday')));
    expect(find.text('1 day'), findsOneWidget);
    expect(
        tester
            .widget<IconButton>(find.byKey(const Key('dateDaysLess')))
            .onPressed,
        isNull);
    await tap(tester, find.byKey(const Key('dateDaysMore')));
    await tap(tester, find.byKey(const Key('dateDaysMore')));
    expect(find.text('3 days'), findsOneWidget);
    expect(book().dates.single.days, 3);
    await tap(tester, find.byKey(const Key('dateDaysLess')));
    expect(book().dates.single.days, 2);
    await tap(tester, find.byKey(const Key('dateType-event')));
    expect(find.text('2 days'), findsOneWidget, reason: 'an event lasts too');
    await pressBack(tester);
    final id = book().dates.single.id;
    List<Color> mark(String day) =>
        (tester.widget<CustomPaint>(find.byKey(Key('datesMark-$day'))).painter!
                as DateMarkPainter)
            .colours;
    expect(mark('2026-10-24'), [DateType.event.colour]);
    expect(mark('2026-10-25'), [DateType.event.colour]);
    expect(mark('2026-10-26'), isEmpty);
    // Picked on its second day: shown from its first.
    await tester.tap(find.byKey(const Key('datesDay-2026-10-25')));
    await tester.pumpAndSettle();
    expect(whenOf(tester, id), 'Sat, 24 Oct – Sun, 25 Oct  ·  in 9 days');
  });

  testWidgets(
      'a day with two dates of one kind (Round 60): its colour once, with '
      'a border; picked, ringed', (tester) async {
    await openDates(tester, start: [
      date('Ana', 24, 10),
      date('Bo', 24, 10),
    ]);
    DateMarkPainter mark() => tester
        .widget<CustomPaint>(find.byKey(const Key('datesMark-2026-10-24')))
        .painter! as DateMarkPainter;
    expect(mark().colours, [DateType.birthday.colour]);
    expect(mark().several, isTrue);
    expect(mark().picked, isNull);
    await tester.tap(find.byKey(const Key('datesDay-2026-10-24')));
    await tester.pumpAndSettle();
    expect(mark().picked, isNotNull);
  });
}
