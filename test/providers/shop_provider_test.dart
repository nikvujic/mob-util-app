import 'package:flutter_test/flutter_test.dart';
import 'package:the_app/data/app_storage.dart';
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
}
