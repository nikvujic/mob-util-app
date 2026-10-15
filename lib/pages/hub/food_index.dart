import 'package:flutter/material.dart';
import 'package:the_app/core/theme.dart';
import 'package:the_app/models/recipe.dart';

/// The index under the food field (Round 47): a new name to add, the
/// foods already used, and the recipes' ingredients that aren't foods
/// yet, each in its section. Round 53: at most [maxHeight] tall,
/// scrolling inside when longer.
class FoodIndex extends StatelessWidget {
  final String typed;
  final bool isNew;
  final List<String> foods;
  final List<Recipe> recipes;
  final ValueChanged<Recipe> onRecipe;
  final List<String> ingredients;
  final ValueChanged<String> onPick;

  const FoodIndex({
    super.key,
    required this.typed,
    required this.isNew,
    required this.foods,
    required this.recipes,
    required this.onRecipe,
    required this.ingredients,
    required this.onPick,
  });

  /// The tallest it gets (Round 53).
  static const maxHeight = 300.0;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    Widget heading(String text) => Padding(
          padding: const EdgeInsets.fromLTRB(16, 10, 16, 2),
          child: Text(
            text,
            style: TextStyle(
              color: colors.textMuted,
              fontSize: 11,
              fontWeight: FontWeight.w600,
              letterSpacing: 1,
            ),
          ),
        );
    Widget row(String name, String kind, {IconData? icon}) => ListTile(
          key: Key('$kind-$name'),
          dense: true,
          minTileHeight: kMinInteractiveDimension,
          leading: icon == null ? null : Icon(icon, size: 20),
          title: Text(name),
          onTap: () => onPick(name),
        );
    return Padding(
      padding: const EdgeInsets.fromLTRB(8, 4, 8, 0),
      child: Material(
        key: const Key('foodIndex'),
        color: colors.card,
        borderRadius: BorderRadius.circular(8),
        clipBehavior: Clip.antiAlias,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxHeight: maxHeight),
          child: SingleChildScrollView(
            key: const Key('foodIndexScroll'),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (isNew) row(typed, 'indexNew', icon: Icons.add),
                if (foods.isNotEmpty) ...[
                  heading('FOODS'),
                  for (final name in foods) row(name, 'indexFood'),
                ],
                if (recipes.isNotEmpty) ...[
                  heading('RECIPES'),
                  for (final recipe in recipes)
                    ListTile(
                      key: Key('indexRecipe-${recipe.name}'),
                      dense: true,
                      minTileHeight: kMinInteractiveDimension,
                      leading: const Icon(Icons.menu_book_outlined, size: 20),
                      title: Text(recipe.name),
                      trailing: const Icon(Icons.chevron_right),
                      onTap: () => onRecipe(recipe),
                    ),
                ],
                if (ingredients.isNotEmpty) ...[
                  heading('INGREDIENTS'),
                  for (final name in ingredients) row(name, 'indexIngredient'),
                ],
                const SizedBox(height: 4),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
