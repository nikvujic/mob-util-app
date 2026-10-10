import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:the_app/core/clock.dart';
import 'package:the_app/core/format.dart';
import 'package:the_app/core/theme.dart';
import 'package:the_app/models/planner_task.dart';
import 'package:the_app/pages/planner/add_task_sheet.dart';
import 'package:the_app/pages/planner/routines.dart';
import 'package:the_app/pages/planner/timeline.dart';
import 'package:the_app/providers/planner_provider.dart';
import 'package:the_app/providers/routines_provider.dart';
import 'package:the_app/widgets/bottom_actions.dart';
import 'package:the_app/widgets/confirm_dialog.dart';
import 'package:the_app/widgets/day_strip.dart';
import 'package:the_app/widgets/main_app_bar.dart';
import 'package:the_app/widgets/selection.dart';

/// The planner (P2, P7): each day is a timeline from 00:00 to 24:00, with
/// tasks as blocks of time and the gaps between them as free time. Tapping
/// free time adds a task there; tapping a block edits it; its checkbox
/// ticks it off. The day strip at the bottom picks the day.
class PlannerPage extends ConsumerStatefulWidget {
  /// Height of one hour on the timeline.
  static const hourHeight = PlannerTimeline.hourHeight;

  const PlannerPage({super.key});

  @override
  ConsumerState<PlannerPage> createState() => _PlannerPageState();
}

class _PlannerPageState extends ConsumerState<PlannerPage> {
  final SelectionController _selection = SelectionController();
  ScrollController? _timeline;

  /// The day shown; null means today (also after midnight passes).
  DateTime? _day;

  DateTime get _now => ref.read(clockProvider)();

  @override
  void dispose() {
    _selection.dispose();
    _timeline?.dispose();
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

  Future<void> _addIn(DateTime day, FreeSlot slot) async {
    // Today, in free time that's going on now: start at the next full hour
    // rather than at the (past) start of the free time.
    final now = _now;
    int? start;
    if (daysBetween(dayOf(now), day) == 0) {
      final minutes = now.hour * 60 + now.minute;
      final nextHour = (minutes + 59) ~/ 60 * 60;
      if (slot.start < nextHour && nextHour < slot.end) start = nextHour;
    }
    final task = await showAddTaskSheet(context, slot, start: start, day: day);
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
            );
      } else {
        ref.read(plannerProvider.notifier).addTask(
              day,
              task.title,
              start: task.start,
              end: task.end,
              color: task.color,
            );
      }
    } on TaskOverlapException {
      _taken(
        task.weekdays == null
            ? 'That time is taken.'
            : 'Another routine has that time on one of those days.',
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
      );
    } on TaskOverlapException {
      _taken();
    }
  }

  /// A routine's block on a day: change it just there, skip it there, or
  /// edit the routine itself (P8).
  Future<void> _routineTapped(RoutineOccurrence occurrence) async {
    final routine = occurrence.routine;
    final choice = await showModalBottomSheet<_RoutineChoice>(
      context: context,
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              title: Text(
                routine.title,
                style: const TextStyle(fontWeight: FontWeight.w600),
              ),
              subtitle: Text(
                '${formatMinutes(routine.start)}–${formatMinutes(routine.end)}'
                ' · a routine',
              ),
            ),
            for (final choice in _RoutineChoice.values)
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
        await _changeThisDay(occurrence);
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

  /// "Change just this day": the routine skips the day, and a one-off
  /// task takes its place, as changed.
  Future<void> _changeThisDay(RoutineOccurrence occurrence) async {
    final routine = occurrence.routine;
    final day = occurrence.day;
    final dayTasks =
        ref.read(plannerProvider).where((t) => isSameDay(t.day, day)).toList();
    final others = routinesOn(day, ref.read(routinesProvider), dayTasks)
        .where((o) => o.routine.id != routine.id);
    final room = freeSlotsAround([
      for (final t in dayTasks)
        if (t.hasTime) (start: t.start!, end: t.end!),
      for (final o in others) (start: o.routine.start, end: o.routine.end),
    ]).firstWhere((s) => s.start <= routine.start && routine.end <= s.end);
    final changed = await showModalBottomSheet<NewTask>(
      context: context,
      isScrollControlled: true,
      builder: (_) => TaskSheet(
        slot: room,
        title: routine.title,
        start: routine.start,
        end: routine.end,
        color: routine.color,
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
          );
    } on TaskOverlapException {
      routines.setSkipped(routine.id, day, skipped: false);
      _taken();
    }
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
    // The past is reachable only back to the oldest unfinished task (P6).
    var firstDay = today;
    for (final t in all) {
      if (!t.done && t.day.isBefore(firstDay)) firstDay = t.day;
    }
    var day = _day ?? today;
    if (day.isBefore(firstDay)) day = firstDay;
    final tasks = all.where((t) => isSameDay(t.day, day)).toList();
    final timed = tasks.where((t) => t.hasTime).toList();
    final untimed = tasks.where((t) => !t.hasTime).toList();
    final routines = routinesOn(day, ref.watch(routinesProvider), tasks); // P8
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
          selected: _selection.isSelected(task.id),
          onTap: () => _selection.handleTap(task.id, () => _edit(task)),
          onLongPress: () => _selection.handleLongPress(task.id),
          onToggleDone: () =>
              ref.read(plannerProvider.notifier).toggleDone(task.id),
        ),
      // Routines aren't selected (they're deleted on the Routines screen).
      for (final o in routines)
        TimelineBlock(
          id: o.routine.id,
          title: o.routine.title,
          start: o.routine.start,
          end: o.routine.end,
          done: o.done,
          repeats: true,
          color: BlockColor.fromName(o.routine.color),
          onTap: selecting ? () {} : () => _routineTapped(o),
          onToggleDone: () =>
              ref.read(routinesProvider.notifier).toggleDone(o.routine.id, day),
        ),
    ];

    // Opens around the current hour (the scroll stays when changing day).
    final timeline = _timeline ??= ScrollController(
      initialScrollOffset: math.max(0, now.hour - 1) * PlannerPage.hourHeight,
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
                child: SingleChildScrollView(
                  controller: timeline,
                  child: PlannerTimeline(
                    blocks: blocks,
                    onAdd: selecting ? null : (slot) => _addIn(day, slot),
                  ),
                ),
              ),
            ],
          ),
          bottomNavigationBar: DayStrip(
            today: today,
            firstDay: firstDay,
            selected: day,
            onSelected: _select,
            hasItems: (d) => all.any((t) => isSameDay(t.day, d)),
          ),
          floatingActionButton: _selection.isActive
              ? SelectionActions(
                  allSelected: _selection.count == tasks.length,
                  onSelectAll: () =>
                      _selection.selectAll(tasks.map((t) => t.id)),
                  onDeselectAll: _selection.clear,
                  onDelete: _deleteSelected,
                  onClose: _selection.clear,
                )
              // No + button: free time on the timeline is where tasks are
              // added. Routines have their own screen.
              : BottomActions(
                  actions: [
                    BottomAction(
                      icon: Icons.repeat,
                      tooltip: 'Routines',
                      onPressed: () => _openRoutines(day),
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

/// What can be done with a routine's block on a day (P8).
enum _RoutineChoice {
  thisDay('Change just this day', Icons.edit_calendar_outlined),
  skip('Skip this day', Icons.event_busy_outlined),
  edit('Edit routine', Icons.repeat);

  final String label;
  final IconData icon;

  const _RoutineChoice(this.label, this.icon);
}
