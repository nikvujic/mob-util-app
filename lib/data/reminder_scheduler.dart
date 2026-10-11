import 'package:flutter/services.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:timezone/timezone.dart' as tz;

/// A planner reminder (P10): a notification at [at].
class Reminder {
  final DateTime at;
  final String title;
  final String body;

  const Reminder({required this.at, required this.title, required this.body});

  @override
  String toString() => 'Reminder($at, $title, $body)';
}

/// Shows reminders as notifications at their time.
abstract class ReminderScheduler {
  /// Asks for permission to show notifications if needed (Android 13+).
  /// Whether they're allowed.
  Future<bool> requestPermission();

  /// Replaces every scheduled reminder with [reminders].
  Future<void> replaceAll(List<Reminder> reminders);
}

/// [ReminderScheduler] with Android notifications at exact times, kept
/// across restarts of the phone (flutter_local_notifications).
class NotificationReminderScheduler implements ReminderScheduler {
  static const _channel = AndroidNotificationDetails(
    'planner-reminders',
    'Planner reminders',
    channelDescription: 'Before planner blocks start',
    importance: Importance.high,
    priority: Priority.high,
    category: AndroidNotificationCategory.reminder,
  );

  final _plugin = FlutterLocalNotificationsPlugin();
  Future<bool>? _ready;

  /// Sets the plugin up once; false where it can't run (e.g. tests).
  Future<bool> _init() => _ready ??= () async {
        try {
          await _plugin.initialize(
            const InitializationSettings(
              android: AndroidInitializationSettings('@mipmap/ic_launcher'),
            ),
          );
          return true;
        } on MissingPluginException {
          return false;
        } on PlatformException {
          return false;
        }
      }();

  AndroidFlutterLocalNotificationsPlugin? get _android =>
      _plugin.resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin>();

  @override
  Future<bool> requestPermission() async {
    if (!await _init()) return false;
    return await _android?.requestNotificationsPermission() ?? false;
  }

  @override
  Future<void> replaceAll(List<Reminder> reminders) async {
    if (!await _init()) return;
    try {
      await _plugin.cancelAll();
      // Exact if Android allows it, else as close as it does.
      final exact = await _android?.canScheduleExactNotifications() ?? false;
      for (final (id, reminder) in reminders.indexed) {
        await _plugin.zonedSchedule(
          id,
          reminder.title,
          reminder.body,
          // An absolute moment: planned again on every app start, so a
          // change of time zone or daylight saving is picked up.
          tz.TZDateTime.from(reminder.at.toUtc(), tz.UTC),
          const NotificationDetails(android: _channel),
          androidScheduleMode: exact
              ? AndroidScheduleMode.exactAllowWhileIdle
              : AndroidScheduleMode.inexactAllowWhileIdle,
        );
      }
    } on PlatformException {
      // Not allowed (e.g. notifications off): nothing to show anyway.
    }
  }
}

final reminderSchedulerProvider =
    Provider<ReminderScheduler>((ref) => NotificationReminderScheduler());
