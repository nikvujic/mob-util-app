import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:the_app/models/recipe.dart';
import 'package:the_app/providers/recipe_transfer.dart';
import 'package:the_app/providers/recipes_provider.dart';
import 'package:the_app/widgets/transfer_sheet.dart';

/// Round 104: the Recipes page's Import / export (Round 131: in its app
/// bar, the shared sheets): recipes in and out as text, several at once,
/// and the rules for an AI agent to write them.
Future<void> showRecipeTransfer(BuildContext context, WidgetRef ref) =>
    showTransferMenu(context, recipeTransferKit(ref));

TransferKit<Recipe, RecipeImport> recipeTransferKit(WidgetRef ref) =>
    TransferKit(
      one: 'recipe',
      many: 'recipes',
      items: () => ref.read(recipesProvider),
      nameOf: (r) => r.name.trim().isEmpty ? 'Untitled' : r.name.trim(),
      export: (recipes) =>
          exportRecipes(recipes, ref.read(ingredientsProvider)),
      agentInstructions: () => agentInstructions(ref.read(ingredientsProvider)),
      parse: parseRecipes,
      importName: (r) => r.name,
      importDetail: (r) {
        final n = r.ingredients.length;
        final added = newIngredients(r, ref.read(ingredientsProvider));
        return [
          n == 1 ? '1 ingredient' : '$n ingredients',
          if (added.isNotEmpty)
            'New: ${added.map((a) => '${a.name} (${a.newSection ? 'new section ' : ''}${a.section})').join(', ')}',
        ].join(' · ');
      },
      alreadyHere: (r) {
        final name = r.name.toLowerCase();
        return ref
            .read(recipesProvider)
            .any((h) => h.name.trim().toLowerCase() == name);
      },
      importAll: (recipes) {
        // Each goes in at the top: the last first, so they keep their order.
        for (final r in recipes.reversed) {
          importRecipe(r,
              recipes: ref.read(recipesProvider.notifier),
              ingredients: ref.read(ingredientsProvider.notifier));
        }
      },
    );
