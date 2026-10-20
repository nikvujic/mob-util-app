import 'package:flutter/material.dart';
import 'package:the_app/core/format.dart';
import 'package:the_app/core/theme.dart';
import 'package:the_app/widgets/app_dialog.dart';

/// Asks for a month (Round 85: a card's expiry, which has no day): a year
/// with ‹ › between [firstYear] and [lastYear], and its twelve months; a
/// tap on one picks it. Opens on [initial]'s year, its month marked. The
/// month's first day, or null if dismissed.
Future<DateTime?> showMonthPicker(
  BuildContext context, {
  required String title,
  required DateTime initial,
  required int firstYear,
  required int lastYear,
}) =>
    showDialog<DateTime>(
      context: context,
      builder: (_) => _MonthPicker(
        title: title,
        initial: initial,
        firstYear: firstYear,
        lastYear: lastYear,
      ),
    );

class _MonthPicker extends StatefulWidget {
  final String title;
  final DateTime initial;
  final int firstYear;
  final int lastYear;

  const _MonthPicker({
    required this.title,
    required this.initial,
    required this.firstYear,
    required this.lastYear,
  });

  @override
  State<_MonthPicker> createState() => _MonthPickerState();
}

class _MonthPickerState extends State<_MonthPicker> {
  late int _year = widget.initial.year.clamp(widget.firstYear, widget.lastYear);

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
          for (var row = 0; row < 3; row++)
            Row(
              children: [
                for (var month = row * 4 + 1; month <= row * 4 + 4; month++)
                  Expanded(
                    child: Center(
                      child: ChoiceChip(
                        label: SizedBox(
                          width: 32,
                          child: Text(
                            monthShort(month),
                            textAlign: TextAlign.center,
                          ),
                        ),
                        selected: _year == widget.initial.year &&
                            month == widget.initial.month,
                        onSelected: (_) =>
                            Navigator.of(context).pop(DateTime(_year, month)),
                      ),
                    ),
                  ),
              ],
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
