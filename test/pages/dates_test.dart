import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:the_app/models/date_entry.dart';
import 'package:the_app/providers/dates_provider.dart';

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
    Iterable<Widget> dots(String day) =>
        tester.widget<Row>(find.byKey(Key('datesDots-$day'))).children;
    expect(dots('2026-10-24'), hasLength(2));
    expect(dots('2026-10-23'), isEmpty);
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
    expect(dots('2026-11-3'), hasLength(1));
  });

  testWidgets(
      '+ on a picked day: a new date there, saved once titled; year '
      'not known; reminders: the day before at 09:00, another added, '
      'one removed', (tester) async {
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
    await tap(tester, find.byKey(const Key('dateYearKnown')));
    expect(find.text('24 October'), findsOneWidget);
    await tap(tester, find.byKey(const Key('dateAddReminder')));
    await tap(tester, find.byKey(const Key('reminderDays-7')));
    await tap(tester, find.byKey(const Key('reminderDone')));
    await tap(tester, find.byKey(const Key('dateReminderRemove-0')));
    await tester.enterText(find.byKey(const Key('dateNote')), 'a book');
    await tester.pumpAndSettle();
    final saved = book().dates.single;
    expect(saved.year, isNull);
    expect(saved.yearly, isTrue);
    expect(saved.type, DateType.birthday);
    expect(saved.note, 'a book');
    expect(saved.reminders, const [DateReminder(daysBefore: 7, minutes: 540)]);
    // Only three.
    await tap(tester, find.byKey(const Key('dateAddReminder')));
    await tap(tester, find.byKey(const Key('reminderDone')));
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
      'an event is once (its year needed: no Year known); back to a '
      'birthday, every year again', (tester) async {
    await openDates(tester);
    await tap(tester, find.byTooltip('Add a date'));
    await tester.enterText(find.byKey(const Key('dateTitle')), 'Exam');
    await tester.pumpAndSettle();
    // Its year not known first: once, it's this year's.
    await tap(tester, find.byKey(const Key('dateYearKnown')));
    expect(book().dates.single.year, isNull);
    await tap(tester, find.byKey(const Key('dateType-event')));
    expect(book().dates.single.yearly, isFalse);
    expect(book().dates.single.year, 2026);
    expect(find.byKey(const Key('dateYearKnown')), findsNothing);
    await tap(tester, find.byKey(const Key('dateType-birthday')));
    expect(book().dates.single.yearly, isTrue);
    expect(find.byKey(const Key('dateYearKnown')), findsOneWidget);
    // Every year off again, its year not known: this year's too.
    await tap(tester, find.byKey(const Key('dateYearKnown')));
    expect(book().dates.single.year, isNull);
    await tap(tester, find.byKey(const Key('dateYearly')));
    expect(book().dates.single.yearly, isFalse);
    expect(book().dates.single.year, 2026);
  });

  testWidgets('opened, changed, deleted with Undo', (tester) async {
    await openDates(tester, start: [date('Ana', 24, 10, year: 1995)]);
    await tap(tester, find.text('Ana'));
    expect(appBarTitle('Date'), findsOneWidget);
    expect(find.byKey(const Key('dateNext')), findsOneWidget);
    expect(find.text('Sat, 24 Oct  ·  in 9 days  ·  turns 31'), findsOneWidget);
    await tap(tester, find.byKey(const Key('deleteDate')));
    expect(book().dates, isEmpty);
    expect(find.text('Ana deleted'), findsOneWidget);
    await tester.tap(find.text('Undo'));
    await tester.pumpAndSettle();
    expect(book().dates, hasLength(1));
    expect(find.text('Ana'), findsOneWidget);
  });
}
