import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:the_app/core/clock.dart';
import 'package:the_app/core/format.dart';
import 'package:the_app/core/theme.dart';
import 'package:the_app/models/planner_task.dart';
import 'package:the_app/providers/planner_provider.dart';
import 'package:the_app/widgets/confirm_dialog.dart';
import 'package:the_app/widgets/day_strip.dart';
import 'package:the_app/widgets/empty_state.dart';
import 'package:the_app/widgets/main_app_bar.dart';
import 'package:the_app/widgets/pull_down_list.dart';
import 'package:the_app/widgets/selection.dart';
import 'package:the_app/widgets/text_input_sheet.dart';

/// The planner (P2): a to-do list per day. The day strip at the bottom picks
/// the day; + adds tasks to it; tapping a task marks it done.
class PlannerPage extends ConsumerStatefulWidget {
  const PlannerPage({super.key});

  @override
  ConsumerState<PlannerPage> createState() => _PlannerPageState();
}

class _PlannerPageState extends ConsumerState<PlannerPage> {
  final SelectionController _selection = SelectionController();

  /// The day shown; null means today (also after midnight passes).
  DateTime? _day;

  DateTime get _today => dayOf(ref.read(clockProvider)());

  @override
  void dispose() {
    _selection.dispose();
    super.dispose();
  }

  void _select(DateTime day) {
    if (_day != null && daysBetween(_day!, day) == 0) return;
    setState(() => _day = day);
    _selection.clear(); // selection is per day
  }

  void _addTasks(DateTime day) {
    showTextInputSheet(
      context,
      hint: 'Add task',
      submitLabel: 'Add',
      keepOpen: true,
      onSubmit: (title) =>
          ref.read(plannerProvider.notifier).addTask(day, title),
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
    final today = _today;
    final all = ref.watch(plannerProvider);
    // The past is reachable only back to the oldest unfinished task (P6).
    var firstDay = today;
    for (final t in all) {
      if (!t.done && t.day.isBefore(firstDay)) firstDay = t.day;
    }
    var day = _day ?? today;
    if (day.isBefore(firstDay)) day = firstDay;
    final tasks = all.where((t) => isSameDay(t.day, day)).toList();
    ref.listen(plannerProvider, (_, next) {
      _selection.retain(next.map((t) => t.id));
    });

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
              Expanded(
                child: tasks.isEmpty
                    ? const EmptyState(
                        icon: Icons.event_available_outlined,
                        message: 'Nothing planned',
                      )
                    : PullDownList(
                        bottomSpace: SelectionActions.listBottomSpace,
                        slivers: [
                          SliverReorderableList(
                            itemCount: tasks.length,
                            // onReorderItem only exists on newer Flutter
                            // than we target.
                            // ignore: deprecated_member_use
                            onReorder: (from, to) => ref
                                .read(plannerProvider.notifier)
                                .reorder(day, from, to),
                            proxyDecorator: (child, _, __) => Material(
                              type: MaterialType.transparency,
                              elevation: 6,
                              child: child,
                            ),
                            itemBuilder: (context, index) {
                              final task = tasks[index];
                              return Padding(
                                key: ValueKey(task.id),
                                padding: const EdgeInsets.symmetric(
                                  vertical: _TaskTile.gap / 2,
                                ),
                                child: _TaskTile(
                                  task: task,
                                  index: index,
                                  selectionMode: _selection.isActive,
                                  selected: _selection.isSelected(task.id),
                                  onTap: () => _selection.handleTap(
                                    task.id,
                                    () => ref
                                        .read(plannerProvider.notifier)
                                        .toggleDone(task.id),
                                  ),
                                  onLongPress: () =>
                                      _selection.handleLongPress(task.id),
                                ),
                              );
                            },
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
              : FloatingActionButton(
                  // Tabs are kept alive side by side; a shared default hero
                  // tag would clash when a route is pushed.
                  heroTag: null,
                  tooltip: 'Add task',
                  onPressed: () => _addTasks(day),
                  child: const Icon(Icons.add),
                ),
        ),
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
          style: const TextStyle(
            color: AppColors.textPrimary,
            fontSize: 16,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    );
  }
}

class _TaskTile extends StatelessWidget {
  /// Vertical space between rows (as in the shop).
  static const gap = 4.0;

  final PlannerTask task;
  final int index;
  final bool selectionMode;
  final bool selected;
  final VoidCallback onTap;
  final VoidCallback onLongPress;

  const _TaskTile({
    required this.task,
    required this.index,
    required this.selectionMode,
    required this.selected,
    required this.onTap,
    required this.onLongPress,
  });

  @override
  Widget build(BuildContext context) {
    // One element for screen readers: "Gym, checkbox, checked".
    return MergeSemantics(
      child: SelectableCard(
        selected: selected,
        onTap: onTap,
        onLongPress: onLongPress,
        child: ReorderableRow(
          content: Row(
            children: [
              // Shows the state only; the row takes the tap.
              IgnorePointer(
                child: Checkbox(value: task.done, onChanged: (_) => onTap()),
              ),
              Expanded(
                child: Text(
                  task.title,
                  style: TextStyle(
                    fontSize: 15,
                    color: task.done
                        ? AppColors.textSecondary
                        : AppColors.textPrimary,
                    decoration: task.done ? TextDecoration.lineThrough : null,
                    decorationColor: AppColors.textSecondary,
                  ),
                ),
              ),
            ],
          ),
          indicator: ReorderOrSelectIndicator(
            index: index,
            selectionMode: selectionMode,
            selected: selected,
          ),
        ),
      ),
    );
  }
}
