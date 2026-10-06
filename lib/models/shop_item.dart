class ShopItem {
  final String id;
  final String name;

  /// false = still "to buy", true = in the "bought" section.
  final bool bought;

  const ShopItem({
    required this.id,
    required this.name,
    this.bought = false,
  });

  ShopItem copyWith({String? name, bool? bought}) {
    return ShopItem(
      id: id,
      name: name ?? this.name,
      bought: bought ?? this.bought,
    );
  }
}
