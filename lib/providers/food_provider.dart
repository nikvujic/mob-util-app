import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:the_app/core/id.dart';
import 'package:the_app/data/app_storage.dart';
import 'package:the_app/models/food.dart';

/// The food tracker (O14, Round 46), saved to `food.json`.
class FoodNotifier extends StateNotifier<FoodBook> {
  FoodNotifier(AppStorage storage) : super(storage.initialFood) {
    addListener(storage.saveFood, fireImmediately: false);
  }

  /// The food called [name] (any case), added to the list if new; null
  /// for a blank name.
  Food? foodNamed(String name) {
    final trimmed = name.trim();
    if (trimmed.isEmpty) return null;
    final existing = state.foodNamed(trimmed);
    if (existing != null) return existing;
    // Deleted before and back by the same name (Round 49): it takes its
    // old id, so its meals (which kept it) are its own again.
    final wanted = trimmed.toLowerCase();
    final orphan = [
      for (final m in state.meals.reversed)
        for (final f in m.foods)
          if (f.foodId != null &&
              f.name.toLowerCase() == wanted &&
              state.foodById(f.foodId!) == null)
            f.foodId!,
    ].firstOrNull;
    final food = Food(id: orphan ?? generateId(), name: trimmed);
    state = FoodBook(foods: [...state.foods, food], meals: state.meals);
    return food;
  }

  /// Logs a meal; returns its id.
  String addMeal({
    required DateTime at,
    required MealKind kind,
    required List<MealFood> foods,
  }) {
    final meal = Meal(id: generateId(), at: at, kind: kind, foods: foods);
    state = FoodBook(foods: state.foods, meals: [...state.meals, meal]);
    return meal.id;
  }

  /// [meal] as it is now (rated, or its foods or time changed); added if
  /// it's new (a meal page saves as it goes).
  void saveMeal(Meal meal) {
    if (state.mealById(meal.id) == null) {
      state = FoodBook(foods: state.foods, meals: [...state.meals, meal]);
      return;
    }
    state = FoodBook(foods: state.foods, meals: [
      for (final m in state.meals)
        if (m.id == meal.id) meal else m,
    ]);
  }

  /// Deletes a meal; returns the book before, for Undo.
  FoodBook deleteMeal(String id) {
    final before = state;
    state = FoodBook(foods: state.foods, meals: [
      for (final m in state.meals)
        if (m.id != id) m,
    ]);
    return before;
  }

  /// A new name for a food (blank, or another food's: left as it was);
  /// meals with it take the new name.
  bool renameFood(String id, String name) {
    final trimmed = name.trim();
    final other = state.foodNamed(trimmed);
    if (trimmed.isEmpty || (other != null && other.id != id)) return false;
    state = FoodBook(
      foods: [
        for (final f in state.foods)
          if (f.id == id) f.copyWith(name: trimmed) else f,
      ],
      meals: [
        for (final m in state.meals)
          m.foods.any((f) => f.foodId == id)
              ? m.copyWith(foods: [
                  for (final f in m.foods)
                    f.foodId == id ? MealFood(foodId: id, name: trimmed) : f,
                ])
              : m,
      ],
    );
    return true;
  }

  /// Merges food [fromId] into [intoId] (Round 50: "Egg" and "Eggs"
  /// typed apart): its meals take the other (once per meal), their tags
  /// are joined, and it leaves the list. Returns the book before, for
  /// Undo.
  FoodBook mergeFood(String fromId, String intoId) {
    final before = state;
    final from = state.foodById(fromId);
    final into = state.foodById(intoId);
    if (from == null || into == null || fromId == intoId) return before;
    state = FoodBook(
      foods: [
        for (final f in state.foods)
          if (f.id == intoId)
            f.copyWith(tags: {...f.tags, ...from.tags})
          else if (f.id != fromId)
            f,
      ],
      meals: [
        for (final m in state.meals)
          m.foods.any((f) => f.foodId == fromId)
              ? m.copyWith(foods: _mergedFoods(m.foods, fromId, into))
              : m,
      ],
    );
    return before;
  }

  /// A meal's foods with [fromId] as [into], once.
  static List<MealFood> _mergedFoods(
    List<MealFood> foods,
    String fromId,
    Food into,
  ) {
    final merged = <MealFood>[];
    for (final f in foods) {
      final food =
          f.foodId == fromId ? MealFood(foodId: into.id, name: into.name) : f;
      if (food.foodId == into.id && merged.any((o) => o.foodId == into.id)) {
        continue;
      }
      merged.add(food);
    }
    return merged;
  }

  void setTags(String id, Set<FoodTag> tags) {
    state = FoodBook(foods: [
      for (final f in state.foods)
        if (f.id == id) f.copyWith(tags: tags) else f,
    ], meals: state.meals);
  }

  /// Deletes a food from the list (meals keep its name); returns the book
  /// before, for Undo.
  FoodBook deleteFood(String id) {
    final before = state;
    state = FoodBook(foods: [
      for (final f in state.foods)
        if (f.id != id) f,
    ], meals: state.meals);
    return before;
  }

  /// Replaces everything (restoring a backup, clearing, Undo).
  void replaceAll(FoodBook book) => state = book;
}

final foodProvider = StateNotifierProvider<FoodNotifier, FoodBook>(
  (ref) => FoodNotifier(ref.watch(appStorageProvider)),
);
