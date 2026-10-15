import 'package:flutter/material.dart';
import 'package:the_app/core/format.dart';
import 'package:the_app/core/theme.dart';
import 'package:the_app/models/food.dart';
import 'package:the_app/pages/hub/food.dart';

/// The food tracker's days as a month calendar (Round 47: like Medicine's
/// history, bigger than a week's line): weeks as rows, Monday first, each
/// day a circle in its worst rated meal's colour (logged, none rated: a
/// ring), the picked day ringed in the accent. It opens on this month;
/// older months are to the left (swipe right, or ‹), back to the first
/// meal's. Days to come can't be picked.
class FoodCalendar extends StatefulWidget {
  final FoodBook book;
  final DateTime today;
  final DateTime picked;
  final ValueChanged<DateTime> onDay;

  const FoodCalendar({
    super.key,
    required this.book,
    required this.today,
    required this.picked,
    required this.onDay,
  });

  /// A day's circle (Round 51: as small as the week line's were) and its
  /// row, which takes the taps between the circles too.
  static const cell = 32.0;
  static const row = 38.0;

  /// Six weeks fit any month.
  static const height = 24 + 6 * row;

  @override
  State<FoodCalendar> createState() => _FoodCalendarState();
}

class _FoodCalendarState extends State<FoodCalendar> {
  final _pages = PageController();
  int _page = 0;

  DateTime get _newest => DateTime(widget.today.year, widget.today.month);

  /// This month back to the first meal's (at least this one).
  int get _months {
    if (widget.book.meals.isEmpty) return 1;
    final first = widget.book.meals.first.at.toLocal();
    final months =
        (_newest.year - first.year) * 12 + _newest.month - first.month + 1;
    return months < 1 ? 1 : months;
  }

  DateTime _monthOf(int page) => DateTime(_newest.year, _newest.month - page);

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
    final months = _months;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          children: [
            IconButton(
              key: const Key('foodMonthBefore'),
              tooltip: 'Month before',
              icon: const Icon(Icons.chevron_left),
              onPressed: _page + 1 < months ? () => _go(_page + 1) : null,
            ),
            Expanded(
              child: Text(
                formatMonth(_monthOf(_page)),
                key: const Key('foodMonth'),
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: colors.textPrimary,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            IconButton(
              key: const Key('foodMonthAfter'),
              tooltip: 'Month after',
              icon: const Icon(Icons.chevron_right),
              onPressed: _page > 0 ? () => _go(_page - 1) : null,
            ),
          ],
        ),
        SizedBox(
          height: FoodCalendar.height,
          // Reversed: this month at the start, older ones to the left.
          child: PageView.builder(
            key: const Key('foodCalendar'),
            controller: _pages,
            reverse: true,
            itemCount: months,
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
  final FoodBook book;
  final DateTime today;
  final DateTime picked;
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
            height: FoodCalendar.row,
            child: Row(
              children: [
                for (var d = 0; d < 7; d++)
                  Expanded(
                    child: _Day(
                      day: addDays(start, w * 7 + d),
                      inMonth: addDays(start, w * 7 + d).month == month.month,
                      book: book,
                      today: today,
                      picked: picked,
                      onDay: onDay,
                    ),
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
  final bool inMonth;
  final FoodBook book;
  final DateTime today;
  final DateTime picked;
  final ValueChanged<DateTime> onDay;

  const _Day({
    required this.day,
    required this.inMonth,
    required this.book,
    required this.today,
    required this.picked,
    required this.onDay,
  });

  @override
  Widget build(BuildContext context) {
    if (!inMonth) return const SizedBox(height: FoodCalendar.row);
    final colors = context.colors;
    final future = day.isAfter(today);
    final worst = book.worstOn(day);
    final logged = worst != null || book.mealsOn(day).isNotEmpty;
    final isPicked = day == picked;
    final isToday = day == today;
    final circle = Center(
      child: Container(
        key: Key('foodDay-${day.year}-${day.month}-${day.day}'),
        width: FoodCalendar.cell,
        height: FoodCalendar.cell,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: worst?.colour,
          border: isPicked
              ? Border.all(color: colors.accent, width: 3)
              : logged && worst == null
                  ? Border.all(color: colors.textMuted)
                  : null,
        ),
        child: Text(
          '${day.day}',
          style: TextStyle(
            color: future
                ? colors.textHint
                : worst != null
                    ? RatingColours.ink
                    : isToday
                        ? colors.accent
                        : colors.textPrimary,
            fontWeight: isToday || logged ? FontWeight.w700 : FontWeight.w400,
          ),
        ),
      ),
    );
    if (future) return ExcludeSemantics(child: circle);
    return Semantics(
      button: true,
      selected: isPicked,
      label: '${formatDayLong(day)}'
          '${worst != null ? ', worst ${worst.label}' : logged ? ', not rated' : ''}',
      excludeSemantics: true,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () => onDay(day),
        child: circle,
      ),
    );
  }
}
