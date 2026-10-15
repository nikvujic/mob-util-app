import 'package:flutter/material.dart';
import 'package:the_app/core/format.dart';
import 'package:the_app/core/theme.dart';
import 'package:the_app/models/date_entry.dart';

/// "1 day before · 09:00", "On the day · 09:00".
String reminderLabel(DateReminder r) =>
    '${daysBeforeLabel(r.daysBefore)}  ·  ${formatMinutes(r.minutes)}';

/// "On the day", "1 day before", "7 days before".
String daysBeforeLabel(int days) =>
    days == 0 ? 'On the day' : '${countOf(days, 'day', 'days')} before';

/// A reminder: how many days before, and the time.
class ReminderSheet extends StatefulWidget {
  final DateReminder start;

  const ReminderSheet({super.key, required this.start});

  @override
  State<ReminderSheet> createState() => _ReminderSheetState();
}

class _ReminderSheetState extends State<ReminderSheet> {
  late var _reminder = widget.start;

  Future<void> _pickTime() async {
    final picked = await showTimePicker(
      context: context,
      initialTime: TimeOfDay(
          hour: _reminder.minutes ~/ 60, minute: _reminder.minutes % 60),
      builder: (context, child) => MediaQuery(
        data: MediaQuery.of(context).copyWith(alwaysUse24HourFormat: true),
        child: child!,
      ),
    );
    if (picked == null || !mounted) return;
    setState(() => _reminder =
        _reminder.copyWith(minutes: picked.hour * 60 + picked.minute));
  }

  @override
  Widget build(BuildContext context) => SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Remind',
                  style: TextStyle(color: context.colors.textSecondary)),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 4,
                children: [
                  for (final days in DateReminder.daysChoices)
                    ChoiceChip(
                      key: Key('reminderDays-$days'),
                      label: Text(daysBeforeLabel(days)),
                      selected: _reminder.daysBefore == days,
                      onSelected: (_) => setState(() =>
                          _reminder = _reminder.copyWith(daysBefore: days)),
                    ),
                ],
              ),
              const SizedBox(height: 8),
              ActionChip(
                key: const Key('reminderTime'),
                avatar: const Icon(Icons.schedule, size: 18),
                label: Text(formatMinutes(_reminder.minutes)),
                onPressed: _pickTime,
              ),
              const SizedBox(height: 8),
              Align(
                alignment: Alignment.centerRight,
                child: FilledButton(
                  key: const Key('reminderDone'),
                  onPressed: () => Navigator.of(context).pop(_reminder),
                  child: const Text('Done'),
                ),
              ),
            ],
          ),
        ),
      );
}
