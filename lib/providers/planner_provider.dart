import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:the_app/core/id.dart';
import 'package:the_app/data/app_storage.dart';
import 'package:the_app/models/planner_task.dart';

/// Thrown when a task would overlap another one on its day.
class TaskOverlapException implements Exception {
  const TaskOverlapException();
}

/// Planner tasks (P2, P7): blocks of time on days. Every change is saved to
/// [AppStorage].
class PlannerNotifier extends StateNotifier<List<PlannerTask>> {
  PlannerNotifier(AppStorage storage) : super(storage.initialPlannerTasks) {
    addListener(storage.savePlannerTasks, fireImmediately: false);
  }

  /// Adds a task on [day] from [start] to [end] (minutes from midnight).
  /// Blank titles are ignored. Throws [TaskOverlapException] if the time
  /// isn't free: tasks never overlap.
  void addTask(
    DateTime day,
    String title, {
    required int start,
    required int end,
  }) {
    final trimmed = title.trim();
    if (trimmed.isEmpty) return;
    final task = PlannerTask(
      id: generateId(),
      title: trimmed,
      day: day,
      start: start,
      end: end,
    );
    final free = freeSlots(state.where((t) => isSameDay(t.day, day)));
    if (!free.any((s) => s.start <= start && end <= s.end)) {
      throw const TaskOverlapException();
    }
    state = [...state, task];
  }

  /// Changes a task's title and times. Blank titles keep the old one.
  /// Throws [TaskOverlapException] if the new time isn't free.
  void updateTask(
    String id, {
    required String title,
    required int start,
    required int end,
  }) {
    final task = state.firstWhere((t) => t.id == id);
    final trimmed = title.trim();
    final updated = PlannerTask(
      id: id,
      title: trimmed.isEmpty ? task.title : trimmed,
      day: task.day,
      start: start,
      end: end,
      done: task.done,
    );
    final others = state.where((t) => t.id != id && isSameDay(t.day, task.day));
    if (!freeSlots(others).any((s) => s.start <= start && end <= s.end)) {
      throw const TaskOverlapException();
    }
    state = [
      for (final t in state)
        if (t.id == id) updated else t,
    ];
  }

  /// The time [task] could take: the free time around it, up to its
  /// neighbours (its own time included).
  FreeSlot roomFor(PlannerTask task) {
    final others =
        state.where((t) => t.id != task.id && isSameDay(t.day, task.day));
    return freeSlots(others).firstWhere(
      (s) => s.start <= task.start! && task.end! <= s.end,
    );
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
}

bool isSameDay(DateTime a, DateTime b) =>
    a.year == b.year && a.month == b.month && a.day == b.day;

final plannerProvider =
    StateNotifierProvider<PlannerNotifier, List<PlannerTask>>(
  (ref) => PlannerNotifier(ref.watch(appStorageProvider)),
);
