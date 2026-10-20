import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:the_app/core/clock.dart';
import 'package:the_app/core/format.dart';
import 'package:the_app/core/theme.dart';
import 'package:the_app/models/notification_target.dart';
import 'package:the_app/models/planner_pin.dart';
import 'package:the_app/models/planner_task.dart';
import 'package:the_app/pages/planner/add_task_sheet.dart';
import 'package:the_app/pages/planner/routines.dart';
import 'package:the_app/pages/planner/pin_menu.dart';
import 'package:the_app/pages/planner/reminders_sheet.dart';
import 'package:the_app/pages/planner/timeline.dart';
import 'package:the_app/providers/pins_provider.dart';
import 'package:the_app/providers/notification_target_provider.dart';
import 'package:the_app/providers/planner_provider.dart';
import 'package:the_app/providers/routines_provider.dart';
import 'package:the_app/widgets/bottom_actions.dart';
import 'package:the_app/widgets/confirm_dialog.dart';
import 'package:the_app/widgets/day_strip.dart';
import 'package:the_app/widgets/main_app_bar.dart';
import 'package:the_app/widgets/pull_down_list.dart';
import 'package:the_app/widgets/section_reset.dart';
import 'package:the_app/widgets/selection.dart';

/// The planner (P2, P7): each day is a timeline from 00:00 to 24:00, with
/// tasks as blocks of time and the gaps between them as free time. Tapping
/// free time adds a task there; tapping a block edits it; its checkbox
/// ticks it off. The day strip at the bottom picks the day.
class PlannerPage extends ConsumerStatefulWidget {
  const PlannerPage({super.key});

  @override
  ConsumerState<PlannerPage> createState() => _PlannerPageState();
}

class _PlannerPageState extends ConsumerState<PlannerPage> {
  final SelectionController _selection = SelectionController();

  /// The day shown; null means today (also after midnight passes).
  DateTime? _day;

  /// A notification tapped (Round 19): the minute to scroll to, and a
  /// count that makes the timeline open there afresh each time.
  int? _goTo;
  int _jumps = 0;
  PlannerTarget? _taking;

  /// Takes a tapped notification's target (once this page is built, so
  /// not while the Planner is locked: it waits for the next visit).
  void _take(PlannerTarget target) {
    if (identical(_taking, target)) return;
    _taking = target;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      ref.read(pendingTargetProvider.notifier).state = null;
      _selection.clear();
      setState(() {
        _day = target.day;
        _goTo = target.minutes;
        _jumps++;
      });
    });
  }

  DateTime get _now => ref.read(clockProvider)();

  @override
  void initState() {
    super.initState();
    // The blocks are built from the selection too, outside the
    // ListenableBuilder below: rebuild them all when it changes.
    _selection.addListener(_rebuild);
    _lifecycle = AppLifecycleListener(onResume: _rebuild);
  }

  /// "Today" is worked out when building: build again when the app comes
  /// back (e.g. the next morning, the app still open since last night).
  late final AppLifecycleListener _lifecycle;

  void _rebuild() => setState(() {});

  /// Fires when the Planner tab is switched to or away from (G18).
  Listenable? _sectionReset;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final reset = SectionReset.maybeOf(context);
    if (!identical(reset, _sectionReset)) {
      _sectionReset?.removeListener(_backToToday);
      _sectionReset = reset?..addListener(_backToToday);
    }
  }

  /// Coming back to the Planner shows today, not the day picked before.
  void _backToToday() {
    _goTo = null; // the scroll stays where it is
    if (_day != null) setState(() => _day = null);
  }

  @override
  void dispose() {
    _sectionReset?.removeListener(_backToToday);
    _lifecycle.dispose();
    _selection
      ..removeListener(_rebuild)
      ..dispose();
    super.dispose();
  }

  void _select(DateTime day) {
    if (_day != null && daysBetween(_day!, day) == 0) return;
    setState(() => _day = day);
    _selection.clear(); // selection is per day
  }

  void _taken([String what = 'That time is taken.']) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(what)));
  }

  /// Adds a task in free [slot] on [day]: near [at] (the minute tapped,
  /// down to :00 or :30, Round 14), else as below.
  Future<void> _addIn(DateTime day, FreeSlot slot, {int? at}) async {
    // Today, in free time that's going on now: start at the next full hour
    // rather than at the (past) start of the free time.
    final now = _now;
    int? start;
    if (at != null) {
      start = (at ~/ 30 * 30).clamp(
          slot.start, math.max(slot.start, slot.end - PlannerTask.minMinutes));
    } else if (daysBetween(dayOf(now), day) == 0) {
      final minutes = now.hour * 60 + now.minute;
      final nextHour = (minutes + 59) ~/ 60 * 60;
      // Only if a block still fits after it.
      if (slot.start < nextHour &&
          nextHour + PlannerTask.minMinutes <= slot.end) {
        start = nextHour;
      }
    }
    start ??= slot.start;
    // Free time is free of both kinds; past it, a task may go on beside a
    // routine and a routine beside a task (P12).
    bool around(FreeSlot room) =>
        room.start <= slot.start && slot.end <= room.end;
    final task = await showAddTaskSheet(
      context,
      ref.read(plannerProvider.notifier).freeOn(day).firstWhere(around),
      // Set to repeat: clear of every routine it would share a day with.
      repeatRoom: (weekdays, until, {required start, required end}) =>
          ref.read(routinesProvider.notifier).roomAround(
                weekdays: weekdays,
                from: day,
                until: until,
                start: start,
                end: end,
              ),
      start: start,
      end: math.min(start + 60, slot.end),
      day: day,
    );
    if (task == null || !mounted) return;
    try {
      final weekdays = task.weekdays;
      if (weekdays != null) {
        // Repeats: a routine from this day on (P8).
        ref.read(routinesProvider.notifier).add(
              title: task.title,
              start: task.start,
              end: task.end,
              weekdays: weekdays,
              from: day,
              until: task.until,
              color: task.color,
              remind: task.remind,
              description: task.description,
            );
      } else {
        ref.read(plannerProvider.notifier).addTask(
              day,
              task.title,
              start: task.start,
              end: task.end,
              color: task.color,
              remind: task.remind,
              description: task.description,
            );
      }
      await allowReminders(context, ref, task.remind);
    } on TaskOverlapException {
      _taken(
        task.weekdays == null
            ? 'That time is taken.'
            : 'Another routine has that time on one of those days.',
      );
    }
  }

  /// A task's block: what it is first, then Edit or Delete (P15), like a
  /// routine's.
  Future<void> _taskTapped(PlannerTask task) async {
    final choice = await showModalBottomSheet<_TaskChoice>(
      context: context,
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _BlockHeader(
              title: task.title,
              start: task.start!,
              end: task.end!,
              color: BlockColor.fromName(task.color),
              remind: task.remind,
              description: task.description,
            ),
            for (final choice in _TaskChoice.values)
              ListTile(
                leading: Icon(choice.icon),
                title: Text(choice.label),
                onTap: () => Navigator.of(context).pop(choice),
              ),
          ],
        ),
      ),
    );
    if (choice == null || !mounted) return;
    switch (choice) {
      case _TaskChoice.edit:
        await _edit(task);
      case _TaskChoice.move:
        await _move(task);
      case _TaskChoice.delete:
        final planner = ref.read(plannerProvider.notifier)
          ..removeTasks({task.id});
        ScaffoldMessenger.of(context)
          ..hideCurrentSnackBar()
          ..showSnackBar(
            SnackBar(
              content: Text('${task.title} deleted'),
              action: SnackBarAction(
                label: 'Undo',
                onPressed: () {
                  try {
                    planner.restoreTask(task);
                  } on TaskOverlapException {
                    _taken();
                  }
                },
              ),
            ),
          );
    }
  }

  Future<void> _edit(PlannerTask task) async {
    final notifier = ref.read(plannerProvider.notifier);
    final changed = await showEditTaskSheet(
      context,
      task,
      notifier.roomFor(task),
    );
    if (changed == null || !mounted) return;
    try {
      notifier.updateTask(
        task.id,
        title: changed.title,
        start: changed.start,
        end: changed.end,
        color: changed.color,
        remind: changed.remind,
        description: changed.description,
      );
      await allowReminders(context, ref, changed.remind);
    } on TaskOverlapException {
      _taken();
    }
  }

  /// Round 83 (Nikola): moves [task] to a picked day (the next one first:
  /// tomorrow for a missed one), at its time if that's free there, else
  /// the nearest free time as long, after saying so. Undo moves it back.
  Future<void> _move(PlannerTask task) async {
    final today = dayOf(_now);
    final day = await showDatePicker(
      context: context,
      helpText: 'Move to',
      initialDate: addDays(task.day.isBefore(today) ? today : task.day, 1),
      firstDate: today,
      lastDate: DateTime(today.year + 10),
      selectableDayPredicate: (d) => !isSameDay(d, task.day),
    );
    if (day == null || !mounted) return;
    final planner = ref.read(plannerProvider.notifier);
    final span = (start: task.start!, end: task.end!);
    final fit = fitTime(planner.freeOn(day), span);
    final label = formatDay(day, today: today);
    if (fit == null) {
      _taken('No free time that long on $label.');
      return;
    }
    if (fit != span) {
      final move = await showConfirmDialog(
        context,
        title: 'That time is taken',
        message: '${_span(span)} is taken on $label, so its time will '
            'change to fit: ${_span(fit)}.',
        confirmLabel: 'Move',
      );
      if (!move || !mounted) return;
    }
    try {
      planner.moveTask(task.id, day, start: fit.start, end: fit.end);
    } on TaskOverlapException {
      _taken();
      return;
    }
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text('${task.title} moved to $label'),
          action: SnackBarAction(
            label: 'Undo',
            onPressed: () {
              try {
                planner.moveTask(task.id, task.day,
                    start: task.start!, end: task.end!);
              } on TaskOverlapException {
                _taken();
              }
            },
          ),
        ),
      );
  }

  static String _span(TimeSpan span) =>
      '${formatMinutes(span.start)}–${formatMinutes(span.end)}';

  /// A block ticked off (or back). Round 78: ticked off on a past day,
  /// it's deleted at once, as the past's done blocks are (Undo puts it
  /// back, not done).
  void _tick(PlannerTask task) {
    final planner = ref.read(plannerProvider.notifier);
    planner.toggleDone(task.id);
    final today = dayOf(_now);
    if (task.done || !task.day.isBefore(today)) return;
    planner.dropDoneBefore(today);
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text('${task.title} done and cleared'),
          action: SnackBarAction(
            label: 'Undo',
            onPressed: () => planner.restoreTask(task),
          ),
        ),
      );
  }

  /// A routine's block on a day: change it just there, skip it there, or
  /// edit the routine itself (P8).
  Future<void> _routineTapped(RoutineOccurrence occurrence) async {
    final routine = occurrence.routine;
    final beside = _besideRoutine(occurrence);
    final choice = await showModalBottomSheet<_RoutineChoice>(
      context: context,
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _BlockHeader(
              title: routine.title,
              start: routine.start,
              end: routine.end,
              color: BlockColor.fromName(routine.color),
              remind: routine.remind,
              description: routine.description,
              routine: true,
            ),
            for (final choice in _RoutineChoice.values)
              if (choice.needsRoom && beside == null)
                // Tasks fill the routine's whole time: no room for another.
                ListTile(
                  enabled: false,
                  leading: Icon(choice.icon),
                  title: Text(choice.label),
                  subtitle: const Text('Tasks fill that time'),
                )
              else
                ListTile(
                  leading: Icon(choice.icon),
                  title: Text(choice.label),
                  onTap: () => Navigator.of(context).pop(choice),
                ),
          ],
        ),
      ),
    );
    if (choice == null || !mounted) return;
    final routines = ref.read(routinesProvider.notifier);
    switch (choice) {
      case _RoutineChoice.thisDay:
        await _changeThisDay(occurrence, beside!);
      case _RoutineChoice.alongside:
        await _addAlongside(occurrence, beside!);
      case _RoutineChoice.skip:
        routines.setSkipped(routine.id, occurrence.day, skipped: true);
        ScaffoldMessenger.of(context)
          ..hideCurrentSnackBar()
          ..showSnackBar(
            SnackBar(
              content: Text('${routine.title} skipped that day'),
              action: SnackBarAction(
                label: 'Undo',
                onPressed: () => routines.setSkipped(
                  routine.id,
                  occurrence.day,
                  skipped: false,
                ),
              ),
            ),
          );
      case _RoutineChoice.edit:
        await editRoutine(context, ref, routine);
    }
  }

  /// Where a task can go beside [occurrence]'s routine (P12): the time free
  /// of tasks that shares the most of the routine's, and the routine's time
  /// fitted into it ([note] says how, if it had to change). Null if tasks
  /// fill all of the routine's time.
  _Beside? _besideRoutine(RoutineOccurrence occurrence) {
    final routine = occurrence.routine;
    FreeSlot? best;
    var most = 0;
    final free = ref.read(plannerProvider.notifier).freeOn(occurrence.day);
    for (final room in free) {
      // Too short for any block.
      if (room.end - room.start < PlannerTask.minMinutes) continue;
      final int shared =
          math.min(room.end, routine.end) - math.max(room.start, routine.start);
      if (shared > most) {
        best = room;
        most = shared;
      }
    }
    if (best == null) return null;
    // The routine's time within the room, at least the shortest block.
    var start = math.max(routine.start, best.start);
    var end = math.min(routine.end, best.end);
    if (end - start < PlannerTask.minMinutes) {
      end = math.min(start + PlannerTask.minMinutes, best.end);
      start = end - PlannerTask.minMinutes;
    }
    return (
      room: best,
      start: start,
      end: end,
      note: start == routine.start && end == routine.end
          ? null
          : 'Now ${formatMinutes(start)}–${formatMinutes(end)}: a task is '
              'there too.',
    );
  }

  /// "Change just this day": the routine skips the day, and a one-off
  /// task takes its place, as changed.
  Future<void> _changeThisDay(
    RoutineOccurrence occurrence,
    _Beside beside,
  ) async {
    final routine = occurrence.routine;
    final day = occurrence.day;
    final changed = await showModalBottomSheet<NewTask>(
      context: context,
      isScrollControlled: true,
      enableDrag: false,
      builder: (_) => TaskSheet(
        slot: beside.room,
        title: routine.title,
        start: beside.start,
        end: beside.end,
        note: beside.note,
        color: routine.color,
        remind: routine.remind,
        description: routine.description,
        submitLabel: 'Save',
      ),
    );
    if (changed == null || !mounted) return;
    final routines = ref.read(routinesProvider.notifier);
    routines.setSkipped(routine.id, day, skipped: true);
    try {
      ref.read(plannerProvider.notifier).addTask(
            day,
            changed.title,
            start: changed.start,
            end: changed.end,
            color: changed.color,
            remind: changed.remind,
            description: changed.description,
          );
      await allowReminders(context, ref, changed.remind);
    } on TaskOverlapException {
      routines.setSkipped(routine.id, day, skipped: false);
      _taken();
    }
  }

  /// A one-off task at the same time as a routine, side by side (P12).
  Future<void> _addAlongside(
    RoutineOccurrence occurrence,
    _Beside beside,
  ) async {
    final task = await showAddTaskSheet(
      context,
      beside.room,
      start: beside.start,
      end: beside.end,
      note: beside.note,
    );
    if (task == null || !mounted) return;
    try {
      ref.read(plannerProvider.notifier).addTask(
            occurrence.day,
            task.title,
            start: task.start,
            end: task.end,
            color: task.color,
            remind: task.remind,
            description: task.description,
          );
      await allowReminders(context, ref, task.remind);
    } on TaskOverlapException {
      _taken();
    }
  }

  /// Adds a reminder (P14) on [day]: today from the next full hour,
  /// other days from 09:00.
  /// Adds a reminder on [day]: at [at] (tapped on the timeline's edge,
  /// down to 15 minutes, Round 14), else today from the next full hour,
  /// other days from 09:00.
  Future<void> _addPin(DateTime day, {int? at}) async {
    final now = _now;
    final time = at != null
        ? (at ~/ 15 * 15).clamp(0, PlannerTask.dayMinutes - 1)
        : daysBetween(dayOf(now), day) == 0
            ? math.min((now.hour + 1) * 60, PlannerTask.dayMinutes - 1)
            : 9 * 60;
    final pin = await showAddPinSheet(context, time: time);
    if (pin == null || !mounted) return;
    ref.read(pinsProvider.notifier).add(day, pin.title, time: pin.start);
    await allowReminders(context, ref, 0);
  }

  Future<void> _editPin(PlannerPin pin) async {
    final pins = ref.read(pinsProvider.notifier);
    final changed = await showEditPinSheet(
      context,
      pin,
      onDelete: () => _removePin(pin, 'deleted'),
    );
    if (changed == null || !mounted) return;
    pins.update(pin.id, title: changed.title, time: changed.start);
  }

  /// A reminder mark tapped (P14): its reminders, each like a small block
  /// with a box to tick it off; tapping one edits it (Delete is there).
  Future<void> _pinsTapped(List<PlannerPin> pins) async {
    final picked = await showPinMenu(context, pins);
    if (picked == null || !mounted) return;
    final (pin, done) = picked;
    done ? _pinDone(pin) : await _editPin(pin);
  }

  /// The bell button (Round 70): every reminder, the next first, to look
  /// over, delete several, or add one ([day]'s); with none yet, straight
  /// to adding one.
  Future<void> _reminders(DateTime day) async {
    final all = ref.read(pinsProvider);
    if (all.isEmpty) return _addPin(day);
    final choice = await showRemindersSheet(context, pins: all, now: _now);
    if (choice == null || !mounted) return;
    if (choice.add) return _addPin(day);
    final pins = ref.read(pinsProvider.notifier);
    final removed = [for (final pin in choice.delete) pins.remove(pin.id)];
    final count = removed.length;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(count == 1
              ? '${removed.single.title}: deleted'
              : '$count reminders deleted'),
          action: SnackBarAction(
            label: 'Undo',
            onPressed: () => removed.forEach(pins.restore),
          ),
        ),
      );
  }

  /// Ticking a reminder off deletes it (Nikola), with undo.
  void _pinDone(PlannerPin pin) => _removePin(pin, 'done');

  void _removePin(PlannerPin pin, String what) {
    final pins = ref.read(pinsProvider.notifier);
    final removed = pins.remove(pin.id);
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text('${pin.title}: $what'),
          action: SnackBarAction(
            label: 'Undo',
            onPressed: () => pins.restore(removed),
          ),
        ),
      );
  }

  void _openRoutines(DateTime day) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => RoutinesPage(weekday: day.weekday),
      ),
    );
  }

  Future<void> _deleteSelected() async {
    final confirmed = await showDeleteConfirmDialog(
      context,
      count: _selection.count,
      singular: 'task',
      plural: 'tasks',
    );
    if (!confirmed || !mounted) return;
    ref.read(plannerProvider.notifier).removeTasks(_selection.selected);
    _selection.clear();
  }

  @override
  Widget build(BuildContext context) {
    final now = _now;
    final today = dayOf(now);
    final all = ref.watch(plannerProvider);
    final allPins = ref.watch(pinsProvider);
    // The past is reachable only back to the oldest unfinished task (P6),
    // or reminder (P14: ticked off, they're gone).
    var firstDay = today;
    for (final t in all) {
      if (!t.done && t.day.isBefore(firstDay)) firstDay = t.day;
    }
    for (final p in allPins) {
      if (p.day.isBefore(firstDay)) firstDay = p.day;
    }
    final target = ref.watch(pendingTargetProvider);
    if (target is PlannerTarget) _take(target);
    var day = _day ?? today;
    if (day.isBefore(firstDay)) day = firstDay;
    final tasks = all.where((t) => isSameDay(t.day, day)).toList();
    final timed = tasks.where((t) => t.hasTime).toList();
    final untimed = tasks.where((t) => !t.hasTime).toList();
    // P8; Round 78: not on past days (they're just there, nothing to
    // tick off).
    final routines = day.isBefore(today)
        ? const <RoutineOccurrence>[]
        : routinesOn(day, ref.watch(routinesProvider));
    final pins = allPins.where((p) => isSameDay(p.day, day)).toList();
    ref.listen(plannerProvider, (_, next) {
      _selection.retain(next.map((t) => t.id));
    });
    final selecting = _selection.isActive;
    final blocks = [
      for (final task in timed)
        TimelineBlock(
          id: task.id,
          title: task.title,
          start: task.start!,
          end: task.end!,
          done: task.done,
          color: BlockColor.fromName(task.color),
          reminds: task.remind != null,
          description: task.description,
          selected: _selection.isSelected(task.id),
          onTap: () => _selection.handleTap(task.id, () => _taskTapped(task)),
          onLongPress: () => _selection.handleLongPress(task.id),
          // While selecting, nothing ticks (as with reminders).
          onToggleDone: selecting ? () {} : () => _tick(task),
        ),
      // Routines aren't selected (they're deleted on the Routines screen).
      for (final o in routines)
        TimelineBlock(
          id: o.routine.id,
          title: o.routine.title,
          start: o.routine.start,
          end: o.routine.end,
          repeats: true,
          color: BlockColor.fromName(o.routine.color),
          reminds: o.routine.remind != null,
          description: o.routine.description,
          // Round 78: no box to tick (Nikola: they're just there).
          onTap: selecting ? () {} : () => _routineTapped(o),
        ),
    ];

    // Opens around the current hour (the scroll stays when changing day),
    // or at a tapped notification's time, a little above it.
    final opensAt = PlannerTimeline.scaleFor(blocks).y(
      _goTo != null ? math.max(0, _goTo! - 30) : math.max(0, now.hour - 1) * 60,
    );

    return SelectionPopScope(
      controller: _selection,
      child: ListenableBuilder(
        listenable: _selection,
        builder: (context, _) => Scaffold(
          appBar: _selection.isActive
              ? SelectionAppBar(count: _selection.count)
              : const MainAppBar(title: 'Planner'),
          body: Column(
            children: [
              _DayHeader(day: day, today: today),
              if (untimed.isNotEmpty)
                _UntimedTasks(
                  tasks: untimed,
                  selection: _selection,
                ),
              Expanded(
                // Reach mode too (Round 14): pulled down at 00:00, the
                // first hours come into thumb reach, and snap back.
                child: PullDownList(
                  key: ValueKey(_jumps),
                  initialOffset: opensAt,
                  slivers: [
                    SliverToBoxAdapter(
                      child: PlannerTimeline(
                        blocks: blocks,
                        onAdd: selecting ? null : (slot) => _addIn(day, slot),
                        onAddAt: selecting
                            ? null
                            : (slot, at) => _addIn(day, slot, at: at),
                        onLeftTap:
                            selecting ? null : (at) => _addPin(day, at: at),
                        now: isSameDay(day, today)
                            ? ref.read(clockProvider)
                            : null,
                        pins: [
                          for (final pin in pins)
                            TimelinePin(
                                id: pin.id, title: pin.title, time: pin.time),
                        ],
                        onPins: selecting
                            ? null
                            : (group) => _pinsTapped([
                                  for (final p in group)
                                    pins.firstWhere((pin) => pin.id == p.id),
                                ]),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          bottomNavigationBar: DayStrip(
            today: today,
            firstDay: firstDay,
            selected: day,
            onSelected: _select,
            hasItems: (d) =>
                all.any((t) => isSameDay(t.day, d)) ||
                allPins.any((p) => isSameDay(p.day, d)),
          ),
          floatingActionButton: _selection.isActive
              ? SelectionActions(
                  allSelected: _selection.count == tasks.length,
                  onSelectAll: () =>
                      _selection.selectAll(tasks.map((t) => t.id)),
                  onDeselectAll: _selection.clear,
                  onDelete: _deleteSelected,
                )
              // No + button: free time on the timeline is where tasks are
              // added. Routines have their own screen; reminders (P14) are
              // listed and added here, outermost (Round 70).
              : BottomActions(
                  actions: [
                    BottomAction(
                      icon: Icons.repeat,
                      tooltip: 'Routines',
                      onPressed: () => _openRoutines(day),
                    ),
                    BottomAction(
                      icon: Icons.notifications_active_outlined,
                      tooltip: 'Reminders',
                      onPressed: () => _reminders(day),
                    ),
                  ],
                ),
        ),
      ),
    );
  }
}

/// Tasks from the first planner, which had no times: shown above the
/// timeline, marked, so they can be deleted (long-press).
class _UntimedTasks extends StatelessWidget {
  final List<PlannerTask> tasks;
  final SelectionController selection;

  const _UntimedTasks({required this.tasks, required this.selection});

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Padding(
      padding: const EdgeInsets.fromLTRB(8, 0, 8, 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (final task in tasks)
            Padding(
              padding: const EdgeInsets.only(bottom: 4),
              child: SelectableCard(
                selected: selection.isSelected(task.id),
                onTap: () => selection.handleTap(task.id, () {}),
                onLongPress: () => selection.handleLongPress(task.id),
                child: ListTile(
                  dense: true,
                  leading: Icon(Icons.error_outline, color: colors.danger),
                  title: Text(task.title),
                  subtitle: Text(
                    'No time (from the old planner)',
                    style: TextStyle(color: colors.textSecondary),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

/// The day shown, e.g. "Today · Thu, 9 Oct".
class _DayHeader extends StatelessWidget {
  final DateTime day;
  final DateTime today;

  const _DayHeader({required this.day, required this.today});

  @override
  Widget build(BuildContext context) {
    final relative = switch (daysBetween(today, day)) {
      0 => 'Today · ',
      1 => 'Tomorrow · ',
      -1 => 'Yesterday · ',
      _ => '',
    };
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
      child: Align(
        alignment: Alignment.centerLeft,
        child: Text(
          '$relative${formatDay(day, today: today)}',
          style: TextStyle(
            color: context.colors.textPrimary,
            fontSize: 16,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    );
  }
}

/// What can be done with a task's block (P15).
enum _TaskChoice {
  edit('Edit', Icons.edit_outlined),
  move('Move to another day', Icons.event_repeat_outlined),
  delete('Delete', Icons.delete_outline);

  final String label;
  final IconData icon;

  const _TaskChoice(this.label, this.icon);
}

/// The top of a block's menu: its colour, title, time and reminder.
class _BlockHeader extends StatelessWidget {
  final String title;
  final int start;
  final int end;
  final BlockColor? color;
  final int? remind;
  final String? description;
  final bool routine;

  const _BlockHeader({
    required this.title,
    required this.start,
    required this.end,
    required this.color,
    required this.remind,
    required this.description,
    this.routine = false,
  });

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final colour = color;
    return ListTile(
      leading: colour == null
          ? null
          : ExcludeSemantics(
              child: Container(
                width: 16,
                height: 16,
                decoration: BoxDecoration(
                  color: colour.stripe,
                  shape: BoxShape.circle,
                ),
              ),
            ),
      title: Text(title, style: const TextStyle(fontWeight: FontWeight.w600)),
      subtitle: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            [
              '${formatMinutes(start)}–${formatMinutes(end)}',
              if (routine) 'a routine',
              if (remind != null)
                'reminds ${remindLabel(remind).toLowerCase()}',
            ].join(' · '),
            style: TextStyle(color: colors.textSecondary),
          ),
          // In full here; the block shows what fits (P20).
          if (description != null)
            Padding(
              padding: const EdgeInsets.only(top: 6),
              child: Text(
                description!,
                style: TextStyle(color: colors.textPrimary),
              ),
            ),
        ],
      ),
    );
  }
}

/// What can be done with a routine's block on a day (P8, P12).
enum _RoutineChoice {
  thisDay('Change just this day', Icons.edit_calendar_outlined,
      needsRoom: true),
  alongside('Add a task alongside', Icons.add, needsRoom: true),
  skip('Skip this day', Icons.event_busy_outlined),
  edit('Edit routine', Icons.repeat);

  final String label;
  final IconData icon;

  /// Whether it makes a one-off task at the routine's time, which needs
  /// time free of tasks there.
  final bool needsRoom;

  const _RoutineChoice(this.label, this.icon, {this.needsRoom = false});
}

/// Where a task can go beside a routine: [room] free of tasks, the
/// routine's time fitted into it, and why it changed ([note]), if it did.
typedef _Beside = ({FreeSlot room, int start, int end, String? note});
