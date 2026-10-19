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
      'search: a field above the keyboard; typing filters the bought list '
      '(1.29.1: only that one) by name, any case; it stays when the '
      'keyboard goes; closed, all back', (tester) async {
    await pumpShop(tester);
    await tester.tap(find.byTooltip('Search'));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('shopSearchBar')), findsOneWidget);
    expect(find.byTooltip('Add item'), findsNothing);
    expect(tester.testTextInput.isVisible, isTrue);
    await tester.enterText(find.byKey(const Key('shopSearchField')), 'AP');
    await tester.pump();
    expect(shown(), ['Bread', 'apples'], reason: 'to buy: all still there');
    await tester.enterText(find.byKey(const Key('shopSearchField')), 'MIL');
    await tester.pump();
    expect(shown(), ['Bread', 'Milk']);
    await tester.enterText(find.byKey(const Key('shopSearchField')), 'AP');
    await tester.pump();
    // A match tapped: to buy, still shown (in the list to buy).
    await tester.tap(find.text('apples'));
    await tester.pump();
    expect(find.text('TO BUY  ·  2'), findsOneWidget);
    expect(shown(), ['Bread', 'apples']);
    // The keyboard closed: the field stays, filtering.
    FocusManager.instance.primaryFocus?.unfocus();
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('shopSearchBar')), findsOneWidget);
    await tester.enterText(find.byKey(const Key('shopSearchField')), 'zu');
    await tester.pump();
    expect(shown(), ['Bread', 'apples', 'Zucchini']);
    await tester.tap(find.byKey(const Key('shopSearchClose')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('shopSearchBar')), findsNothing);
    expect(shown(), ['Bread', 'Milk', 'apples', 'Zucchini']);
    expect(find.byTooltip('Add item'), findsOneWidget);
  });

  testWidgets(
      'the search button beside + at the bottom (G11), none in the top '
      'bar; only once something\'s bought', (tester) async {
    container = await pumpApp(tester);
    await openTab(tester, 'Shop');
    container.read(shopProvider.notifier).addItem('Bread');
    await tester.pumpAndSettle();
    expect(find.byTooltip('Search'), findsNothing,
        reason: 'nothing bought to search');
    final shop = container.read(shopProvider.notifier);
    shop.toggle(container.read(shopProvider).single.id);
    await tester.pumpAndSettle();
    final search = find.byTooltip('Search');
    final add = find.byTooltip('Add item');
    expect(search, findsOneWidget);
    expect(find.descendant(of: find.byType(AppBar), matching: search),
        findsNothing);
    expect(tester.getCenter(search).dy,
        moreOrLessEquals(tester.getCenter(add).dy, epsilon: 1),
        reason: 'one row');
    expect(tester.getCenter(search).dy, greaterThan(450),
        reason: 'at the bottom');
  });

  testWidgets('the search\'s icon and its text on one line (1.29.1)',
      (tester) async {
    await pumpShop(tester);
    await tester.tap(find.byTooltip('Search'));
    await tester.pumpAndSettle();
    final icon = tester.getCenter(find.byKey(const Key('shopSearchIcon')));
    final text = tester.getCenter(find.descendant(
        of: find.byKey(const Key('shopSearchField')),
        matching: find.byType(EditableText)));
    expect(icon.dy, moreOrLessEquals(text.dy, epsilon: 1));
    final hint = tester.getCenter(find.text('Search bought items'));
    expect(icon.dy, moreOrLessEquals(hint.dy, epsilon: 1));
  });

  testWidgets('nothing matches: it offers to add what was typed',
      (tester) async {
    await pumpShop(tester);
    await tester.tap(find.byTooltip('Search'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const Key('shopSearchField')), 'Eggs');
    await tester.pump();
    expect(find.text('Nothing called “Eggs”'), findsOneWidget);
    expect(shown(), ['Bread'], reason: 'the list to buy still there');
    await tester.tap(find.byKey(const Key('shopAddTyped')));
    await tester.pumpAndSettle();
    expect(container.read(shopProvider).where((i) => i.name == 'Eggs'),
        hasLength(1));
  });

  testWidgets('Back closes the search', (tester) async {
    await pumpShop(tester);
    await tester.tap(find.byTooltip('Search'));
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
