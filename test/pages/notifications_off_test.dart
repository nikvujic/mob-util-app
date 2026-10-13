import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../helpers.dart';

/// Settings says so when the phone blocks the app's notifications (E1,
/// Round 23), and tapping it asks to allow them.
void main() {
  final warning = find.byKey(const Key('notificationsOff'));

  Future<FakeReminderScheduler> openSettings(
    WidgetTester tester, {
    required bool allowed,
  }) async {
    final scheduler = FakeReminderScheduler()..allowed = allowed;
    await pumpApp(tester, reminders: scheduler);
    await openMenu(tester);
    await tester.tap(find.text('Settings'));
    await tester.pumpAndSettle();
    return scheduler;
  }

  testWidgets('allowed: nothing said', (tester) async {
    await openSettings(tester, allowed: true);
    expect(warning, findsNothing);
  });

  testWidgets('off: said at the top; tapping asks, and it goes once allowed',
      (tester) async {
    final scheduler = await openSettings(tester, allowed: false);
    expect(warning, findsOneWidget);
    expect(tester.getTopLeft(warning).dy,
        lessThan(tester.getTopLeft(find.text('Line numbers in notes')).dy));

    scheduler.allowed = true; // the user allows them in the dialog
    await tester.tap(warning);
    await tester.pumpAndSettle();
    expect(scheduler.asked, 1);
    expect(warning, findsNothing);
  });
}
