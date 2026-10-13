import 'package:flutter/material.dart';
import 'package:the_app/core/format.dart';
import 'package:the_app/core/theme.dart';
import 'package:the_app/models/medicine.dart';
import 'package:the_app/pages/hub/medicine_history.dart';

/// A medicine's days as a month calendar (O13, Round 16: "an actual
/// calendar with marks"): weeks as rows, Monday first, each day coloured
/// by how it went. It opens on this month; older months are to the left
/// (swipe right, or ‹). Tapping a day sets its doses.
class MedicineCalendar extends StatefulWidget {
  final Medicine medicine;
  final MedicineBook book;
  final DateTime today;
  final ValueChanged<DateTime> onDay;

  const MedicineCalendar({
    super.key,
    required this.medicine,
    required this.book,
    required this.today,
    required this.onDay,
  });

  static const _cell = 42.0;
  static const _gap = 4.0;

  /// Six weeks fit any month.
  static const height = 24 + 6 * (_cell + _gap);

  @override
  State<MedicineCalendar> createState() => _MedicineCalendarState();
}

class _MedicineCalendarState extends State<MedicineCalendar> {
  final _pages = PageController();

  /// Page 0 is the newest month shown (this month, or the last one it's
  /// taken in); each page after it a month earlier.
  late DateTime _newest;
  late int _months;
  int _page = 0;

  @override
  void initState() {
    super.initState();
    _range();
  }

  @override
  void didUpdateWidget(MedicineCalendar old) {
    super.didUpdateWidget(old);
    _range();
  }

  void _range() {
    final m = widget.medicine;
    final end = m.until != null && m.until!.isBefore(widget.today)
        ? m.until!
        : widget.today;
    _newest = DateTime(end.year, end.month);
    _months = (end.year - m.from.year) * 12 + end.month - m.from.month + 1;
    if (_months < 1) _months = 1;
  }

  @override
  void dispose() {
    _pages.dispose();
    super.dispose();
  }

  DateTime _monthOf(int page) => DateTime(_newest.year, _newest.month - page);

  void _go(int page) => _pages.animateToPage(
        page,
        duration: const Duration(milliseconds: 250),
        curve: Curves.easeOut,
      );

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final month = _monthOf(_page);
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // The month, with arrows: ‹ older (left), › newer.
        Row(
          children: [
            IconButton(
              key: const Key('calendarOlder'),
              tooltip: 'Month before',
              icon: const Icon(Icons.chevron_left),
              onPressed: _page + 1 < _months ? () => _go(_page + 1) : null,
            ),
            Expanded(
              child: Text(
                formatMonth(month),
                key: const Key('calendarMonth'),
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: colors.textPrimary,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            IconButton(
              key: const Key('calendarNewer'),
              tooltip: 'Month after',
              icon: const Icon(Icons.chevron_right),
              onPressed: _page > 0 ? () => _go(_page - 1) : null,
            ),
          ],
        ),
        SizedBox(
          height: MedicineCalendar.height,
          // Reversed: the newest month at the start, older ones to the
          // left.
          child: PageView.builder(
            key: const Key('medicineCalendar'),
            controller: _pages,
            reverse: true,
            itemCount: _months,
            onPageChanged: (page) => setState(() => _page = page),
            itemBuilder: (context, page) => Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              child: _Month(
                month: _monthOf(page),
                medicine: widget.medicine,
                book: widget.book,
                today: widget.today,
                onDay: widget.onDay,
              ),
            ),
          ),
        ),
        const _Legend(),
      ],
    );
  }
}

/// One month: weekday letters, then its weeks.
class _Month extends StatelessWidget {
  final DateTime month;
  final Medicine medicine;
  final MedicineBook book;
  final DateTime today;
  final ValueChanged<DateTime> onDay;

  const _Month({
    required this.month,
    required this.medicine,
    required this.book,
    required this.today,
    required this.onDay,
  });

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    // Monday of the week the month starts in.
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
          Padding(
            padding: const EdgeInsets.only(bottom: MedicineCalendar._gap),
            child: Row(
              children: [
                for (var d = 0; d < 7; d++)
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: MedicineCalendar._gap / 2,
                      ),
                      child: _Day(
                        day: addDays(start, w * 7 + d),
                        month: month,
                        medicine: medicine,
                        book: book,
                        today: today,
                        onDay: onDay,
                      ),
                    ),
                  ),
              ],
            ),
          ),
      ],
    );
  }
}

/// A day's square: coloured by how it went while the medicine was taken
/// (up to today); other days just show their number, faint.
class _Day extends StatelessWidget {
  final DateTime day;
  final DateTime month;
  final Medicine medicine;
  final MedicineBook book;
  final DateTime today;
  final ValueChanged<DateTime> onDay;

  const _Day({
    required this.day,
    required this.month,
    required this.medicine,
    required this.book,
    required this.today,
    required this.onDay,
  });

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    if (day.month != month.month) {
      return const SizedBox(height: MedicineCalendar._cell);
    }
    final counts = medicine.isOn(day) && !day.isAfter(today);
    final outcome = counts ? outcomeOf(book, [medicine], day) : DayOutcome.none;
    final dark = outcome == DayOutcome.taken || outcome == DayOutcome.missed;
    final isToday = daysBetween(day, today) == 0;
    final square = Container(
      key: Key('calendar-${PlannerDay.key(day)}'),
      height: MedicineCalendar._cell,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: counts ? outcomeColour(context, outcome) : null,
        borderRadius: BorderRadius.circular(8),
        border:
            isToday ? Border.all(color: colors.textPrimary, width: 2) : null,
      ),
      child: Text(
        '${day.day}',
        style: TextStyle(
          color: !counts
              ? colors.textMuted
              : dark
                  ? colors.background
                  : colors.textPrimary,
          fontWeight: counts ? FontWeight.w600 : FontWeight.w400,
        ),
      ),
    );
    if (!counts) return ExcludeSemantics(child: square);
    return Semantics(
      button: true,
      label: '${formatDayLong(day)}: ${_said(outcome)}',
      excludeSemantics: true,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () => onDay(day),
        child: square,
      ),
    );
  }

  static String _said(DayOutcome outcome) => switch (outcome) {
        DayOutcome.taken => 'all taken',
        DayOutcome.partly => 'some taken',
        DayOutcome.missed => 'missed',
        DayOutcome.unsure => 'not sure',
        DayOutcome.none => 'not set',
      };
}

/// What the colours mean.
class _Legend extends StatelessWidget {
  const _Legend();

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    Widget item(DayOutcome outcome, String label) => Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 12,
              height: 12,
              decoration: BoxDecoration(
                color: outcomeColour(context, outcome),
                borderRadius: BorderRadius.circular(3),
                border: outcome == DayOutcome.none
                    ? Border.all(color: colors.textHint)
                    : null,
              ),
            ),
            const SizedBox(width: 4),
            Text(
              label,
              style: TextStyle(color: colors.textSecondary, fontSize: 12),
            ),
          ],
        );
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 0),
      child: Wrap(
        spacing: 12,
        runSpacing: 4,
        alignment: WrapAlignment.center,
        children: [
          item(DayOutcome.taken, 'Taken'),
          item(DayOutcome.partly, 'Some'),
          item(DayOutcome.missed, 'Missed'),
          item(DayOutcome.unsure, 'Not sure'),
          item(DayOutcome.none, 'Not set'),
        ],
      ),
    );
  }
}
