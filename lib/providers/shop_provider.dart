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

  /// Adds an item to the top of "To buy". Blank names are ignored.
  void addItem(String name) {
    final trimmed = name.trim();
    if (trimmed.isEmpty) return;
    state = [ShopItem(id: generateId(), name: trimmed), ...state];
  }

  /// Moves the item to the other section, placing it at the top.
  void toggle(String id) {
    final index = state.indexWhere((item) => item.id == id);
    if (index == -1) return;
    final item = state[index];
    state = [
      item.copyWith(toBuy: !item.toBuy),
      ...state.take(index),
      ...state.skip(index + 1),
    ];
  }

  void removeItems(Set<String> ids) {
    state = state.where((item) => !ids.contains(item.id)).toList();
  }

  /// Reorders within one section. [oldIndex] and [newIndex] are positions
  /// inside that section and follow `ReorderableListView.onReorder`
  /// semantics. The other section is left untouched.
  void reorder({required bool toBuy, required int oldIndex, required int newIndex}) {
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
