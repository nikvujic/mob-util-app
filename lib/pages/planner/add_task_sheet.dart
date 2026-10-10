import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:the_app/core/format.dart';
import 'package:the_app/core/theme.dart';
import 'package:the_app/models/planner_task.dart';

/// What the add sheet returns.
typedef NewTask = ({String title, int start, int end});

/// Asks for a new task in the free [slot]: a title, the start (the slot's
/// start by default) and the end (1 hour later by default; quick options
/// 15 / 30 / 60 / 120 min and the end of the free time, or a picked time).
/// Null if dismissed.
Future<NewTask?> showAddTaskSheet(BuildContext context, FreeSlot slot) {
  return showModalBottomSheet<NewTask>(
    context: context,
    isScrollControlled: true,
    builder: (_) => AddTaskSheet(slot: slot),
  );
}

class AddTaskSheet extends StatefulWidget {
  /// Quick lengths offered for the end, in minutes.
  static const quickLengths = [15, 30, 60, 120];

  final FreeSlot slot;

  const AddTaskSheet({super.key, required this.slot});

  @override
  State<AddTaskSheet> createState() => _AddTaskSheetState();
}

class _AddTaskSheetState extends State<AddTaskSheet> {
  final _title = TextEditingController();
  late int _start = widget.slot.start;
  late int _end = math.min(_start + 60, widget.slot.end);

  @override
  void dispose() {
    _title.dispose();
    super.dispose();
  }

  /// A 24-hour time picker, kept within the free slot. Null if cancelled.
  Future<int?> _pickTime(int initial, {required int min, required int max}) {
    return showTimePicker(
      context: context,
      initialTime: TimeOfDay(hour: initial ~/ 60 % 24, minute: initial % 60),
      builder: (context, child) => MediaQuery(
        data: MediaQuery.of(context).copyWith(alwaysUse24HourFormat: true),
        child: child!,
      ),
    ).then((time) {
      if (time == null) return null;
      var minutes = time.hour * 60 + time.minute;
      // 00:00 as an end means midnight at the end of the day.
      if (minutes == 0 && min > 0) minutes = PlannerTask.dayMinutes;
      return minutes.clamp(min, max);
    });
  }

  Future<void> _pickStart() async {
    final start = await _pickTime(
      _start,
      min: widget.slot.start,
      max: widget.slot.end - 1,
    );
    if (start == null || !mounted) return;
    setState(() {
      final length = _end - _start;
      _start = start;
      _end = math.min(_start + length, widget.slot.end);
    });
  }

  Future<void> _pickEnd() async {
    final end = await _pickTime(_end, min: _start + 1, max: widget.slot.end);
    if (end == null || !mounted) return;
    setState(() => _end = end);
  }

  void _submit() {
    final title = _title.text.trim();
    if (title.isEmpty) return;
    Navigator.of(context)
        .pop<NewTask>((title: title, start: _start, end: _end));
  }

  @override
  Widget build(BuildContext context) {
    final slotEnd = widget.slot.end;
    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.viewInsetsOf(context).bottom,
      ),
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              TextField(
                key: const Key('taskTitle'),
                controller: _title,
                autofocus: true,
                textCapitalization: TextCapitalization.sentences,
                decoration: const InputDecoration(hintText: 'Task'),
                onSubmitted: (_) => _submit(),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Text(
                    'From',
                    style: TextStyle(color: context.colors.textSecondary),
                  ),
                  TextButton(
                    onPressed: _pickStart,
                    child: Text(formatMinutes(_start)),
                  ),
                  Text(
                    'to',
                    style: TextStyle(color: context.colors.textSecondary),
                  ),
                  TextButton(
                    onPressed: _pickEnd,
                    child: Text(formatMinutes(_end)),
                  ),
                ],
              ),
              Wrap(
                spacing: 8,
                children: [
                  for (final length in AddTaskSheet.quickLengths)
                    ChoiceChip(
                      label: Text(
                          length < 60 ? '$length min' : '${length ~/ 60} h'),
                      selected: _end == _start + length,
                      onSelected: _start + length <= slotEnd
                          ? (_) => setState(() => _end = _start + length)
                          : null,
                    ),
                  ChoiceChip(
                    label: const Text('Until free time ends'),
                    selected: _end == slotEnd,
                    onSelected: (_) => setState(() => _end = slotEnd),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Align(
                alignment: Alignment.centerRight,
                child:
                    FilledButton(onPressed: _submit, child: const Text('Add')),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
