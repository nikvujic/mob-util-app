import 'package:flutter/material.dart';
import 'package:the_app/core/format.dart';
import 'package:the_app/core/theme.dart';

/// A horizontal strip of days, a week wide. Swiping scrolls freely (a fast
/// swipe travels far) and then snaps a day into the middle, which becomes
/// the selected day; tapping a day selects it too. Today is outlined, and
/// days that have something on them ([hasItems]) get a dot.
///
/// It starts at [firstDay]; the 3 days before it are shown greyed out as
/// filler and can't be selected or scrolled to (P6).
class DayStrip extends StatefulWidget {
  /// How many days after today can be reached.
  static const futureDays = 3650;

  /// Days visible at once; the selected one is in the middle.
  static const visibleDays = 7;

  /// Greyed-out days before [firstDay] (half the strip, minus the middle).
  static const fillerDays = visibleDays ~/ 2;

  static const height = 72.0;

  final DateTime today;

  /// The first day that can be selected (today, or earlier).
  final DateTime firstDay;
  final DateTime selected;
  final ValueChanged<DateTime> onSelected;
  final bool Function(DateTime day) hasItems;

  const DayStrip({
    super.key,
    required this.today,
    required this.firstDay,
    required this.selected,
    required this.onSelected,
    required this.hasItems,
  });

  @override
  State<DayStrip> createState() => _DayStripState();
}

class _DayStripState extends State<DayStrip> {
  ScrollController? _controller;
  double _extent = 0;

  /// Selectable days, from [DayStrip.firstDay] to the last future one.
  int get _dayCount =>
      daysBetween(widget.firstDay, widget.today) + DayStrip.futureDays + 1;

  /// Position of [day] among the selectable days (0 = first day).
  int _indexOf(DateTime day) =>
      daysBetween(widget.firstDay, day).clamp(0, _dayCount - 1).toInt();

  /// The scroll offset that puts selectable day [index] in the middle.
  double _offsetOf(int index) => index * _extent;

  void _goTo(int index) {
    _controller?.animateTo(
      _offsetOf(index),
      duration: const Duration(milliseconds: 250),
      curve: Curves.easeOut,
    );
  }

  bool _onScroll(ScrollNotification notification) {
    if (notification is ScrollEndNotification && _extent > 0) {
      final index = (notification.metrics.pixels / _extent).round();
      final day = addDays(widget.firstDay, index);
      if (daysBetween(day, widget.selected) != 0) widget.onSelected(day);
    }
    return false;
  }

  @override
  void didUpdateWidget(DayStrip old) {
    super.didUpdateWidget(old);
    final controller = _controller;
    if (controller == null || !controller.hasClients || _extent == 0) return;
    // The first day moved, or a day was selected from outside: keep the
    // selected day in the middle.
    final target = _offsetOf(_indexOf(widget.selected));
    if (daysBetween(old.firstDay, widget.firstDay) != 0) {
      controller.jumpTo(target);
    } else if (!controller.position.isScrollingNotifier.value &&
        (controller.offset - target).abs() > 1) {
      _goTo(_indexOf(widget.selected));
    }
  }

  @override
  void dispose() {
    _controller?.dispose();
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
          child: LayoutBuilder(
            builder: (context, box) {
              _extent = box.maxWidth / DayStrip.visibleDays;
              final controller = _controller ??= ScrollController(
                initialScrollOffset: _offsetOf(_indexOf(widget.selected)),
              );
              const filler = DayStrip.fillerDays;
              return NotificationListener<ScrollNotification>(
                onNotification: _onScroll,
                child: ListView.builder(
                  controller: controller,
                  scrollDirection: Axis.horizontal,
                  physics: _SnapToDay(_extent),
                  itemExtent: _extent,
                  // Room after the last day, so it can reach the middle.
                  padding: EdgeInsets.only(right: filler * _extent),
                  itemCount: filler + _dayCount,
                  itemBuilder: (context, i) {
                    final day = addDays(widget.firstDay, i - filler);
                    if (i < filler) return _DayCell.filler(day: day);
                    return _DayCell(
                      day: day,
                      selected: daysBetween(day, widget.selected) == 0,
                      isToday: daysBetween(day, widget.today) == 0,
                      hasItems: widget.hasItems(day),
                      onTap: () => _goTo(i - filler),
                    );
                  },
                ),
              );
            },
          ),
        ),
      ),
    );
  }
}

/// Scrolls with the fling's full momentum, then settles with a day exactly
/// in the middle (offsets that are a multiple of the day width).
class _SnapToDay extends ScrollPhysics {
  final double extent;

  const _SnapToDay(this.extent, {super.parent});

  @override
  _SnapToDay applyTo(ScrollPhysics? ancestor) =>
      _SnapToDay(extent, parent: buildParent(ancestor));

  @override
  Simulation? createBallisticSimulation(
    ScrollMetrics position,
    double velocity,
  ) {
    if (extent <= 0) return super.createBallisticSimulation(position, velocity);
    // Where the fling would come to rest on its own, rounded to a day.
    final natural = super.createBallisticSimulation(position, velocity);
    final end = natural?.x(double.infinity) ?? position.pixels;
    final target = ((end / extent).round() * extent)
        .clamp(position.minScrollExtent, position.maxScrollExtent)
        .toDouble();
    if ((target - position.pixels).abs() < toleranceFor(position).distance &&
        velocity.abs() < toleranceFor(position).velocity) {
      return null;
    }
    return ScrollSpringSimulation(
      spring,
      position.pixels,
      target,
      velocity,
      tolerance: toleranceFor(position),
    );
  }
}

class _DayCell extends StatelessWidget {
  final DateTime day;
  final bool selected;
  final bool isToday;
  final bool hasItems;

  /// Null for greyed-out filler days.
  final VoidCallback? onTap;

  const _DayCell({
    required this.day,
    required this.selected,
    required this.isToday,
    required this.hasItems,
    required this.onTap,
  });

  const _DayCell.filler({required this.day})
      : selected = false,
        isToday = false,
        hasItems = false,
        onTap = null;

  @override
  Widget build(BuildContext context) {
    final filler = onTap == null;
    final color = filler
        ? AppColors.textHint
        : selected
            ? AppColors.background
            : isToday
                ? AppColors.accent
                : AppColors.textPrimary;
    final content = Padding(
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
    );
    // Filler days are only there to fill the strip.
    if (filler) return ExcludeSemantics(child: content);
    return Semantics(
      button: true,
      selected: selected,
      label: '${isToday ? 'Today, ' : ''}${formatDayLong(day)}'
          '${hasItems ? ', has tasks' : ''}',
      excludeSemantics: true,
      child: content,
    );
  }
}
