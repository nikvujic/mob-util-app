import 'package:flutter/material.dart';
import 'package:the_app/core/format.dart';
import 'package:the_app/core/theme.dart';

/// A horizontal strip of days, a week wide. Swiping snaps a day into the
/// middle and selects it; tapping a day selects it too. Today is marked,
/// and days that have something on them ([hasItems]) get a dot.
class DayStrip extends StatefulWidget {
  /// How many days before and after today can be reached.
  static const range = 3650;

  /// Days visible at once.
  static const visibleDays = 7;

  static const height = 72.0;

  final DateTime today;
  final DateTime selected;
  final ValueChanged<DateTime> onSelected;
  final bool Function(DateTime day) hasItems;

  const DayStrip({
    super.key,
    required this.today,
    required this.selected,
    required this.onSelected,
    required this.hasItems,
  });

  @override
  State<DayStrip> createState() => _DayStripState();
}

class _DayStripState extends State<DayStrip> {
  late final PageController _controller = PageController(
    initialPage: _pageOf(widget.selected),
    viewportFraction: 1 / DayStrip.visibleDays,
  );

  int _pageOf(DateTime day) => DayStrip.range + daysBetween(widget.today, day);

  DateTime _dayAt(int page) => addDays(widget.today, page - DayStrip.range);

  @override
  void didUpdateWidget(DayStrip old) {
    super.didUpdateWidget(old);
    // Selected from outside (e.g. "Today"): bring it to the middle.
    final page = _pageOf(widget.selected);
    if (_controller.hasClients && _controller.page?.round() != page) {
      _controller.animateToPage(
        page,
        duration: const Duration(milliseconds: 250),
        curve: Curves.easeOut,
      );
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.surface,
      child: SafeArea(
        top: false,
        child: SizedBox(
          height: DayStrip.height,
          child: PageView.builder(
            controller: _controller,
            itemCount: 2 * DayStrip.range + 1,
            onPageChanged: (page) => widget.onSelected(_dayAt(page)),
            itemBuilder: (context, page) {
              final day = _dayAt(page);
              return _DayCell(
                day: day,
                selected: daysBetween(day, widget.selected) == 0,
                isToday: page == DayStrip.range,
                hasItems: widget.hasItems(day),
                onTap: () => _controller.animateToPage(
                  page,
                  duration: const Duration(milliseconds: 250),
                  curve: Curves.easeOut,
                ),
              );
            },
          ),
        ),
      ),
    );
  }
}

class _DayCell extends StatelessWidget {
  final DateTime day;
  final bool selected;
  final bool isToday;
  final bool hasItems;
  final VoidCallback onTap;

  const _DayCell({
    required this.day,
    required this.selected,
    required this.isToday,
    required this.hasItems,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final color = selected
        ? AppColors.background
        : isToday
            ? AppColors.accent
            : AppColors.textPrimary;
    return Semantics(
      button: true,
      selected: selected,
      label: '${isToday ? 'Today, ' : ''}${formatDayLong(day)}'
          '${hasItems ? ', has tasks' : ''}',
      excludeSemantics: true,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 2, vertical: 6),
        child: Material(
          color: selected ? AppColors.accent : Colors.transparent,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
            side: isToday && !selected
                ? const BorderSide(color: AppColors.accent)
                : BorderSide.none,
          ),
          child: InkWell(
            borderRadius: BorderRadius.circular(12),
            onTap: onTap,
            // With a very large system font, shrink to fit the cell rather
            // than overflow it.
            child: FittedBox(
              fit: BoxFit.scaleDown,
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    weekdayShort(day),
                    style: TextStyle(color: color, fontSize: 11),
                  ),
                  Text(
                    '${day.day}',
                    style: TextStyle(
                      color: color,
                      fontSize: 18,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  Container(
                    width: 5,
                    height: 5,
                    margin: const EdgeInsets.only(top: 2),
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: hasItems ? color : Colors.transparent,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
