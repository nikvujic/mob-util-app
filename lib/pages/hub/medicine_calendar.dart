import 'package:flutter/material.dart';
import 'package:the_app/core/format.dart';
import 'package:the_app/core/theme.dart';
import 'package:the_app/models/medicine.dart';
import 'package:the_app/pages/hub/medicine_history.dart';

/// A medicine's days as a strip of small squares (O13), oldest at the left
/// and today at the right, where it opens; older ones are a scroll to the
/// left. Each square is coloured by how the day went; tapping one sets
/// its doses.
class MedicineCalendar extends StatelessWidget {
  final Medicine medicine;
  final MedicineBook book;

  /// Oldest first.
  final List<DateTime> days;
  final DateTime today;
  final ValueChanged<DateTime> onDay;

  const MedicineCalendar({
    super.key,
    required this.medicine,
    required this.book,
    required this.days,
    required this.today,
    required this.onDay,
  });

  static const _cell = 44.0;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return SizedBox(
      height: _cell + 22,
      // Reversed: it starts at the end, today in view.
      child: ListView.separated(
        key: const Key('medicineCalendar'),
        scrollDirection: Axis.horizontal,
        reverse: true,
        padding: const EdgeInsets.symmetric(horizontal: 12),
        itemCount: days.length,
        separatorBuilder: (_, __) => const SizedBox(width: 4),
        itemBuilder: (context, index) {
          final day = days[days.length - 1 - index];
          final outcome = outcomeOf(book, [medicine], day);
          final fill = outcomeColour(context, outcome);
          final dark =
              outcome == DayOutcome.taken || outcome == DayOutcome.missed;
          return Semantics(
            button: true,
            label: '${formatDayLong(day)}: ${outcome.name}',
            excludeSemantics: true,
            child: GestureDetector(
              key: Key('calendar-${PlannerDay.key(day)}'),
              onTap: () => onDay(day),
              child: Column(
                children: [
                  Text(
                    weekdayShort(day).substring(0, 1),
                    style: TextStyle(color: colors.textMuted, fontSize: 11),
                  ),
                  const SizedBox(height: 4),
                  Container(
                    width: _cell,
                    height: _cell,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: fill,
                      borderRadius: BorderRadius.circular(8),
                      border: daysBetween(day, today) == 0
                          ? Border.all(color: colors.textPrimary, width: 2)
                          : null,
                    ),
                    child: Text(
                      '${day.day}',
                      style: TextStyle(
                        color: dark ? colors.background : colors.textPrimary,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}
