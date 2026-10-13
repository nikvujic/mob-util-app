import 'package:flutter/painting.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:the_app/data/reminder_scheduler.dart';

/// What each reminder is shown with on Android.
void main() {
  Reminder reminder(ReminderKind kind, {Color? colour}) => Reminder(
        at: DateTime(2026, 10, 13, 10),
        title: 'T',
        body: 'B',
        kind: kind,
        colour: colour,
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
}
