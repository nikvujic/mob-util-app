import 'package:flutter_test/flutter_test.dart';
import 'package:the_app/providers/shop_provider.dart';

void main() {
  late ShopNotifier notifier;

  setUp(() => notifier = ShopNotifier());

  List<String> toBuy() =>
      notifier.state.where((i) => !i.bought).map((i) => i.name).toList();
  List<String> bought() =>
      notifier.state.where((i) => i.bought).map((i) => i.name).toList();
  String idOf(String name) =>
      notifier.state.firstWhere((i) => i.name == name).id;

  test('adds trimmed items to the top of "to buy" and ignores blanks', () {
    notifier
      ..addItem('Milk')
      ..addItem('  Bread ')
      ..addItem('   ');
    expect(toBuy(), ['Bread', 'Milk']);
    expect(notifier.state.map((i) => i.id).toSet().length, 2);
  });

  test('toggleBought moves an item to the top of the other section', () {
    notifier
      ..addItem('Eggs')
      ..addItem('Milk')
      ..addItem('Bread');

    notifier.toggleBought(idOf('Eggs'));
    notifier.toggleBought(idOf('Bread'));
    expect(toBuy(), ['Milk']);
    expect(bought(), ['Bread', 'Eggs']);

    notifier.toggleBought(idOf('Eggs'));
    expect(toBuy(), ['Eggs', 'Milk']);
    expect(bought(), ['Bread']);
  });

  test('renameItem ignores blank names', () {
    notifier.addItem('Milk');
    final id = idOf('Milk');

    notifier.renameItem(id, ' ');
    expect(toBuy(), ['Milk']);

    notifier.renameItem(id, 'Oat milk');
    expect(toBuy(), ['Oat milk']);
  });

  test('removeItems deletes across both sections', () {
    notifier
      ..addItem('Eggs')
      ..addItem('Milk')
      ..addItem('Bread');
    notifier.toggleBought(idOf('Eggs'));

    notifier.removeItems({idOf('Eggs'), idOf('Bread')});
    expect(toBuy(), ['Milk']);
    expect(bought(), isEmpty);
  });
}
