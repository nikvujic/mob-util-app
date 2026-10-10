import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:the_app/core/id.dart';
import 'package:the_app/data/app_storage.dart';
import 'package:the_app/models/planner_task.dart';
import 'package:the_app/providers/routines_provider.dart';

/// Thrown when a task would overlap another one on its day.
class TaskOverlapException implements Exception {
  const TaskOverlapException();
}

/// Planner tasks (P2, P7): blocks of time on days. Every change is saved to
/// [AppStorage].
///
/// Tasks never overlap each other, nor the routines shown on their day
/// ([busy], P8).
class PlannerNotifier extends StateNotifier<List<PlannerTask>> {
  /// Times taken on a day besides its tasks (its routines), given the
  /// day's tasks (which a routine gives way to).
  final List<TimeSpan> Function(DateTime day, List<PlannerTask> dayTasks) _busy;

  PlannerNotifier(
    AppStorage storage, {
    List<TimeSpan> Function(DateTime day, List<PlannerTask> dayTasks)? busy,
  })  : _busy = busy ?? ((_, __) => const []),
        super(storage.initialPlannerTasks) {
    addListener(storage.savePlannerTasks, fireImmediately: false);
  }

  List<PlannerTask> _on(DateTime day) =>
      state.where((t) => isSameDay(t.day, day)).toList();

  /// The free time on [day] with [tasks] there, around its routines too.
  /// [dayTasks] are all the day's tasks, which routines give way to.
  List<FreeSlot> _free(
    DateTime day,
    Iterable<PlannerTask> tasks,
    List<PlannerTask> dayTasks,
  ) =>
      freeSlotsAround([
        for (final t in tasks)
          if (t.hasTime) (start: t.start!, end: t.end!),
        ..._busy(day, dayTasks),
      ]);

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
    final dayTasks = _on(day);
    final free = _free(day, dayTasks, dayTasks);
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
      color: task.color,
    );
    final dayTasks = _on(task.day);
    final others = dayTasks.where((t) => t.id != id);
    // Routines this task keeps away stay away while it's edited.
    final free = _free(task.day, others, dayTasks);
    if (!free.any((s) => s.start <= start && end <= s.end)) {
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
    final dayTasks = _on(task.day);
    final others = dayTasks.where((t) => t.id != task.id);
    return _free(task.day, others, dayTasks).firstWhere(
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
  (ref) => PlannerNotifier(
    ref.watch(appStorageProvider),
    busy: (day, dayTasks) => [
      for (final o in routinesOn(day, ref.read(routinesProvider), dayTasks))
        (start: o.routine.start, end: o.routine.end),
    ],
  ),
);
