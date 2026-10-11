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
///
/// Tasks never overlap each other. Routines don't get in their way: a task
/// and a routine may share time, side by side (P12).
class PlannerNotifier extends StateNotifier<List<PlannerTask>> {
  PlannerNotifier(AppStorage storage) : super(storage.initialPlannerTasks) {
    addListener(storage.savePlannerTasks, fireImmediately: false);
  }

  List<PlannerTask> _on(DateTime day) =>
      state.where((t) => isSameDay(t.day, day)).toList();

  /// The time free of [tasks].
  static List<FreeSlot> _free(Iterable<PlannerTask> tasks) => freeSlotsAround([
        for (final t in tasks)
          if (t.hasTime) (start: t.start!, end: t.end!),
      ]);

  /// Adds a task on [day] from [start] to [end] (minutes from midnight).
  /// Blank titles are ignored. Throws [TaskOverlapException] if the time
  /// isn't free: tasks never overlap.
  void addTask(
    DateTime day,
    String title, {
    required int start,
    required int end,
    String? color,
    int? remind,
  }) {
    final trimmed = title.trim();
    if (trimmed.isEmpty) return;
    final task = PlannerTask(
      id: generateId(),
      title: trimmed,
      day: day,
      start: start,
      end: end,
      color: color,
      remind: remind,
    );
    final free = _free(_on(day));
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
    String? color,
    int? remind,
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
      color: color,
      remind: remind,
    );
    final free = _free(_on(task.day).where((t) => t.id != id));
    if (!free.any((s) => s.start <= start && end <= s.end)) {
      throw const TaskOverlapException();
    }
    state = [
      for (final t in state)
        if (t.id == id) updated else t,
    ];
  }

  /// The time [task] could take: up to the tasks around it (its own time
  /// included); routines don't count (P12).
  FreeSlot roomFor(PlannerTask task) =>
      _free(_on(task.day).where((t) => t.id != task.id)).firstWhere(
        (s) => s.start <= task.start! && task.end! <= s.end,
      );

  /// The stretches of [day] free of tasks (routines don't count, P12).
  List<FreeSlot> freeOn(DateTime day) => _free(_on(day));

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
