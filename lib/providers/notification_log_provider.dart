import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:the_app/data/app_storage.dart';
import 'package:the_app/data/reminder_scheduler.dart';
import 'package:the_app/models/notification_log.dart';

/// What the app scheduled, for the notifications' history (Round 31),
/// saved to `notifications.json`.
class NotificationLogNotifier extends StateNotifier<NotificationLog> {
  NotificationLogNotifier(AppStorage storage)
      : super(storage.initialNotificationLog) {
    addListener(storage.saveNotificationLog, fireImmediately: false);
  }

  /// [reminders] were just scheduled, at [now].
  void planned(List<Reminder> reminders, DateTime now) {
    state = state.planned([
      for (final r in reminders)
        LoggedNotification(
          at: r.at,
          title: r.title,
          body: r.body,
          kind: r.kind.name,
          target: r.target,
        ),
    ], now);
  }

  /// The history cleared, at [now].
  void clear(DateTime now) => state = state.clearedAtTime(now);
}

final notificationLogProvider =
    StateNotifierProvider<NotificationLogNotifier, NotificationLog>(
  (ref) => NotificationLogNotifier(ref.watch(appStorageProvider)),
);
