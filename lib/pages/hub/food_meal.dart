import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:the_app/core/clock.dart';
import 'package:the_app/core/format.dart';
import 'package:the_app/core/id.dart';
import 'package:the_app/core/theme.dart';
import 'package:the_app/models/food.dart';
import 'package:the_app/pages/hub/food.dart';
import 'package:the_app/pages/hub/ingredients.dart';
import 'package:the_app/providers/food_provider.dart';
import 'package:the_app/widgets/pull_down_list.dart';

/// A meal (Round 46): what kind and when, its foods, and how it went.
/// Saved as it goes; a new one ([at]) is kept once it has a food, a
/// rating or a note, so one left empty is dropped. Opened for an
/// existing one ([mealId]), its menu deletes it (with Undo).
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

  FoodNotifier get _notifier => ref.read(foodProvider.notifier);

  /// The meal as saved, or the draft.
  Meal get _meal => ref.read(foodProvider).mealById(_draft.id) ?? _draft;

  @override
  void initState() {
    super.initState();
    _food.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _note.dispose();
    _food.dispose();
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
    if (meal.foods.any((f) => f.foodId == food.id)) return;
    _change(meal.copyWith(
      foods: [...meal.foods, MealFood(foodId: food.id, name: food.name)],
    ));
  }

  void _typed(String name) {
    _addFood(name);
    _food.clear();
  }

  Future<void> _fromIngredients() async {
    final picked = await pickIngredients(context, already: const {});
    if (picked == null || !mounted) return;
    for (final ingredient in picked) {
      _addFood(ingredient.name);
    }
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
    final suggestions = [
      for (final f in book.foodsByUse)
        if (!inMeal.contains(f.id) &&
            (typed.isEmpty || f.name.toLowerCase().contains(typed)))
          f,
    ].take(12).toList();
    final recent = meal.foods.isEmpty ? book.recentMeals() : const <Meal>[];

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.mealId == null && !saved ? 'New meal' : 'Meal'),
        actions: [
          if (saved)
            IconButton(
              tooltip: 'Delete meal',
              icon: const Icon(Icons.delete_outline),
              onPressed: _delete,
            ),
        ],
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
                ActionChip(
                  key: const Key('mealTime'),
                  avatar: const Icon(Icons.schedule, size: 18),
                  label: Text(
                    '${formatDay(local, today: ref.read(clockProvider)())}  '
                    '${formatMinutes(local.hour * 60 + local.minute)}',
                  ),
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
                    // A tap takes it out (Round 46: a chip's own small
                    // delete button is too small a target).
                    InputChip(
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
                ],
              ),
            ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
            child: TextField(
              key: const Key('mealFoodField'),
              controller: _food,
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
          if (suggestions.isNotEmpty)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
              child: Wrap(
                spacing: 8,
                runSpacing: 4,
                children: [
                  for (final f in suggestions)
                    ActionChip(
                      key: Key('foodSuggestion-${f.name}'),
                      label: Text(f.name),
                      onPressed: () {
                        _addFood(f.name);
                        _food.clear();
                      },
                    ),
                ],
              ),
            ),
          Padding(
            padding: const EdgeInsets.fromLTRB(8, 4, 16, 0),
            child: Align(
              alignment: Alignment.centerLeft,
              child: TextButton.icon(
                key: const Key('fromIngredients'),
                icon: const Icon(Icons.playlist_add),
                label: const Text('From ingredients'),
                onPressed: _fromIngredients,
              ),
            ),
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
                for (final rating in MealRating.values)
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
        ],
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
