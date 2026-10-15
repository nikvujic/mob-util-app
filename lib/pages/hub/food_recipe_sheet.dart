import 'package:flutter/material.dart';
import 'package:the_app/core/theme.dart';
import 'package:the_app/models/recipe.dart';

/// A recipe's ingredients (Round 48), each ticked, to choose which to add
/// to the meal; Add closes with the ticked names, in the recipe's order.
class RecipeIngredientsSheet extends StatefulWidget {
  final Recipe recipe;

  const RecipeIngredientsSheet({super.key, required this.recipe});

  @override
  State<RecipeIngredientsSheet> createState() => _RecipeIngredientsSheetState();
}

class _RecipeIngredientsSheetState extends State<RecipeIngredientsSheet> {
  late final _names = {
    for (final i in widget.recipe.ingredients)
      if (i.name.trim().isNotEmpty) i.name.trim(),
  }.toList();
  late final _ticked = {..._names};

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final media = MediaQuery.of(context);
    return ConstrainedBox(
      constraints: BoxConstraints(maxHeight: media.size.height * 0.8),
      child: SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
              child: Text(
                widget.recipe.name,
                style: TextStyle(color: colors.textSecondary, fontSize: 14),
              ),
            ),
            Flexible(
              child: ListView(
                shrinkWrap: true,
                children: [
                  for (final name in _names)
                    CheckboxListTile(
                      key: Key('recipeIngredient-$name'),
                      value: _ticked.contains(name),
                      title: Text(name),
                      controlAffinity: ListTileControlAffinity.leading,
                      onChanged: (on) => setState(() {
                        if (on ?? false) {
                          _ticked.add(name);
                        } else {
                          _ticked.remove(name);
                        }
                      }),
                    ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
              child: FilledButton(
                key: const Key('addFromRecipe'),
                style: FilledButton.styleFrom(
                  minimumSize: const Size.fromHeight(52),
                ),
                onPressed: _ticked.isEmpty
                    ? null
                    : () => Navigator.of(context).pop([
                          for (final n in _names)
                            if (_ticked.contains(n)) n,
                        ]),
                child: Text('Add ${_ticked.length}'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
