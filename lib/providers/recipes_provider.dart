import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:the_app/core/clock.dart';
import 'package:the_app/core/id.dart';
import 'package:the_app/data/app_storage.dart';
import 'package:the_app/models/recipe.dart';
import 'package:the_app/models/shop_item.dart';
import 'package:the_app/providers/shop_provider.dart';

/// The recipes (Round 42), in the user's order, saved to `recipes.json`.
class RecipesNotifier extends StateNotifier<List<Recipe>> {
  final DateTime Function() _now;

  RecipesNotifier(AppStorage storage, this._now)
      : super(storage.initialRecipes) {
    addListener(storage.saveRecipes, fireImmediately: false);
  }

  Recipe? byId(String id) => state.where((r) => r.id == id).firstOrNull;

  /// A new, empty recipe at the top; returns its id.
  String add() {
    final recipe = Recipe(id: generateId(), name: '', createdAt: _now());
    state = [recipe, ...state];
    return recipe.id;
  }

  /// [recipe] as it is now (from its editor); its modified time moves on
  /// only when something changed.
  void save(Recipe recipe) {
    final old = byId(recipe.id);
    if (old == null || old.sameAs(recipe)) return;
    final saved = recipe.copyWith(modifiedAt: _now());
    state = [
      for (final r in state)
        if (r.id == recipe.id) saved else r,
    ];
  }

  /// Puts [recipe] back as it was (Discard changes), times included.
  void restore(Recipe recipe) {
    if (byId(recipe.id) == null) return;
    state = [
      for (final r in state)
        if (r.id == recipe.id) recipe else r,
    ];
  }

  /// A copy of [id] named "… (Copy)", just below it; returns its id.
  String? duplicate(String id) {
    final index = state.indexWhere((r) => r.id == id);
    if (index == -1) return null;
    final now = _now();
    final copy = state[index].copyWith(
      id: generateId(),
      name: '${state[index].name} (Copy)',
      createdAt: now,
      modifiedAt: now,
    );
    state = [...state.take(index + 1), copy, ...state.skip(index + 1)];
    return copy.id;
  }

  /// Removes [ids]; returns what was removed with where it was (for Undo).
  List<(int, Recipe)> remove(Set<String> ids) {
    final removed = [
      for (var i = 0; i < state.length; i++)
        if (ids.contains(state[i].id)) (i, state[i]),
    ];
    if (removed.isNotEmpty) {
      state = [
        for (final r in state)
          if (!ids.contains(r.id)) r,
      ];
    }
    return removed;
  }

  /// Puts back what [remove] removed, where it was.
  void undoRemove(List<(int, Recipe)> removed) {
    final list = [...state];
    for (final (index, recipe) in removed) {
      if (list.any((r) => r.id == recipe.id)) continue;
      list.insert(index.clamp(0, list.length), recipe);
    }
    state = list;
  }

  /// `ReorderableListView.onReorder` semantics.
  void reorder(int oldIndex, int newIndex) {
    if (newIndex > oldIndex) newIndex--;
    if (oldIndex == newIndex) return;
    final list = [...state];
    list.insert(newIndex, list.removeAt(oldIndex));
    state = list;
  }

  /// An ingredient renamed in the list: recipes that use it follow
  /// (decided, Round 41). Their modified times stay.
  void renameIngredient(String ingredientId, String name) {
    if (!state.any((r) => r.ingredients
        .any((i) => i.ingredientId == ingredientId && i.name != name))) {
      return;
    }
    state = [
      for (final r in state)
        r.copyWith(ingredients: [
          for (final i in r.ingredients)
            if (i.ingredientId == ingredientId) i.copyWith(name: name) else i,
        ]),
    ];
  }

  /// Replaces everything (restoring a backup, Clear data).
  void replaceAll(List<Recipe> recipes) => state = List.unmodifiable(recipes);
}

final recipesProvider = StateNotifierProvider<RecipesNotifier, List<Recipe>>(
  (ref) =>
      RecipesNotifier(ref.watch(appStorageProvider), ref.watch(clockProvider)),
);

/// The ingredients list (Round 42), saved to `ingredients.json`.
class IngredientsNotifier extends StateNotifier<IngredientBook> {
  final Ref _ref;

  IngredientsNotifier(this._ref, AppStorage storage)
      : super(storage.initialIngredients) {
    addListener(storage.saveIngredients, fireImmediately: false);
  }

  /// The section an empty list starts with when an ingredient is added.
  static const firstSectionName = 'Ingredients';

  /// Adds [name] at the top of the first section (made if there's none);
  /// returns its id, or null for a blank name.
  String? add(String name) {
    final trimmed = name.trim();
    if (trimmed.isEmpty) return null;
    final item = Ingredient(id: generateId(), name: trimmed);
    final sections = state.sections.isEmpty
        ? [IngredientSection(id: generateId(), name: firstSectionName)]
        : state.sections;
    state = IngredientBook([
      sections.first.copyWith(items: [item, ...sections.first.items]),
      ...sections.skip(1),
    ]);
    return item.id;
  }

  /// A new section at the top; returns its id, or null for a blank name.
  String? addSection(String name) {
    final trimmed = name.trim();
    if (trimmed.isEmpty) return null;
    final section = IngredientSection(id: generateId(), name: trimmed);
    state = IngredientBook([section, ...state.sections]);
    return section.id;
  }

  void renameSection(String id, String name) {
    final trimmed = name.trim();
    if (trimmed.isEmpty) return;
    state = IngredientBook([
      for (final s in state.sections)
        if (s.id == id) s.copyWith(name: trimmed) else s,
    ]);
  }

  /// Deletes a section; its ingredients move to the end of the section
  /// above (the one below for the first). The last section can only go
  /// when it's empty. Returns the book as it was (for Undo), or null if
  /// nothing changed.
  IngredientBook? deleteSection(String id) {
    final sections = [...state.sections];
    final index = sections.indexWhere((s) => s.id == id);
    if (index == -1) return null;
    final items = sections[index].items;
    if (sections.length == 1 && items.isNotEmpty) return null;
    final before = state;
    sections.removeAt(index);
    if (items.isNotEmpty) {
      final into = index == 0 ? 0 : index - 1;
      final target = sections[into];
      sections[into] = target.copyWith(
        items: index == 0
            ? [...items, ...target.items]
            : [...target.items, ...items],
      );
    }
    state = IngredientBook(sections);
    return before;
  }

  /// Renames an ingredient, here and in the recipes that use it.
  void rename(String id, String name) {
    final trimmed = name.trim();
    if (trimmed.isEmpty) return;
    state = IngredientBook([
      for (final s in state.sections)
        s.copyWith(items: [
          for (final i in s.items)
            if (i.id == id) Ingredient(id: id, name: trimmed) else i,
        ]),
    ]);
    _ref.read(recipesProvider.notifier).renameIngredient(id, trimmed);
  }

  /// Deletes an ingredient (recipes keep theirs, Round 41); returns the
  /// book as it was (for Undo).
  IngredientBook delete(String id) {
    final before = state;
    state = IngredientBook([
      for (final s in state.sections)
        s.copyWith(items: [
          for (final i in s.items)
            if (i.id != id) i,
        ]),
    ]);
    return before;
  }

  /// Moves ingredient [id] into section [sectionId] at [index] (its place
  /// there once it's taken out of where it was).
  void move(String id, {required String sectionId, required int index}) {
    final item = state.byId(id);
    if (item == null || !state.sections.any((s) => s.id == sectionId)) {
      return;
    }
    final sections = [
      for (final s in state.sections)
        s.copyWith(items: [
          for (final i in s.items)
            if (i.id != id) i,
        ]),
    ];
    state = IngredientBook([
      for (final s in sections)
        if (s.id == sectionId)
          s.copyWith(
              items: [...s.items]..insert(index.clamp(0, s.items.length), item))
        else
          s,
    ]);
  }

  /// Moves a whole section to [index] among the sections.
  void moveSection(String id, int index) {
    final sections = [...state.sections];
    final from = sections.indexWhere((s) => s.id == id);
    if (from == -1) return;
    final section = sections.removeAt(from);
    sections.insert(index.clamp(0, sections.length), section);
    state = IngredientBook(sections);
  }

  /// Replaces everything (restoring a backup, Clear data, Undo).
  void replaceAll(IngredientBook book) => state = book;
}

final ingredientsProvider =
    StateNotifierProvider<IngredientsNotifier, IngredientBook>(
  (ref) => IngredientsNotifier(ref, ref.watch(appStorageProvider)),
);

/// A recipe's quantity as Shop reads it (Round 41): "200 g" or "1.5 kg" a
/// weight, "2" or "3 pcs" a count; anything else ("1 tbsp", "a pinch")
/// none.
({Quantity? quantity, int count, double grams}) shopQuantityOf(String text) {
  const none = (
    quantity: null,
    count: ShopItem.defaultCount,
    grams: ShopItem.defaultGrams,
  );
  final match = _quantity.firstMatch(text.trim().toLowerCase());
  if (match == null) return none;
  final number = double.tryParse(match[1]!.replaceAll(',', '.'));
  if (number == null || number <= 0) return none;
  final unit = match[2] ?? '';
  if (unit == 'kg') {
    return (
      quantity: Quantity.weight,
      count: ShopItem.defaultCount,
      grams: number * 1000,
    );
  }
  if (unit.startsWith('g')) {
    return (
      quantity: Quantity.weight,
      count: ShopItem.defaultCount,
      grams: number,
    );
  }
  // A count: whole pieces only.
  if (number != number.roundToDouble()) return none;
  return (
    quantity: Quantity.count,
    count: number.round().clamp(1, ShopNotifier.maxCount),
    grams: ShopItem.defaultGrams,
  );
}

final _quantity = RegExp(
  r'^(\d+(?:[.,]\d+)?)\s*(kg|g|gr|grams?|pcs?|pieces?|x|×)?$',
);

/// What [sendToShop] did.
typedef ToShop = ({int added, int putBack, List<ShopItem> before});

/// Puts [recipe]'s ingredients on Shop's to-buy list (Round 41): one with
/// the same name (any case) and the same quantity is put back on the
/// list (or left there); otherwise a new item, a copy beside any with
/// another quantity. [ToShop.before] is Shop as it was, for Undo. [read]
/// is a `ref.read` (or a container's).
ToShop sendToShop(
  T Function<T>(ProviderListenable<T> provider) read,
  Recipe recipe,
) {
  final shop = read(shopProvider.notifier);
  final before = read(shopProvider);
  var added = 0, putBack = 0;
  for (final ingredient in recipe.ingredients) {
    final name = ingredient.name.trim();
    if (name.isEmpty) continue;
    final wanted = shopQuantityOf(ingredient.quantity);
    bool sameQuantity(ShopItem item) =>
        item.quantity == wanted.quantity &&
        switch (wanted.quantity) {
          null => true,
          Quantity.count => item.count == wanted.count,
          Quantity.weight => item.grams == wanted.grams,
        };
    final same = read(shopProvider).where((item) =>
        item.name.toLowerCase() == name.toLowerCase() && sameQuantity(item));
    if (same.isNotEmpty) {
      final item = same.first;
      if (!item.toBuy) {
        shop.toggle(item.id);
        putBack++;
      }
      continue;
    }
    final id = shop.addItem(name);
    if (id == null) continue;
    added++;
    switch (wanted.quantity) {
      case null:
        break;
      case Quantity.count:
        shop.setQuantity(id, Quantity.count);
        shop.setCount(id, wanted.count);
      case Quantity.weight:
        shop.setQuantity(id, Quantity.weight);
        shop.setGrams(id, wanted.grams);
    }
  }
  return (added: added, putBack: putBack, before: before);
}
