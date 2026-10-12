import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:the_app/core/clock.dart';
import 'package:the_app/core/format.dart';
import 'package:the_app/data/reminder_scheduler.dart';
import 'package:the_app/models/app_section.dart';
import 'package:the_app/models/planner_pin.dart';
import 'package:the_app/models/planner_task.dart';
import 'package:the_app/models/routine.dart';
import 'package:the_app/providers/medicine_alerts_provider.dart';
import 'package:the_app/providers/medicine_provider.dart';
import 'package:the_app/providers/pins_provider.dart';
import 'package:the_app/providers/planner_provider.dart';
import 'package:the_app/providers/preferences_provider.dart';
import 'package:the_app/providers/routines_provider.dart';
import 'package:the_app/providers/section_locks_provider.dart';
import 'package:the_app/providers/security_provider.dart';

/// How far ahead reminders are planned (P10); planned again on every
/// change and app start, so routines keep reminding.
const reminderDays = 14;

/// At most this many are scheduled (Android allows about 500 alarms).
const maxReminders = 400;

/// The reminders due after [now] for the next [reminderDays] days: tasks
/// and routines with a reminder, not ticked off (nor skipped), and the
/// planner's own reminders ([pins], P14) at their time. With [hideTitles]
/// (the Planner section is locked), titles are left out.
List<Reminder> planReminders({
  required DateTime now,
  required List<PlannerTask> tasks,
  required RoutineBook routines,
  List<PlannerPin> pins = const [],
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
    for (final t in tasks) {
      if (isSameDay(t.day, day) && t.hasTime && !t.done && t.remind != null) {
        add(day, t.title, t.start!, t.end!, t.remind!);
      }
    }
    for (final o in routinesOn(day, routines)) {
      final r = o.routine;
      if (!o.done && r.remind != null) {
        add(day, r.title, r.start, r.end, r.remind!);
      }
    }
  }
  final last = addDays(today, reminderDays + 1);
  for (final pin in pins) {
    final at = DateTime(pin.day.year, pin.day.month, pin.day.day, 0, pin.time);
    if (!at.isAfter(now) || !at.isBefore(last)) continue;
    final time = formatMinutes(pin.time);
    reminders.add(
      hideTitles
          ? Reminder(at: at, title: 'Planner', body: 'A reminder at $time')
          : Reminder(at: at, title: pin.title, body: 'Reminder · $time'),
    );
  }
  reminders.sort((a, b) => a.at.compareTo(b.at));
  return reminders.take(maxReminders).toList();
}

/// Keeps the phone's scheduled reminders in step with the planner (P10)
/// and the medicines (O13): plans them again whenever tasks, routines,
/// reminders, medicines, their settings or a lock change,
/// and on [refresh] (e.g. when the app comes back).
class ReminderPlanner {
  final Ref _ref;
  bool _pending = false;
  bool _disposed = false;

  ReminderPlanner(this._ref) {
    _ref.onDispose(() => _disposed = true);
    _ref.listen(plannerProvider, (_, __) => _soon());
    _ref.listen(routinesProvider, (_, __) => _soon());
    _ref.listen(pinsProvider, (_, __) => _soon());
    _ref.listen(sectionLocksProvider, (_, __) => _soon());
    _ref.listen(securityProvider, (_, __) => _soon());
    _ref.listen(medicineProvider, (_, __) => _soon());
    _ref.listen(preferencesProvider, (before, after) {
      if (before == null ||
          before.medicineReminders != after.medicineReminders ||
          before.medicineFollowUp != after.medicineFollowUp ||
          before.medicinePausedUntil != after.medicinePausedUntil) {
        _soon();
      }
    });
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

  /// The refresh running now, if any.
  Future<void>? _running;

  /// Something changed while [_running]: plan once more when it's done.
  bool _again = false;

  /// Plans and schedules the reminders now. One at a time: scheduling
  /// cancels everything and then adds reminders one by one, so two at once
  /// could leave the older one's reminders behind (e.g. for a deleted
  /// task). A refresh asked for meanwhile runs right after.
  Future<void> refresh() {
    _pending = false;
    if (_running != null) {
      _again = true;
      return _running!;
    }
    return _running = _refreshUntilDone();
  }

  Future<void> _refreshUntilDone() async {
    try {
      do {
        _again = false;
        if (_disposed) return;
        await _plan();
      } while (_again);
    } finally {
      _running = null;
    }
  }

  Future<void> _plan() async {
    final locks = _ref.read(sectionLocksProvider);
    final password = _ref.read(securityProvider) != null;
    final now = _ref.read(clockProvider)();
    final reminders = [
      ...planReminders(
        now: now,
        tasks: _ref.read(plannerProvider),
        routines: _ref.read(routinesProvider),
        pins: _ref.read(pinsProvider),
        hideTitles: password && locks.contains(AppSection.planner),
      ),
      ...planMedicineReminders(
        now: now,
        book: _ref.read(medicineProvider),
        preferences: _ref.read(preferencesProvider),
        days: reminderDays,
        hideNames: password && locks.contains(AppSection.hub),
      ),
    ]..sort((a, b) => a.at.compareTo(b.at));
    await _ref
        .read(reminderSchedulerProvider)
        .replaceAll(reminders.take(maxReminders).toList());
  }
}

final reminderPlannerProvider = Provider<ReminderPlanner>(ReminderPlanner.new);
