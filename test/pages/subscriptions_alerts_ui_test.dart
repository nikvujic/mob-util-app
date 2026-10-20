import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:the_app/data/reminder_scheduler.dart';
import 'package:the_app/models/hub_tool.dart';
import 'package:the_app/models/notify_settings.dart';
import 'package:the_app/models/subscription.dart';
import 'package:the_app/providers/preferences_provider.dart';
import 'package:the_app/providers/section_locks_provider.dart';
import 'package:the_app/providers/security_provider.dart';
import 'package:the_app/providers/subscriptions_provider.dart';

import '../helpers.dart';

/// Subscriptions in the app (Round 79): their notifications, the
/// Notifications page, private or locked.
void main() {
  late ProviderContainer container;
  late FakeReminderScheduler scheduler;

  final grok = Subscription(
    id: 'grok',
    name: 'Grok',
    price: 16,
    state: SubscriptionState.toCancel,
    date: DateTime(2026, 10, 22),
    remindBefore: 2,
  );

  Future<void> start(WidgetTester tester) async {
    scheduler = FakeReminderScheduler();
    container = await pumpApp(tester,
        clock: () => DateTime(2026, 10, 19, 12),
        reminders: scheduler,
        subscriptions: SubscriptionBook([grok]));
    await tester.pumpAndSettle();
  }

  List<String> ours() => [
        for (final r in scheduler.scheduled)
          if (r.kind == ReminderKind.subscriptions)
            '${r.at.day} ${r.at.hour}:${r.at.minute} ${r.title}: ${r.body}',
      ];

  testWidgets(
      'to cancel: two days before and on the day; its page on the '
      'Notifications page turns them off', (tester) async {
    await start(tester);
    expect(ours(), [
      '20 9:0 Cancel Grok: It renews in 2 days · 16€',
      '22 9:0 Cancel Grok: It renews today · 16€',
    ]);
    await openMenu(tester);
    await tester.tap(find.text('Notifications'));
    await tester.pumpAndSettle();
    final on = find.byKey(const Key('notifyOn-subscriptions'));
    await reveal(tester, on);
    expect(find.textContaining('On a subscription\'s day at 09:00'),
        findsOneWidget);
    await tester.tap(on);
    await tester.pumpAndSettle();
    expect(container.read(preferencesProvider).subscriptionsReminders, isFalse);
    expect(ours(), isEmpty);
  });

  testWidgets('private: no names; Round 82: locked, names still',
      (tester) async {
    await start(tester);
    final prefs = container.read(preferencesProvider.notifier);
    prefs.setNotifyStyle(
      NotifyPage.subscriptions,
      container
          .read(preferencesProvider)
          .styleOf(NotifyPage.subscriptions)
          .copyWith(private: true),
    );
    await tester.pumpAndSettle();
    expect(ours().first,
        '20 9:0 Subscriptions: A subscription to cancel renews in 2 days');
    prefs.setNotifyStyle(
      NotifyPage.subscriptions,
      container
          .read(preferencesProvider)
          .styleOf(NotifyPage.subscriptions)
          .copyWith(private: false),
    );
    await tester.pumpAndSettle();
    expect(ours().first, startsWith('20 9:0 Cancel Grok'));
    // Set inactive: none.
    container
        .read(subscriptionsProvider.notifier)
        .save(grok.copyWith(state: SubscriptionState.inactive));
    await tester.pumpAndSettle();
    expect(ours(), isEmpty);
    container.read(subscriptionsProvider.notifier).save(grok);
    await tester.pumpAndSettle();
    await tester.runAsync(() => container
        .read(securityProvider.notifier)
        .setPassword('master password'));
    container.read(pageLocksProvider.notifier).lock(HubTool.subscriptions);
    await tester.pumpAndSettle();
    expect(ours().first, startsWith('20 9:0 Cancel Grok'));
  });
}
