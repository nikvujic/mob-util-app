/// How much of an item to buy (S7): a count or a weight.
enum Quantity { count, weight }

class ShopItem {
  /// A count starts at 1, a weight at 200 g (Nikola).
  static const defaultCount = 1;
  static const defaultGrams = 200.0;

  /// The weights − / + step through (in grams), so no typing is needed;
  /// an exact one can still be typed.
  static const commonGrams = <double>[
    1, 5, 10, 20, 25, 50, 80, 100, 150, 200, 250, 280, 300, 400, 500, //
    600, 750, 1000, 1250, 1500, 2000, 2500, 3000, 4000, 5000,
  ];

  final String id;
  final String name;

  /// true = in the "To buy" section, false = in the "Items" section (things
  /// bought before, kept around so they can be put back on the list).
  final bool toBuy;

  /// Which amount it shows; null for none.
  final Quantity? quantity;

  /// The count and the weight are both kept, so switching between them
  /// and back finds each as it was.
  final int count;
  final double grams;

  const ShopItem({
    required this.id,
    required this.name,
    this.toBuy = true,
    this.quantity,
    this.count = defaultCount,
    this.grams = defaultGrams,
  });

  ShopItem copyWith({
    bool? toBuy,
    Quantity? Function()? quantity,
    int? count,
    double? grams,
  }) {
    return ShopItem(
      id: id,
      name: name,
      toBuy: toBuy ?? this.toBuy,
      quantity: quantity == null ? this.quantity : quantity(),
      count: count ?? this.count,
      grams: grams ?? this.grams,
    );
  }

  /// Only what differs from the defaults is written.
  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'toBuy': toBuy,
        if (quantity != null) 'quantity': quantity!.name,
        if (count != defaultCount) 'count': count,
        if (grams != defaultGrams) 'grams': grams,
      };

  factory ShopItem.fromJson(Map<String, dynamic> json) => ShopItem(
        id: json['id'] as String,
        name: json['name'] as String,
        toBuy: json['toBuy'] as bool,
        // An unknown kind (from a newer app) shows as none.
        quantity: Quantity.values
            .where((q) => q.name == json['quantity'])
            .firstOrNull,
        count: (json['count'] as num?)?.toInt() ?? defaultCount,
        grams: (json['grams'] as num?)?.toDouble() ?? defaultGrams,
      );
}

/// [grams] as shown: "200 g", "0.5 g", "1.5 kg".
String formatGrams(double grams) {
  String trim(double v) {
    final s = v.toStringAsFixed(2);
    return s.contains('.') ? s.replaceFirst(RegExp(r'\.?0+$'), '') : s;
  }

  return grams >= 1000 ? '${trim(grams / 1000)} kg' : '${trim(grams)} g';
}

/// The next common weight above [grams] (or 1 kg more past the last).
double gramsUp(double grams) =>
    ShopItem.commonGrams.where((g) => g > grams).firstOrNull ??
    (grams / 1000).floor() * 1000 + 1000;

/// The next common weight below [grams]; null if there's none.
double? gramsDown(double grams) {
  final below = ShopItem.commonGrams.where((g) => g < grams);
  if (below.isNotEmpty) {
    // Past the list: whole kilos down to the last common weight.
    final last = ShopItem.commonGrams.last;
    if (grams > last + 1000) return (grams / 1000).ceil() * 1000 - 1000;
    return below.last;
  }
  return null;
}
