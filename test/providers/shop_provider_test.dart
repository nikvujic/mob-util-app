import 'package:flutter_test/flutter_test.dart';
import 'package:the_app/data/app_storage.dart';
import 'package:the_app/models/shop_item.dart';
import 'package:the_app/providers/shop_provider.dart';

void main() {
  late ShopNotifier notifier;

  setUp(() => notifier = ShopNotifier(AppStorage.inMemory()));

  List<String> toBuy() =>
      notifier.state.where((i) => i.toBuy).map((i) => i.name).toList();
  List<String> stock() =>
      notifier.state.where((i) => !i.toBuy).map((i) => i.name).toList();
  String idOf(String name) =>
      notifier.state.firstWhere((i) => i.name == name).id;

  test('adds trimmed items to the end of "To buy" and ignores blanks', () {
    notifier
      ..addItem('Milk')
      ..addItem('  Bread ')
      ..addItem('   ');
    expect(toBuy(), ['Milk', 'Bread']);
    expect(notifier.state.map((i) => i.id).toSet().length, 2);
  });

  test('new items go after everything in "To buy", not among "Items"', () {
    notifier
      ..addItem('Milk')
      ..addItem('Eggs');
    notifier.toggle(idOf('Milk')); // bought
    notifier.addItem('Bread');

    expect(toBuy(), ['Eggs', 'Bread']);
    expect(stock(), ['Milk']);
  });

  test(
      'bought items go to the top of "Items"; '
      'moved back, to the end of "To buy"', () {
    notifier
      ..addItem('Eggs')
      ..addItem('Milk')
      ..addItem('Bread');

    notifier.toggle(idOf('Eggs'));
    notifier.toggle(idOf('Bread'));
    expect(toBuy(), ['Milk']);
    expect(stock(), ['Bread', 'Eggs']);

    notifier.toggle(idOf('Eggs'));
    expect(toBuy(), ['Milk', 'Eggs']);
    expect(stock(), ['Bread']);
  });

  test('reorder only moves items within the given section', () {
    notifier
      ..addItem('A')
      ..addItem('X')
      ..addItem('B')
      ..addItem('Y')
      ..addItem('C');
    notifier
      ..toggle(idOf('Y'))
      ..toggle(idOf('X')); // Items: X, Y
    expect(toBuy(), ['A', 'B', 'C']);

    notifier.reorder(toBuy: true, oldIndex: 0, newIndex: 3); // A to bottom
    expect(toBuy(), ['B', 'C', 'A']);
    expect(stock(), ['X', 'Y']);

    notifier.reorder(toBuy: false, oldIndex: 1, newIndex: 0); // Y to top
    expect(stock(), ['Y', 'X']);
    expect(toBuy(), ['B', 'C', 'A']);
  });

  test('removeItems deletes across both sections', () {
    notifier
      ..addItem('Eggs')
      ..addItem('Milk')
      ..addItem('Bread');
    notifier.toggle(idOf('Eggs'));

    notifier.removeItems({idOf('Eggs'), idOf('Bread')});
    expect(toBuy(), ['Milk']);
    expect(stock(), isEmpty);
  });

  group('quantities (S7)', () {
    ShopItem item(String name) =>
        notifier.state.firstWhere((i) => i.name == name);

    test('the button goes none → count → weight → none', () {
      notifier.addItem('Milk');
      final id = idOf('Milk');
      expect(item('Milk').quantity, isNull);
      notifier.cycleQuantity(id);
      expect(item('Milk').quantity, Quantity.count);
      expect(item('Milk').count, 1);
      notifier.cycleQuantity(id);
      expect(item('Milk').quantity, Quantity.weight);
      expect(item('Milk').grams, 200);
      notifier.cycleQuantity(id);
      expect(item('Milk').quantity, isNull);
    });

    test('each kind keeps its value when switched away and back', () {
      notifier.addItem('Flour');
      final id = idOf('Flour');
      notifier
        ..setQuantity(id, Quantity.count)
        ..setCount(id, 3)
        ..setQuantity(id, Quantity.weight)
        ..setGrams(id, 1500)
        ..setQuantity(id, null)
        ..setQuantity(id, Quantity.count);
      expect(item('Flour').count, 3);
      notifier.setQuantity(id, Quantity.weight);
      expect(item('Flour').grams, 1500);
    });

    test('a count is 1–999; a weight anything above 0', () {
      notifier.addItem('Eggs');
      final id = idOf('Eggs');
      notifier.setCount(id, 0);
      expect(item('Eggs').count, 1);
      notifier.setCount(id, 5000);
      expect(item('Eggs').count, 999);
      notifier.setGrams(id, 0.5);
      expect(item('Eggs').grams, 0.5, reason: 'below 1 g is fine');
      notifier
        ..setGrams(id, 0)
        ..setGrams(id, -3)
        ..setGrams(id, double.nan);
      expect(item('Eggs').grams, 0.5, reason: 'nonsense is ignored');
    });

    test('weights step through common amounts', () {
      expect(gramsUp(200), 250);
      expect(gramsDown(200), 150);
      expect(gramsUp(230), 250, reason: 'from a typed one: the next');
      expect(gramsDown(230), 200);
      expect(gramsDown(1), isNull, reason: 'nothing below 1 g to step to');
      expect(gramsDown(0.5), isNull);
      expect(gramsUp(0.5), 1);
      expect(gramsUp(5000), 6000, reason: 'past the list: whole kilos');
      expect(gramsUp(6000), 7000);
      expect(gramsDown(7000), 6000);
      expect(gramsDown(5500), 5000);
    });

    test('shown as g or kg', () {
      expect(formatGrams(200), '200 g');
      expect(formatGrams(0.5), '0.5 g');
      expect(formatGrams(12.25), '12.25 g');
      expect(formatGrams(1000), '1 kg');
      expect(formatGrams(1500), '1.5 kg');
    });

    test('saved only where it differs from the defaults', () {
      const plain = ShopItem(id: 'a', name: 'Milk');
      expect(plain.toJson().keys, ['id', 'name', 'toBuy']);
      const full = ShopItem(
        id: 'b',
        name: 'Flour',
        quantity: Quantity.weight,
        count: 2,
        grams: 1500,
      );
      final back = ShopItem.fromJson(full.toJson());
      expect((back.quantity, back.count, back.grams),
          (Quantity.weight, 2, 1500.0));
      expect(
        ShopItem.fromJson({
          'id': 'c',
          'name': 'X',
          'toBuy': true,
          'quantity': 'volume', // a newer kind
        }).quantity,
        isNull,
      );
    });
  });

  group('Round 58', () {
    test('an item added again is moved, not doubled (any case)', () {
      notifier
        ..addItem('Milk')
        ..addItem('Eggs')
        ..addItem('Bread');
      notifier.toggle(idOf('Milk')); // bought
      final milk = idOf('Milk');
      expect(notifier.addItem(' milk '), milk);
      expect(toBuy(), ['Eggs', 'Bread', 'Milk']);
      expect(stock(), isEmpty);
      // Already to buy: to the end, as if new.
      expect(notifier.addItem('EGGS'), idOf('Eggs'));
      expect(toBuy(), ['Bread', 'Milk', 'Eggs']);
      expect(notifier.state, hasLength(3));
    });

    test('a moved item keeps its amount', () {
      final id = notifier.addItem('Flour')!;
      notifier
        ..setQuantity(id, Quantity.weight)
        ..setGrams(id, 500)
        ..toggle(id)
        ..addItem('flour');
      final flour = notifier.state.single;
      expect(flour.toBuy, isTrue);
      expect(flour.grams, 500);
      expect(flour.name, 'Flour', reason: 'its name as it was');
    });

    test('rename: trimmed; not blank, not another item\'s name', () {
      notifier
        ..addItem('Milk')
        ..addItem('Bread');
      final milk = idOf('Milk');
      expect(notifier.rename(milk, '  Oat milk '), isTrue);
      expect(notifier.state.first.name, 'Oat milk');
      expect(notifier.rename(milk, '   '), isFalse);
      expect(notifier.rename(milk, 'bread'), isFalse);
      expect(notifier.state.first.name, 'Oat milk');
      // Its own name in another case is fine.
      expect(notifier.rename(milk, 'OAT MILK'), isTrue);
      expect(notifier.state.first.name, 'OAT MILK');
      expect(notifier.state.first.id, milk);
    });

    test('suggest: items not on the list containing it, starts first', () {
      notifier
        ..addItem('Oat milk')
        ..addItem('Milk')
        ..addItem('Milk chocolate')
        ..addItem('Bread');
      for (final name in ['Oat milk', 'Milk', 'Bread']) {
        notifier.toggle(idOf(name));
      }
      expect(notifier.suggest('MIL'), ['Milk', 'Oat milk'],
          reason: 'Milk chocolate is on the list already');
      expect(notifier.suggest('  '), isEmpty);
      expect(notifier.suggest('x'), isEmpty);
    });
  });
}
