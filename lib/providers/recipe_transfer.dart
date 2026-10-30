import 'dart:convert';

import 'package:the_app/models/recipe.dart';
import 'package:the_app/providers/recipes_provider.dart';

/// Recipes as text, to copy and paste (Round 104; Round 131: several at
/// once): **export** (recipes someone else imports), **agent
/// instructions** (the rules and a general example, so an AI agent writes
/// recipes to import) and **import** (pasted text: new recipes, the
/// ingredients they name that aren't there yet added to their sections).

/// What the text says it is, and its shape's version (Round 131: 2, a
/// list; 1, one recipe, still read).
const recipesFormat = 'the-app/recipes';
const recipeFormat = 'the-app/recipe';
const recipeFormatVersion = 2;

/// [recipes] as JSON text to import elsewhere; each ingredient with its
/// section in [book] (if it has one).
String exportRecipes(List<Recipe> recipes, IngredientBook book) =>
    const JsonEncoder.withIndent('  ').convert({
      'format': recipesFormat,
      'version': recipeFormatVersion,
      'recipes': [for (final r in recipes) _recipeJson(r, book)],
    });

Map<String, dynamic> _recipeJson(Recipe recipe, IngredientBook book) => {
      'name': recipe.name,
      if (recipe.prepMinutes != null) 'prepMinutes': recipe.prepMinutes,
      if (recipe.type != null) 'type': recipe.type!.name,
      'ingredients': [
        for (final i in recipe.ingredients)
          {
            'name': i.name,
            if (i.quantity.isNotEmpty) 'quantity': i.quantity,
            if (_sectionOf(i, book) case final section?) 'section': section,
          },
      ],
      'method': recipe.method,
    };

String? _sectionOf(RecipeIngredient ingredient, IngredientBook book) {
  final key = ingredientKey(ingredient.name);
  for (final s in book.sections) {
    for (final i in s.items) {
      if (i.id == ingredient.ingredientId || ingredientKey(i.name) == key) {
        return s.name;
      }
    }
  }
  return null;
}

/// The general example in [agentInstructions]: its method shows the
/// shape and the detail wanted (optional extras, numbered stages of short
/// steps, tips).
const exampleMethod = """### Optional
* A little black pepper
* Parsley (fresh or dried)
* 1 small onion
* 1 clove of garlic
* A little ground paprika

### Method

### 1. Preparing the vegetables
* Wash the carrots, potatoes and tomato.
* Peel the carrots and cut them into rounds about 0.5–1 cm thick.
* Peel the potatoes and cut them into cubes of about 2 cm.
* Cut the tomato into small cubes. There's no need to peel it.

### 2. Preparing the chicken
* Cut the chicken into cubes of about 2–3 cm.
* Trim off any extra fat if needed.

### 3. Cooking the chicken
* Pour about 1.5 l of cold water into a large pot.
* Add the chopped chicken.
* Turn the heat up high and wait for the water to boil.
* Once it boils, skim off any foam that comes up with a spoon.
* Turn the heat down so the water simmers gently.
* Cook for about 15 minutes.

### 4. Adding the vegetables
* Add the carrots and potatoes to the pot.
* Add the chopped tomato (it can also go in 10 minutes later).
* Add about half a teaspoon of salt.
* If you like, add a little pepper or other optional spices.
* Stir, and add a little water if needed so the vegetables are covered.

### 5. Cooking the soup
* Keep cooking on low to medium heat for another 25–30 minutes, stirring now and then.
* The soup should simmer gently, not boil hard.
* Check the potatoes are soft by piercing a piece with a fork.
* If the fork goes through easily, the vegetables are done. If they're still hard, cook another 5–10 minutes.
* Check the chicken is cooked through.
* Taste the soup and add a little more salt if needed.

### 6. Thickening the soup (optional)
* Take out a few pieces of cooked potato.
* Mash them with a fork on a plate.
* Put the mashed potato back into the pot.
* Stir well and cook for another 2–3 minutes.
* Repeat if needed until it's as thick as you like.

### Tips
* Thickness: for a thicker soup, mash some of the potato instead of adding flour or oil.
* Salt: start with less and add more near the end if needed.
* Chicken: skinless meat is a good choice for a lighter soup.
* Water: if too much water cooks off, add a little hot water.
* Keeping: put leftover soup in the fridge within 2 hours of cooking. It keeps 3–4 days.
* Reheating: reheat only as much as will be eaten, until it's piping hot.""";

/// The example recipe in [agentInstructions].
final exampleRecipe = Recipe(
  id: 'example',
  name: 'Chicken and vegetable soup',
  prepMinutes: 60,
  type: RecipeType.lunch,
  ingredients: const [
    RecipeIngredient(name: 'Chicken breast', quantity: '400 g'),
    RecipeIngredient(name: 'Carrots', quantity: '2'),
    RecipeIngredient(name: 'Potatoes', quantity: '3 medium'),
    RecipeIngredient(name: 'Tomato', quantity: '1'),
    RecipeIngredient(name: 'Salt', quantity: '1/2 tsp'),
    RecipeIngredient(name: 'Water', quantity: '1.5 l'),
  ],
  method: exampleMethod,
  createdAt: DateTime(2026),
);

/// Round 131: the rules for an AI agent (ChatGPT, Claude, ...) to write
/// recipes to import: the JSON's shape, the ingredients already in
/// [book] by section, how a method is written, and a general example
/// (no recipe of the user's picked). The user adds what they want.
String agentInstructions(IngredientBook book) {
  final sections = [
    for (final s in book.sections)
      if (s.items.isNotEmpty)
        '- ${s.name}: ${s.items.map((i) => i.name).join(', ')}',
  ];
  final example = const JsonEncoder.withIndent('  ').convert({
    'format': recipesFormat,
    'version': recipeFormatVersion,
    'recipes': [
      {
        ..._recipeJson(exampleRecipe, IngredientBook(const [])),
        'ingredients': [
          for (final (i, section) in [
            (exampleRecipe.ingredients[0], 'Meat'),
            (exampleRecipe.ingredients[1], 'Vegetables'),
            (exampleRecipe.ingredients[2], 'Vegetables'),
            (exampleRecipe.ingredients[3], 'Vegetables'),
            (exampleRecipe.ingredients[4], 'Spices'),
            (exampleRecipe.ingredients[5], 'Other'),
          ])
            {'name': i.name, 'quantity': i.quantity, 'section': section},
        ],
      },
    ],
  });
  return [
    'You write recipes for my recipe app. I will ask you for one or more '
        'recipes. Answer with only the recipes as JSON in exactly the shape '
        'below (one code block, nothing else), so I can paste them into the '
        'app. Write the recipes in the language I ask you in.',
    'Rules:\n'
        '- "format" is "$recipesFormat" and "version" is '
        '$recipeFormatVersion; "recipes" is a list (one recipe or more).\n'
        '- "name" is the recipe\'s name.\n'
        '- "prepMinutes" is the whole time in minutes, a whole number (leave '
        'it out if unknown).\n'
        '- "type" is one of: '
        '${RecipeType.values.map((t) => t.name).join(', ')} (or leave it '
        'out).\n'
        '- "ingredients": what\'s needed, each with a "name", a "quantity" '
        'as short free text (e.g. "200 g", "2", "1 tbsp", "a pinch") and a '
        '"section". Optional extras (spices to taste, garnish) are not '
        'ingredients: they go under "### Optional" in the method.\n'
        '- Use the ingredient names I already have (below) when they fit, '
        'with their section; a new ingredient goes in the section it fits, '
        'or a new section.\n'
        '- "method" is Markdown in one JSON string (line breaks as \\n), in '
        'this order: "### Optional" with the optional extras as "* " bullets '
        '(leave it out if there are none); "### Method"; then the stages, '
        'each a "### " heading numbered "1.", "2.", ... with short, '
        'concrete steps as "* " bullets (sizes, amounts, times, heat, how '
        'to tell it\'s done); then "### Tips" with "* Topic: tip" bullets '
        '(e.g. thickness, salt, keeping, reheating).\n'
        '- Be as detailed as the example: someone who rarely cooks should '
        'manage from it alone.',
    if (sections.isNotEmpty)
      'My ingredients by section:\n${sections.join('\n')}',
    'Example:\n$example',
  ].join('\n\n');
}

/// One ingredient of an imported recipe.
typedef ImportedIngredient = ({String name, String quantity, String? section});

/// A recipe read from pasted text, not yet added.
class RecipeImport {
  final String name;
  final int? prepMinutes;
  final RecipeType? type;
  final List<ImportedIngredient> ingredients;
  final String method;

  const RecipeImport({
    required this.name,
    this.prepMinutes,
    this.type,
    this.ingredients = const [],
    this.method = '',
  });
}

/// Reads the recipes in pasted [text]: as exported (a list; Round 104's
/// one recipe too), a list on its own, or a recipe on its own, even with
/// words or a code fence around it (as an agent writes it). Ones with no
/// name are left out. Throws a [FormatException] saying what's wrong.
List<RecipeImport> parseRecipes(String text) {
  final open = [text.indexOf('{'), text.indexOf('[')].where((i) => i >= 0);
  if (open.isEmpty) {
    throw const FormatException('No recipes in the copied text.');
  }
  final start = open.reduce((a, b) => a < b ? a : b);
  final end = text.lastIndexOf(text[start] == '{' ? '}' : ']');
  if (end < start) {
    throw const FormatException('No recipes in the copied text.');
  }
  final Object? decoded;
  try {
    decoded = jsonDecode(text.substring(start, end + 1));
  } on FormatException {
    throw const FormatException("The copied text isn't readable recipes.");
  }
  final Object? list;
  if (decoded is List) {
    list = decoded;
  } else if (decoded is Map<String, dynamic>) {
    final format = decoded['format'];
    if (format != null && format != recipesFormat && format != recipeFormat) {
      throw const FormatException("The copied text isn't recipes.");
    }
    final version = decoded['version'];
    if (version is int && version > recipeFormatVersion) {
      throw const FormatException(
          'These recipes are from a newer version of the app. Update it '
          'first.');
    }
    list = decoded['recipes'] ??
        (decoded['recipe'] != null ? [decoded['recipe']] : [decoded]);
  } else {
    list = null;
  }
  if (list is! List) {
    throw const FormatException('No recipes in the copied text.');
  }
  final recipes = [
    for (final r in list)
      if (r is Map<String, dynamic>) _readRecipe(r),
  ].whereType<RecipeImport>().toList();
  if (recipes.isEmpty) {
    throw const FormatException('No recipes with a name in the copied text.');
  }
  return recipes;
}

RecipeImport? _readRecipe(Map<String, dynamic> json) {
  final name = json['name'];
  if (name is! String || name.trim().isEmpty) return null;
  final minutes = json['prepMinutes'];
  final ingredients = <ImportedIngredient>[];
  for (final i in json['ingredients'] as List<dynamic>? ?? const []) {
    if (i is! Map<String, dynamic>) continue;
    final n = i['name'];
    if (n is! String || n.trim().isEmpty) continue;
    final section = i['section'];
    ingredients.add((
      name: n.trim(),
      quantity: '${i['quantity'] ?? ''}'.trim(),
      section: section is String && section.trim().isNotEmpty
          ? section.trim()
          : null,
    ));
  }
  final method = json['method'];
  return RecipeImport(
    name: name.trim(),
    prepMinutes: minutes is num && minutes > 0 ? minutes.round() : null,
    type: RecipeType.fromId(json['type'] as String?),
    ingredients: ingredients,
    method: method is String ? method.trim() : '',
  );
}

/// What importing [recipe] adds to [book]: each new ingredient, with the
/// section it goes in and whether that section is new too.
List<({String name, String section, bool newSection})> newIngredients(
    RecipeImport recipe, IngredientBook book) {
  final known = {for (final i in book.all) ingredientKey(i.name)};
  final sections = {for (final s in book.sections) s.name.toLowerCase()};
  final added = <({String name, String section, bool newSection})>[];
  for (final i in recipe.ingredients) {
    final key = ingredientKey(i.name);
    if (!known.add(key)) continue;
    final section = i.section ?? IngredientsNotifier.firstSectionName;
    added.add((
      name: i.name,
      section: section,
      newSection: !sections.contains(section.toLowerCase()),
    ));
    sections.add(section.toLowerCase());
  }
  return added;
}

/// Adds [recipe] as a new recipe at the top, its new ingredients added to
/// the ingredients list first; returns its id.
String importRecipe(RecipeImport recipe,
    {required RecipesNotifier recipes,
    required IngredientsNotifier ingredients}) {
  final lines = [
    for (final i in recipe.ingredients)
      RecipeIngredient(
        ingredientId: ingredients.ensure(i.name, section: i.section),
        name: i.name,
        quantity: i.quantity,
      ),
  ];
  return recipes.addWhole(
    name: recipe.name,
    prepMinutes: recipe.prepMinutes,
    type: recipe.type,
    ingredients: lines,
    method: recipe.method,
  );
}
