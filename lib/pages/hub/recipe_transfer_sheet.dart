import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:the_app/core/theme.dart';
import 'package:the_app/models/recipe.dart';
import 'package:the_app/pages/hub/recipe_page.dart' show showChoicesSheet;
import 'package:the_app/providers/recipe_transfer.dart';
import 'package:the_app/providers/recipes_provider.dart';
import 'package:the_app/widgets/confirm_dialog.dart';

/// Round 104 (Nikola): the Recipes page's Import / export button. Import
/// pastes a recipe (a new one); the exports copy a picked recipe, for
/// someone to import or for an AI agent to write a new one like it.
Future<void> showRecipeTransfer(BuildContext context, WidgetRef ref) async {
  final choice = await showChoicesSheet(context, 'Import / export', const [
    (Icons.content_paste, 'Import (paste)', 'import'),
    (Icons.ios_share, 'Export for import', 'export'),
    (Icons.smart_toy_outlined, 'Export for agents', 'agent'),
  ]);
  if (choice == null || !context.mounted) return;
  if (choice == 'import') return _import(context, ref);

  final recipes = ref.read(recipesProvider);
  if (recipes.isEmpty) return _toast(context, 'No recipes to export');
  final recipe = await _pickRecipe(context, recipes);
  if (recipe == null || !context.mounted) return;
  final book = ref.read(ingredientsProvider);
  final agent = choice == 'agent';
  await Clipboard.setData(ClipboardData(
      text: agent ? exportForAgent(recipe, book) : exportRecipe(recipe, book)));
  if (context.mounted) {
    _toast(
        context,
        agent
            ? 'Copied for agents: ${_named(recipe)}'
            : 'Copied: ${_named(recipe)}');
  }
}

String _named(Recipe recipe) =>
    recipe.name.trim().isEmpty ? 'Untitled' : recipe.name.trim();

void _toast(BuildContext context, String message) =>
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));

/// Which recipe to export: a list in a bottom sheet (capped in height,
/// scrolled when long).
Future<Recipe?> _pickRecipe(BuildContext context, List<Recipe> recipes) =>
    showModalBottomSheet<Recipe>(
      context: context,
      isScrollControlled: true,
      builder: (context) => SafeArea(
        child: ConstrainedBox(
          constraints: BoxConstraints(
              maxHeight: MediaQuery.sizeOf(context).height * 0.7),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                child: Text(
                  'Export which recipe?',
                  style: TextStyle(
                      color: context.colors.textSecondary, fontSize: 14),
                ),
              ),
              Flexible(
                child: ListView(
                  shrinkWrap: true,
                  children: [
                    for (final recipe in recipes)
                      ListTile(
                        key: Key('exportRecipe-${recipe.id}'),
                        leading: const Icon(Icons.menu_book_outlined),
                        title: Text(_named(recipe),
                            maxLines: 1, overflow: TextOverflow.ellipsis),
                        onTap: () => Navigator.of(context).pop(recipe),
                      ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );

Future<void> _import(BuildContext context, WidgetRef ref) async {
  final text = (await Clipboard.getData(Clipboard.kTextPlain))?.text ?? '';
  if (!context.mounted) return;
  if (text.trim().isEmpty) {
    return _toast(context, 'Copy a recipe first, then import');
  }
  final RecipeImport recipe;
  try {
    recipe = parseRecipe(text);
  } on FormatException catch (e) {
    return _toast(context, e.message);
  }
  final added = newIngredients(recipe, ref.read(ingredientsProvider));
  final count = recipe.ingredients.length;
  final confirmed = await showConfirmDialog(
    context,
    title: 'Import "${recipe.name}"?',
    message: [
      count == 1 ? '1 ingredient.' : '$count ingredients.',
      if (added.isNotEmpty)
        'New to your ingredients:\n${[
          for (final a in added)
            '• ${a.name} (${a.newSection ? 'new section ' : ''}${a.section})',
        ].join('\n')}',
    ].join('\n\n'),
    confirmLabel: 'Import',
  );
  if (!confirmed || !context.mounted) return;
  importRecipe(recipe,
      recipes: ref.read(recipesProvider.notifier),
      ingredients: ref.read(ingredientsProvider.notifier));
  _toast(context, 'Imported: ${recipe.name}');
}
