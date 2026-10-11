import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:the_app/core/clock.dart';
import 'package:the_app/core/format.dart';
import 'package:the_app/data/reminder_scheduler.dart';
import 'package:the_app/models/app_section.dart';
import 'package:the_app/models/planner_task.dart';
import 'package:the_app/models/routine.dart';
import 'package:the_app/providers/planner_provider.dart';
import 'package:the_app/providers/routines_provider.dart';
import 'package:the_app/providers/section_locks_provider.dart';
import 'package:the_app/providers/security_provider.dart';

/// How far ahead reminders are planned (P10); planned again on every
/// change and app start, so routines keep reminding.
const reminderDays = 14;

/// At most this many are scheduled (Android allows about 500 alarms).
const maxReminders = 400;

/// The reminders due after [now] for the next [reminderDays] days: tasks
/// and routines with a reminder, not ticked off (nor skipped). With
/// [hideTitles] (the Planner section is locked), titles are left out.
List<Reminder> planReminders({
  required DateTime now,
  required List<PlannerTask> tasks,
  required RoutineBook routines,
  bool hideTitles = false,
}) {
  final reminders = <Reminder>[];
  final today = dayOf(now);

  void add(DateTime day, String title, int start, int end, int remind) {
    // Minutes beyond 0–59 roll over, also into the day before.
    final at = DateTime(day.year, day.month, day.day, 0, start - remind);
    if (!at.isAfter(now)) return;
    final time = '${formatMinutes(start)}–${formatMinutes(end)}';
    final when = remind == 0
        ? 'Now'
        : remind < 60
            ? 'In $remind min'
            : 'In ${remind ~/ 60} h${remind % 60 == 0 ? '' : ' ${remind % 60} min'}';
    reminders.add(
      hideTitles
          ? Reminder(
              at: at,
              title: 'Planner',
              body: 'A block starts at ${formatMinutes(start)}',
            )
          : Reminder(at: at, title: title, body: '$when · $time'),
    );
  }

  for (var i = 0; i <= reminderDays; i++) {
    final day = addDays(today, i);
    final dayTasks = [
      for (final t in tasks)
        if (isSameDay(t.day, day)) t,
    ];
    for (final t in dayTasks) {
      if (t.hasTime && !t.done && t.remind != null) {
        add(day, t.title, t.start!, t.end!, t.remind!);
      }
    }
    for (final o in routinesOn(day, routines, dayTasks)) {
      final r = o.routine;
      if (!o.done && r.remind != null) {
        add(day, r.title, r.start, r.end, r.remind!);
      }
    }
  }
  reminders.sort((a, b) => a.at.compareTo(b.at));
  return reminders.take(maxReminders).toList();
}

/// Keeps the phone's scheduled reminders in step with the planner (P10):
/// plans them again whenever tasks, routines or the Planner's lock change,
/// and on [refresh] (e.g. when the app comes back).
class ReminderPlanner {
  final Ref _ref;
  bool _pending = false;
  bool _disposed = false;

  ReminderPlanner(this._ref) {
    _ref.onDispose(() => _disposed = true);
    _ref.listen(plannerProvider, (_, __) => _soon());
    _ref.listen(routinesProvider, (_, __) => _soon());
    _ref.listen(sectionLocksProvider, (_, __) => _soon());
    _ref.listen(securityProvider, (_, __) => _soon());
    _soon();
  }

  /// Several changes in a row (one action) are planned once.
  void _soon() {
    if (_pending) return;
    _pending = true;
    scheduleMicrotask(refresh);
  }

  /// Asks to show notifications (when a reminder is set). Whether they're
  /// allowed.
  Future<bool> requestPermission() =>
      _ref.read(reminderSchedulerProvider).requestPermission();

  /// Plans and schedules the reminders now.
  Future<void> refresh() async {
    _pending = false;
    if (_disposed) return;
    final hide = _ref.read(sectionLocksProvider).contains(AppSection.planner) &&
        _ref.read(securityProvider) != null;
    await _ref.read(reminderSchedulerProvider).replaceAll(
          planReminders(
            now: _ref.read(clockProvider)(),
            tasks: _ref.read(plannerProvider),
            routines: _ref.read(routinesProvider),
            hideTitles: hide,
          ),
        );
  }
}

final reminderPlannerProvider = Provider<ReminderPlanner>(ReminderPlanner.new);
