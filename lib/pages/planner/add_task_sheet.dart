import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:the_app/core/format.dart';
import 'package:the_app/core/theme.dart';
import 'package:the_app/widgets/app_dialog.dart';
import 'package:the_app/widgets/pull_down_list.dart';
import 'package:the_app/models/planner_pin.dart';
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
  String? color,
  int? remind,
  String? description,
});

/// The time a repeating block (a routine) on [weekdays], until [until]
/// (null: for good), could take around [start]–[end].
typedef RepeatRoom = FreeSlot Function(
  Set<int> weekdays,
  DateTime? until, {
  required int start,
  required int end,
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

/// Asks for a new task within [slot] (the time free of other tasks): a
/// title, the start ([start], or the slot's start) and the end ([end], or
/// 1 hour later; quick options 15 / 30 / 60 / 120 min and up to the next
/// task, or a picked time). [note] says why the times aren't the ones
/// asked for, if they had to change. Null if dismissed.
///
/// [day] is the day it's for: then it can be made to repeat from that day
/// (Repeat: once, every day, weekdays or chosen days; until a date or for
/// good), and while it repeats its times stay within [repeatRoom] (the
/// time free of the routines it would share a day with).
Future<NewTask?> showAddTaskSheet(
  BuildContext context,
  FreeSlot slot, {
  int? start,
  int? end,
  DateTime? day,
  RepeatRoom? repeatRoom,
  String? note,
}) {
  return showModalBottomSheet<NewTask>(
    context: context,
    isScrollControlled: true,
    // Pulling down is reach mode, not closing (✕ closes).
    enableDrag: false,
    builder: (_) => TaskSheet(
      slot: slot,
      repeatRoom: repeatRoom,
      start: start,
      end: end,
      repeat: day == null ? RepeatChoice.never : RepeatChoice.optional,
      from: day,
      note: note,
      color: BlockColor.taskDefault.name,
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
  RepeatRoom? room,
}) {
  return showModalBottomSheet<NewTask>(
    context: context,
    isScrollControlled: true,
    // Pulling down is reach mode, not closing (✕ closes).
    enableDrag: false,
    builder: (_) => TaskSheet(
      slot: slot,
      repeatRoom: room,
      repeat: RepeatChoice.always,
      weekdays: {weekday},
      from: from,
      color: BlockColor.routineDefault.name,
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
  RepeatRoom? repeatRoom,
}) {
  return showModalBottomSheet<NewTask>(
    context: context,
    isScrollControlled: true,
    // Pulling down is reach mode, not closing (✕ closes).
    enableDrag: false,
    builder: (_) => TaskSheet(
      slot: room,
      repeatRoom: repeatRoom,
      title: routine.title,
      start: routine.start,
      end: routine.end,
      repeat: RepeatChoice.always,
      weekdays: routine.weekdays,
      from: routine.from,
      until: routine.until,
      color: routine.color,
      remind: routine.remind,
      description: routine.description,
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
    // Pulling down is reach mode, not closing (✕ closes).
    enableDrag: false,
    builder: (_) => TaskSheet(
      slot: room,
      title: task.title,
      start: task.start,
      end: task.end,
      color: task.color,
      remind: task.remind,
      description: task.description,
      submitLabel: 'Save',
    ),
  );
}

/// A block's reminder in words (P10): Off, At start, 10 min before, …
String remindLabel(int? minutes) => switch (minutes) {
      null => 'Off',
      0 => 'At start',
      60 => '1 h before',
      final m => '$m min before',
    };

/// The whole day: a reminder can go at any time (P14).
const FreeSlot _wholeDay = (start: 0, end: PlannerTask.dayMinutes);

/// Asks for a new reminder (P14): a title and a time ([time] to begin
/// with). Its `start` is the time. Null if dismissed.
Future<NewTask?> showAddPinSheet(BuildContext context, {required int time}) {
  return showModalBottomSheet<NewTask>(
    context: context,
    isScrollControlled: true,
    // Pulling down is reach mode, not closing (✕ closes).
    enableDrag: false,
    builder: (_) => TaskSheet(slot: _wholeDay, start: time, point: true),
  );
}

/// Edits [pin]'s title and time; [onDelete] deletes it. Null if dismissed
/// or deleted.
Future<NewTask?> showEditPinSheet(
  BuildContext context,
  PlannerPin pin, {
  required VoidCallback onDelete,
}) {
  return showModalBottomSheet<NewTask>(
    context: context,
    isScrollControlled: true,
    // Pulling down is reach mode, not closing (✕ closes).
    enableDrag: false,
    builder: (_) => TaskSheet(
      slot: _wholeDay,
      title: pin.title,
      start: pin.time,
      point: true,
      submitLabel: 'Save',
      onDelete: onDelete,
      deleteLabel: 'Delete',
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

  /// The time it can take while it repeats, if not [slot]: free of the
  /// routines it would share a day with, so it depends on the weekdays and
  /// end date chosen (and a task and a routine may share time, P12).
  final RepeatRoom? repeatRoom;

  /// Why [start] / [end] aren't the times asked for, shown under them.
  final String? note;
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

  /// The Delete button's label.
  final String deleteLabel;

  /// A reminder (P14): just a title and a time ("At"), no end, colour,
  /// remind or repeat. What it returns has its end at its start.
  final bool point;

  /// Its colour (P9): a [BlockColor] name, or null.
  final String? color;

  /// Minutes before its start to remind (P10), or null for none.
  final int? remind;

  /// More about it (P20); not asked for a reminder.
  final String? description;

  const TaskSheet({
    super.key,
    required this.slot,
    this.repeatRoom,
    this.note,
    this.title = '',
    this.start,
    this.end,
    this.submitLabel = 'Add',
    this.repeat = RepeatChoice.never,
    this.weekdays,
    this.from,
    this.until,
    this.onDelete,
    this.deleteLabel = 'Delete routine',
    this.point = false,
    this.color,
    this.remind,
    this.description,
  });

  @override
  State<TaskSheet> createState() => _TaskSheetState();
}

class _TaskSheetState extends State<TaskSheet> {
  late final _title = TextEditingController(text: widget.title)
    ..addListener(() => setState(() {})); // canPop follows the changes
  late final _description =
      TextEditingController(text: widget.description ?? '')
        ..addListener(() => setState(() {}));
  late int _start = widget.start ?? widget.slot.start;
  late int _end = widget.end ?? math.min(_start + 60, widget.slot.end);

  /// The weekdays it repeats on; empty: it doesn't repeat.
  late Set<int> _weekdays = {...?widget.weekdays};
  late DateTime? _until = widget.until;
  late BlockColor? _color = BlockColor.fromName(widget.color);

  /// Set once a colour is picked: until then, a new block's colour
  /// follows whether it repeats (P19).
  bool _colourPicked = false;
  late int? _remind = widget.remind;

  /// Reminder choices (P10): minutes before the start; null: off.
  static const _reminders = <int?>[null, 0, 5, 10, 15, 30, 60];

  static String _remindLabel(int? minutes) => remindLabel(minutes);

  bool get _repeats => _weekdays.isNotEmpty;

  /// The shortest a block can be.
  static const _min = PlannerTask.minMinutes;

  /// The shortest a block can be within [room]: [_min], or all of a
  /// shorter room (an old, shorter block between its neighbours), so the
  /// clamps below never get a lower bound above the upper one.
  static int _minIn(FreeSlot room) => math.min(_min, room.end - room.start);

  /// The time it can take now: a routine's free time differs from a
  /// task's (P12).
  FreeSlot get _room => _repeats && widget.repeatRoom != null
      ? widget.repeatRoom!(_weekdays, _until, start: _start, end: _end)
      : widget.slot;

  /// Sets the weekdays it repeats on (none: it doesn't), keeping the times
  /// within the room that comes with that, and saying so if they change.
  void _setWeekdays(Set<int> weekdays) => setState(() {
        final repeated = _repeats;
        _weekdays = weekdays;
        // A new block's default colour: blue for a task, purple for a
        // routine (P19), unless one was picked.
        if (widget.title.isEmpty && !_colourPicked && repeated != _repeats) {
          _color =
              _repeats ? BlockColor.routineDefault : BlockColor.taskDefault;
        }
        _fit();
      });

  /// Keeps the times within [_room] (which changes with the weekdays and
  /// end date), saying so if they had to change. Call within setState.
  void _fit() {
    final room = _room;
    if (room.start <= _start && _end <= room.end) return;
    final length = _end - _start;
    final min = _minIn(room);
    _start = _start.clamp(room.start, room.end - min);
    _end = (_start + length).clamp(_start + min, room.end);
    _adjusted = 'Now ${formatMinutes(_start)}–${formatMinutes(_end)}: '
        '${_repeats ? 'a routine' : 'a task'} is there too.';
  }

  @override
  void dispose() {
    _title.dispose();
    _description.dispose();
    super.dispose();
  }

  /// Why the times were changed to fit, shown under them (instead of
  /// changing them quietly); null if they fit.
  late String? _adjusted = widget.note;

  /// A 24-hour time picker. Null if cancelled; 00:00 as an [end] is
  /// midnight at the end of the day.
  Future<int?> _pickTime(int initial, {bool end = false}) {
    return showTimePicker(
      context: context,
      initialTime: TimeOfDay(hour: initial ~/ 60 % 24, minute: initial % 60),
      builder: (context, child) => MediaQuery(
        data: MediaQuery.of(context).copyWith(alwaysUse24HourFormat: true),
        child: child!,
      ),
    ).then((time) {
      if (time == null) return null;
      final minutes = time.hour * 60 + time.minute;
      return end && minutes == 0 ? PlannerTask.dayMinutes : minutes;
    });
  }

  Future<void> _pickStart() async {
    final picked = await _pickTime(_start);
    if (picked == null || !mounted) return;
    if (widget.point) {
      // A reminder has no length: any minute of the day (P14).
      setState(() {
        _start = picked.clamp(0, PlannerTask.dayMinutes - 1);
        _end = _start;
        _adjusted = null;
      });
      return;
    }
    final slot = _room;
    setState(() {
      final length = _end - _start;
      final min = _minIn(slot);
      _start = picked.clamp(slot.start, slot.end - min);
      _end = (_start + length).clamp(_start + min, slot.end);
      _adjusted = picked < slot.start
          ? 'Starts at ${formatMinutes(_start)}: what\'s before ends then.'
          : picked >= slot.end
              ? 'Starts at ${formatMinutes(_start)}: what\'s after starts '
                  'at ${formatMinutes(slot.end)}.'
              : picked > slot.end - min
                  ? 'Starts at ${formatMinutes(_start)}: it takes at least '
                      '$min minutes.'
                  : _start + length > slot.end
                      ? 'Ends at ${formatMinutes(_end)}: what\'s after starts '
                          'then.'
                      : null;
    });
  }

  Future<void> _pickEnd() async {
    final picked = await _pickTime(_end, end: true);
    if (picked == null || !mounted) return;
    final slot = _room;
    setState(() {
      final min = _minIn(slot);
      _end = picked.clamp(_start + min, slot.end);
      _adjusted = picked > slot.end
          ? 'Ends at ${formatMinutes(_end)}: what\'s after starts then.'
          : picked <= _start
              ? 'Ends at ${formatMinutes(_end)}: it has to end after it '
                  'starts.'
              : picked < _start + min
                  ? 'Ends at ${formatMinutes(_end)}: it takes at least '
                      '$min minutes.'
                  : null;
    });
  }

  /// Whether anything differs from how the sheet opened.
  bool get _changed =>
      _title.text != widget.title ||
      _description.text != (widget.description ?? '') ||
      _start != _initialStart ||
      _end != _initialEnd ||
      !_sameDays(_weekdays, widget.weekdays ?? const {}) ||
      _until != widget.until ||
      _color?.name != widget.color ||
      _remind != widget.remind;

  /// The times it opened with.
  late final int _initialStart;
  late final int _initialEnd;

  @override
  void initState() {
    super.initState();
    _initialStart = _start;
    _initialEnd = _end;
  }

  static bool _sameDays(Set<int> a, Set<int> b) =>
      a.length == b.length && a.containsAll(b);

  /// Closes, asking first if something was changed. In that question,
  /// back counts as "Discard" (Nikola), unlike a note's "Save changes?".
  Future<void> _close() async {
    if (!_changed) {
      Navigator.of(context).pop();
      return;
    }
    final discard = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (context) => AppDialog(
        title: 'Discard changes?',
        content: const DialogMessage('What you changed here won\'t be kept.'),
        actions: [
          DialogButton(
            label: 'Cancel',
            onPressed: () => Navigator.of(context).pop(false),
          ),
          DialogButton(
            label: 'Discard',
            primary: true,
            danger: true,
            onPressed: () => Navigator.of(context).pop(true),
          ),
        ],
      ),
    );
    // Back (null) closes too.
    if ((discard ?? true) && mounted) Navigator.of(context).pop();
  }

  void _submit() {
    final title = _title.text.trim();
    if (title.isEmpty) return;
    Navigator.of(context).pop<NewTask>((
      title: title,
      start: _start,
      end: widget.point ? _start : _end,
      weekdays: _repeats ? _weekdays : null,
      until: _repeats ? _until : null,
      color: _color?.name,
      remind: _remind,
      description: widget.point ? null : _description.text,
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
    if (picked != null && mounted) {
      setState(() {
        _until = picked;
        _fit();
      });
    }
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
              onSelected: (_) => _setWeekdays({}),
            ),
          ChoiceChip(
            label: const Text('Every day'),
            selected: _isExactly(_everyDay),
            onSelected: (_) => _setWeekdays({..._everyDay}),
          ),
          ChoiceChip(
            label: const Text('Weekdays'),
            selected: _isExactly(_workdays),
            onSelected: (_) => _setWeekdays({..._workdays}),
          ),
          if (!_repeats)
            ChoiceChip(
              label: const Text('Choose days'),
              selected: false,
              onSelected: (_) => _setWeekdays({firstDay}),
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
                onSelected: (on) {
                  if (on) {
                    _setWeekdays({..._weekdays, day});
                  } else if (_weekdays.length > 1 ||
                      widget.repeat == RepeatChoice.optional) {
                    _setWeekdays({..._weekdays}..remove(day));
                  }
                },
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
              onSelected: (_) => setState(() {
                _until = null;
                _fit();
              }),
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
    final slotEnd = _room.end;
    final media = MediaQuery.of(context);
    // A fixed share of the room above the keyboard: the fields scroll (with
    // reach mode, so pulling down brings the top ones into thumb reach)
    // and the buttons stay at the bottom.
    final room =
        media.size.height - media.viewInsets.bottom - media.padding.top;
    return PopScope(
      canPop: !_changed,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _close();
      },
      child: Padding(
        padding: EdgeInsets.only(bottom: media.viewInsets.bottom),
        child: SizedBox(
          height: room * 0.8,
          child: Column(
            children: [
              Expanded(
                child: PullDownList.children(
                  children: [
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          TextField(
                            key: const Key('taskTitle'),
                            controller: _title,
                            // Only when adding: tapping a block to edit it
                            // shouldn't open the keyboard (P15).
                            autofocus: widget.title.isEmpty,
                            textCapitalization: TextCapitalization.sentences,
                            decoration: InputDecoration(
                              hintText: widget.point
                                  ? 'Reminder'
                                  : widget.repeat == RepeatChoice.always
                                      ? 'Routine'
                                      : 'Task',
                            ),
                            onSubmitted: (_) => _submit(),
                          ),
                          if (!widget.point) ...[
                            const SizedBox(height: 4),
                            TextField(
                              key: const Key('taskDescription'),
                              controller: _description,
                              textCapitalization: TextCapitalization.sentences,
                              minLines: 1,
                              maxLines: 4,
                              decoration: const InputDecoration(
                                hintText: 'Description (optional)',
                              ),
                            ),
                          ],
                          const SizedBox(height: 12),
                          // Wraps (e.g. with a very large font) instead of overflowing.
                          Wrap(
                            spacing: 8,
                            runSpacing: 4,
                            crossAxisAlignment: WrapCrossAlignment.center,
                            children: [
                              Text(
                                widget.point ? 'At' : 'From',
                                style: TextStyle(
                                    color: context.colors.textSecondary),
                              ),
                              _TimeButton(_start, onPressed: _pickStart),
                              if (!widget.point) ...[
                                Text(
                                  'to',
                                  style: TextStyle(
                                      color: context.colors.textSecondary),
                                ),
                                _TimeButton(_end, onPressed: _pickEnd),
                              ],
                            ],
                          ),
                          if (_adjusted != null)
                            Padding(
                              padding: const EdgeInsets.only(top: 4, bottom: 4),
                              child: Row(
                                children: [
                                  Icon(
                                    Icons.info_outline,
                                    size: 18,
                                    color: context.colors.textSecondary,
                                  ),
                                  const SizedBox(width: 6),
                                  Expanded(
                                    child: Text(
                                      _adjusted!,
                                      key: const Key('timeAdjusted'),
                                      style: TextStyle(
                                          color: context.colors.textPrimary),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          // A reminder is just a title and a time (P14).
                          if (!widget.point) ...[
                            Wrap(
                              spacing: 8,
                              children: [
                                for (final length in TaskSheet.quickLengths)
                                  ChoiceChip(
                                    label: Text(length < 60
                                        ? '$length min'
                                        : '${length ~/ 60} h'),
                                    selected: _end == _start + length,
                                    onSelected: _start + length <= slotEnd
                                        ? (_) => setState(
                                            () => _end = _start + length)
                                        : null,
                                  ),
                                ChoiceChip(
                                  // Up to what's next of the same kind: a
                                  // task and a routine may share time (P12).
                                  label: Text(
                                    slotEnd == PlannerTask.dayMinutes
                                        ? 'Until midnight'
                                        : _repeats
                                            ? 'Until the next routine'
                                            : 'Until the next task',
                                  ),
                                  selected: _end == slotEnd,
                                  onSelected: (_) =>
                                      setState(() => _end = slotEnd),
                                ),
                              ],
                            ),
                            const SizedBox(height: 8),
                            _ColourChoice(
                              selected: _color,
                              onSelected: (c) => setState(() {
                                _color = c;
                                _colourPicked = true;
                              }),
                            ),
                            const SizedBox(height: 4),
                            Wrap(
                              spacing: 8,
                              crossAxisAlignment: WrapCrossAlignment.center,
                              children: [
                                Text(
                                  'Remind',
                                  style: TextStyle(
                                      color: context.colors.textSecondary),
                                ),
                                for (final minutes in _reminders)
                                  ChoiceChip(
                                    label: Text(_remindLabel(minutes)),
                                    selected: _remind == minutes,
                                    onSelected: (_) =>
                                        setState(() => _remind = minutes),
                                  ),
                              ],
                            ),
                            if (widget.repeat != RepeatChoice.never)
                              ..._repeatChoices(context),
                          ],
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              Divider(height: 1, color: context.colors.divider),
              SafeArea(
                top: false,
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(8, 8, 16, 8),
                  child: Row(
                    children: [
                      IconButton(
                        icon: const Icon(Icons.close),
                        tooltip: 'Close',
                        onPressed: _close,
                      ),
                      if (widget.onDelete != null)
                        Flexible(
                          child: TextButton.icon(
                            icon: const Icon(Icons.delete_outline),
                            label: Text(widget.deleteLabel),
                            style: TextButton.styleFrom(
                              foregroundColor: context.colors.danger,
                            ),
                            onPressed: () {
                              Navigator.of(context).pop();
                              widget.onDelete!();
                            },
                          ),
                        ),
                      const Spacer(),
                      FilledButton(
                        // Greyed out until there's a title (P15).
                        onPressed: _title.text.trim().isEmpty ? null : _submit,
                        child: Text(widget.submitLabel),
                      ),
                    ],
                  ),
                ),
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

/// The colour row (P9): none, or one of the [BlockColor]s.
class _ColourChoice extends StatelessWidget {
  final BlockColor? selected;
  final ValueChanged<BlockColor?> onSelected;

  const _ColourChoice({required this.selected, required this.onSelected});

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    Widget dot(BlockColor? colour) {
      final isSelected = colour == selected;
      return Semantics(
        button: true,
        selected: isSelected,
        label: 'Colour: ${colour?.label ?? 'none'}',
        excludeSemantics: true,
        child: InkResponse(
          onTap: () => onSelected(colour),
          radius: 24,
          child: SizedBox.square(
            dimension: 48,
            child: Center(
              child: Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: colour?.stripe ?? Colors.transparent,
                  border: Border.all(
                    color: isSelected ? colors.textPrimary : colors.textHint,
                    width: isSelected ? 3 : 1,
                  ),
                ),
                child: colour == null
                    ? Icon(Icons.block, size: 18, color: colors.textSecondary)
                    : null,
              ),
            ),
          ),
        ),
      );
    }

    return Wrap(
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        Padding(
          padding: const EdgeInsets.only(right: 4),
          child: Text(
            'Colour',
            style: TextStyle(color: colors.textSecondary),
          ),
        ),
        dot(null),
        for (final colour in BlockColor.values) dot(colour),
      ],
    );
  }
}
