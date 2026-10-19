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
    // Round 79.
    await tester.tap(find.byTooltip('Subscriptions'));
    await tester.pumpAndSettle();
    expect(scheduler.cleared.last, ReminderKind.subscriptions);
    await pressBack(tester);

    await openMenu(tester);
    await tester.tap(find.text('Backup'));
    await tester.pumpAndSettle();
    expect(scheduler.cleared.last, ReminderKind.backup);
    // All but the planner's notification that stays while a block is on
    // (Round 72): it goes when the block ends or is ticked.
    expect(scheduler.cleared.toSet(),
        ReminderKind.values.toSet()..remove(ReminderKind.plannerNow));
  });
}
