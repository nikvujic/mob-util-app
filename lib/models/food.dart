/// The food tracker (O14, Round 46): foods, the meals eaten from them,
/// and how each meal went. Every enum's [name] is stored, so one is never
/// renamed here, only its label.
library;

/// When in the day a meal was eaten.
enum MealKind {
  breakfast('Breakfast'),
  lunch('Lunch'),
  dinner('Dinner'),
  snack('Snack');

  const MealKind(this.label);

  final String label;

  /// A guess from the time of day: breakfast till 11, lunch till 16,
  /// dinner till 22, a snack otherwise.
  static MealKind at(DateTime time) => switch (time.hour) {
        >= 5 && < 11 => breakfast,
        >= 11 && < 16 => lunch,
        >= 16 && < 22 => dinner,
        _ => snack,
      };

  static MealKind? fromId(String? id) =>
      values.where((k) => k.name == id).firstOrNull;
}

/// How a meal went, best first.
enum MealRating {
  great('Great'),
  good('Good'),
  ok('OK'),
  bad('Bad'),
  awful('Awful');

  const MealRating(this.label);

  final String label;

  /// Bad or awful: what the statistics count as trouble.
  bool get isBad => this == bad || this == awful;

  static MealRating? fromId(String? id) =>
      values.where((r) => r.name == id).firstOrNull;
}

/// What followed a meal, if anything.
enum Symptom {
  bloating('Bloating'),
  heartburn('Heartburn'),
  cramps('Cramps'),
  nausea('Nausea'),
  tiredness('Tiredness'),
  headache('Headache'),
  other('Other');

  const Symptom(this.label);

  final String label;

  static Symptom? fromId(String id) =>
      values.where((s) => s.name == id).firstOrNull;
}

/// What a food is or has, for the statistics by kind.
enum FoodTag {
  dairy('Dairy'),
  gluten('Gluten'),
  spicy('Spicy'),
  fried('Fried'),
  sugar('Sugar'),
  alcohol('Alcohol'),
  caffeine('Caffeine'),
  meat('Meat'),
  fish('Fish');

  const FoodTag(this.label);

  final String label;

  static FoodTag? fromId(String id) =>
      values.where((t) => t.name == id).firstOrNull;
}

/// A food in the list (it grows as meals are logged).
class Food {
  final String id;
  final String name;
  final Set<FoodTag> tags;

  Food({required this.id, required this.name, Set<FoodTag> tags = const {}})
      : tags = Set.unmodifiable(tags);

  Food copyWith({String? name, Set<FoodTag>? tags}) =>
      Food(id: id, name: name ?? this.name, tags: tags ?? this.tags);

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        if (tags.isNotEmpty)
          'tags': [
            for (final t in FoodTag.values)
              if (tags.contains(t)) t.name,
          ],
      };

  /// Unknown tags (from a newer app) are skipped.
  factory Food.fromJson(Map<String, dynamic> json) => Food(
        id: json['id'] as String,
        name: json['name'] as String,
        tags: {
          for (final t in json['tags'] as List<dynamic>? ?? const [])
            if (FoodTag.fromId(t as String) case final tag?) tag,
        },
      );
}

/// One of a meal's foods: the food it is (its id in the list) and its
/// name too, so the meal stays whole if that food is deleted.
class MealFood {
  final String? foodId;
  final String name;

  const MealFood({this.foodId, required this.name});

  /// The same food: by id, or by name when either has none.
  String get key => foodId ?? 'name:${name.toLowerCase()}';

  Map<String, dynamic> toJson() => {
        if (foodId != null) 'food': foodId,
        'name': name,
      };

  factory MealFood.fromJson(Map<String, dynamic> json) => MealFood(
        foodId: json['food'] as String?,
        name: json['name'] as String,
      );

  @override
  bool operator ==(Object other) =>
      other is MealFood && other.foodId == foodId && other.name == name;

  @override
  int get hashCode => Object.hash(foodId, name);
}

/// A meal: when, what kind, its foods, and (once rated) how it went.
class Meal {
  final String id;
  final DateTime at;
  final MealKind kind;
  final List<MealFood> foods;

  /// Null: not rated yet.
  final MealRating? rating;
  final Set<Symptom> symptoms;
  final String note;

  Meal({
    required this.id,
    required this.at,
    required this.kind,
    List<MealFood> foods = const [],
    this.rating,
    Set<Symptom> symptoms = const {},
    this.note = '',
  })  : foods = List.unmodifiable(foods),
        symptoms = Set.unmodifiable(symptoms);

  Meal copyWith({
    DateTime? at,
    MealKind? kind,
    List<MealFood>? foods,
    MealRating? Function()? rating,
    Set<Symptom>? symptoms,
    String? note,
  }) =>
      Meal(
        id: id,
        at: at ?? this.at,
        kind: kind ?? this.kind,
        foods: foods ?? this.foods,
        rating: rating == null ? this.rating : rating(),
        symptoms: symptoms ?? this.symptoms,
        note: note ?? this.note,
      );

  /// Whether it was eaten on [day] (local time).
  bool isOn(DateTime day) {
    final local = at.toLocal();
    return local.year == day.year &&
        local.month == day.month &&
        local.day == day.day;
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'at': at.toUtc().toIso8601String(),
        'kind': kind.name,
        'foods': [for (final f in foods) f.toJson()],
        if (rating != null) 'rating': rating!.name,
        if (symptoms.isNotEmpty)
          'symptoms': [
            for (final s in Symptom.values)
              if (symptoms.contains(s)) s.name,
          ],
        if (note.isNotEmpty) 'note': note,
      };

  /// An unknown kind reads as a snack; unknown ratings and symptoms (from
  /// a newer app) are skipped.
  factory Meal.fromJson(Map<String, dynamic> json) => Meal(
        id: json['id'] as String,
        at: DateTime.parse(json['at'] as String),
        kind: MealKind.fromId(json['kind'] as String?) ?? MealKind.snack,
        foods: [
          for (final f in json['foods'] as List<dynamic>? ?? const [])
            MealFood.fromJson(f as Map<String, dynamic>),
        ],
        rating: MealRating.fromId(json['rating'] as String?),
        symptoms: {
          for (final s in json['symptoms'] as List<dynamic>? ?? const [])
            if (Symptom.fromId(s as String) case final symptom?) symptom,
        },
        note: json['note'] as String? ?? '',
      );
}

/// Everything the food tracker holds: the foods, and the meals (in the
/// order they were eaten).
class FoodBook {
  final List<Food> foods;
  final List<Meal> meals;

  const FoodBook._(this.foods, this.meals);

  FoodBook({required List<Food> foods, required List<Meal> meals})
      : foods = List.unmodifiable(foods),
        meals =
            List.unmodifiable([...meals]..sort((a, b) => a.at.compareTo(b.at)));

  static const empty = FoodBook._([], []);

  /// Foods and meals, for counting (Clear data).
  int get size => foods.length + meals.length;

  Food? foodById(String id) => foods.where((f) => f.id == id).firstOrNull;

  /// The food called [name] (any case), or null.
  Food? foodNamed(String name) {
    final wanted = name.trim().toLowerCase();
    return foods.where((f) => f.name.toLowerCase() == wanted).firstOrNull;
  }

  Meal? mealById(String id) => meals.where((m) => m.id == id).firstOrNull;

  /// The meals eaten on [day], in order.
  List<Meal> mealsOn(DateTime day) => [
        for (final m in meals)
          if (m.isOn(day)) m,
      ];

  /// The worst rating of [day]'s meals, or null if none is rated.
  MealRating? worstOn(DateTime day) {
    MealRating? worst;
    for (final m in mealsOn(day)) {
      final r = m.rating;
      if (r != null && (worst == null || r.index > worst.index)) worst = r;
    }
    return worst;
  }

  /// The foods, most eaten first (ties by name).
  List<Food> get foodsByUse {
    final uses = <String, int>{};
    for (final m in meals) {
      for (final f in m.foods) {
        if (f.foodId != null) uses[f.foodId!] = (uses[f.foodId!] ?? 0) + 1;
      }
    }
    return [...foods]..sort((a, b) {
        final byUse = (uses[b.id] ?? 0).compareTo(uses[a.id] ?? 0);
        return byUse != 0
            ? byUse
            : a.name.toLowerCase().compareTo(b.name.toLowerCase());
      });
  }

  Map<String, dynamic> toJson() => {
        'foods': [for (final f in foods) f.toJson()],
        'meals': [for (final m in meals) m.toJson()],
      };

  factory FoodBook.fromJson(Map<String, dynamic> json) => FoodBook(
        foods: [
          for (final f in json['foods'] as List<dynamic>? ?? const [])
            Food.fromJson(f as Map<String, dynamic>),
        ],
        meals: [
          for (final m in json['meals'] as List<dynamic>? ?? const [])
            Meal.fromJson(m as Map<String, dynamic>),
        ],
      );
}
