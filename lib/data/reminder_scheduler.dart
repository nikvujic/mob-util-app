import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:the_app/models/notify_settings.dart';
import 'package:timezone/timezone.dart' as tz;

/// What a reminder is about: each kind has its own Android channel, so
/// they can be set apart in the phone's settings.
enum ReminderKind { planner, medicine, backup, notice, dates }

/// A reminder (P10, O13): a notification at [at].
class Reminder {
  final DateTime at;
  final String title;
  final String body;
  final ReminderKind kind;

  /// Where tapping it leads (Round 19), as [NotificationTarget.payload].
  final String? target;

  /// Its tint (Round 31), or null: the phone's own.
  final Color? colour;

  /// Its sound (Round 31), and how loud (Round 41).
  final NotifySound sound;
  final NotifyVolume volume;

  const Reminder({
    required this.at,
    required this.title,
    required this.body,
    this.kind = ReminderKind.planner,
    this.target,
    this.colour,
    this.sound = NotifySound.phone,
    this.volume = NotifyVolume.loud,
  });

  /// As its page's settings say (Round 31).
  Reminder styled({
    Color? colour,
    NotifySound sound = NotifySound.phone,
    NotifyVolume volume = NotifyVolume.loud,
  }) =>
      Reminder(
        at: at,
        title: title,
        body: body,
        kind: kind,
        target: target,
        colour: colour,
        sound: sound,
        volume: volume,
      );

  @override
  String toString() => 'Reminder($at, $title, $body, ${kind.name})';
}

/// Shows reminders as notifications at their time.
abstract class ReminderScheduler {
  /// Asks for permission to show notifications if needed (Android 13+).
  /// Whether they're allowed.
  Future<bool> requestPermission();

  /// Whether the phone lets the app show notifications at all.
  Future<bool> areAllowed();

  /// Replaces every scheduled reminder with [reminders].
  Future<void> replaceAll(List<Reminder> reminders);

  /// The [Reminder.target] of each notification tapped while the app runs.
  Stream<String> get opened;

  /// The [Reminder.target] of the notification that started the app, if
  /// one did; only once.
  Future<String?> takeLaunch();
}

/// [ReminderScheduler] with Android notifications at exact times, kept
/// across restarts of the phone (flutter_local_notifications).
class NotificationReminderScheduler implements ReminderScheduler {
  static const _channels = {
    ReminderKind.planner: AndroidNotificationDetails(
      'planner-reminders',
      'Planner reminders',
      channelDescription: 'Before planner blocks start',
      importance: Importance.high,
      priority: Priority.high,
      category: AndroidNotificationCategory.reminder,
    ),
    ReminderKind.medicine: AndroidNotificationDetails(
      'medicine-reminders',
      'Medicine reminders',
      channelDescription: 'When a dose is due, and again if not taken',
      importance: Importance.high,
      priority: Priority.high,
      category: AndroidNotificationCategory.reminder,
    ),
    ReminderKind.backup: AndroidNotificationDetails(
      'backup-reminders',
      'Backup reminders',
      channelDescription: 'When a week has gone by without a backup',
      category: AndroidNotificationCategory.reminder,
    ),
    ReminderKind.notice: AndroidNotificationDetails(
      'app-notices',
      'From the app',
      channelDescription: 'When the app needs opening to keep reminders',
      category: AndroidNotificationCategory.reminder,
    ),
  };

  /// Its kind's channel, with its tint and sound (Round 31). Android fixes
  /// a channel's sound when it's made, so each sound is a channel of its
  /// own: the kind's as before for the phone's sound, `…-coin` etc.
  @visibleForTesting
  static AndroidNotificationDetails detailsFor(Reminder reminder) {
    final channel = _channels[reminder.kind]!;
    final sound = reminder.sound;
    // Round 41: a quieter copy of the sound for a quieter volume, each its
    // own channel too (`…-coin-quiet`).
    final volume = sound.resource == null ? NotifyVolume.loud : reminder.volume;
    final resource = volume.resourceOf(sound);
    final quieter = volume == NotifyVolume.loud ? '' : '-${volume.name}';
    final quieterName =
        volume == NotifyVolume.loud ? '' : ', ${volume.label.toLowerCase()}';
    if (reminder.colour == null && sound == NotifySound.phone) return channel;
    return AndroidNotificationDetails(
      sound == NotifySound.phone
          ? channel.channelId
          : '${channel.channelId}-${sound.name}$quieter',
      sound == NotifySound.phone
          ? channel.channelName
          : '${channel.channelName} (${sound.label.toLowerCase()}$quieterName)',
      channelDescription: channel.channelDescription,
      importance: channel.importance,
      priority: channel.priority,
      category: channel.category,
      color: reminder.colour,
      playSound: sound != NotifySound.silent,
      sound: resource == null
          ? null
          : RawResourceAndroidNotificationSound(resource),
    );
  }

  final _plugin = FlutterLocalNotificationsPlugin();
  Future<bool>? _ready;
  final _opened = StreamController<String>.broadcast();
  bool _launchTaken = false;

  @override
  Stream<String> get opened {
    _init(); // so taps are heard
    return _opened.stream;
  }

  @override
  Future<String?> takeLaunch() async {
    if (_launchTaken || !await _init()) return null;
    _launchTaken = true;
    try {
      final details = await _plugin.getNotificationAppLaunchDetails();
      if (details?.didNotificationLaunchApp != true) return null;
      return details!.notificationResponse?.payload;
    } on PlatformException {
      return null;
    }
  }

  /// Sets the plugin up once; false where it can't run (e.g. tests).
  Future<bool> _init() => _ready ??= () async {
        try {
          await _plugin.initialize(
            const InitializationSettings(
              android:
                  AndroidInitializationSettings('@drawable/ic_notification'),
            ),
            // Tapped while the app runs (or is in the background).
            onDidReceiveNotificationResponse: (response) {
              final payload = response.payload;
              if (payload != null) _opened.add(payload);
            },
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
  Future<bool> areAllowed() async {
    if (!await _init()) return true;
    try {
      return await _android?.areNotificationsEnabled() ?? true;
    } on PlatformException {
      return true;
    }
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
          NotificationDetails(android: detailsFor(reminder)),
          androidScheduleMode: exact
              ? AndroidScheduleMode.exactAllowWhileIdle
              : AndroidScheduleMode.inexactAllowWhileIdle,
          payload: reminder.target,
        );
      }
    } on PlatformException {
      // Not allowed (e.g. notifications off): nothing to show anyway.
    }
  }
}

final reminderSchedulerProvider =
    Provider<ReminderScheduler>((ref) => NotificationReminderScheduler());
