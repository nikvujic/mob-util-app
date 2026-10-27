import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:the_app/core/theme.dart';
import 'package:the_app/models/notification_target.dart';
import 'package:the_app/models/subscription.dart';
import 'package:the_app/pages/hub/subscriptions.dart';
import 'package:the_app/providers/notification_target_provider.dart';
import 'package:the_app/providers/subscriptions_provider.dart';
import 'package:the_app/widgets/selection.dart';

import '../helpers.dart';

/// Hub → Subscriptions (Round 79, `docs/SUBSCRIPTIONS_SPEC.md`).
void main() {
  late ProviderContainer container;
  // Monday 19 October 2026, 12:00.
  final now = DateTime(2026, 10, 19, 12);
  DateTime day(int month, int d) => DateTime(2026, month, d);

  SubscriptionBook book() => container.read(subscriptionsProvider);

  /// a real list.
  final nikolas = SubscriptionBook([
    Subscription(
        id: 'claude',
        name: 'Claude',
        price: 20,
        date: day(11, 3),
        card: 'Revolut 4421'),
    Subscription(id: 'claude2', name: 'Claude 2', price: 20, date: day(11, 12)),
    Subscription(
        id: 'gpt',
        name: 'ChatGPT',
        price: 23,
        state: SubscriptionState.cancelled,
        date: day(11, 13)),
    Subscription(
        id: 'grok',
        name: 'Grok',
        price: 16,
        state: SubscriptionState.toCancel,
        date: day(11, 17),
        note: 'real ~30€',
        remindBefore: 2),
    Subscription(
        id: 'aws', name: 'AWS', price: 5, about: true, date: day(11, 1)),
    Subscription(
        id: 'spotify',
        name: 'Spotify',
        price: 6,
        about: true,
        state: SubscriptionState.inactive,
        note: 'payment failed'),
  ]);

  Future<void> open(WidgetTester tester,
      {SubscriptionBook start = SubscriptionBook.empty}) async {
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 2.625;
    addTearDown(tester.view.reset);
    container = await pumpApp(tester, clock: () => now, subscriptions: start);
    await openTab(tester, 'Hub');
    await tester.tap(find.byTooltip('Subscriptions'));
    await tester.pumpAndSettle();
  }

  Finder card(String id) => find.byKey(ValueKey(id));

  testWidgets('empty: a hint, no total', (tester) async {
    await open(tester);
    expect(appBarTitle('Subscriptions'), findsOneWidget);
    expect(find.textContaining('Add your subscriptions'), findsOneWidget);
    expect(find.byKey(const Key('subscriptionsTotal')), findsNothing);
  });

  testWidgets(
      'his list: two to a row, in his order, tinted by state, with all there is '
      'to know; a month\'s total', (tester) async {
    await open(tester, start: nikolas);
    expect(find.text('~61€ a month'), findsOneWidget,
        reason: 'Claude, Claude 2, Grok, AWS: running ones that cost');
    // Round 89: in his order (as added; moved by dragging), not by state.
    final order = ['claude', 'claude2', 'gpt', 'grok', 'aws', 'spotify'];
    final at = [for (final id in order) tester.getTopLeft(card(id))];
    for (var i = 0; i < at.length; i += 2) {
      expect(at[i].dy, at[i + 1].dy, reason: 'a row: ${order[i]}');
      expect(at[i].dx, lessThan(at[i + 1].dx));
    }
    expect(at[2].dy, greaterThan(at[0].dy));
    expect(at[4].dy, greaterThan(at[2].dy));

    Color tint(String id) => tester
        .widget<SelectableCard>(find.descendant(
            of: card(id), matching: find.byType(SelectableCard)))
        .color!;
    final base = tester.widget<SelectableCard>(find.descendant(
        of: card('grok'), matching: find.byType(SelectableCard)));
    expect(base.color, isNotNull);
    expect(tint('grok'), isNot(tint('claude')));
    expect(tint('claude'), tint('aws'), reason: 'both active');
    expect(tint('spotify'), isNot(tint('claude')));
    expect(tint('gpt'), isNot(tint('grok')));

    expect(find.text('16€ / month'), findsOneWidget);
    expect(find.text('~5€ / month'), findsOneWidget);
    expect(find.text('Cancel by Tue, 17 Nov'), findsOneWidget);
    expect(find.text('Renews Tue, 3 Nov'), findsOneWidget);
    expect(find.text('Active until Fri, 13 Nov'), findsOneWidget);
    expect(find.text('Inactive'), findsOneWidget);
    expect(find.text('Revolut 4421'), findsOneWidget);
    expect(find.text('Card unknown'), findsNWidgets(5));
    expect(find.byKey(const Key('subscriptionRemind-grok')), findsOneWidget);
    expect(find.text('2 days before'), findsOneWidget);
    expect(find.byKey(const Key('subscriptionRemind-claude')), findsNothing);
    expect(find.text('real ~30€'), findsOneWidget);
    expect(find.text('payment failed'), findsOneWidget);
  });

  testWidgets(
      'added: named, priced, its card; saved as typed, shown on its card',
      (tester) async {
    await open(tester);
    await tester.tap(find.byTooltip('Add a subscription'));
    await tester.pumpAndSettle();
    expect(appBarTitle('New subscription'), findsOneWidget);
    await leaveSaved(tester);
    expect(book().isEmpty, isTrue, reason: 'no name: not kept');

    await tester.tap(find.byTooltip('Add a subscription'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const Key('subscriptionName')), 'Claude');
    await tester.enterText(find.byKey(const Key('subscriptionPrice')), '19,99');
    await tester.enterText(
        find.byKey(const Key('subscriptionCardField')), 'Revolut 4421');
    await tester.pumpAndSettle();
    final s = book().subscriptions.single;
    expect((
      s.name,
      s.price,
      s.card,
      s.state,
      s.date
    ), (
      'Claude',
      19.99,
      'Revolut 4421',
      SubscriptionState.active,
      day(11, 19)
    ));
    await leaveSaved(tester);
    expect(find.text('19.99€ / month'), findsOneWidget);
    expect(find.text('Renews Thu, 19 Nov'), findsOneWidget);
  });

  testWidgets(
      'edited: to cancel brings a reminder 2 days before; its reminder and '
      'about change on the card; cancelled: active until', (tester) async {
    await open(tester, start: SubscriptionBook([nikolas.byId('claude')!]));
    await tester.tap(card('claude'));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('subscriptionStateChip-toCancel')));
    await tester.pumpAndSettle();
    expect(book().byId('claude')!.state, SubscriptionState.toCancel);
    expect(book().byId('claude')!.remindBefore, 2);
    await tester.ensureVisible(find.byKey(const Key('subscriptionRemind-7')));
    await tester.tap(find.byKey(const Key('subscriptionRemind-7')));
    await tester.pumpAndSettle();
    expect(book().byId('claude')!.remindBefore, 7);
    await tester.ensureVisible(find.byKey(const Key('subscriptionAbout')));
    await tester.tap(find.byKey(const Key('subscriptionAbout')));
    await tester.pumpAndSettle();
    await leaveSaved(tester);
    expect(find.text('1 week before'), findsOneWidget);
    expect(find.text('~20€ / month'), findsOneWidget);
    expect(find.text('Cancel by Tue, 3 Nov'), findsOneWidget);

    await tester.tap(card('claude'));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('subscriptionStateChip-cancelled')));
    await tester.pumpAndSettle();
    expect(book().byId('claude')!.remindBefore, 7, reason: 'kept');
    await tester.tap(find.byKey(const Key('subscriptionStateChip-inactive')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('subscriptionDate')), findsNothing,
        reason: 'no day while inactive');
    await tester.tap(find.byKey(const Key('subscriptionStateChip-cancelled')));
    await tester.pumpAndSettle();
    await leaveSaved(tester);
    expect(find.text('Active until Tue, 3 Nov'), findsOneWidget);
    expect(find.byKey(const Key('subscriptionsTotal')), findsNothing,
        reason: 'nothing that costs');
  });

  testWidgets(
      'Round 80: the card\'s expiry set on its page, shown on its card; '
      'before it renews, a warning; cleared', (tester) async {
    await open(tester, start: SubscriptionBook([nikolas.byId('claude')!]));
    await tester.tap(card('claude'));
    await tester.pumpAndSettle();
    final expires = find.byKey(const Key('subscriptionCardExpires'));
    await tester.scrollUntilVisible(expires, 200,
        scrollable: find.byType(Scrollable).last);
    expect(find.text('Not set'), findsOneWidget);
    await tester.tap(expires);
    await tester.pumpAndSettle();
    // Round 85: a month and year (cards have no day): this year first,
    // the next one picked, then March.
    expect(find.text('Card expires'), findsNWidgets(2));
    expect(find.byKey(const Key('monthPickerYear')), findsOneWidget);
    expect(find.text('2026'), findsOneWidget);
    await tester.tap(find.byTooltip('Year after'));
    await tester.pumpAndSettle();
    expect(find.text('2027'), findsOneWidget);
    await tester.tap(find.text('Mar'));
    await tester.pumpAndSettle();
    expect(book().byId('claude')!.cardExpires, DateTime(2027, 3, 31),
        reason: 'good through its last day');
    expect(find.text('03/27'), findsOneWidget);
    await leaveSaved(tester);
    expect(find.text('Revolut 4421 · expires 03/27'), findsOneWidget);
    expect(find.text('Card expires before it renews'), findsNothing,
        reason: 'it renews on the 3rd, before');
    // Expiring before it renews: a warning on the card and its page.
    container
        .read(subscriptionsProvider.notifier)
        .save(book().byId('claude')!.copyWith(cardExpires: () => day(10, 30)));
    await tester.pumpAndSettle();
    expect(find.text('Card expires before it renews'), findsOneWidget);
    await tester.tap(card('claude'));
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(expires, 200,
        scrollable: find.byType(Scrollable).last);
    expect(find.text('Before it renews'), findsOneWidget);
    await tester.tap(find.byKey(const Key('subscriptionCardExpiresClear')));
    await tester.pumpAndSettle();
    expect(book().byId('claude')!.cardExpires, isNull);
    expect(find.text('Not set'), findsOneWidget);
  });

  testWidgets(
      'Round 81: typing its name, then its day: the name lets go, so the '
      'keyboard doesn\'t come back once the picker closes', (tester) async {
    await open(tester, start: SubscriptionBook([nikolas.byId('claude')!]));
    await tester.tap(card('claude'));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('subscriptionName')));
    await tester.pumpAndSettle();
    bool typing() => tester.testTextInput.isVisible;
    expect(typing(), isTrue);
    await tester.tap(find.byKey(const Key('subscriptionDate')));
    await tester.pumpAndSettle();
    expect(typing(), isFalse);
    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();
    expect(typing(), isFalse, reason: 'not back to the name');
    // The card's expiry too.
    await tester.tap(find.byKey(const Key('subscriptionName')));
    await tester.pumpAndSettle();
    final expires = find.byKey(const Key('subscriptionCardExpires'));
    await tester.scrollUntilVisible(expires, 200,
        scrollable: find.byType(Scrollable).last);
    await tester.tap(expires);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();
    expect(typing(), isFalse);
  });

  testWidgets('an inactive one set going again gets a day a month on',
      (tester) async {
    await open(tester, start: SubscriptionBook([nikolas.byId('spotify')!]));
    await tester.tap(card('spotify'));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('subscriptionStateChip-active')));
    await tester.pumpAndSettle();
    expect(book().byId('spotify')!.date, day(11, 19));
    expect(find.byKey(const Key('subscriptionDate')), findsOneWidget);
  });

  testWidgets('deleted, asked first, with Undo', (tester) async {
    await open(tester, start: nikolas);
    await tester.tap(card('aws'));
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(
        find.byKey(const Key('deleteSubscription')), 300,
        scrollable: find.byType(Scrollable).last);
    await tester.tap(find.byKey(const Key('deleteSubscription')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Delete'));
    await tester.pumpAndSettle();
    expect(book().byId('aws'), isNull);
    expect(find.text('AWS deleted'), findsOneWidget);
    await tester.tap(find.text('Undo'));
    await tester.pumpAndSettle();
    expect(book().byId('aws'), isNotNull);
  });

  testWidgets('one to cancel soon: a red dot on its tile', (tester) async {
    container = await pumpApp(tester,
        clock: () => DateTime(2026, 11, 15, 12), subscriptions: nikolas);
    await openTab(tester, 'Hub');
    final dot = find.descendant(
        of: find.byTooltip('Subscriptions'),
        matching: find.byKey(const Key('toolDot')));
    expect(dot, findsOneWidget, reason: 'Grok by the 17th, 2 days before');
    container.read(subscriptionsProvider.notifier).save(
        nikolas.byId('grok')!.copyWith(state: SubscriptionState.cancelled));
    await tester.pumpAndSettle();
    expect(dot, findsNothing);
  });

  testWidgets('its notification tapped: the page', (tester) async {
    container = await pumpApp(tester, clock: () => now, subscriptions: nikolas);
    container.read(pendingTargetProvider.notifier).state =
        const SubscriptionsTarget();
    await tester.pumpAndSettle();
    expect(appBarTitle('Subscriptions'), findsOneWidget);
    expect(container.read(pendingTargetProvider), isNull);
    expect(
        NotificationTarget.parse('subscriptions'), isA<SubscriptionsTarget>());
  });

  test('state colours', () {
    expect(SubscriptionState.active.colour, SubscriptionColours.active);
    expect(SubscriptionState.toCancel.colour, SubscriptionColours.toCancel);
    final ended = Subscription(
        id: 'x',
        name: 'x',
        state: SubscriptionState.cancelled,
        date: day(10, 1));
    expect(
        subscriptionColour(ended, day(10, 19)), SubscriptionColours.inactive);
    expect(
        subscriptionColour(ended, day(9, 19)), SubscriptionColours.cancelled);
  });
}
