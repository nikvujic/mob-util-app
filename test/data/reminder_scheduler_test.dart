import 'package:flutter/painting.dart';
import 'package:flutter_test/flutter_test.dart';
import 'dart:io';

import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:the_app/data/reminder_scheduler.dart';
import 'package:the_app/models/notify_settings.dart';

/// What each reminder is shown with on Android.
void main() {
  Reminder reminder(
    ReminderKind kind, {
    Color? colour,
    NotifySound sound = NotifySound.phone,
  }) =>
      Reminder(
        at: DateTime(2026, 10, 13, 10),
        title: 'T',
        body: 'B',
        kind: kind,
        colour: colour,
        sound: sound,
      );

  test('its kind\'s channel, with its tint (Round 31)', () {
    final plain = NotificationReminderScheduler.detailsFor(
        reminder(ReminderKind.medicine));
    expect(plain.channelId, 'medicine-reminders');
    expect(plain.color, isNull);

    const green = Color(0xFF81C784);
    final tinted = NotificationReminderScheduler.detailsFor(
        reminder(ReminderKind.planner, colour: green));
    expect(tinted.channelId, 'planner-reminders');
    expect(tinted.color, green);
    expect(tinted.importance, plain.importance, reason: 'the rest as before');
  });

  test('each sound its own channel; silent plays none (Round 31)', () {
    final phone = NotificationReminderScheduler.detailsFor(
        reminder(ReminderKind.planner));
    expect(phone.channelId, 'planner-reminders', reason: 'as before');
    expect(phone.sound, isNull);

    final chime = NotificationReminderScheduler.detailsFor(
        reminder(ReminderKind.planner, sound: NotifySound.chime));
    expect(chime.channelId, 'planner-reminders-chime');
    expect(chime.channelName, 'Planner reminders (chime)');
    expect((chime.sound! as RawResourceAndroidNotificationSound).sound,
        'notify_chime');
    expect(chime.playSound, isTrue);

    final silent = NotificationReminderScheduler.detailsFor(
        reminder(ReminderKind.medicine, sound: NotifySound.silent));
    expect(silent.channelId, 'medicine-reminders-silent');
    expect(silent.playSound, isFalse);
  });

  test('every sound of the app\'s own is there, and can be heard', () {
    final activity = File(
      'android/app/src/main/kotlin/com/nikvujic/the_app/MainActivity.kt',
    ).readAsStringSync();
    for (final sound in NotifySound.values) {
      final resource = sound.resource;
      if (resource == null) continue;
      expect(File('android/app/src/main/res/raw/$resource.wav').existsSync(),
          isTrue,
          reason: resource);
      // Loaded by name (kept in release builds, and heard when picking).
      expect(activity, contains('R.raw.$resource'), reason: resource);
    }
  });
}
