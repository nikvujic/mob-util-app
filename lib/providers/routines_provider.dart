import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:the_app/core/id.dart';
import 'package:the_app/data/app_storage.dart';
import 'package:the_app/models/planner_task.dart';
import 'package:the_app/models/routine.dart';
import 'package:the_app/providers/planner_provider.dart';

/// Planner routines (P8): blocks that repeat on weekdays, and what happened
/// to them on particular days (ticked off, skipped). Saved to
/// `routines.json` on every change.
///
/// Routines never overlap each other on a day they could share.
class RoutinesNotifier extends StateNotifier<RoutineBook> {
  RoutinesNotifier(AppStorage storage) : super(storage.initialRoutines) {
    addListener(storage.saveRoutines, fireImmediately: false);
  }

  Routine _find(String id) => state.routines.firstWhere((r) => r.id == id);

  void _checkFree(Routine candidate) {
    for (final other in state.routines) {
      if (other.id != candidate.id &&
          other.sharesDaysWith(candidate) &&
          other.overlapsInTime(candidate)) {
        throw const TaskOverlapException();
      }
    }
  }

  /// Adds a routine and returns its id; null for a blank title. Throws
  /// [TaskOverlapException] if it would overlap another routine.
  String? add({
    required String title,
    required int start,
    required int end,
    required Set<int> weekdays,
    required DateTime from,
    DateTime? until,
    String? color,
  }) {
    final trimmed = title.trim();
    if (trimmed.isEmpty) return null;
    final routine = Routine(
      id: generateId(),
      title: trimmed,
      start: start,
      end: end,
      weekdays: weekdays,
      from: from,
      until: until,
      color: color,
    );
    _checkFree(routine);
    state = RoutineBook(
      routines: [...state.routines, routine],
      days: state.days,
    );
    return routine.id;
  }

  /// Changes a routine everywhere it's on, past days too (P8); ticks and
  /// skips stay with their days. A blank title keeps the old one. Throws
  /// [TaskOverlapException] if it would overlap another routine.
  void update(
    String id, {
    required String title,
    required int start,
    required int end,
    required Set<int> weekdays,
    required DateTime? until,
    String? color,
  }) {
    final old = _find(id);
    final trimmed = title.trim();
    final routine = old.copyWith(
      title: trimmed.isEmpty ? old.title : trimmed,
      start: start,
      end: end,
      weekdays: weekdays,
      until: () => until,
      color: () => color,
    );
    _checkFree(routine);
    state = RoutineBook(
      routines: [
        for (final r in state.routines)
          if (r.id == id) routine else r,
      ],
      days: state.days,
    );
  }

  /// Deletes a routine from every day, with its ticks and skips.
  void remove(String id) {
    state = RoutineBook(
      routines: state.routines.where((r) => r.id != id).toList(),
      days: {
        for (final e in state.days.entries)
          if (e.value.routineId != id) e.key: e.value,
      },
    );
  }

  void _setDay(String id, DateTime day, RoutineDay Function(RoutineDay) f) {
    final key = RoutineDay.keyFor(id, day);
    final next = f(state.days[key] ?? RoutineDay(routineId: id, day: day));
    state = RoutineBook(
      routines: state.routines,
      days: {
        for (final e in state.days.entries)
          if (e.key != key) e.key: e.value,
        if (!next.isEmpty) key: next,
      },
    );
  }

  /// Ticks a routine off (or back) for [day] only.
  void toggleDone(String id, DateTime day) => _setDay(
        id,
        day,
        (d) => RoutineDay(
          routineId: id,
          day: day,
          done: !d.done,
          skipped: d.skipped,
        ),
      );

  /// Leaves a routine out on [day] only (or puts it back).
  void setSkipped(String id, DateTime day, {required bool skipped}) => _setDay(
        id,
        day,
        (d) => RoutineDay(
          routineId: id,
          day: day,
          done: d.done,
          skipped: skipped,
        ),
      );

  /// Replaces everything (restoring a backup, resetting).
  void replaceAll(RoutineBook book) => state = book;

  /// The time [routine] could take on all its weekdays: the free time
  /// around it, up to the nearest other routine on any of them.
  FreeSlot roomFor(Routine routine) {
    final others = [
      for (final r in state.routines)
        if (r.id != routine.id && r.sharesDaysWith(routine))
          (start: r.start, end: r.end),
    ];
    return freeSlotsAround(others).firstWhere(
      (s) => s.start <= routine.start && routine.end <= s.end,
    );
  }
}

final routinesProvider = StateNotifierProvider<RoutinesNotifier, RoutineBook>(
  (ref) => RoutinesNotifier(ref.watch(appStorageProvider)),
);

/// A routine on one day (P8).
class RoutineOccurrence {
  final Routine routine;
  final DateTime day;
  final bool done;

  const RoutineOccurrence(this.routine, this.day, {this.done = false});
}

/// The routines shown on [day]: those that fall on it and aren't skipped
/// there. Where a one-off task in [dayTasks] already is, the one-off wins
/// and the routine stays away that day (P8).
List<RoutineOccurrence> routinesOn(
  DateTime day,
  RoutineBook book,
  Iterable<PlannerTask> dayTasks,
) {
  final tasks = [
    for (final t in dayTasks)
      if (t.hasTime) t,
  ];
  return [
    for (final r in book.routines)
      if (r.occursOn(day) &&
          !(book.dayOf(r.id, day)?.skipped ?? false) &&
          !tasks.any((t) => t.start! < r.end && r.start < t.end!))
        RoutineOccurrence(
          r,
          day,
          done: book.dayOf(r.id, day)?.done ?? false,
        ),
  ]..sort((a, b) => a.routine.start.compareTo(b.routine.start));
}
