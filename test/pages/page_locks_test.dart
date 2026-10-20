import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:the_app/models/app_section.dart';
import 'package:the_app/models/hub_tool.dart';
import 'package:the_app/models/notification_target.dart';
import 'package:the_app/providers/counters_provider.dart';
import 'package:the_app/providers/medicine_provider.dart';
import 'package:the_app/providers/notes_provider.dart';
import 'package:the_app/providers/section_locks_provider.dart';
import 'package:the_app/providers/security_provider.dart';
import 'package:the_app/providers/session_provider.dart';

import '../helpers.dart';

/// A lock for each of the Hub's pages (O7, Round 21): switches under the
/// Hub on Security; a locked page shows a lock screen while the app is
/// locked, whatever the Hub's own lock says.
void main() {
  const password = 'master password';

  late ProviderContainer container;
  late FakeReminderScheduler scheduler;

  Set<HubTool> pageLocks() => container.read(pageLocksProvider);
  final medicineLock = find.byKey(const Key('pageLock-medicine'));

  /// The app with a counter and a master password (unlocked), [pages]
  /// locked and, with [hub], the Hub too.
  Future<void> start(
    WidgetTester tester, {
    Set<HubTool> pages = const {},
    bool hub = false,
  }) async {
    scheduler = FakeReminderScheduler();
    container = await pumpApp(tester, reminders: scheduler);
    container.read(countersProvider.notifier).add('Push-ups');
    await tester.runAsync(() async {
      await container.read(securityProvider.notifier).setPassword(password);
      await container.read(sessionProvider.notifier).unlock(password);
    });
    pages.forEach(container.read(pageLocksProvider.notifier).lock);
    if (hub) container.read(sectionLocksProvider.notifier).lock(AppSection.hub);
    await tester.pumpAndSettle();
  }

  void lockApp() => container.read(sessionProvider.notifier).lock();

  Future<void> openSecurity(WidgetTester tester) async {
    await openMenu(tester);
    await tester.tap(find.text('Security'));
    await tester.pumpAndSettle();
  }

  Future<void> enterPassword(WidgetTester tester, String value) async {
    await tester.enterText(find.byKey(const Key('promptPassword')), value);
    await tester.tap(find.text('Unlock').last);
    await settleBusy(tester);
  }

  Future<void> showMedicineLock(WidgetTester tester) async {
    await tester.scrollUntilVisible(medicineLock, 100,
        scrollable: find.byType(Scrollable).last);
    await tester.pumpAndSettle();
  }

  Future<void> openTile(WidgetTester tester, String label) async {
    await tester.tap(find.byTooltip(label));
    await tester.pumpAndSettle();
  }

  testWidgets('Security: a switch per Hub page, under the Hub', (tester) async {
    await start(tester);
    await openSecurity(tester);
    await showMedicineLock(tester);
    final hub = tester.getTopLeft(find.widgetWithText(SwitchListTile, 'Hub'));
    for (final page in HubTool.values) {
      final tile = find.byKey(Key('pageLock-${page.name}'));
      // Pip Home has no lock (Round 35).
      expect(tile, page.lockable ? findsOneWidget : findsNothing);
      if (!page.lockable) continue;
      expect(tester.getTopLeft(tile).dy, greaterThan(hub.dy));
    }
    expect(HubTool.values.where((p) => !p.lockable),
        [HubTool.pip, HubTool.spotify],
        reason: 'Round 93: Spotify has nothing to hide');
    container.read(pageLocksProvider.notifier).lock(HubTool.pip);
    expect(pageLocks(), isEmpty, reason: "Pip can't be locked");
    final title =
        find.descendant(of: medicineLock, matching: find.text('Medicine'));
    expect(tester.getTopLeft(title).dx, greaterThan(hub.dx + 48),
        reason: 'indented under the Hub');

    await tester.tap(medicineLock);
    await tester.pumpAndSettle();
    expect(pageLocks(), {HubTool.medicine});
    expect(container.read(sectionLocksProvider), isEmpty,
        reason: 'the Hub itself stays free');
  });

  testWidgets(
      'a free Hub, a locked page: the others open, it asks; unlocked, it '
      'opens in place', (tester) async {
    await start(tester, pages: {HubTool.medicine});
    lockApp();
    await openTab(tester, 'Hub');
    expect(find.text('Hub is locked'), findsNothing);
    expect(find.byKey(const Key('toolLock-Medicine')), findsOneWidget);
    expect(find.byKey(const Key('toolLock-Counters')), findsNothing);
    // Bottom left (Round 25), clear of the icon (44 dp, centred).
    final tile = tester.getRect(find.byTooltip('Medicine'));
    final lock = tester.getRect(find.byKey(const Key('toolLock-Medicine')));
    expect(lock.right, lessThan(tile.center.dx - 22));
    expect(lock.top, greaterThan(tile.center.dy));
    expect(lock.left - tile.left, lessThan(16), reason: 'in the corner');

    await openTile(tester, 'Counters');
    expect(find.text('Push-ups'), findsOneWidget);
    await tester.pageBack();
    await tester.pumpAndSettle();

    await openTile(tester, 'Medicine');
    expect(find.text('Medicine is locked'), findsOneWidget);
    expect(find.byTooltip('Add medicine'), findsNothing, reason: 'not built');
    // Round 61: it asks at once, no Unlock to press first.
    expect(find.byType(TextField), findsOneWidget);
    await enterPassword(tester, password);
    expect(find.text('Medicine is locked'), findsNothing);
    expect(find.byTooltip('Add medicine'), findsOneWidget);
  });

  testWidgets('open when the app locks: closes at once', (tester) async {
    await start(tester, pages: {HubTool.counters});
    await openTab(tester, 'Hub');
    await openTile(tester, 'Counters');
    expect(find.text('Push-ups'), findsOneWidget);
    lockApp();
    await tester.pump();
    expect(find.text('Push-ups'), findsNothing);
    expect(find.text('Counters is locked'), findsOneWidget);
    // Round 61: locked while open, it doesn't ask by itself.
    await tester.pumpAndSettle();
    expect(find.byType(TextField), findsNothing);
  });

  testWidgets(
      'locking while its menu is open: everything over the page closes '
      '(Round 24)', (tester) async {
    await start(tester, pages: {HubTool.medicine});
    container
        .read(medicineProvider.notifier)
        .add('Iron', times: [480], from: DateTime(2026, 10, 1));
    await openTab(tester, 'Hub');
    await openTile(tester, 'Medicine');
    await tester.tap(find.text('Iron'));
    await tester.pumpAndSettle();
    expect(find.text('History'), findsOneWidget);
    lockApp();
    await tester.pumpAndSettle();
    expect(find.text('History'), findsNothing, reason: 'the menu closed');
    expect(find.text('Iron'), findsNothing);
    expect(appBarTitle('Hub'), findsOneWidget);
  });

  testWidgets("elsewhere, a page's lock leaves what's open alone",
      (tester) async {
    await start(tester, pages: {HubTool.medicine});
    container.read(notesProvider.notifier).addNote(title: 'Diary');
    await tester.pumpAndSettle();
    await tester.tap(find.text('Diary'));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('noteContentField')), findsOneWidget);
    lockApp(); // Notes isn't locked: the note stays open
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('noteContentField')), findsOneWidget);
  });

  testWidgets(
      'a locked Hub with a free page: the Hub asks, its pages keep their '
      'own switches', (tester) async {
    await start(tester, hub: true, pages: {HubTool.counters});
    lockApp();
    await openTab(tester, 'Hub');
    expect(find.text('Hub is locked'), findsOneWidget);
    expect(pageLocks(), {HubTool.counters});
  });

  testWidgets('turning a page lock off needs the password while locked',
      (tester) async {
    await start(tester, pages: {HubTool.medicine});
    lockApp();
    await openSecurity(tester);
    await showMedicineLock(tester);
    await tester.tap(medicineLock);
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('promptPassword')), findsOneWidget);
    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();
    expect(pageLocks(), {HubTool.medicine}, reason: 'cancelled');

    await tester.tap(medicineLock);
    await tester.pumpAndSettle();
    await enterPassword(tester, password);
    expect(pageLocks(), isEmpty);
  });

  testWidgets(
      'a medicine notification with the page locked: its lock screen, '
      'then the page once unlocked', (tester) async {
    await start(tester, pages: {HubTool.medicine});
    lockApp();
    await tester.pumpAndSettle();
    scheduler.taps.add(const MedicineTarget().payload);
    await tester.pumpAndSettle();
    expect(find.text('Medicine is locked'), findsOneWidget);
    await tester.runAsync(
        () => container.read(sessionProvider.notifier).unlock(password));
    await tester.pumpAndSettle();
    expect(appBarTitle('Medicine'), findsOneWidget);
    expect(find.byTooltip('Add medicine'), findsOneWidget);
  });
}
