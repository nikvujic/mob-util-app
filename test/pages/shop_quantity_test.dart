import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:the_app/models/shop_item.dart';
import 'package:the_app/providers/shop_provider.dart';

import '../helpers.dart';

/// Amounts on shop items (S7): a button picks none / count / weight, the
/// amount opens a sheet with big − / +, and a weight can be typed.
void main() {
  late ProviderContainer container;

  final kind = find.byKey(const Key('quantityKind'));
  final amount = find.byKey(const Key('shopAmount'));

  ShopItem milk() =>
      container.read(shopProvider).firstWhere((i) => i.name == 'Milk');

  Future<void> openShop(WidgetTester tester) async {
    container = await pumpApp(tester);
    container.read(shopProvider.notifier).addItem('Milk');
    await openTab(tester, 'Shop');
    await tester.pump();
  }

  Future<void> openAmount(WidgetTester tester) async {
    await tester.tap(amount);
    await tester.pumpAndSettle();
  }

  String shown(WidgetTester tester) => tester.widget<Text>(amount).data!;

  testWidgets('the button goes none → count → weight → none', (tester) async {
    await openShop(tester);
    expect(amount, findsNothing);
    expect(find.byTooltip('Amount: none'), findsOneWidget);

    await tester.tap(kind);
    await tester.pump();
    expect(shown(tester), '×1');
    await tester.tap(kind);
    await tester.pump();
    expect(shown(tester), '200 g');
    await tester.tap(kind);
    await tester.pump();
    expect(amount, findsNothing);
    expect(milk().toBuy, isTrue, reason: 'the row itself was not tapped');
  });

  testWidgets('a count: − / + in the sheet, never below 1', (tester) async {
    await openShop(tester);
    await tester.tap(kind);
    await tester.pump();
    await openAmount(tester);

    final less = find.byTooltip('Less');
    final more = find.byTooltip('More');
    expect(
        tester
            .widget<IconButton>(find.ancestor(
                of: find.byIcon(Icons.remove),
                matching: find.byType(IconButton)))
            .onPressed,
        isNull);
    await tester.tap(more);
    await tester.tap(more);
    await tester.pump();
    expect(milk().count, 3);
    await tester.tap(less);
    await tester.pump();
    expect(milk().count, 2);
    expect(find.text('2'), findsOneWidget);
  });

  testWidgets('a weight steps through common amounts, or is typed',
      (tester) async {
    await openShop(tester);
    container
        .read(shopProvider.notifier)
        .setQuantity(milk().id, Quantity.weight);
    await tester.pump();
    await openAmount(tester);

    await tester.tap(find.byTooltip('More'));
    await tester.pump();
    expect(milk().grams, 250);
    await tester.tap(find.byTooltip('Less'));
    await tester.tap(find.byTooltip('Less'));
    await tester.pump();
    expect(milk().grams, 150);

    await tester.tap(find.byKey(const Key('typeWeight')));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), '0,5');
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();
    expect(milk().grams, 0.5, reason: 'a comma works too');
    expect(find.text('0.5 g'), findsWidgets);
  });

  testWidgets('switching kind in the sheet keeps each value', (tester) async {
    await openShop(tester);
    await tester.tap(kind);
    await tester.pump();
    await openAmount(tester);
    await tester.tap(find.byTooltip('More'));
    await tester.pump();
    await tester.tap(find.text('Weight'));
    await tester.pump();
    expect(find.text('200 g'), findsWidgets);
    await tester.tap(find.text('Count'));
    await tester.pump();
    expect(milk().count, 2);
    await tester.tap(find.text('None'));
    await tester.pump();
    expect(milk().quantity, isNull);
  });

  testWidgets('bought: the amount shows, but nothing changes it',
      (tester) async {
    await openShop(tester);
    final shop = container.read(shopProvider.notifier)
      ..setQuantity(milk().id, Quantity.count)
      ..setCount(milk().id, 4);
    shop.toggle(milk().id);
    await tester.pump();

    expect(shown(tester), '×4');
    expect(kind, findsNothing);
    await tester.tap(amount);
    await tester.pumpAndSettle();
    expect(find.byTooltip('More'), findsNothing, reason: 'no sheet');
  });

  testWidgets('while selecting, no amount buttons', (tester) async {
    await openShop(tester);
    await tester.tap(kind);
    await tester.pump();
    await tester.longPress(find.text('Milk'));
    await tester.pumpAndSettle();
    expect(kind, findsNothing);
    expect(shown(tester), '×1');
  });

  testWidgets('long-pressing the amount or its button selects the row',
      (tester) async {
    await openShop(tester);
    await tester.tap(kind);
    await tester.pump();
    await tester.longPress(amount);
    await tester.pumpAndSettle();
    expect(find.text('1 selected'), findsOneWidget);
  });

  testWidgets('tapping a bought item\'s amount moves it back, like the row',
      (tester) async {
    await openShop(tester);
    final shop = container.read(shopProvider.notifier)
      ..setQuantity(milk().id, Quantity.count);
    shop.toggle(milk().id);
    await tester.pump();
    await tester.tap(amount);
    await tester.pump();
    expect(milk().toBuy, isTrue);
  });

  testWidgets('holding − or + shows no tooltip (Round 15)', (tester) async {
    await openShop(tester);
    await tester.tap(kind);
    await tester.pump();
    await openAmount(tester);
    for (final label in ['Less', 'More']) {
      await tester.longPress(find.byTooltip(label));
      await tester.pumpAndSettle();
      expect(find.text(label), findsNothing, reason: label);
    }
  });
}
