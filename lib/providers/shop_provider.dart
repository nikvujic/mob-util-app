import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:the_app/core/id.dart';
import 'package:the_app/data/app_storage.dart';
import 'package:the_app/models/shop_item.dart';

/// Shopping list items. A single ordered list; the "To buy" and "Items"
/// sections are the items filtered by [ShopItem.toBuy], in list order.
/// Every change is saved to [AppStorage].
class ShopNotifier extends StateNotifier<List<ShopItem>> {
  ShopNotifier(AppStorage storage) : super(storage.initialShopItems) {
    addListener(storage.saveShopItems, fireImmediately: false);
  }

  /// Adds an item at the end of "To buy" (S5), so the list keeps the order
  /// things were added in, and returns its id. Blank names are ignored
  /// (null). One already there by that name (Round 58, any case) isn't
  /// added twice: it's moved there instead, as if new. [copy]: a new one
  /// all the same (a recipe's To Shop, for another quantity).
  String? addItem(String name, {bool copy = false}) {
    final trimmed = name.trim();
    if (trimmed.isEmpty) return null;
    final existing = copy ? null : named(trimmed);
    if (existing != null) {
      final others = state.where((i) => i.id != existing.id);
      state = [...others, existing.copyWith(toBuy: true)];
      return existing.id;
    }
    final item = ShopItem(id: generateId(), name: trimmed);
    state = [...state, item];
    return item.id;
  }

  /// The item called [name] (any case), if there is one.
  ShopItem? named(String name) {
    final key = name.trim().toLowerCase();
    return state.where((i) => i.name.toLowerCase() == key).firstOrNull;
  }

  /// The items not on the list that [typed] is part of (any case), the
  /// ones it starts first (Round 58: offered while adding).
  List<String> suggest(String typed) {
    final key = typed.trim().toLowerCase();
    if (key.isEmpty) return const [];
    final found = [
      for (final item in state)
        if (!item.toBuy && item.name.toLowerCase().contains(key)) item.name,
    ];
    bool starts(String n) => n.toLowerCase().startsWith(key);
    return [...found.where(starts), ...found.where((n) => !starts(n))];
  }

  /// Renames an item (Round 58). False if [name] is blank or another
  /// item has it already; its own name in another case is fine.
  bool rename(String id, String name) {
    final trimmed = name.trim();
    if (trimmed.isEmpty) return false;
    final other = named(trimmed);
    if (other != null && other.id != id) return false;
    _update(id, (item) => item.copyWith(name: trimmed));
    return true;
  }

  /// Moves the item to the other section: back to "To buy" at its end
  /// (like a new item), or to "Items" at its top (bought most recently).
  void toggle(String id) {
    final index = state.indexWhere((item) => item.id == id);
    if (index == -1) return;
    final moved = state[index].copyWith(toBuy: !state[index].toBuy);
    final others = [...state.take(index), ...state.skip(index + 1)];
    state = moved.toBuy ? [...others, moved] : [moved, ...others];
  }

  /// The quantity button (S7): none → count → weight → none; a typed
  /// amount (Round 70, set in the amount sheet) → none.
  void cycleQuantity(String id) => _update(
        id,
        (item) => item.copyWith(
          quantity: () => switch (item.quantity) {
            null => Quantity.count,
            Quantity.count => Quantity.weight,
            Quantity.weight || Quantity.text => null,
          },
        ),
      );

  void setQuantity(String id, Quantity? quantity) =>
      _update(id, (item) => item.copyWith(quantity: () => quantity));

  /// Count − / +: at least 1.
  static const maxCount = 999;
  void setCount(String id, int count) =>
      _update(id, (item) => item.copyWith(count: count.clamp(1, maxCount)));

  /// A weight in grams; anything above 0 (an exact one may be below 1 g).
  void setGrams(String id, double grams) {
    if (grams <= 0 || grams.isNaN || grams.isInfinite) return;
    _update(id, (item) => item.copyWith(grams: grams));
  }

  /// A typed amount (Round 70), trimmed.
  void setText(String id, String text) =>
      _update(id, (item) => item.copyWith(text: text.trim()));

  void _update(String id, ShopItem Function(ShopItem) change) {
    state = [
      for (final item in state)
        if (item.id == id) change(item) else item,
    ];
  }

  /// Replaces everything (used when restoring a backup).
  void replaceAll(List<ShopItem> items) {
    state = List.unmodifiable(items);
  }

  void removeItems(Set<String> ids) {
    state = state.where((item) => !ids.contains(item.id)).toList();
  }

  /// Reorders within one section. [oldIndex] and [newIndex] are positions
  /// inside that section and follow `ReorderableListView.onReorder`
  /// semantics. The other section is left untouched.
  void reorder(
      {required bool toBuy, required int oldIndex, required int newIndex}) {
    if (newIndex > oldIndex) newIndex--;
    if (oldIndex == newIndex) return;

    final section = state.where((i) => i.toBuy == toBuy).toList();
    section.insert(newIndex, section.removeAt(oldIndex));

    // Put the reordered section back into the slots it occupied.
    final reordered = section.iterator;
    state = [
      for (final item in state)
        if (item.toBuy == toBuy) (reordered..moveNext()).current else item,
    ];
  }
}

final shopProvider = StateNotifierProvider<ShopNotifier, List<ShopItem>>((ref) {
  return ShopNotifier(ref.watch(appStorageProvider));
});
