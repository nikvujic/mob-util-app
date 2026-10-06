import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:the_app/data/app_storage.dart';
import 'package:the_app/main.dart';
import 'package:the_app/providers/shop_provider.dart';

void main() {
  late ProviderContainer container;

  Future<void> pumpShop(WidgetTester tester) async {
    container = ProviderContainer(
      overrides: [appStorageProvider.overrideWithValue(AppStorage.inMemory())],
    );
    addTearDown(container.dispose);
    await tester.pumpWidget(
      UncontrolledProviderScope(container: container, child: const MyApp()),
    );
    await tester.tap(find.text('Shop'));
    await tester.pumpAndSettle();
  }

  testWidgets('adds several items in a row from the add sheet',
      (tester) async {
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

    // The checkbox does the same as tapping the row.
    await tester.tap(find.byType(Checkbox).last);
    await tester.pump();
    expect(find.text('TO BUY  ·  2'), findsOneWidget);
    expect(container.read(shopProvider).first.name, 'Milk');
  });

  testWidgets('dragging the handle reorders within a section',
      (tester) async {
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

  testWidgets('To Do tab shows the placeholder', (tester) async {
    await pumpShop(tester);
    await tester.tap(find.text('To Do').last);
    await tester.pumpAndSettle();
    expect(find.text('To-do lists are coming soon'), findsOneWidget);
  });
}
