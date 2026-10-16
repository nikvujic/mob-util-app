import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:the_app/core/clock.dart';
import 'package:the_app/core/format.dart';
import 'package:the_app/core/theme.dart';
import 'package:the_app/data/reminder_scheduler.dart';
import 'package:the_app/models/app_section.dart';
import 'package:the_app/models/hub_tool.dart';
import 'package:the_app/models/notification_target.dart';
import 'package:the_app/models/notify_settings.dart';
import 'package:the_app/models/planner_pin.dart';
import 'package:the_app/models/planner_task.dart';
import 'package:the_app/models/preferences.dart';
import 'package:the_app/models/routine.dart';
import 'package:the_app/providers/backup_reminder_provider.dart';
import 'package:the_app/providers/dates_alerts_provider.dart';
import 'package:the_app/providers/dates_provider.dart';
import 'package:the_app/providers/medicine_alerts_provider.dart';
import 'package:the_app/providers/medicine_provider.dart';
import 'package:the_app/providers/notification_log_provider.dart';
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
    // Tapped: the planner on that day, at the block (Round 19).
    final target = PlannerTarget(day, start).payload;
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
              target: target,
            )
          : Reminder(
              at: at,
              title: title,
              body: '$when · $time',
              target: target,
            ),
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
    final target = PlannerTarget(pin.day, pin.time).payload;
    reminders.add(
      hideTitles
          ? Reminder(
              at: at,
              title: 'Planner',
              body: 'A reminder at $time',
              target: target,
            )
          : Reminder(
              at: at,
              title: pin.title,
              body: 'Reminder · $time',
              target: target,
            ),
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
    _ref.listen(pageLocksProvider, (_, __) => _soon());
    _ref.listen(securityProvider, (_, __) => _soon());
    _ref.listen(medicineProvider, (_, __) => _soon());
    _ref.listen(datesProvider, (_, __) => _soon());
    // Whether notifications are allowed, known for the history.
    _ref.listen(notificationsAllowedProvider, (_, __) {});
    _ref.listen(preferencesProvider, (before, after) {
      if (before == null ||
          before.medicineReminders != after.medicineReminders ||
          before.medicinePausedUntil != after.medicinePausedUntil ||
          before.plannerReminders != after.plannerReminders ||
          before.plannerPausedUntil != after.plannerPausedUntil ||
          before.datesReminders != after.datesReminders ||
          before.datesPausedUntil != after.datesPausedUntil ||
          !_sameStyles(before.notifyStyles, after.notifyStyles) ||
          before.backupDueAt != after.backupDueAt ||
          before.lastBackupAt != after.lastBackupAt) {
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

  static bool _sameStyles(
    Map<NotifyPage, NotifyStyle> a,
    Map<NotifyPage, NotifyStyle> b,
  ) =>
      NotifyPage.values.every((p) => a[p] == b[p]);

  Future<void> _plan() async {
    final locks = _ref.read(sectionLocksProvider);
    final password = _ref.read(securityProvider) != null;
    final now = _ref.read(clockProvider)();
    final preferences = _ref.read(preferencesProvider);
    bool private(NotifyPage page) => preferences.styleOf(page).private;
    final reminders = [
      ...planReminders(
        now: now,
        tasks: _ref.read(plannerProvider),
        routines: _ref.read(routinesProvider),
        pins: _ref.read(pinsProvider),
        // Locked, or set private (Round 31): no names.
        hideTitles: password && locks.contains(AppSection.planner) ||
            private(NotifyPage.planner),
      ),
      ...planMedicineReminders(
        now: now,
        book: _ref.read(medicineProvider),
        preferences: preferences,
        days: reminderDays,
        hideNames: password &&
                (locks.contains(AppSection.hub) ||
                    _ref.read(pageLocksProvider).contains(HubTool.medicine)) ||
            private(NotifyPage.medicine),
      ),
      ...planDateReminders(
        now: now,
        book: _ref.read(datesProvider),
        preferences: preferences,
        days: reminderDays,
        hideNames: password &&
                (locks.contains(AppSection.hub) ||
                    _ref.read(pageLocksProvider).contains(HubTool.dates)) ||
            private(NotifyPage.dates),
      ),
      ...planBackupReminders(
        now: now,
        preferences: preferences,
        days: reminderDays,
      ),
    ]..sort((a, b) => a.at.compareTo(b.at));
    final scheduled =
        withKeepGoing(withNotifySettings(reminders, preferences), now: now);
    // Kept for the history (Round 31); nothing shows if not allowed (as
    // last looked at: asking here would hold planning up).
    if (_ref.read(notificationsAllowedProvider).valueOrNull ?? true) {
      _ref.read(notificationLogProvider.notifier).planned(scheduled, now);
    }
    await _ref.read(reminderSchedulerProvider).replaceAll(scheduled);
  }
}

/// Takes [page]'s shown notifications out of the phone's tray (Round 61:
/// once it's opened, not when the app is); null: the app's own notices.
final clearShownProvider = Provider<Future<void> Function(NotifyPage?)>(
  (ref) => (page) => ref.read(reminderSchedulerProvider).clearShown(
        switch (page) {
          null => ReminderKind.notice,
          NotifyPage.planner => ReminderKind.planner,
          NotifyPage.medicine => ReminderKind.medicine,
          NotifyPage.backup => ReminderKind.backup,
          NotifyPage.dates => ReminderKind.dates,
        },
      ),
);

/// The page a kind of reminder comes from (none for the app's own).
NotifyPage? pageOf(ReminderKind kind) => switch (kind) {
      ReminderKind.planner => NotifyPage.planner,
      ReminderKind.medicine => NotifyPage.medicine,
      ReminderKind.backup => NotifyPage.backup,
      ReminderKind.dates => NotifyPage.dates,
      ReminderKind.notice => null,
    };

/// [reminders] as each page's settings say (Round 31): none from the
/// planner while it's off or paused that day (Medicine and Backup leave
/// theirs out when planning), each with its page's tint and sound.
List<Reminder> withNotifySettings(
  List<Reminder> reminders,
  Preferences preferences,
) {
  final kept = <Reminder>[];
  for (final r in reminders) {
    final page = pageOf(r.kind);
    if (page == null) {
      kept.add(r);
      continue;
    }
    if (page == NotifyPage.planner &&
        (!preferences.plannerReminders || preferences.plannerPausedOn(r.at))) {
      continue;
    }
    final style = preferences.styleOf(page);
    kept.add(r.styled(
      colour: BlockColor.fromName(style.colour)?.stripe,
      sound: style.sound,
      volume: style.volume,
    ));
  }
  return kept;
}

/// [reminders] (sorted) as many as can be scheduled, and when they'd run
/// on past what is (they're planned [reminderDays] ahead, or cut at
/// [maxReminders]), a notice the evening before the last one to open the
/// app, which plans them again (E1, Round 23). Without it, an app left
/// unopened for two weeks would go quiet with nothing said.
List<Reminder> withKeepGoing(List<Reminder> reminders,
    {required DateTime now}) {
  final kept = reminders.take(maxReminders - 1).toList();
  if (kept.isEmpty) return kept;
  final cut = kept.length < reminders.length;
  final nearEnd = now.add(const Duration(days: reminderDays - 2));
  if (!cut && !kept.last.at.isAfter(nearEnd)) return kept;
  final last = kept.last.at;
  final at = DateTime(last.year, last.month, last.day - 1, 19);
  if (!at.isAfter(now)) return kept;
  return [
    ...kept,
    Reminder(
      at: at,
      kind: ReminderKind.notice,
      title: 'Open The App',
      body: 'Reminders are planned two weeks ahead. Open the app to keep '
          'them coming.',
    ),
  ]..sort((a, b) => a.at.compareTo(b.at));
}

final reminderPlannerProvider = Provider<ReminderPlanner>(ReminderPlanner.new);

/// Whether notifications are allowed (E1): Settings says so when they
/// aren't. Looked at again when the app comes back (they may have been
/// turned on in the phone's settings meanwhile).
final notificationsAllowedProvider = FutureProvider<bool>(
  (ref) => ref.watch(reminderSchedulerProvider).areAllowed(),
);
