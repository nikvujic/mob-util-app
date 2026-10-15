import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:the_app/core/clock.dart';
import 'package:the_app/core/format.dart';
import 'package:the_app/core/id.dart';
import 'package:the_app/core/theme.dart';
import 'package:the_app/models/food.dart';
import 'package:the_app/models/recipe.dart';
import 'package:the_app/pages/hub/food.dart';
import 'package:the_app/pages/hub/food_recipe_sheet.dart';
import 'package:the_app/providers/food_provider.dart';
import 'package:the_app/providers/recipes_provider.dart';
import 'package:the_app/widgets/pull_down_list.dart';

/// A meal (Round 46): what kind and when, its foods, and how it went.
/// Saved as it goes; a new one ([at]) is kept once it has a food, a
/// rating or a note, so one left empty is dropped. Opened for an
/// existing one ([mealId]), a button at the end deletes it (with Undo).
///
/// Round 47: foods are added from an index under the field (while it's
/// focused), in sections: *Foods* already used and the recipes'
/// *Ingredients* not foods yet, narrowed as you type, so names repeat
/// the same way. A food added twice flashes its chip instead.
class MealPage extends ConsumerStatefulWidget {
  final String? mealId;

  /// When a new meal was eaten (its kind guessed from the time).
  final DateTime? at;

  const MealPage({super.key, this.mealId, this.at})
      : assert((mealId == null) != (at == null));

  @override
  ConsumerState<MealPage> createState() => _MealPageState();
}

class _MealPageState extends ConsumerState<MealPage> {
  /// The meal while it's new and empty (not saved yet).
  late Meal _draft = Meal(
    id: widget.mealId ?? generateId(),
    at: widget.at ?? DateTime.now(),
    kind: MealKind.at(widget.at ?? DateTime.now()),
  );

  late final _note = TextEditingController(text: _meal.note);
  final _food = TextEditingController();
  final _foodFocus = FocusNode();

  /// The food whose chip flashes (added again), and a count so a second
  /// flash starts over.
  String? _flashing;
  int _flashes = 0;

  FoodNotifier get _notifier => ref.read(foodProvider.notifier);

  /// The meal as saved, or the draft.
  Meal get _meal => ref.read(foodProvider).mealById(_draft.id) ?? _draft;

  @override
  void initState() {
    super.initState();
    _food.addListener(() => setState(() {}));
    _foodFocus.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _note.dispose();
    _food.dispose();
    _foodFocus.dispose();
    super.dispose();
  }

  void _change(Meal meal) {
    final saved = ref.read(foodProvider).mealById(meal.id) != null;
    final empty =
        meal.foods.isEmpty && meal.rating == null && meal.note.trim().isEmpty;
    if (saved || !empty) {
      _notifier.saveMeal(meal);
    } else {
      setState(() => _draft = meal);
    }
  }

  void _addFood(String name) {
    final food = _notifier.foodNamed(name);
    if (food == null) return;
    final meal = _meal;
    if (meal.foods.any((f) => f.foodId == food.id)) {
      // There already: its chip flashes.
      HapticFeedback.lightImpact();
      setState(() {
        _flashing = food.id;
        _flashes++;
      });
      return;
    }
    _change(meal.copyWith(
      foods: [...meal.foods, MealFood(foodId: food.id, name: food.name)],
    ));
  }

  void _typed(String name) {
    _addFood(name);
    _food.clear();
  }

  /// A recipe's ingredients, all ticked, to choose which to add (Round
  /// 48); each becomes a food (the same name reused).
  Future<void> _fromRecipe(Recipe recipe) async {
    final picked = await showModalBottomSheet<List<String>>(
      context: context,
      isScrollControlled: true,
      builder: (_) => RecipeIngredientsSheet(recipe: recipe),
    );
    if (picked == null || !mounted) return;
    for (final name in picked) {
      _addFood(name);
    }
    _food.clear();
  }

  /// Another day, the same time; days to come aren't offered.
  Future<void> _pickDay() async {
    final local = _meal.at.toLocal();
    final today = dayOf(ref.read(clockProvider)());
    final picked = await showDatePicker(
      context: context,
      initialDate: dayOf(local).isAfter(today) ? today : dayOf(local),
      firstDate: DateTime(2000),
      lastDate: today,
    );
    if (picked == null || !mounted) return;
    _change(_meal.copyWith(
      at: DateTime(
          picked.year, picked.month, picked.day, local.hour, local.minute),
    ));
  }

  Future<void> _pickTime() async {
    final local = _meal.at.toLocal();
    final picked = await showTimePicker(
      context: context,
      initialTime: TimeOfDay(hour: local.hour, minute: local.minute),
      builder: (context, child) => MediaQuery(
        data: MediaQuery.of(context).copyWith(alwaysUse24HourFormat: true),
        child: child!,
      ),
    );
    if (picked == null || !mounted) return;
    _change(_meal.copyWith(
      at: DateTime(
          local.year, local.month, local.day, picked.hour, picked.minute),
    ));
  }

  void _delete() {
    final meal = _meal;
    // Kept: Undo comes after this page has closed.
    final notifier = _notifier;
    final before = notifier.deleteMeal(meal.id);
    final messenger = ScaffoldMessenger.of(context);
    Navigator.of(context).pop();
    messenger
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(
        content: Text('${meal.kind.label} deleted'),
        action: SnackBarAction(
          label: 'Undo',
          onPressed: () => notifier.replaceAll(before),
        ),
      ));
  }

  Widget _heading(String text) => Padding(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
        child: Text(
          text,
          style: TextStyle(
            color: context.colors.accent,
            fontSize: 12,
            fontWeight: FontWeight.w600,
            letterSpacing: 1,
          ),
        ),
      );

  @override
  Widget build(BuildContext context) {
    final book = ref.watch(foodProvider);
    final meal = book.mealById(_draft.id) ?? _draft;
    final saved = book.mealById(meal.id) != null;
    final colors = context.colors;
    final local = meal.at.toLocal();
    final inMeal = {for (final f in meal.foods) f.foodId};
    final typed = _food.text.trim().toLowerCase();
    bool matches(String name) =>
        typed.isEmpty || name.toLowerCase().contains(typed);
    // The index (Round 47): foods most eaten first, then ingredients that
    // aren't foods yet, by name.
    final indexFoods = [
      for (final f in book.foodsByUse)
        if (!inMeal.contains(f.id) && matches(f.name)) f,
    ];
    final indexIngredients = {
      for (final i in ref.watch(ingredientsProvider).all)
        if (book.foodNamed(i.name) == null && matches(i.name))
          i.name.toLowerCase(): i.name,
    }.values.toList()
      ..sort((a, b) => a.toLowerCase().compareTo(b.toLowerCase()));
    // Round 48: recipes too, by name; a tap opens its ingredients.
    final indexRecipes = [
      for (final recipe in ref.watch(recipesProvider))
        if (recipe.name.trim().isNotEmpty &&
            recipe.ingredients.isNotEmpty &&
            matches(recipe.name))
          recipe,
    ];
    final isNew = typed.isNotEmpty &&
        book.foodNamed(typed) == null &&
        !indexIngredients.any((n) => n.toLowerCase() == typed);
    final showIndex = _foodFocus.hasFocus &&
        (isNew ||
            indexFoods.isNotEmpty ||
            indexRecipes.isNotEmpty ||
            indexIngredients.isNotEmpty);
    final recent = meal.foods.isEmpty ? book.recentMeals() : const <Meal>[];

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.mealId == null && !saved ? 'New meal' : 'Meal'),
      ),
      body: PullDownList.children(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
            child: Wrap(
              spacing: 8,
              runSpacing: 4,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                for (final kind in MealKind.values)
                  ChoiceChip(
                    key: Key('mealKind-${kind.name}'),
                    label: Text(kind.label),
                    selected: meal.kind == kind,
                    onSelected: (_) => _change(meal.copyWith(kind: kind)),
                  ),
                // The day can change too (Round 50), not only the time.
                ActionChip(
                  key: const Key('mealDay'),
                  avatar: const Icon(Icons.calendar_today, size: 18),
                  label: Text(
                    formatDay(local, today: ref.read(clockProvider)()),
                  ),
                  onPressed: _pickDay,
                ),
                ActionChip(
                  key: const Key('mealTime'),
                  avatar: const Icon(Icons.schedule, size: 18),
                  label: Text(formatMinutes(local.hour * 60 + local.minute)),
                  onPressed: _pickTime,
                ),
              ],
            ),
          ),
          _heading('FOODS'),
          if (meal.foods.isNotEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Wrap(
                spacing: 8,
                runSpacing: 4,
                children: [
                  for (final f in meal.foods)
                    _Flash(
                      key: f.foodId != null && f.foodId == _flashing
                          ? ValueKey('flash-${f.name}-$_flashes')
                          : ValueKey('chip-${f.name}'),
                      on: f.foodId != null && f.foodId == _flashing,
                      // A tap takes it out (Round 46: a chip's own small
                      // delete button is too small a target).
                      child: InputChip(
                        key: Key('mealFood-${f.name}'),
                        tooltip: 'Remove ${f.name}',
                        label: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(f.name),
                            const SizedBox(width: 6),
                            const Icon(Icons.close, size: 16),
                          ],
                        ),
                        selected: true,
                        showCheckmark: false,
                        onPressed: () => _change(meal.copyWith(foods: [
                          for (final other in meal.foods)
                            if (other != f) other,
                        ])),
                      ),
                    ),
                ],
              ),
            ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
            child: TextField(
              key: const Key('mealFoodField'),
              controller: _food,
              focusNode: _foodFocus,
              textCapitalization: TextCapitalization.sentences,
              textInputAction: TextInputAction.done,
              decoration: InputDecoration(
                hintText: 'Add a food',
                suffixIcon: _food.text.trim().isEmpty
                    ? null
                    : IconButton(
                        tooltip: 'Add',
                        icon: const Icon(Icons.add),
                        onPressed: () => _typed(_food.text),
                      ),
              ),
              onSubmitted: _typed,
            ),
          ),
          if (showIndex)
            _FoodIndex(
              typed: _food.text.trim(),
              isNew: isNew,
              foods: [for (final f in indexFoods) f.name],
              recipes: indexRecipes,
              onRecipe: _fromRecipe,
              ingredients: indexIngredients,
              onPick: (name) {
                _addFood(name);
                _food.clear();
              },
            ),
          if (recent.isNotEmpty) ...[
            _heading('SAME AS'),
            for (final r in recent)
              ListTile(
                key: Key('repeatMeal-${r.id}'),
                dense: true,
                leading: const Icon(Icons.replay),
                title: Text(
                  r.foods.map((f) => f.name).join(', '),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                subtitle: Text(
                  '${r.kind.label} · ${formatDay(r.at.toLocal(), today: ref.read(clockProvider)())}',
                  style: TextStyle(color: colors.textMuted),
                ),
                onTap: () => _change(meal.copyWith(foods: r.foods)),
              ),
          ],
          _heading('HOW IT WENT'),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                // From bad to good (Round 47).
                for (final rating in MealRating.values.reversed)
                  _RatingButton(
                    rating: rating,
                    selected: meal.rating == rating,
                    // Tapped again: not rated.
                    onTap: () => _change(meal.copyWith(
                      rating: () => meal.rating == rating ? null : rating,
                    )),
                  ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
            child: Wrap(
              spacing: 8,
              runSpacing: 4,
              children: [
                for (final symptom in Symptom.values)
                  FilterChip(
                    key: Key('symptom-${symptom.name}'),
                    label: Text(symptom.label),
                    selected: meal.symptoms.contains(symptom),
                    onSelected: (on) => _change(meal.copyWith(
                      symptoms: on
                          ? {...meal.symptoms, symptom}
                          : ({...meal.symptoms}..remove(symptom)),
                    )),
                  ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
            child: TextField(
              key: const Key('mealNote'),
              controller: _note,
              minLines: 1,
              maxLines: 4,
              textCapitalization: TextCapitalization.sentences,
              decoration: const InputDecoration(labelText: 'Note'),
              onChanged: (text) => _change(_meal.copyWith(note: text)),
            ),
          ),
          // At the end of the page, not up top nor round (Round 47).
          if (saved)
            Padding(
              padding: const EdgeInsets.fromLTRB(8, 0, 16, 24),
              child: Align(
                alignment: Alignment.centerLeft,
                child: TextButton.icon(
                  key: const Key('deleteMeal'),
                  style: TextButton.styleFrom(foregroundColor: colors.danger),
                  icon: const Icon(Icons.delete_outline),
                  label: const Text('Delete meal'),
                  onPressed: _delete,
                ),
              ),
            ),
        ],
      ),
    );
  }
}

/// A food's chip, flashing once in the accent when [on] (Round 47: added
/// again, it's there already).
class _Flash extends StatelessWidget {
  final bool on;
  final Widget child;

  const _Flash({super.key, required this.on, required this.child});

  static const duration = Duration(milliseconds: 900);

  @override
  Widget build(BuildContext context) {
    if (!on) return child;
    final accent = context.colors.accent;
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: duration,
      builder: (context, t, child) {
        // Two pulses, then gone.
        final glow = t >= 1 ? 0.0 : (1 - (2 * t % 1 - 0.5).abs() * 2);
        return DecoratedBox(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            boxShadow: [
              if (glow > 0)
                BoxShadow(
                  color: accent.withValues(alpha: glow),
                  blurRadius: 10 * glow,
                  spreadRadius: 3 * glow,
                ),
            ],
          ),
          child: child,
        );
      },
      child: child,
    );
  }
}

/// The index under the food field (Round 47): a new name to add, the
/// foods already used, and the recipes' ingredients that aren't foods
/// yet, each in its section.
class _FoodIndex extends StatelessWidget {
  final String typed;
  final bool isNew;
  final List<String> foods;
  final List<Recipe> recipes;
  final ValueChanged<Recipe> onRecipe;
  final List<String> ingredients;
  final ValueChanged<String> onPick;

  const _FoodIndex({
    required this.typed,
    required this.isNew,
    required this.foods,
    required this.recipes,
    required this.onRecipe,
    required this.ingredients,
    required this.onPick,
  });

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
    );
  }
}

/// One of the five faces: in its colour when picked.
class _RatingButton extends StatelessWidget {
  final MealRating rating;
  final bool selected;
  final VoidCallback onTap;

  const _RatingButton({
    required this.rating,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final colour = rating.colour;
    return Semantics(
      button: true,
      selected: selected,
      label: rating.label,
      excludeSemantics: true,
      child: InkResponse(
        key: Key('rating-${rating.name}'),
        onTap: onTap,
        child: SizedBox(
          width: 60,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: selected ? colour : null,
                  border: Border.all(color: colour, width: 2),
                ),
                child: Icon(
                  rating.face,
                  color: selected ? RatingColours.ink : colour,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                rating.label,
                style: TextStyle(
                  color: selected ? colors.textPrimary : colors.textSecondary,
                  fontSize: 12,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
