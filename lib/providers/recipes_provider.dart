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

  /// Round 104: a whole new recipe at the top (imported); returns its id.
  String addWhole({
    required String name,
    int? prepMinutes,
    RecipeType? type,
    List<RecipeIngredient> ingredients = const [],
    String method = '',
  }) {
    final recipe = Recipe(
      id: generateId(),
      name: name,
      prepMinutes: prepMinutes,
      type: type,
      ingredients: ingredients,
      method: method,
      createdAt: _now(),
    );
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
      : super(_firstOnTop(storage.initialIngredients)) {
    addListener(storage.saveIngredients, fireImmediately: false);
  }

  /// The first section (Round 43): the default one, "Ingredients", which
  /// stays at the top; new sections go under it. An empty list makes it
  /// when the first ingredient or section is added.
  static const firstSectionName = 'Ingredients';

  /// 1.9.0 put new sections on top: its "Ingredients" goes back up.
  static IngredientBook _firstOnTop(IngredientBook book) {
    final at = book.sections.indexWhere((s) => s.name == firstSectionName);
    if (at <= 0) return book;
    final sections = [...book.sections];
    return IngredientBook([sections.removeAt(at), ...sections]);
  }

  /// The sections, with the first one made if there's none.
  List<IngredientSection> _withFirst() => state.sections.isEmpty
      ? [IngredientSection(id: generateId(), name: firstSectionName)]
      : state.sections;

  /// The ingredient called [name] (Round 92: case and spaces aside) and
  /// its section, other than [except]; null if there's none.
  (Ingredient, IngredientSection)? named(String name, {String? except}) {
    final key = ingredientKey(name);
    for (final s in state.sections) {
      for (final i in s.items) {
        if (i.id != except && ingredientKey(i.name) == key) return (i, s);
      }
    }
    return null;
  }

  /// Adds [name] at the top of the first section (made if there's none);
  /// returns its id, or null for a blank name or one already there
  /// (Round 92: no two of the same).
  String? add(String name) {
    final trimmed = name.trim();
    if (trimmed.isEmpty || named(trimmed) != null) return null;
    final item = Ingredient(id: generateId(), name: trimmed);
    final sections = _withFirst();
    state = IngredientBook([
      sections.first.copyWith(items: [item, ...sections.first.items]),
      ...sections.skip(1),
    ]);
    return item.id;
  }

  /// Round 104 (an imported recipe): the id of the ingredient called
  /// [name], added at the top of the section called [section] (made, as
  /// a new section, if there's none; the first section if null) when
  /// it isn't there yet.
  String ensure(String name, {String? section}) {
    if (named(name) case (final item, _)) return item.id;
    final id = add(name)!;
    final wanted = section?.trim().toLowerCase();
    if (wanted == null || wanted == state.sections.first.name.toLowerCase()) {
      return id;
    }
    final sectionId = state.sections
            .where((s) => s.name.toLowerCase() == wanted)
            .firstOrNull
            ?.id ??
        addSection(section!)!;
    move(id, sectionId: sectionId, index: 0);
    return id;
  }

  /// A new section just under the first one (Round 43); returns its id,
  /// or null for a blank name.
  String? addSection(String name) {
    final trimmed = name.trim();
    if (trimmed.isEmpty) return null;
    final section = IngredientSection(id: generateId(), name: trimmed);
    final sections = _withFirst();
    state = IngredientBook([sections.first, section, ...sections.skip(1)]);
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
  /// above. The first one stays (Round 43). Returns the book as it was
  /// (for Undo), or null if nothing changed.
  IngredientBook? deleteSection(String id) {
    final sections = [...state.sections];
    final index = sections.indexWhere((s) => s.id == id);
    if (index < 1) return null;
    final items = sections[index].items;
    final before = state;
    sections.removeAt(index);
    final target = sections[index - 1];
    sections[index - 1] = target.copyWith(items: [...target.items, ...items]);
    state = IngredientBook(sections);
    return before;
  }

  /// Renames an ingredient, here and in the recipes that use it.
  void rename(String id, String name) {
    final trimmed = name.trim();
    if (trimmed.isEmpty || named(trimmed, except: id) != null) return;
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

  /// Moves a whole section to [index] among the sections (Round 43);
  /// never above the first one, which doesn't move.
  void moveSection(String id, int index) {
    final sections = [...state.sections];
    final from = sections.indexWhere((s) => s.id == id);
    if (from < 1) return;
    final section = sections.removeAt(from);
    sections.insert(index.clamp(1, sections.length), section);
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
/// weight, "2" or "3 pcs" a count; anything else ("1 tbsp", "1-2") typed
/// text (Round 70); empty none.
({Quantity? quantity, int count, double grams, String text}) shopQuantityOf(
    String text) {
  final trimmed = text.trim();
  final typed = (
    quantity: trimmed.isEmpty ? null : Quantity.text,
    count: ShopItem.defaultCount,
    grams: ShopItem.defaultGrams,
    text: trimmed,
  );
  final match = _quantity.firstMatch(trimmed.toLowerCase());
  if (match == null) return typed;
  final number = double.tryParse(match[1]!.replaceAll(',', '.'));
  if (number == null || number <= 0) return typed;
  final unit = match[2] ?? '';
  if (unit == 'kg') {
    return (
      quantity: Quantity.weight,
      count: ShopItem.defaultCount,
      grams: number * 1000,
      text: '',
    );
  }
  if (unit.startsWith('g')) {
    return (
      quantity: Quantity.weight,
      count: ShopItem.defaultCount,
      grams: number,
      text: '',
    );
  }
  // A count: whole pieces only.
  if (number != number.roundToDouble()) return typed;
  return (
    quantity: Quantity.count,
    count: number.round().clamp(1, ShopNotifier.maxCount),
    grams: ShopItem.defaultGrams,
    text: '',
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
          Quantity.text => item.text.toLowerCase() == wanted.text.toLowerCase(),
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
    // Another quantity: a copy beside it (Round 58: not moved).
    final id = shop.addItem(name, copy: true);
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
      case Quantity.text:
        shop.setQuantity(id, Quantity.text);
        shop.setText(id, wanted.text);
    }
  }
  return (added: added, putBack: putBack, before: before);
}

/// An ingredient's name as compared (Round 92): no case, single spaces.
String ingredientKey(String name) =>
    name.trim().toLowerCase().replaceAll(RegExp(r'\s+'), ' ');
