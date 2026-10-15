import 'package:flutter/material.dart';
import 'package:the_app/core/format.dart';
import 'package:the_app/core/theme.dart';
import 'package:the_app/models/date_entry.dart';
import 'package:the_app/pages/hub/dates.dart';

/// Birthdays & dates on a month calendar (Round 57; like Food's, but it
/// goes forward too): weeks as rows, Monday first, a day with dates
/// shows a dot in each one's colour (up to three), today's number in the
/// accent, the picked day ringed. A year back and a year ahead; it opens
/// on this month.
class DatesCalendar extends StatefulWidget {
  final DateBook book;
  final DateTime today;
  final DateTime? picked;
  final ValueChanged<DateTime> onDay;

  const DatesCalendar({
    super.key,
    required this.book,
    required this.today,
    required this.picked,
    required this.onDay,
  });

  /// Months before this one, and after it.
  static const reach = 12;

  static const cell = 32.0;
  static const row = 40.0;

  /// Six weeks fit any month.
  static const height = 24 + 6 * row;

  @override
  State<DatesCalendar> createState() => _DatesCalendarState();
}

class _DatesCalendarState extends State<DatesCalendar> {
  final _pages = PageController(initialPage: DatesCalendar.reach);
  int _page = DatesCalendar.reach;

  DateTime _monthOf(int page) => DateTime(
      widget.today.year, widget.today.month + page - DatesCalendar.reach);

  void _go(int page) => _pages.animateToPage(
        page,
        duration: const Duration(milliseconds: 250),
        curve: Curves.easeOut,
      );

  @override
  void dispose() {
    _pages.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    const last = 2 * DatesCalendar.reach;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          children: [
            IconButton(
              key: const Key('datesMonthBefore'),
              tooltip: 'Month before',
              icon: const Icon(Icons.chevron_left),
              onPressed: _page > 0 ? () => _go(_page - 1) : null,
            ),
            Expanded(
              child: Text(
                formatMonth(_monthOf(_page)),
                key: const Key('datesMonth'),
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: colors.textPrimary,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            IconButton(
              key: const Key('datesMonthAfter'),
              tooltip: 'Month after',
              icon: const Icon(Icons.chevron_right),
              onPressed: _page < last ? () => _go(_page + 1) : null,
            ),
          ],
        ),
        SizedBox(
          height: DatesCalendar.height,
          child: PageView.builder(
            key: const Key('datesCalendar'),
            controller: _pages,
            itemCount: last + 1,
            onPageChanged: (page) => setState(() => _page = page),
            itemBuilder: (context, page) => Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              child: _Month(
                month: _monthOf(page),
                book: widget.book,
                today: widget.today,
                picked: widget.picked,
                onDay: widget.onDay,
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _Month extends StatelessWidget {
  final DateTime month;
  final DateBook book;
  final DateTime today;
  final DateTime? picked;
  final ValueChanged<DateTime> onDay;

  const _Month({
    required this.month,
    required this.book,
    required this.today,
    required this.picked,
    required this.onDay,
  });

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final first = DateTime(month.year, month.month);
    final start = addDays(first, -(first.weekday - 1));
    final last = DateTime(month.year, month.month + 1, 0);
    final weeks = (daysBetween(start, last) ~/ 7) + 1;
    return Column(
      children: [
        SizedBox(
          height: 24,
          child: Row(
            children: [
              for (var i = 0; i < 7; i++)
                Expanded(
                  child: Text(
                    weekdayShort(addDays(start, i)).substring(0, 1),
                    textAlign: TextAlign.center,
                    style: TextStyle(color: colors.textMuted, fontSize: 12),
                  ),
                ),
            ],
          ),
        ),
        for (var w = 0; w < weeks; w++)
          SizedBox(
            height: DatesCalendar.row,
            child: Row(
              children: [
                for (var d = 0; d < 7; d++)
                  Expanded(
                    child: addDays(start, w * 7 + d).month == month.month
                        ? _Day(
                            day: addDays(start, w * 7 + d),
                            dates: book.on(addDays(start, w * 7 + d)),
                            today: today,
                            picked: picked,
                            onDay: onDay,
                          )
                        : const SizedBox.shrink(),
                  ),
              ],
            ),
          ),
      ],
    );
  }
}

class _Day extends StatelessWidget {
  final DateTime day;
  final List<DateEntry> dates;
  final DateTime today;
  final DateTime? picked;
  final ValueChanged<DateTime> onDay;

  const _Day({
    required this.day,
    required this.dates,
    required this.today,
    required this.picked,
    required this.onDay,
  });

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final isToday = day == today;
    final isPicked = day == picked;
    return Semantics(
      button: true,
      selected: isPicked,
      label: '${formatDayLong(day)}'
          '${dates.isEmpty ? '' : ', ${dates.map((d) => d.title).join(', ')}'}',
      excludeSemantics: true,
      child: GestureDetector(
        key: Key('datesDay-${day.year}-${day.month}-${day.day}'),
        behavior: HitTestBehavior.opaque,
        onTap: () => onDay(day),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: DatesCalendar.cell,
              height: DatesCalendar.cell - 6,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(13),
                border: isPicked
                    ? Border.all(color: colors.accent, width: 2.5)
                    : null,
              ),
              child: Text(
                '${day.day}',
                style: TextStyle(
                  color: isToday ? colors.accent : colors.textPrimary,
                  fontWeight: isToday || dates.isNotEmpty
                      ? FontWeight.w700
                      : FontWeight.w400,
                ),
              ),
            ),
            SizedBox(
              height: 8,
              child: Row(
                key: Key('datesDots-${day.year}-${day.month}-${day.day}'),
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  for (final d in dates.take(3))
                    Container(
                      width: 6,
                      height: 6,
                      margin: const EdgeInsets.symmetric(horizontal: 1),
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: d.type.colour,
                      ),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
