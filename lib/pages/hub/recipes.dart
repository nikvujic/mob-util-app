import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:the_app/core/theme.dart';
import 'package:the_app/models/hub_tool.dart';
import 'package:the_app/models/recipe.dart';
import 'package:the_app/pages/hub/ingredients.dart';
import 'package:the_app/pages/hub/page_gate.dart';
import 'package:the_app/pages/hub/recipe_page.dart';
import 'package:the_app/pages/hub/recipe_transfer_sheet.dart';
import 'package:the_app/providers/recipes_provider.dart';
import 'package:the_app/widgets/bottom_actions.dart';
import 'package:the_app/widgets/confirm_dialog.dart';
import 'package:the_app/widgets/empty_state.dart';
import 'package:the_app/widgets/pull_down_list.dart';
import 'package:the_app/widgets/selection.dart';

/// Opens a recipe (view mode), or a new one in edit mode ([isNew]).
void openRecipe(BuildContext context, String id, {bool isNew = false}) {
  Navigator.of(context).push(
    MaterialPageRoute<void>(
      builder: (_) => PageGate(
        page: HubTool.recipes,
        child: RecipePage(recipeId: id, isNew: isNew),
      ),
    ),
  );
}

/// Recipes (Round 42): cards with the name and "prep time · type", in
/// the user's order (the handle moves them). A tap opens one; holding one
/// selects it (to delete several, asked first). + makes a new one, opened
/// in edit mode; the Ingredients button opens the ingredients list.
class RecipesPage extends ConsumerStatefulWidget {
  const RecipesPage({super.key});

  @override
  ConsumerState<RecipesPage> createState() => _RecipesPageState();
}

class _RecipesPageState extends ConsumerState<RecipesPage> {
  final SelectionController _selection = SelectionController();

  RecipesNotifier get _notifier => ref.read(recipesProvider.notifier);

  @override
  void dispose() {
    _selection.dispose();
    super.dispose();
  }

  void _add() => openRecipe(context, _notifier.add(), isNew: true);

  /// Asked first, and no Undo after (like Notes).
  Future<void> _deleteSelected() async {
    final confirmed = await showDeleteConfirmDialog(
      context,
      count: _selection.count,
      singular: 'recipe',
      plural: 'recipes',
    );
    if (!confirmed || !mounted) return;
    _notifier.remove(_selection.selected);
    _selection.clear();
  }

  @override
  Widget build(BuildContext context) {
    final recipes = ref.watch(recipesProvider);
    ref.listen(recipesProvider, (_, next) {
      _selection.retain(next.map((r) => r.id));
    });

    return SelectionPopScope(
      controller: _selection,
      child: ListenableBuilder(
        listenable: _selection,
        builder: (context, _) => Scaffold(
          appBar: _selection.isActive
              ? SelectionAppBar(count: _selection.count)
              : AppBar(title: Text(HubTool.recipes.label)),
          body: recipes.isEmpty
              ? const EmptyState(
                  icon: Icons.menu_book_outlined,
                  message: 'No recipes',
                )
              : PullDownList(
                  bottomSpace: SelectionActions.listBottomSpace,
                  slivers: [
                    SliverPadding(
                      padding: const EdgeInsets.only(top: 4),
                      sliver: SliverReorderableList(
                        itemCount: recipes.length,
                        // onReorderItem only exists on newer Flutter than
                        // we target.
                        // ignore: deprecated_member_use
                        onReorder: _notifier.reorder,
                        proxyDecorator: (child, _, __) => Material(
                          type: MaterialType.transparency,
                          elevation: 6,
                          child: child,
                        ),
                        itemBuilder: (context, index) {
                          final recipe = recipes[index];
                          return Padding(
                            key: ValueKey(recipe.id),
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 3,
                            ),
                            child: _RecipeCard(
                              recipe: recipe,
                              index: index,
                              selectionMode: _selection.isActive,
                              selected: _selection.isSelected(recipe.id),
                              onTap: () => _selection.handleTap(
                                recipe.id,
                                () => openRecipe(context, recipe.id),
                              ),
                              onLongPress: () =>
                                  _selection.handleLongPress(recipe.id),
                            ),
                          );
                        },
                      ),
                    ),
                  ],
                ),
          floatingActionButton: _selection.isActive
              ? SelectionActions(
                  allSelected: _selection.count == recipes.length,
                  onSelectAll: () =>
                      _selection.selectAll(recipes.map((r) => r.id)),
                  onDeselectAll: _selection.clear,
                  onDelete: _deleteSelected,
                )
              : BottomActions(
                  actions: [
                    BottomAction(
                      icon: Icons.kitchen_outlined,
                      tooltip: 'Ingredients',
                      onPressed: () => openIngredients(context),
                    ),
                    // Round 104: recipes as text, copied and pasted.
                    BottomAction(
                      icon: Icons.import_export,
                      tooltip: 'Import / export',
                      onPressed: () => showRecipeTransfer(context, ref),
                    ),
                    // Outermost, under the thumb.
                    BottomAction(
                      icon: Icons.add,
                      tooltip: 'New recipe',
                      primary: true,
                      onPressed: _add,
                    ),
                  ],
                ),
        ),
      ),
    );
  }
}

class _RecipeCard extends StatelessWidget {
  final Recipe recipe;
  final int index;
  final bool selectionMode;
  final bool selected;
  final VoidCallback onTap;
  final VoidCallback onLongPress;

  const _RecipeCard({
    required this.recipe,
    required this.index,
    required this.selectionMode,
    required this.selected,
    required this.onTap,
    required this.onLongPress,
  });

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final untitled = recipe.name.trim().isEmpty;
    return SelectableCard(
      key: Key('recipe-${recipe.id}'),
      selected: selected,
      onTap: onTap,
      onLongPress: onLongPress,
      child: ReorderableRow(
        content: Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 0, 12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                untitled ? 'Untitled' : recipe.name,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 16,
                  color: untitled ? colors.textSecondary : colors.textPrimary,
                ),
              ),
              // Its time and type as chips (Round 44).
              if (recipe.prepMinutes != null || recipe.type != null) ...[
                const SizedBox(height: 6),
                Wrap(
                  spacing: 6,
                  runSpacing: 4,
                  children: [
                    if (recipe.prepMinutes case final minutes?)
                      _Chip(
                        key: const Key('recipeChip-time'),
                        icon: Icons.timer_outlined,
                        text: prepTimeLabel(minutes),
                      ),
                    if (recipe.type case final type?)
                      _Chip(
                        key: const Key('recipeChip-type'),
                        icon: Icons.restaurant_outlined,
                        text: type.label,
                      ),
                  ],
                ),
              ],
            ],
          ),
        ),
        indicator: ReorderOrSelectIndicator(
          index: index,
          selectionMode: selectionMode,
          selected: selected,
        ),
      ),
    );
  }
}

/// A small chip on a recipe's card: its prep time, or its type.
class _Chip extends StatelessWidget {
  final IconData icon;
  final String text;

  const _Chip({super.key, required this.icon, required this.text});

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: colors.background,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: colors.textSecondary),
          const SizedBox(width: 4),
          Text(text,
              style: TextStyle(fontSize: 12, color: colors.textSecondary)),
        ],
      ),
    );
  }
}
