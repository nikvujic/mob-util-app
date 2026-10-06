class ShopItem {
  final String id;
  final String name;

  /// true = in the "To buy" section, false = in the "Items" section (things
  /// bought before, kept around so they can be put back on the list).
  final bool toBuy;

  const ShopItem({
    required this.id,
    required this.name,
    this.toBuy = true,
  });

  ShopItem copyWith({bool? toBuy}) {
    return ShopItem(id: id, name: name, toBuy: toBuy ?? this.toBuy);
  }
}
