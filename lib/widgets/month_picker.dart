import 'package:flutter/material.dart';
import 'package:the_app/core/format.dart';
import 'package:the_app/core/theme.dart';
import 'package:the_app/widgets/app_dialog.dart';

/// Asks for a month (Round 85: a card's expiry, which has no day): a year
/// with ‹ › between [firstYear] and [lastYear], and its twelve months; a
/// tap on one picks it. Opens on [initial]'s year, its month marked, or
/// with none set on [today]'s (Round 91). The month's first day, or null
/// if dismissed.
Future<DateTime?> showMonthPicker(
  BuildContext context, {
  required String title,
  required DateTime today,
  DateTime? initial,
  required int firstYear,
  required int lastYear,
}) =>
    showDialog<DateTime>(
      context: context,
      builder: (_) => _MonthPicker(
        title: title,
        initial: initial,
        today: today,
        firstYear: firstYear,
        lastYear: lastYear,
      ),
    );

class _MonthPicker extends StatefulWidget {
  final String title;
  final DateTime? initial;
  final DateTime today;
  final int firstYear;
  final int lastYear;

  const _MonthPicker({
    required this.title,
    required this.initial,
    required this.today,
    required this.firstYear,
    required this.lastYear,
  });

  @override
  State<_MonthPicker> createState() => _MonthPickerState();
}

class _MonthPickerState extends State<_MonthPicker> {
  // Round 91 (Nikola): opens on the set month's year; none set, this one.
  late int _year = (widget.initial ?? widget.today)
      .year
      .clamp(widget.firstYear, widget.lastYear);

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return AppDialog(
      title: widget.title,
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              IconButton(
                tooltip: 'Year before',
                icon: const Icon(Icons.chevron_left),
                onPressed: _year > widget.firstYear
                    ? () => setState(() => _year--)
                    : null,
              ),
              Text(
                '$_year',
                key: const Key('monthPickerYear'),
                style: TextStyle(
                  color: colors.textPrimary,
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                ),
              ),
              IconButton(
                tooltip: 'Year after',
                icon: const Icon(Icons.chevron_right),
                onPressed: _year < widget.lastYear
                    ? () => setState(() => _year++)
                    : null,
              ),
            ],
          ),
          const SizedBox(height: 8),
          // Round 86 (Nikola: four across were squished): three across,
          // four rows, spaced, each a full-width button.
          for (var row = 0; row < 4; row++)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Row(
                children: [
                  for (var month = row * 3 + 1;
                      month <= row * 3 + 3;
                      month++) ...[
                    if (month % 3 != 1) const SizedBox(width: 8),
                    Expanded(
                      child: _Month(
                        month: month,
                        picked: _year == widget.initial?.year &&
                            month == widget.initial?.month,
                        onTap: () =>
                            Navigator.of(context).pop(DateTime(_year, month)),
                      ),
                    ),
                  ],
                ],
              ),
            ),
        ],
      ),
      actions: [
        DialogButton(
          label: 'Cancel',
          onPressed: () => Navigator.of(context).pop(),
        ),
      ],
    );
  }
}

/// A month's button: its short name; the picked one washed and edged in
/// the accent, as a picked chip.
class _Month extends StatelessWidget {
  final int month;
  final bool picked;
  final VoidCallback onTap;

  const _Month({
    required this.month,
    required this.picked,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final accent = colors.accentForeground ?? colors.accent;
    final shape = RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(8),
      side: picked
          ? BorderSide(color: accent, width: 1.5)
          : BorderSide(color: colors.divider),
    );
    return Material(
      color: picked
          ? Color.alphaBlend(colors.accent.withValues(alpha: 0.24), colors.card)
          : colors.card,
      shape: shape,
      child: InkWell(
        key: Key('month-$month'),
        customBorder: shape,
        onTap: onTap,
        child: SizedBox(
          height: 44,
          child: Center(
            child: Text(
              monthShort(month),
              style: TextStyle(
                color: colors.textPrimary,
                fontWeight: picked ? FontWeight.w600 : FontWeight.normal,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
