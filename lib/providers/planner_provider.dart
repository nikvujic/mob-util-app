import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:the_app/core/id.dart';
import 'package:the_app/data/app_storage.dart';
import 'package:the_app/models/planner_task.dart';

/// Planner tasks (P2). A single ordered list; each day shows its tasks in
/// list order. Every change is saved to [AppStorage].
class PlannerNotifier extends StateNotifier<List<PlannerTask>> {
  PlannerNotifier(AppStorage storage) : super(storage.initialPlannerTasks) {
    addListener(storage.savePlannerTasks, fireImmediately: false);
  }

  /// Adds a task at the end of [day]. Blank titles are ignored.
  void addTask(DateTime day, String title) {
    final trimmed = title.trim();
    if (trimmed.isEmpty) return;
    state = [
      ...state,
      PlannerTask(id: generateId(), title: trimmed, day: day),
    ];
  }

  void toggleDone(String id) {
    state = [
      for (final t in state)
        if (t.id == id) t.copyWith(done: !t.done) else t,
    ];
  }

  void removeTasks(Set<String> ids) {
    state = state.where((t) => !ids.contains(t.id)).toList();
  }

  /// Replaces everything (used when restoring a backup).
  void replaceAll(List<PlannerTask> tasks) {
    state = List.unmodifiable(tasks);
  }

  /// Reorders the tasks of [day]. Indices are positions within that day
  /// and follow `ReorderableListView.onReorder` semantics; other days are
  /// left untouched.
  void reorder(DateTime day, int oldIndex, int newIndex) {
    if (newIndex > oldIndex) newIndex--;
    if (oldIndex == newIndex) return;
    bool onDay(PlannerTask t) => isSameDay(t.day, day);

    final tasks = state.where(onDay).toList();
    tasks.insert(newIndex, tasks.removeAt(oldIndex));
    final reordered = tasks.iterator;
    state = [
      for (final t in state)
        if (onDay(t)) (reordered..moveNext()).current else t,
    ];
  }
}

bool isSameDay(DateTime a, DateTime b) =>
    a.year == b.year && a.month == b.month && a.day == b.day;

final plannerProvider =
    StateNotifierProvider<PlannerNotifier, List<PlannerTask>>(
  (ref) => PlannerNotifier(ref.watch(appStorageProvider)),
);
