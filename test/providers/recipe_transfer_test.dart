import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:the_app/core/clock.dart';
import 'package:the_app/data/app_storage.dart';
import 'package:the_app/models/recipe.dart';
import 'package:the_app/providers/recipe_transfer.dart';
import 'package:the_app/providers/recipes_provider.dart';

/// Round 104 (Nikola): recipes as text: export for import, export for
/// ChatGPT, import (paste).
void main() {
  late ProviderContainer container;

  setUp(() {
    container = ProviderContainer(overrides: [
      appStorageProvider.overrideWithValue(AppStorage.inMemory()),
      clockProvider.overrideWithValue(() => DateTime(2026, 10, 26, 12)),
    ]);
    addTearDown(container.dispose);
  });

  RecipesNotifier recipes() => container.read(recipesProvider.notifier);
  IngredientsNotifier ingredients() =>
      container.read(ingredientsProvider.notifier);
  IngredientBook book() => container.read(ingredientsProvider);

  final sampleBook = IngredientBook([
    IngredientSection(id: 's1', name: 'Ingredients', items: const [
      Ingredient(id: 'i1', name: 'Flour'),
    ]),
    IngredientSection(id: 's2', name: 'Dairy', items: const [
      Ingredient(id: 'i2', name: 'Eggs'),
      Ingredient(id: 'i3', name: 'Milk'),
    ]),
  ]);

  final pancakes = Recipe(
    id: 'r1',
    name: 'Pancakes',
    prepMinutes: 25,
    type: RecipeType.breakfast,
    ingredients: const [
      RecipeIngredient(ingredientId: 'i1', name: 'Flour', quantity: '200 g'),
      RecipeIngredient(ingredientId: 'i2', name: 'Eggs', quantity: '2'),
      RecipeIngredient(name: 'Salt'),
    ],
    method: '1. Mix\n2. Fry',
    createdAt: DateTime(2026, 10, 14),
  );

  test('export for import: the recipe, each ingredient with its section', () {
    final json = jsonDecode(exportRecipe(pancakes, sampleBook));
    expect(json['format'], recipeFormat);
    expect(json['version'], recipeFormatVersion);
    expect(json['recipe'], {
      'name': 'Pancakes',
      'prepMinutes': 25,
      'type': 'breakfast',
      'ingredients': [
        {'name': 'Flour', 'quantity': '200 g', 'section': 'Ingredients'},
        {'name': 'Eggs', 'quantity': '2', 'section': 'Dairy'},
        {'name': 'Salt'},
      ],
      'method': '1. Mix\n2. Fry',
    });
  });

  test('and back: the same recipe', () {
    final back = parseRecipe(exportRecipe(pancakes, sampleBook));
    expect(back.name, 'Pancakes');
    expect(back.prepMinutes, 25);
    expect(back.type, RecipeType.breakfast);
    expect(back.method, '1. Mix\n2. Fry');
    expect(back.ingredients, [
      (name: 'Flour', quantity: '200 g', section: 'Ingredients'),
      (name: 'Eggs', quantity: '2', section: 'Dairy'),
      (name: 'Salt', quantity: '', section: null),
    ]);
  });

  test(
      'export for agents: what to answer, the rules, his ingredients by '
      'section, the example', () {
    final text = exportForAgent(pancakes, sampleBook);
    expect(text, contains('only the new recipe as JSON'));
    expect(text, contains('"format" is "$recipeFormat"'));
    for (final t in RecipeType.values) {
      expect(text, contains(t.name));
    }
    expect(text, contains('- Ingredients: Flour'));
    expect(text, contains('- Dairy: Eggs, Milk'));
    expect(text, contains(exportRecipe(pancakes, sampleBook)));
    // The example in it reads back as the recipe.
    expect(
        parseRecipe(text.substring(text.indexOf('Example:'))).name, 'Pancakes');
  });

  group('import reads', () {
    test("an agent's answer: words and a code fence around it", () {
      final r = parseRecipe('Sure! Here it is:\n```json\n'
          '{"format": "$recipeFormat", "version": 1, "recipe": '
          '{"name": " Crepes ", "prepMinutes": 20.4, "type": "snack", '
          '"ingredients": [{"name": "Flour", "quantity": 150, '
          '"section": "Ingredients"}, {"name": " "}, "junk"], '
          '"method": "1. Mix"}}\n```\nEnjoy!');
      expect(r.name, 'Crepes');
      expect(r.prepMinutes, 20);
      expect(r.type, RecipeType.snack);
      expect(r.ingredients,
          [(name: 'Flour', quantity: '150', section: 'Ingredients')]);
    });

    test('the recipe on its own; an unknown type and time left out', () {
      final r = parseRecipe('{"name": "Tea", "type": "brunch", '
          '"prepMinutes": "soon"}');
      expect(r.name, 'Tea');
      expect(r.type, isNull);
      expect(r.prepMinutes, isNull);
      expect(r.ingredients, isEmpty);
      expect(r.method, '');
    });

    test('says why it can\'t', () {
      String why(String text) {
        try {
          parseRecipe(text);
        } on FormatException catch (e) {
          return e.message;
        }
        return 'read';
      }

      expect(why('hello'), 'No recipe in the copied text.');
      expect(why('{"name": "x",'), 'No recipe in the copied text.');
      expect(why('{not json}'), "The copied text isn't a readable recipe.");
      expect(why('{"format": "other", "name": "x"}'),
          "The copied text isn't a recipe.");
      expect(why('{"format": "$recipeFormat", "version": 2, "recipe": {}}'),
          contains('newer version'));
      expect(why('{"recipe": {"name": "  "}}'), 'The recipe has no name.');
      expect(why('{"recipe": [1]}'), 'No recipe in the copied text.');
    });
  });

  test(
      'what it adds: new ingredients, to their section (new or not); the '
      'ones there (any case) not again', () {
    final r = parseRecipe('{"name": "Cake", "ingredients": ['
        '{"name": "flour"}, {"name": "Butter", "section": "dairy"}, '
        '{"name": "Vanilla", "section": "Baking"}, '
        '{"name": "Cocoa", "section": "Baking"}, {"name": "Water"}, '
        '{"name": "butter"}]}');
    expect(newIngredients(r, sampleBook), [
      (name: 'Butter', section: 'dairy', newSection: false),
      (name: 'Vanilla', section: 'Baking', newSection: true),
      (name: 'Cocoa', section: 'Baking', newSection: false),
      (name: 'Water', section: 'Ingredients', newSection: false),
    ]);
  });

  test(
      'importing: a new recipe on top, linked to the ingredients, new ones '
      'added to their sections', () {
    ingredients().replaceAll(sampleBook);
    recipes().replaceAll([pancakes]);
    final r = parseRecipe('{"name": "Cake", "prepMinutes": 50, '
        '"type": "cake", "method": "Bake", "ingredients": ['
        '{"name": "flour", "quantity": "300 g"}, '
        '{"name": "Butter", "quantity": "100 g", "section": "Dairy"}, '
        '{"name": "Vanilla", "section": "Baking"}, {"name": "Water"}]}');
    final id = importRecipe(r, recipes: recipes(), ingredients: ingredients());

    final all = container.read(recipesProvider);
    expect(all.map((r) => r.name), ['Cake', 'Pancakes']);
    final cake = all.first;
    expect(cake.id, id);
    expect(cake.id, isNot('r1'));
    expect(cake.prepMinutes, 50);
    expect(cake.type, RecipeType.cake);
    expect(cake.method, 'Bake');
    expect(cake.ingredients.map((i) => (i.name, i.quantity)), [
      ('flour', '300 g'),
      ('Butter', '100 g'),
      ('Vanilla', ''),
      ('Water', ''),
    ]);
    expect(cake.ingredients.first.ingredientId, 'i1', reason: 'Flour');
    for (final i in cake.ingredients) {
      expect(book().byId(i.ingredientId!)?.name.toLowerCase(),
          i.name.toLowerCase());
    }
    final sections = {
      for (final s in book().sections) s.name: s.items.map((i) => i.name)
    };
    expect(sections['Ingredients'], ['Water', 'Flour']);
    expect(sections['Dairy'], ['Butter', 'Eggs', 'Milk']);
    expect(sections['Baking'], ['Vanilla']);
  });
}
