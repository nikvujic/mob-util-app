import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:the_app/providers/preferences_provider.dart';
import 'package:the_app/providers/shop_provider.dart';

import '../helpers.dart';

/// Shop's search and A–Z (Round 69).
void main() {
  late ProviderContainer container;

  Future<void> pumpShop(WidgetTester tester) async {
    container = await pumpApp(tester);
    await openTab(tester, 'Shop');
    final shop = container.read(shopProvider.notifier);
    // Bought, newest on top: Zucchini, apples, Milk; to buy: Bread.
    for (final name in ['Milk', 'apples', 'Zucchini', 'Bread']) {
      shop.addItem(name);
    }
    for (final name in ['Milk', 'apples', 'Zucchini']) {
      shop.toggle(
          container.read(shopProvider).firstWhere((i) => i.name == name).id);
    }
    await tester.pumpAndSettle();
  }

  List<String> shown() => [
        for (final name in ['Bread', 'Milk', 'apples', 'Zucchini'])
          if (find.text(name).evaluate().isNotEmpty) name,
      ];

  double y(WidgetTester tester, String name) =>
      tester.getTopLeft(find.text(name)).dy;

  testWidgets(
      'search: a field above the keyboard; typing filters by name, any '
      'case; it stays when the keyboard goes; closed, all back',
      (tester) async {
    await pumpShop(tester);
    await tester.tap(find.byKey(const Key('shopSearch')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('shopSearchBar')), findsOneWidget);
    expect(find.byTooltip('Add item'), findsNothing);
    expect(tester.testTextInput.isVisible, isTrue);
    await tester.enterText(find.byKey(const Key('shopSearchField')), 'AP');
    await tester.pump();
    expect(shown(), ['apples']);
    await tester.enterText(find.byKey(const Key('shopSearchField')), 'MIL');
    await tester.pump();
    expect(shown(), ['Milk']);
    await tester.enterText(find.byKey(const Key('shopSearchField')), 'AP');
    await tester.pump();
    // A match tapped: to buy, still shown (now on top).
    await tester.tap(find.text('apples'));
    await tester.pump();
    expect(find.text('TO BUY  ·  1'), findsOneWidget);
    expect(shown(), ['apples']);
    // The keyboard closed: the field stays, filtering.
    FocusManager.instance.primaryFocus?.unfocus();
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('shopSearchBar')), findsOneWidget);
    expect(shown(), ['apples']);
    await tester.tap(find.byKey(const Key('shopSearchClose')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('shopSearchBar')), findsNothing);
    expect(shown(), ['Bread', 'Milk', 'apples', 'Zucchini']);
    expect(find.byTooltip('Add item'), findsOneWidget);
  });

  testWidgets('nothing matches: it offers to add what was typed',
      (tester) async {
    await pumpShop(tester);
    await tester.tap(find.byKey(const Key('shopSearch')));
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const Key('shopSearchField')), 'Eggs');
    await tester.pump();
    expect(find.text('Nothing called “Eggs”'), findsOneWidget);
    await tester.tap(find.byKey(const Key('shopAddTyped')));
    await tester.pumpAndSettle();
    expect(container.read(shopProvider).where((i) => i.name == 'Eggs'),
        hasLength(1));
  });

  testWidgets('Back closes the search', (tester) async {
    await pumpShop(tester);
    await tester.tap(find.byKey(const Key('shopSearch')));
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const Key('shopSearchField')), 'mi');
    await tester.pump();
    await pressBack(tester);
    expect(find.byKey(const Key('shopSearchBar')), findsNothing);
    expect(shown(), hasLength(4));
  });

  testWidgets(
      'A–Z: the bought list sorted, no handles; its own order kept, new '
      'ones still on its top; remembered', (tester) async {
    await pumpShop(tester);
    // Its own order: Zucchini, apples, Milk.
    expect(y(tester, 'Zucchini'), lessThan(y(tester, 'apples')));
    final handles = find.byIcon(Icons.drag_handle).evaluate().length;
    await tester.tap(find.byKey(const Key('shopSort')));
    await tester.pumpAndSettle();
    expect(container.read(preferencesProvider).shopSorted, isTrue);
    expect(y(tester, 'apples'), lessThan(y(tester, 'Milk')));
    expect(y(tester, 'Milk'), lessThan(y(tester, 'Zucchini')));
    expect(find.byIcon(Icons.drag_handle).evaluate().length, handles - 3,
        reason: 'the to-buy list keeps its handle');
    final order = container
        .read(shopProvider)
        .where((i) => !i.toBuy)
        .map((i) => i.name)
        .toList();
    expect(order, ['Zucchini', 'apples', 'Milk'], reason: 'unchanged');
    // Back to its own order.
    await tester.tap(find.byKey(const Key('shopSort')));
    await tester.pumpAndSettle();
    expect(y(tester, 'Zucchini'), lessThan(y(tester, 'apples')));
  });
}
