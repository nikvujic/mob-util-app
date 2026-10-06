import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:the_app/core/id.dart';
import 'package:the_app/models/shop_item.dart';

/// Shopping list items. A single ordered list; the "to buy" and "bought"
/// sections are the items filtered by [ShopItem.bought], in list order.
class ShopNotifier extends StateNotifier<List<ShopItem>> {
  ShopNotifier() : super([]);

  /// Adds an item to the top of "to buy". Blank names are ignored.
  void addItem(String name) {
    final trimmed = name.trim();
    if (trimmed.isEmpty) return;
    state = [ShopItem(id: generateId(), name: trimmed), ...state];
  }

  void renameItem(String id, String name) {
    final trimmed = name.trim();
    if (trimmed.isEmpty) return;
    state = [
      for (final item in state)
        if (item.id == id) item.copyWith(name: trimmed) else item,
    ];
  }

  /// Moves the item to the other section, placing it at the top.
  void toggleBought(String id) {
    final index = state.indexWhere((item) => item.id == id);
    if (index == -1) return;
    final item = state[index];
    state = [
      item.copyWith(bought: !item.bought),
      ...state.take(index),
      ...state.skip(index + 1),
    ];
  }

  void removeItems(Set<String> ids) {
    state = state.where((item) => !ids.contains(item.id)).toList();
  }
}

final shopProvider = StateNotifierProvider<ShopNotifier, List<ShopItem>>((ref) {
  return ShopNotifier();
});
