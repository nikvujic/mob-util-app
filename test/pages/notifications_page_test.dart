import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:the_app/data/reminder_scheduler.dart';
import 'package:the_app/models/notify_settings.dart';
import 'package:the_app/providers/notification_log_provider.dart';
import 'package:the_app/providers/preferences_provider.dart';

import '../helpers.dart';

/// The Notifications page (Round 31): the latest notifications, the whole
/// history, and each page's settings.
void main() {
  /// Thursday 8 October 2026, 12:00.
  final now = DateTime(2026, 10, 8, 12);
  late ProviderContainer container;

  Reminder shown(int hoursAgo, String title, {String? target}) => Reminder(
        at: now.subtract(Duration(hours: hoursAgo)),
        title: title,
        body: 'Body of $title',
        target: target,
      );

  Future<void> open(WidgetTester tester,
      {List<Reminder> log = const []}) async {
    container = await pumpApp(tester, clock: () => now);
    container
        .read(notificationLogProvider.notifier)
        .planned(log, now.subtract(const Duration(days: 3)));
    await openMenu(tester);
    await tester.tap(find.text('Notifications'));
    await tester.pumpAndSettle();
  }

  final recent = find.byKey(const Key('recentNotifications'));

  testWidgets('in the menu; the 3 latest in a window, newest first',
      (tester) async {
    await open(tester, log: [
      shown(30, 'Yesterday early'),
      shown(5, 'This morning'),
      shown(3, 'Late morning'),
      shown(1, 'Just now'),
      shown(60, 'Too long ago'),
    ]);
    expect(appBarTitle('Notifications'), findsOneWidget);
    final titles = [
      for (final t in ['Just now', 'Late morning', 'This morning'])
        tester
            .getTopLeft(find.descendant(of: recent, matching: find.text(t)))
            .dy,
    ];
    expect(titles, orderedEquals([...titles]..sort()));
    expect(find.text('Yesterday early'), findsNothing, reason: 'only 3');
    expect(find.textContaining('Today 11:00'), findsOneWidget);
    expect(find.text('All 4'), findsOneWidget, reason: 'today and yesterday');
  });

  testWidgets('none: said so', (tester) async {
    await open(tester);
    expect(find.text('None today or yesterday'), findsOneWidget);
    expect(find.textContaining('All '), findsNothing);
  });

  testWidgets('all of them, by day; Clear, with Undo', (tester) async {
    await open(tester, log: [shown(30, 'Yesterday early'), shown(1, 'Now')]);
    await tester.tap(find.text('All 2'));
    await tester.pumpAndSettle();
    expect(appBarTitle('Recent notifications'), findsOneWidget);
    expect(find.text('TODAY'), findsOneWidget);
    expect(find.text('YESTERDAY'), findsOneWidget);
    expect(find.textContaining('Yesterday 06:00'), findsOneWidget);

    await tester.tap(find.byTooltip('Clear'));
    await tester.pumpAndSettle();
    expect(find.text('None today or yesterday'), findsOneWidget);
    await tester.tap(find.text('Undo'));
    await tester.pumpAndSettle();
    expect(find.text('Now'), findsOneWidget);
  });

  testWidgets('tapping one goes where it leads', (tester) async {
    await open(tester,
        log: [shown(1, 'Dentist', target: 'planner|2026-10-08|660')]);
    await tester.tap(find.text('Dentist'));
    await tester.pumpAndSettle();
    expect(appBarTitle('Notifications'), findsNothing, reason: 'closed');
    expect(find.byType(Drawer), findsNothing, reason: 'the menu too');
    expect(appBarTitle('Planner'), findsOneWidget);
  });

  testWidgets('each page\'s settings are kept', (tester) async {
    await open(tester);
    Future<void> tap(String key) async {
      final f = find.byKey(Key(key));
      await reveal(tester, f);
      await tester.tap(f);
      await tester.pumpAndSettle();
    }

    await tap('notifyPrivate-planner');
    expect(container.read(preferencesProvider).styleOf(NotifyPage.planner),
        const NotifyStyle(private: true));

    await tap('notifyOn-planner');
    expect(container.read(preferencesProvider).plannerReminders, isFalse);
    expect(find.byKey(const Key('notifyPrivate-planner')), findsNothing,
        reason: 'off: nothing more to set');
    await tap('notifyOn-planner');

    await tap('notifyPause-planner');
    await tester.tap(find.text('Today'));
    await tester.pumpAndSettle();
    expect(container.read(preferencesProvider).plannerPausedUntil,
        DateTime(2026, 10, 8));

    await tap('notifySound-medicine');
    await tester.tap(find.text('Bell'));
    await tester.pumpAndSettle();
    expect(container.read(preferencesProvider).styleOf(NotifyPage.medicine),
        const NotifyStyle(sound: NotifySound.bell));
    expect(
        find.descendant(
          of: find.byKey(const Key('notifySound-medicine')),
          matching: find.text('Bell'),
        ),
        findsOneWidget);

    final colours = find.byKey(const Key('notifyColour-backup'));
    await reveal(tester, colours);
    await tester.tap(find.descendant(
        of: colours, matching: find.bySemanticsLabel('Colour: Green')));
    await tester.pumpAndSettle();
    expect(
        container.read(preferencesProvider).styleOf(NotifyPage.backup).colour,
        'green');
  });
}
