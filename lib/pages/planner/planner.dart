import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:the_app/core/clock.dart';
import 'package:the_app/core/format.dart';
import 'package:the_app/core/theme.dart';
import 'package:the_app/models/planner_task.dart';
import 'package:the_app/pages/planner/add_task_sheet.dart';
import 'package:the_app/providers/planner_provider.dart';
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
  /// Height of one hour on the timeline: a 30-minute block is one touch
  /// target high.
  static const hourHeight = 96.0;

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
    final task = await showAddTaskSheet(context, slot, start: start);
    if (task == null || !mounted) return;
    try {
      ref.read(plannerProvider.notifier).addTask(
            day,
            task.title,
            start: task.start,
            end: task.end,
          );
    } on TaskOverlapException {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('That time is taken.')),
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
      );
    } on TaskOverlapException {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('That time is taken.')),
      );
    }
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
    final timed = tasks.where((t) => t.hasTime).toList()
      ..sort((a, b) => a.start!.compareTo(b.start!));
    final untimed = tasks.where((t) => !t.hasTime).toList();
    ref.listen(plannerProvider, (_, next) {
      _selection.retain(next.map((t) => t.id));
    });

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
                  child: _Timeline(
                    tasks: timed,
                    selection: _selection,
                    onToggleDone: ref.read(plannerProvider.notifier).toggleDone,
                    onEdit: _edit,
                    onAdd: _selection.isActive
                        ? null
                        : (slot) => _addIn(day, slot),
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
          // No + button: free time on the timeline is where tasks are added.
          floatingActionButton: _selection.isActive
              ? SelectionActions(
                  allSelected: _selection.count == tasks.length,
                  onSelectAll: () =>
                      _selection.selectAll(tasks.map((t) => t.id)),
                  onDeselectAll: _selection.clear,
                  onDelete: _deleteSelected,
                  onClose: _selection.clear,
                )
              : null,
        ),
      ),
    );
  }
}

/// The day's timeline: hour marks, task blocks and free time between them.
class _Timeline extends StatelessWidget {
  static const _labelWidth = 56.0;

  /// Free stretches shorter than this aren't offered for adding.
  static const _minFreeMinutes = 5;

  final List<PlannerTask> tasks;
  final SelectionController selection;
  final ValueChanged<String> onToggleDone;
  final ValueChanged<PlannerTask> onEdit;

  /// Null while selecting.
  final ValueChanged<FreeSlot>? onAdd;

  const _Timeline({
    required this.tasks,
    required this.selection,
    required this.onToggleDone,
    required this.onEdit,
    required this.onAdd,
  });

  static double _y(int minutes) => minutes * PlannerPage.hourHeight / 60;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return SizedBox(
      // Room below 24:00 so the last hours can scroll clear of buttons.
      height: _y(PlannerTask.dayMinutes) + BottomActions.contentClearance,
      child: Stack(
        children: [
          for (var hour = 0; hour <= 24; hour++)
            Positioned(
              top: _y(hour * 60) - 8,
              left: 0,
              right: 0,
              child: ExcludeSemantics(
                child: Row(
                  children: [
                    SizedBox(
                      width: _labelWidth,
                      child: Text(
                        formatMinutes(hour * 60),
                        textAlign: TextAlign.center,
                        style: TextStyle(color: colors.textMuted, fontSize: 12),
                      ),
                    ),
                    Expanded(child: Divider(color: colors.divider, height: 16)),
                  ],
                ),
              ),
            ),
          for (final slot in freeSlots(tasks))
            if (slot.end - slot.start >= _minFreeMinutes)
              Positioned(
                top: _y(slot.start),
                height: _y(slot.end) - _y(slot.start),
                left: _labelWidth,
                right: 8,
                child: _FreeTime(
                  slot: slot,
                  onTap: onAdd == null ? null : () => onAdd!(slot),
                ),
              ),
          for (final task in tasks)
            Positioned(
              top: _y(task.start!),
              height: _y(task.end!) - _y(task.start!),
              left: _labelWidth,
              right: 8,
              child: _TaskBlock(
                task: task,
                selected: selection.isSelected(task.id),
                onTap: () => selection.handleTap(task.id, () => onEdit(task)),
                onLongPress: () => selection.handleLongPress(task.id),
                onToggleDone: () => onToggleDone(task.id),
              ),
            ),
        ],
      ),
    );
  }
}

class _FreeTime extends StatelessWidget {
  final FreeSlot slot;
  final VoidCallback? onTap;

  const _FreeTime({required this.slot, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final range = '${formatMinutes(slot.start)}–${formatMinutes(slot.end)}';
    return Semantics(
      button: true,
      label: 'Free time, $range. Add a task',
      excludeSemantics: true,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(12, 10, 12, 0),
          child: Align(
            alignment: Alignment.topLeft,
            child: Text(
              'Free · $range',
              style: TextStyle(color: context.colors.textHint, fontSize: 12),
            ),
          ),
        ),
      ),
    );
  }
}

/// A task: a block from its start to its end, with its title and time, and
/// a checkbox in the top-right corner to tick it off.
class _TaskBlock extends StatelessWidget {
  final PlannerTask task;
  final bool selected;
  final VoidCallback onTap;
  final VoidCallback onLongPress;
  final VoidCallback onToggleDone;

  const _TaskBlock({
    required this.task,
    required this.selected,
    required this.onTap,
    required this.onLongPress,
    required this.onToggleDone,
  });

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final range = '${formatMinutes(task.start!)}–${formatMinutes(task.end!)}';
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 1),
      child: LayoutBuilder(
        builder: (context, box) {
          // Short blocks put everything on one line.
          final compact = box.maxHeight < 56;
          final title = Text(
            task.title,
            maxLines: compact ? 1 : 2,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: task.done ? colors.textSecondary : colors.textPrimary,
              fontWeight: FontWeight.w600,
              decoration: task.done ? TextDecoration.lineThrough : null,
              decorationColor: colors.textSecondary,
            ),
          );
          final time = Text(
            range,
            style: TextStyle(color: colors.textSecondary, fontSize: 12),
          );
          return SelectableCard(
            selected: selected,
            onTap: onTap,
            onLongPress: onLongPress,
            child: Stack(
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(12, 4, 48, 4),
                  child: compact
                      ? Row(
                          children: [
                            Flexible(child: title),
                            const SizedBox(width: 8),
                            time,
                          ],
                        )
                      : Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [title, time],
                        ),
                ),
                Positioned(
                  top: 0,
                  right: 0,
                  child: Checkbox(
                    value: task.done,
                    semanticLabel: 'Done: ${task.title}',
                    materialTapTargetSize: compact
                        ? MaterialTapTargetSize.shrinkWrap
                        : MaterialTapTargetSize.padded,
                    visualDensity: compact ? VisualDensity.compact : null,
                    onChanged: (_) => onToggleDone(),
                  ),
                ),
              ],
            ),
          );
        },
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
