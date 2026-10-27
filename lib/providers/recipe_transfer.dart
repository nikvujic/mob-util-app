import 'dart:convert';

import 'package:the_app/models/recipe.dart';
import 'package:the_app/providers/recipes_provider.dart';

/// Recipes as text, to copy and paste (Round 104, Nikola): **export for
/// import** (a recipe someone else pastes in), **export for an agent** (a
/// recipe as an example, with the rules, so an AI agent writes a new one in
/// the same shape) and **import** (pasted text: a new recipe, ingredients
/// it names that aren't there yet added to their sections).

/// What the text says it is, and its shape's version.
const recipeFormat = 'the-app/recipe';
const recipeFormatVersion = 1;

/// [recipe] as JSON text to import elsewhere; each ingredient with its
/// section in [book] (if it has one).
String exportRecipe(Recipe recipe, IngredientBook book) =>
    const JsonEncoder.withIndent('  ').convert({
      'format': recipeFormat,
      'version': recipeFormatVersion,
      'recipe': _recipeJson(recipe, book),
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

/// [recipe] as an example for an AI agent (ChatGPT, Claude, ...): what the text is, the
/// rules of its shape, the ingredients already there by section, and the
/// example; the user adds what new recipe they want.
String exportForAgent(Recipe recipe, IngredientBook book) {
  final sections = [
    for (final s in book.sections)
      if (s.items.isNotEmpty)
        '- ${s.name}: ${s.items.map((i) => i.name).join(', ')}',
  ];
  return [
    'This is a recipe exported from my recipe app, as JSON. I will ask '
        'you for a new recipe. Answer with only the new recipe as JSON in '
        'exactly this shape (one code block, nothing else), so I can paste '
        'it into the app.',
    'Rules:\n'
        '- "format" is "$recipeFormat" and "version" is '
        '$recipeFormatVersion.\n'
        '- "prepMinutes" is a whole number of minutes (leave it out if '
        'unknown).\n'
        '- "type" is one of: '
        '${RecipeType.values.map((t) => t.name).join(', ')} (or leave it '
        'out).\n'
        '- Each ingredient has a "name", a "quantity" as short free text '
        '(e.g. "200 g", "2", "1 tbsp", "a pinch") and a "section".\n'
        '- Use the ingredient names I already have (below) when they fit, '
        'with their section; a new ingredient goes in the section it fits, '
        'or a new section.\n'
        '- "method" is the steps in Markdown, one numbered step per line.',
    if (sections.isNotEmpty)
      'My ingredients by section:\n${sections.join('\n')}',
    'Example:\n${exportRecipe(recipe, book)}',
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

/// Reads a recipe from pasted [text]: the JSON as exported (with or
/// without "format", the recipe on its own too), even with words or a
/// code fence around it (as an agent writes it). Throws a
/// [FormatException] saying what's wrong.
RecipeImport parseRecipe(String text) {
  final start = text.indexOf('{'), end = text.lastIndexOf('}');
  if (start < 0 || end < start) {
    throw const FormatException('No recipe in the copied text.');
  }
  final Object? decoded;
  try {
    decoded = jsonDecode(text.substring(start, end + 1));
  } on FormatException {
    throw const FormatException('The copied text isn\'t a readable recipe.');
  }
  if (decoded is! Map<String, dynamic>) {
    throw const FormatException('No recipe in the copied text.');
  }
  final format = decoded['format'];
  if (format != null && format != recipeFormat) {
    throw const FormatException('The copied text isn\'t a recipe.');
  }
  final version = decoded['version'];
  if (version is int && version > recipeFormatVersion) {
    throw const FormatException(
        'This recipe is from a newer version of the app. Update it first.');
  }
  final json = decoded['recipe'] ?? decoded;
  if (json is! Map<String, dynamic>) {
    throw const FormatException('No recipe in the copied text.');
  }
  final name = json['name'];
  if (name is! String || name.trim().isEmpty) {
    throw const FormatException('The recipe has no name.');
  }
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
