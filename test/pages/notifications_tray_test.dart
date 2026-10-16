import 'package:flutter_test/flutter_test.dart';
import 'package:the_app/data/reminder_scheduler.dart';

import '../helpers.dart';

/// Round 61: shown notifications stay in the tray until their page is
/// opened (not just the app).
void main() {
  testWidgets(
      'the app opened: only "open the app" ones go; each page takes its '
      'own', (tester) async {
    final scheduler = FakeReminderScheduler();
    await pumpApp(tester, reminders: scheduler);
    await tester.pumpAndSettle();
    expect(scheduler.cleared, [ReminderKind.notice]);

    await openTab(tester, 'Shop');
    expect(scheduler.cleared, [ReminderKind.notice]);
    await openTab(tester, 'Planner');
    expect(scheduler.cleared.last, ReminderKind.planner);

    await openTab(tester, 'Hub');
    await tester.tap(find.byTooltip('Medicine'));
    await tester.pumpAndSettle();
    expect(scheduler.cleared.last, ReminderKind.medicine);
    await pressBack(tester);
    await tester.tap(find.byTooltip('Dates'));
    await tester.pumpAndSettle();
    expect(scheduler.cleared.last, ReminderKind.dates);
    await pressBack(tester);

    await openMenu(tester);
    await tester.tap(find.text('Backup'));
    await tester.pumpAndSettle();
    expect(scheduler.cleared.last, ReminderKind.backup);
    expect(scheduler.cleared.toSet(), ReminderKind.values.toSet());
  });
}
