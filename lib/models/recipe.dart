import 'package:the_app/models/shop_item.dart';

/// What kind of dish a recipe is (Round 40): a fixed list (Round 41).
/// The [name] is stored, so a type is never renamed here, only its
/// [label].
enum RecipeType {
  breakfast('Breakfast'),
  lunch('Lunch'),
  dinner('Dinner'),
  snack('Snack'),
  cake('Cake'),
  drink('Drink'),
  other('Other');

  const RecipeType(this.label);

  final String label;

  /// The type stored as [id], or null if unknown (e.g. from a newer app).
  static RecipeType? fromId(String? id) =>
      values.where((t) => t.name == id).firstOrNull;
}

/// One of a recipe's ingredients: the ingredient it was picked from (its
/// id in the ingredients list), its [name] as well (so the recipe stays
/// whole if that one is deleted, or the list isn't restored), and a
/// [quantity] as any text ("200 g", "2", "a pinch"; empty: none yet).
class RecipeIngredient {
  /// The ingredient in the list it came from; null if none.
  final String? ingredientId;
  final String name;
  final String quantity;

  const RecipeIngredient({
    this.ingredientId,
    required this.name,
    this.quantity = '',
  });

  RecipeIngredient copyWith({String? name, String? quantity}) =>
      RecipeIngredient(
        ingredientId: ingredientId,
        name: name ?? this.name,
        quantity: quantity ?? this.quantity,
      );

  Map<String, dynamic> toJson() => {
        if (ingredientId != null) 'ingredient': ingredientId,
        'name': name,
        if (quantity.isNotEmpty) 'quantity': quantity,
      };

  factory RecipeIngredient.fromJson(Map<String, dynamic> json) =>
      RecipeIngredient(
        ingredientId: json['ingredient'] as String?,
        name: json['name'] as String,
        quantity: json['quantity'] as String? ?? '',
      );

  @override
  bool operator ==(Object other) =>
      other is RecipeIngredient &&
      other.ingredientId == ingredientId &&
      other.name == name &&
      other.quantity == quantity;

  @override
  int get hashCode => Object.hash(ingredientId, name, quantity);
}

/// A recipe (Round 40): a name, how long it takes, what kind it is, its
/// ingredients in order (one flat list, Round 42), and the method as
/// Markdown text, like a note's.
class Recipe {
  final String id;
  final String name;

  /// How long it takes, in minutes; null if not set.
  final int? prepMinutes;
  final RecipeType? type;
  final List<RecipeIngredient> ingredients;

  /// How it's made (Markdown).
  final String method;
  final DateTime createdAt;
  final DateTime modifiedAt;

  Recipe({
    required this.id,
    required this.name,
    this.prepMinutes,
    this.type,
    List<RecipeIngredient> ingredients = const [],
    this.method = '',
    required this.createdAt,
    DateTime? modifiedAt,
  })  : ingredients = List.unmodifiable(ingredients),
        modifiedAt = modifiedAt ?? createdAt;

  /// Nothing in it at all: a new recipe left like this is dropped (like an
  /// empty note).
  bool get isEmpty =>
      name.trim().isEmpty &&
      prepMinutes == null &&
      type == null &&
      ingredients.isEmpty &&
      method.trim().isEmpty;

  Recipe copyWith({
    String? id,
    String? name,
    int? Function()? prepMinutes,
    RecipeType? Function()? type,
    List<RecipeIngredient>? ingredients,
    String? method,
    DateTime? createdAt,
    DateTime? modifiedAt,
  }) =>
      Recipe(
        id: id ?? this.id,
        name: name ?? this.name,
        prepMinutes: prepMinutes == null ? this.prepMinutes : prepMinutes(),
        type: type == null ? this.type : type(),
        ingredients: ingredients ?? this.ingredients,
        method: method ?? this.method,
        createdAt: createdAt ?? this.createdAt,
        modifiedAt: modifiedAt ?? this.modifiedAt,
      );

  /// Whether it holds the same things as [other] (times aside).
  bool sameAs(Recipe other) =>
      name == other.name &&
      prepMinutes == other.prepMinutes &&
      type == other.type &&
      method == other.method &&
      ingredients.length == other.ingredients.length &&
      [
        for (var i = 0; i < ingredients.length; i++)
          ingredients[i] == other.ingredients[i],
      ].every((same) => same);

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        if (prepMinutes != null) 'prepMinutes': prepMinutes,
        if (type != null) 'type': type!.name,
        'ingredients': [for (final i in ingredients) i.toJson()],
        'method': method,
        'createdAt': createdAt.toUtc().toIso8601String(),
        'modifiedAt': modifiedAt.toUtc().toIso8601String(),
      };

  /// An unknown type (from a newer app) reads as none.
  factory Recipe.fromJson(Map<String, dynamic> json) => Recipe(
        id: json['id'] as String,
        name: json['name'] as String,
        prepMinutes: json['prepMinutes'] as int?,
        type: RecipeType.fromId(json['type'] as String?),
        ingredients: [
          for (final i in json['ingredients'] as List<dynamic>? ?? const [])
            RecipeIngredient.fromJson(i as Map<String, dynamic>),
        ],
        method: json['method'] as String? ?? '',
        createdAt: DateTime.parse(json['createdAt'] as String).toLocal(),
        modifiedAt: DateTime.parse(json['modifiedAt'] as String).toLocal(),
      );
}

/// A prep time as shown: "25 min", "1 h", "1 h 30".
String prepTimeLabel(int minutes) {
  final hours = minutes ~/ 60, rest = minutes % 60;
  if (hours == 0) return '$minutes min';
  return rest == 0 ? '$hours h' : '$hours h ${rest.toString().padLeft(2, '0')}';
}

/// The kinds of quantity a recipe's ingredient picks from (Round 43): as
/// Shop's (a count, a weight), and spoons, small and big.
enum AmountKind {
  none('None'),
  count('Count'),
  weight('Weight'),
  teaspoon('Teaspoon'),
  tablespoon('Tablespoon');

  const AmountKind(this.label);

  final String label;

  /// Spoons step by halves.
  bool get isSpoon => this == teaspoon || this == tablespoon;
}

/// A quantity as picked: its kind and how much (a count, grams, spoons).
typedef Amount = ({AmountKind kind, double value});

/// Where each kind starts when picked.
double startOf(AmountKind kind) => switch (kind) {
      AmountKind.none => 0,
      AmountKind.count => 1,
      AmountKind.weight => ShopItem.defaultGrams,
      AmountKind.teaspoon || AmountKind.tablespoon => 1,
    };

/// The most spoons, or pieces.
const maxSpoons = 20.0;
const maxCount = 999.0;

/// [amount] as a recipe keeps it: "2", "200 g", "1½ tsp", "2 tbsp"; empty
/// for none. Shop reads the first two (`shopQuantityOf`).
String amountText(Amount amount) {
  final value = amount.value;
  String spoons(String unit) {
    final whole = value.floor();
    final half = value - whole >= 0.5;
    final number = whole == 0 && half ? '½' : '$whole${half ? '½' : ''}';
    return '$number $unit';
  }

  return switch (amount.kind) {
    AmountKind.none => '',
    AmountKind.count => '${value.round()}',
    AmountKind.weight => formatGrams(value),
    AmountKind.teaspoon => spoons('tsp'),
    AmountKind.tablespoon => spoons('tbsp'),
  };
}

final _amount = RegExp(
  r'^(\d+(?:[.,]\d+)?)?(½)?\s*(kg|g|tsp|tbsp)?$',
);

/// [text] read back as an [Amount] (to start the picker where it is);
/// null for text it doesn't know (typed before Round 43, e.g. "a pinch").
Amount? readAmount(String text) {
  final trimmed = text.trim();
  if (trimmed.isEmpty) return (kind: AmountKind.none, value: 0);
  final match = _amount.firstMatch(trimmed.toLowerCase());
  if (match == null || (match[1] == null && match[2] == null)) return null;
  final number = double.tryParse((match[1] ?? '0').replaceAll(',', '.'));
  if (number == null) return null;
  final value = number + (match[2] == null ? 0 : 0.5);
  return switch (match[3]) {
    'kg' => (kind: AmountKind.weight, value: value * 1000),
    'g' => (kind: AmountKind.weight, value: value),
    'tsp' => (kind: AmountKind.teaspoon, value: value),
    'tbsp' => (kind: AmountKind.tablespoon, value: value),
    _ => value == value.roundToDouble() && value >= 1
        ? (kind: AmountKind.count, value: value)
        : null,
  };
}

/// The next amount up from [amount] (null at the end): a count by one,
/// a weight through Shop's common weights, spoons by halves.
double? amountUp(Amount amount) => switch (amount.kind) {
      AmountKind.none => null,
      AmountKind.count => amount.value < maxCount ? amount.value + 1 : null,
      AmountKind.weight => gramsUp(amount.value),
      AmountKind.teaspoon ||
      AmountKind.tablespoon =>
        amount.value < maxSpoons ? amount.value + 0.5 : null,
    };

/// The next amount down (null at the start).
double? amountDown(Amount amount) => switch (amount.kind) {
      AmountKind.none => null,
      AmountKind.count => amount.value > 1 ? amount.value - 1 : null,
      AmountKind.weight => gramsDown(amount.value),
      AmountKind.teaspoon ||
      AmountKind.tablespoon =>
        amount.value > 0.5 ? amount.value - 0.5 : null,
    };

/// One ingredient in the list (Round 40).
class Ingredient {
  final String id;
  final String name;

  const Ingredient({required this.id, required this.name});

  Map<String, dynamic> toJson() => {'id': id, 'name': name};

  factory Ingredient.fromJson(Map<String, dynamic> json) => Ingredient(
        id: json['id'] as String,
        name: json['name'] as String,
      );
}

/// A section of the ingredients list (Baking, Dairy…), its ingredients in
/// order.
class IngredientSection {
  final String id;
  final String name;
  final List<Ingredient> items;

  IngredientSection({
    required this.id,
    required this.name,
    List<Ingredient> items = const [],
  }) : items = List.unmodifiable(items);

  IngredientSection copyWith({String? name, List<Ingredient>? items}) =>
      IngredientSection(
        id: id,
        name: name ?? this.name,
        items: items ?? this.items,
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'items': [for (final i in items) i.toJson()],
      };

  factory IngredientSection.fromJson(Map<String, dynamic> json) =>
      IngredientSection(
        id: json['id'] as String,
        name: json['name'] as String,
        items: [
          for (final i in json['items'] as List<dynamic>? ?? const [])
            Ingredient.fromJson(i as Map<String, dynamic>),
        ],
      );
}

/// The ingredients list (Round 40): sections in order.
class IngredientBook {
  final List<IngredientSection> sections;

  const IngredientBook._(this.sections);

  IngredientBook(List<IngredientSection> sections)
      : sections = List.unmodifiable(sections);

  static const empty = IngredientBook._([]);

  /// Every ingredient, section by section.
  Iterable<Ingredient> get all => sections.expand((s) => s.items);

  int get size => all.length;

  /// The ingredient with [id], or null.
  Ingredient? byId(String id) => all.where((i) => i.id == id).firstOrNull;

  Map<String, dynamic> toJson() => {
        'sections': [for (final s in sections) s.toJson()],
      };

  factory IngredientBook.fromJson(Map<String, dynamic> json) => IngredientBook([
        for (final s in json['sections'] as List<dynamic>? ?? const [])
          IngredientSection.fromJson(s as Map<String, dynamic>),
      ]);
}
