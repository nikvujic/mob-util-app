import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:the_app/core/format.dart';
import 'package:the_app/core/theme.dart';
import 'package:the_app/models/planner_task.dart';
import 'package:the_app/models/routine.dart';

/// What the task sheet returns. [weekdays] is set when it repeats (a
/// routine, P8), with [until] its last day (null: for good).
typedef NewTask = ({
  String title,
  int start,
  int end,
  Set<int>? weekdays,
  DateTime? until,
});

/// Whether the sheet asks about repeating.
enum RepeatChoice {
  /// A plain task.
  never,

  /// A task that may repeat (becoming a routine).
  optional,

  /// A routine: it always repeats.
  always,
}

/// Asks for a new task in the free [slot]: a title, the start ([start], or
/// the slot's start) and the end (1 hour later by default; quick options
/// 15 / 30 / 60 / 120 min and the end of the free time, or a picked time).
/// Null if dismissed.
///
/// [day] is the day it's for: then it can be made to repeat from that day
/// (Repeat: once, every day, weekdays or chosen days; until a date or for
/// good).
Future<NewTask?> showAddTaskSheet(
  BuildContext context,
  FreeSlot slot, {
  int? start,
  DateTime? day,
}) {
  return showModalBottomSheet<NewTask>(
    context: context,
    isScrollControlled: true,
    builder: (_) => TaskSheet(
      slot: slot,
      start: start,
      repeat: day == null ? RepeatChoice.never : RepeatChoice.optional,
      from: day,
    ),
  );
}

/// Asks for a new routine (P8) in [slot], on [weekday] to begin with,
/// starting [from]. Null if dismissed.
Future<NewTask?> showAddRoutineSheet(
  BuildContext context,
  FreeSlot slot, {
  required int weekday,
  required DateTime from,
}) {
  return showModalBottomSheet<NewTask>(
    context: context,
    isScrollControlled: true,
    builder: (_) => TaskSheet(
      slot: slot,
      repeat: RepeatChoice.always,
      weekdays: {weekday},
      from: from,
    ),
  );
}

/// Edits [routine] within [room]; [onDelete] deletes it (after asking).
/// Null if dismissed or deleted.
Future<NewTask?> showEditRoutineSheet(
  BuildContext context,
  Routine routine,
  FreeSlot room, {
  required VoidCallback onDelete,
}) {
  return showModalBottomSheet<NewTask>(
    context: context,
    isScrollControlled: true,
    builder: (_) => TaskSheet(
      slot: room,
      title: routine.title,
      start: routine.start,
      end: routine.end,
      repeat: RepeatChoice.always,
      weekdays: routine.weekdays,
      from: routine.from,
      until: routine.until,
      submitLabel: 'Save',
      onDelete: onDelete,
    ),
  );
}

/// Edits [task]: its title and times, which can move within [room] (the
/// free time around it, up to its neighbours). Null if dismissed.
Future<NewTask?> showEditTaskSheet(
  BuildContext context,
  PlannerTask task,
  FreeSlot room,
) {
  return showModalBottomSheet<NewTask>(
    context: context,
    isScrollControlled: true,
    builder: (_) => TaskSheet(
      slot: room,
      title: task.title,
      start: task.start,
      end: task.end,
      submitLabel: 'Save',
    ),
  );
}

/// The sheet for adding or editing a task within [slot].
class TaskSheet extends StatefulWidget {
  /// Quick lengths offered for the end, in minutes.
  static const quickLengths = [15, 30, 60, 120];

  /// The time the task can take: free time (plus the task's own, when
  /// editing).
  final FreeSlot slot;
  final String title;
  final int? start;
  final int? end;
  final String submitLabel;

  /// Whether it asks about repeating (P8).
  final RepeatChoice repeat;

  /// The weekdays it's on, if it repeats.
  final Set<int>? weekdays;

  /// The first day it's on (repeating starts here); the last can't be
  /// earlier.
  final DateTime? from;
  final DateTime? until;

  /// Shows a Delete button (editing a routine); called once the sheet is
  /// closed.
  final VoidCallback? onDelete;

  const TaskSheet({
    super.key,
    required this.slot,
    this.title = '',
    this.start,
    this.end,
    this.submitLabel = 'Add',
    this.repeat = RepeatChoice.never,
    this.weekdays,
    this.from,
    this.until,
    this.onDelete,
  });

  @override
  State<TaskSheet> createState() => _TaskSheetState();
}

class _TaskSheetState extends State<TaskSheet> {
  late final _title = TextEditingController(text: widget.title);
  late int _start = widget.start ?? widget.slot.start;
  late int _end = widget.end ?? math.min(_start + 60, widget.slot.end);

  /// The weekdays it repeats on; empty: it doesn't repeat.
  late Set<int> _weekdays = {...?widget.weekdays};
  late DateTime? _until = widget.until;

  bool get _repeats => _weekdays.isNotEmpty;

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
    Navigator.of(context).pop<NewTask>((
      title: title,
      start: _start,
      end: _end,
      weekdays: _repeats ? _weekdays : null,
      until: _repeats ? _until : null,
    ));
  }

  Future<void> _pickUntil() async {
    final from = widget.from ?? DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: _until ?? from.add(const Duration(days: 30)),
      firstDate: from,
      lastDate: DateTime(from.year + 10),
    );
    if (picked != null && mounted) setState(() => _until = picked);
  }

  static const _everyDay = {1, 2, 3, 4, 5, 6, 7};
  static const _workdays = {1, 2, 3, 4, 5};

  bool _isExactly(Set<int> days) =>
      _weekdays.length == days.length && _weekdays.containsAll(days);

  /// Repeat: once / every day / weekdays, and the weekdays themselves;
  /// until: for good or a date.
  List<Widget> _repeatChoices(BuildContext context) {
    final colors = context.colors;
    final firstDay = widget.from?.weekday ?? DateTime.now().weekday;
    final label = TextStyle(color: colors.textSecondary);
    return [
      const SizedBox(height: 8),
      Text('Repeat', style: label),
      Wrap(
        spacing: 8,
        children: [
          if (widget.repeat == RepeatChoice.optional)
            ChoiceChip(
              label: const Text('Once'),
              selected: !_repeats,
              onSelected: (_) => setState(() => _weekdays = {}),
            ),
          ChoiceChip(
            label: const Text('Every day'),
            selected: _isExactly(_everyDay),
            onSelected: (_) => setState(() => _weekdays = {..._everyDay}),
          ),
          ChoiceChip(
            label: const Text('Weekdays'),
            selected: _isExactly(_workdays),
            onSelected: (_) => setState(() => _weekdays = {..._workdays}),
          ),
          if (!_repeats)
            ChoiceChip(
              label: const Text('Choose days'),
              selected: false,
              onSelected: (_) => setState(() => _weekdays = {firstDay}),
            ),
        ],
      ),
      if (_repeats) ...[
        Wrap(
          spacing: 4,
          children: [
            for (var day = 1; day <= 7; day++)
              FilterChip(
                label: Text(weekdayName(day)),
                selected: _weekdays.contains(day),
                // A routine keeps at least one day.
                onSelected: (on) => setState(() {
                  if (on) {
                    _weekdays = {..._weekdays, day};
                  } else if (_weekdays.length > 1 ||
                      widget.repeat == RepeatChoice.optional) {
                    _weekdays = {..._weekdays}..remove(day);
                  }
                }),
              ),
          ],
        ),
        Wrap(
          spacing: 8,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            Text('Until', style: label),
            ChoiceChip(
              label: const Text('Forever'),
              selected: _until == null,
              onSelected: (_) => setState(() => _until = null),
            ),
            ChoiceChip(
              label: Text(
                _until == null
                    ? 'A date…'
                    : formatDay(_until!, today: DateTime.now()),
              ),
              selected: _until != null,
              onSelected: (_) => _pickUntil(),
            ),
          ],
        ),
      ],
    ];
  }

  @override
  Widget build(BuildContext context) {
    final slotEnd = widget.slot.end;
    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.viewInsetsOf(context).bottom,
      ),
      child: SafeArea(
        // Scrolls when the keyboard leaves too little room.
        child: SingleChildScrollView(
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
                decoration: InputDecoration(
                  hintText:
                      widget.repeat == RepeatChoice.always ? 'Routine' : 'Task',
                ),
                onSubmitted: (_) => _submit(),
              ),
              const SizedBox(height: 12),
              // Wraps (e.g. with a very large font) instead of overflowing.
              Wrap(
                spacing: 8,
                runSpacing: 4,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  Text(
                    'From',
                    style: TextStyle(color: context.colors.textSecondary),
                  ),
                  _TimeButton(_start, onPressed: _pickStart),
                  Text(
                    'to',
                    style: TextStyle(color: context.colors.textSecondary),
                  ),
                  _TimeButton(_end, onPressed: _pickEnd),
                ],
              ),
              Wrap(
                spacing: 8,
                children: [
                  for (final length in TaskSheet.quickLengths)
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
              if (widget.repeat != RepeatChoice.never)
                ..._repeatChoices(context),
              const SizedBox(height: 8),
              Wrap(
                alignment: widget.onDelete == null
                    ? WrapAlignment.end
                    : WrapAlignment.spaceBetween,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  if (widget.onDelete != null)
                    TextButton.icon(
                      icon: const Icon(Icons.delete_outline),
                      label: const Text('Delete routine'),
                      style: TextButton.styleFrom(
                        foregroundColor: context.colors.danger,
                      ),
                      onPressed: () {
                        Navigator.of(context).pop();
                        widget.onDelete!();
                      },
                    ),
                  FilledButton(
                    onPressed: _submit,
                    child: Text(widget.submitLabel),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// A time to tap and change: outlined, in the main text colour (readable
/// on every theme's sheet).
class _TimeButton extends StatelessWidget {
  final int minutes;
  final VoidCallback onPressed;

  const _TimeButton(this.minutes, {required this.onPressed});

  @override
  Widget build(BuildContext context) {
    return OutlinedButton(
      onPressed: onPressed,
      style: OutlinedButton.styleFrom(
        foregroundColor: context.colors.textPrimary,
        side: BorderSide(color: context.colors.textHint),
      ),
      child: Text(formatMinutes(minutes)),
    );
  }
}
