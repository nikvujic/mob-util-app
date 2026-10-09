import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:the_app/providers/shop_provider.dart';

import '../helpers.dart';

void main() {
  late ProviderContainer container;

  Future<void> pumpShop(WidgetTester tester) async {
    container = await pumpApp(tester);
    await openTab(tester, 'Shop');
  }

  testWidgets('adds several items in a row from the add sheet', (tester) async {
    await pumpShop(tester);
    expect(find.text('Your shopping list is empty'), findsOneWidget);

    await tester.tap(find.byTooltip('Add item'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), 'Milk');
    await tester.testTextInput.receiveAction(TextInputAction.send);
    await tester.pump();
    await tester.enterText(find.byType(TextField), 'Bread');
    await tester.tap(find.text('Add'));
    await tester.pump();

    expect(container.read(shopProvider).map((i) => i.name), ['Bread', 'Milk']);
    expect(find.byType(TextField), findsOneWidget, reason: 'sheet stays open');
  });

  testWidgets('tapping an item moves it to Items and back', (tester) async {
    await pumpShop(tester);
    container.read(shopProvider.notifier)
      ..addItem('Milk')
      ..addItem('Bread');
    await tester.pump();
    expect(find.text('ITEMS  ·  1'), findsNothing);

    await tester.tap(find.text('Milk'));
    await tester.pump();
    expect(find.text('TO BUY  ·  1'), findsOneWidget);
    expect(find.text('ITEMS  ·  1'), findsOneWidget);
    expect(
      tester.getTopLeft(find.text('Milk')).dy,
      greaterThan(tester.getTopLeft(find.text('ITEMS  ·  1')).dy),
    );

    // Tapping on the checkbox does the same as tapping the row: the
    // checkbox only shows the state, the row takes the tap.
    await tester.tap(find.byType(Checkbox).last, warnIfMissed: false);
    await tester.pump();
    expect(find.text('TO BUY  ·  2'), findsOneWidget);
    expect(container.read(shopProvider).first.name, 'Milk');
  });

  testWidgets('dragging the handle reorders within a section', (tester) async {
    await pumpShop(tester);
    container.read(shopProvider.notifier)
      ..addItem('C')
      ..addItem('B')
      ..addItem('A');
    await tester.pump();

    final gesture = await tester
        .startGesture(tester.getCenter(find.byIcon(Icons.drag_handle).first));
    for (var i = 0; i < 10; i++) {
      await gesture.moveBy(const Offset(0, 20));
      await tester.pump(const Duration(milliseconds: 16));
    }
    await gesture.up();
    await tester.pumpAndSettle();

    expect(container.read(shopProvider).map((i) => i.name).first, 'B');
  });

  testWidgets('long-press selects and deletes with confirmation',
      (tester) async {
    await pumpShop(tester);
    container.read(shopProvider.notifier)
      ..addItem('Milk')
      ..addItem('Bread');
    await tester.pump();

    await tester.longPress(find.text('Milk'));
    await tester.pump();
    expect(find.text('1 selected'), findsOneWidget);

    await tester.tap(find.byTooltip('Delete'));
    await tester.pumpAndSettle();
    expect(find.text('Delete item?'), findsOneWidget);
    await tester.tap(find.text('Delete'));
    await tester.pumpAndSettle();

    expect(container.read(shopProvider).map((i) => i.name), ['Bread']);
  });

  group('add sheet and the keyboard', () {
    Future<void> openAddSheet(WidgetTester tester) async {
      await pumpShop(tester);
      addTearDown(tester.view.resetViewInsets);
      await tester.tap(find.byTooltip('Add item'));
      await tester.pumpAndSettle();
      tester.view.viewInsets = const FakeViewPadding(bottom: 300);
      await tester.pumpAndSettle(); // keyboard shown
    }

    testWidgets('closing the keyboard closes the sheet', (tester) async {
      await openAddSheet(tester);
      expect(find.byType(TextField), findsOneWidget);

      tester.view.viewInsets = FakeViewPadding.zero; // keyboard's back key
      await tester.pumpAndSettle();

      expect(find.byType(TextField), findsNothing);
      expect(find.byType(BottomSheet), findsNothing);
      expect(appBarTitle('Shop'), findsOneWidget, reason: 'page stays');
    });

    testWidgets('adding items keeps the sheet open', (tester) async {
      await openAddSheet(tester);
      await tester.enterText(find.byType(TextField), 'Milk');
      await tester.testTextInput.receiveAction(TextInputAction.send);
      await tester.pumpAndSettle();

      expect(find.byType(TextField), findsOneWidget);
      expect(container.read(shopProvider).single.name, 'Milk');
    });

    testWidgets('the keyboard hiding while the sheet closes leaves the page',
        (tester) async {
      await openAddSheet(tester);
      await tester.tapAt(const Offset(20, 100)); // outside: sheet closes
      tester.view.viewInsets = FakeViewPadding.zero;
      await tester.pumpAndSettle();

      expect(find.byType(BottomSheet), findsNothing);
      expect(appBarTitle('Shop'), findsOneWidget);
    });
  });
}
