import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:the_app/models/date_entry.dart';
import 'package:the_app/models/subscription.dart';
import 'package:the_app/providers/dates_provider.dart';
import 'package:the_app/providers/food_provider.dart';
import 'package:the_app/providers/subscriptions_provider.dart';

import '../helpers.dart';

/// Round 91 (Nikola): pages saved as they're typed (a subscription, a
/// date, a meal) ask on back, once changed, Save or Discard, as a note
/// does; Discard puts it back (a new one goes); a tap outside stays.
void main() {
  late ProviderContainer container;
  final now = DateTime(2026, 10, 20, 12);

  Finder dialogButton(String label) =>
      find.descendant(of: find.byType(AlertDialog), matching: find.text(label));

  group('a subscription', () {
    final claude = Subscription(
        id: 'c', name: 'Claude', price: 20, date: DateTime(2026, 11, 3));

    Future<void> open(WidgetTester tester, {bool add = false}) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 2.625;
      addTearDown(tester.view.reset);
      container = await pumpApp(tester,
          clock: () => now, subscriptions: SubscriptionBook([claude]));
      await openTab(tester, 'Hub');
      await tester.tap(find.byTooltip('Subscriptions'));
      await tester.pumpAndSettle();
      await tester.tap(add
          ? find.byTooltip('Add a subscription')
          : find.byKey(const ValueKey('c')));
      await tester.pumpAndSettle();
    }

    Subscription? stored(String id) =>
        container.read(subscriptionsProvider).byId(id);

    testWidgets('unchanged: back just leaves', (tester) async {
      await open(tester);
      await pressBack(tester);
      expect(find.byType(AlertDialog), findsNothing);
      expect(appBarTitle('Subscriptions'), findsOneWidget);
    });

    testWidgets(
        'changed: asked; a tap outside stays; Discard puts it back as it '
        'was', (tester) async {
      await open(tester);
      await tester.enterText(find.byKey(const Key('subscriptionName')), 'X');
      await tester.pump();
      expect(stored('c')!.name, 'X', reason: 'saved as typed');
      await pressBack(tester);
      expect(find.text('Save changes?'), findsOneWidget);
      await tester.tapAt(const Offset(8, 300));
      await tester.pumpAndSettle();
      expect(find.byType(AlertDialog), findsNothing);
      expect(find.byKey(const Key('subscriptionName')), findsOneWidget,
          reason: 'still on its page');

      await pressBack(tester);
      await tester.tap(dialogButton('Discard'));
      await tester.pumpAndSettle();
      expect(stored('c'), claude);
      expect(appBarTitle('Subscriptions'), findsOneWidget);
      expect(find.text('Claude'), findsOneWidget);
    });

    testWidgets('changed, Save: kept', (tester) async {
      await open(tester);
      await tester.enterText(find.byKey(const Key('subscriptionName')), 'X');
      await tester.pump();
      await pressBack(tester);
      await tester.tap(dialogButton('Save'));
      await tester.pumpAndSettle();
      expect(stored('c')!.name, 'X');
      expect(appBarTitle('Subscriptions'), findsOneWidget);
    });

    testWidgets('a new one: "Save new subscription?"; Discard deletes it',
        (tester) async {
      await open(tester, add: true);
      await pressBack(tester);
      expect(find.byType(AlertDialog), findsNothing,
          reason: 'nothing typed: nothing kept, nothing asked');
      await tester.tap(find.byTooltip('Add a subscription'));
      await tester.pumpAndSettle();
      await tester.enterText(
          find.byKey(const Key('subscriptionName')), 'Spotify');
      await tester.pump();
      expect(container.read(subscriptionsProvider).subscriptions, hasLength(2));
      await pressBack(tester);
      expect(find.text('Save new subscription?'), findsOneWidget);
      await tester.tap(dialogButton('Discard'));
      await tester.pumpAndSettle();
      expect(container.read(subscriptionsProvider).subscriptions, [claude]);
    });
  });

  testWidgets('a date: changed, Discard puts it back', (tester) async {
    final d = DateEntry(
        id: 'd',
        title: 'Mum',
        type: DateType.birthday,
        day: 25,
        month: 10,
        year: 1960);
    container = await pumpApp(tester, clock: () => now);
    container.read(datesProvider.notifier).replaceAll(DateBook([d]));
    await openTab(tester, 'Hub');
    await tester.tap(find.byTooltip('Dates'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Mum').first);
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const Key('dateTitle')), 'Mother');
    await tester.pump();
    expect(container.read(datesProvider).byId('d')!.title, 'Mother');
    await pressBack(tester);
    expect(find.text('Save changes?'), findsOneWidget);
    await tester.tap(dialogButton('Discard'));
    await tester.pumpAndSettle();
    expect(container.read(datesProvider).byId('d'), d);
  });

  testWidgets(
      'a meal: a new one with a note, Discard: gone; the food list open, '
      'back closes it first, nothing asked', (tester) async {
    container = await pumpApp(tester, clock: () => now);
    await openTab(tester, 'Hub');
    await tester.tap(find.byTooltip('Food'));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Log a meal'));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('mealFoodField')));
    await tester.pumpAndSettle();
    await pressBack(tester);
    expect(find.byType(AlertDialog), findsNothing);
    expect(find.byKey(const Key('mealNote')), findsOneWidget,
        reason: 'still on the meal');

    await tester.enterText(find.byKey(const Key('mealNote')), 'Good');
    await tester.pump();
    expect(container.read(foodProvider).meals, hasLength(1));
    // The note field let go first (its own back), then back again.
    FocusManager.instance.primaryFocus?.unfocus();
    await tester.pumpAndSettle();
    await pressBack(tester);
    expect(find.text('Save new meal?'), findsOneWidget);
    await tester.tap(dialogButton('Discard'));
    await tester.pumpAndSettle();
    expect(container.read(foodProvider).meals, isEmpty);
  });
}
