import 'dart:math' as math;

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
  /// A description as kept: trimmed, null if blank (P20).
  static String? _described(String? text) {
    final trimmed = text?.trim() ?? '';
    return trimmed.isEmpty ? null : trimmed;
  }

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
    int? remind,
    String? description,
  }) {
    final trimmed = title.trim();
    if (trimmed.isEmpty) return null;
    PlannerTask.checkLength(start, end);
    final routine = Routine(
      id: generateId(),
      title: trimmed,
      start: start,
      end: end,
      weekdays: weekdays,
      from: from,
      until: until,
      color: color,
      remind: remind,
      description: _described(description),
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
    int? remind,
    String? description,
  }) {
    final old = _find(id);
    if (start != old.start || end != old.end) {
      PlannerTask.checkLength(start, end);
    }
    final trimmed = title.trim();
    final routine = old.copyWith(
      title: trimmed.isEmpty ? old.title : trimmed,
      start: start,
      end: end,
      weekdays: weekdays,
      until: () => until,
      color: () => color,
      remind: () => remind,
      description: () => _described(description),
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

  /// Puts back [routine] with its [days] (restoring part of a backup,
  /// Round 28). Nothing happens if it's already there. Throws
  /// [TaskOverlapException] if it would overlap another routine.
  void restore(Routine routine, Iterable<RoutineDay> days) {
    if (state.routines.any((r) => r.id == routine.id)) return;
    _checkFree(routine);
    state = RoutineBook(
      routines: [...state.routines, routine],
      days: {
        ...state.days,
        for (final d in days) RoutineDay.keyFor(d.routineId, d.day): d,
      },
    );
  }

  /// Replaces everything (restoring a backup, resetting).
  void replaceAll(RoutineBook book) => state = book;

  /// The time [routine] could take on all its weekdays: the free time
  /// around it, up to the nearest other routine on any of them.
  FreeSlot roomFor(Routine routine) => roomAround(
        weekdays: routine.weekdays,
        from: routine.from,
        until: routine.until,
        start: routine.start,
        end: routine.end,
        except: routine.id,
      );

  /// The time a routine on [weekdays], [from] [until], could take around
  /// [start]–[end]: the stretch free of every other routine (but
  /// [except]) it could share a day with, skipped days and ones starting
  /// later included. If [start]–[end] isn't all free, the stretch with the
  /// most of it (or the next one), so the times can be fitted into it.
  FreeSlot roomAround({
    required Set<int> weekdays,
    required DateTime from,
    DateTime? until,
    required int start,
    required int end,
    String? except,
  }) {
    final probe = Routine(
      id: except ?? '',
      title: '',
      start: start,
      end: end,
      weekdays: weekdays,
      from: from,
      until: until,
    );
    final free = freeSlotsAround([
      for (final r in state.routines)
        if (r.id != except && r.sharesDaysWith(probe))
          (start: r.start, end: r.end),
    ]).where((s) => s.end - s.start >= PlannerTask.minMinutes).toList();
    FreeSlot? best;
    var most = 0;
    for (final slot in free) {
      final int shared = math.min(slot.end, end) - math.max(slot.start, start);
      if (shared > most) {
        best = slot;
        most = shared;
      }
    }
    return best ??
        free.firstWhere(
          (s) => s.start >= start,
          orElse: () => free.isEmpty
              ? (start: start, end: end) // nothing free: as it was
              : free.last,
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

  const RoutineOccurrence(this.routine, this.day);
}

/// The routines shown on [day]: those that fall on it and aren't skipped
/// there. One-off tasks don't push them away: a one-off and a routine may
/// share time, side by side (P12).
List<RoutineOccurrence> routinesOn(DateTime day, RoutineBook book) => [
      for (final r in book.routines)
        if (r.occursOn(day) && !(book.dayOf(r.id, day)?.skipped ?? false))
          RoutineOccurrence(r, day),
    ]..sort((a, b) => a.routine.start.compareTo(b.routine.start));
