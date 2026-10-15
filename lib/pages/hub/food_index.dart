import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:the_app/core/theme.dart';
import 'package:the_app/models/recipe.dart';

/// The index under the food field (Round 47): a new name to add, the
/// foods already used, and the recipes' ingredients that aren't foods
/// yet, each in its section. Round 53: at most [maxHeight] tall,
/// scrolling inside when longer. Round 54: scrolled to its end, a drag
/// on scrolls the page.
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
          child: _HandOn(
            child: SingleChildScrollView(
              key: const Key('foodIndexScroll'),
              physics: const ClampingScrollPhysics(),
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
                    for (final name in ingredients)
                      row(name, 'indexIngredient'),
                  ],
                  const SizedBox(height: 4),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// A drag past the end of the scrolling [child] goes on to the page
/// around it (Round 54), as a drag of the page itself, so letting go
/// flings the page on (Round 56: before, only the finger's moves went
/// on, and the index stretched at its end as if still scrolling: it no
/// longer stretches).
class _HandOn extends StatefulWidget {
  final Widget child;

  const _HandOn({required this.child});

  @override
  State<_HandOn> createState() => _HandOnState();
}

class _HandOnState extends State<_HandOn> {
  /// The page's drag while the index is past its end, or null.
  Drag? _page;

  bool _onScroll(ScrollNotification n) {
    if (n.depth != 0) return false;
    if (n is OverscrollNotification) {
      final details = n.dragDetails;
      if (details == null) return false; // its own fling: let it stop
      final page = Scrollable.maybeOf(context)?.position;
      if (page == null) return false;
      _page ??= page.drag(
        DragStartDetails(
          globalPosition: details.globalPosition,
          localPosition: details.localPosition,
        ),
        () => _page = null,
      );
      _page!.update(DragUpdateDetails(
        globalPosition: details.globalPosition,
        localPosition: details.localPosition,
        delta: Offset(0, -n.overscroll),
        primaryDelta: -n.overscroll,
      ));
      return true;
    }
    if (n is ScrollEndNotification && _page != null) {
      _page!.end(n.dragDetails ?? DragEndDetails(primaryVelocity: 0));
      _page = null;
    }
    return false;
  }

  @override
  void dispose() {
    _page?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) =>
      NotificationListener<ScrollNotification>(
        onNotification: _onScroll,
        child: ScrollConfiguration(
          behavior: ScrollConfiguration.of(context).copyWith(overscroll: false),
          child: widget.child,
        ),
      );
}
