import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:the_app/models/food.dart';
import 'package:the_app/models/recipe.dart';
import 'package:the_app/providers/food_provider.dart';
import 'package:the_app/providers/recipes_provider.dart';

import '../helpers.dart';

/// Hub → Food, the food tracker (O14, Round 46).
void main() {
  late ProviderContainer container;
  // Wednesday 14 October 2026, 13:20.
  final now = DateTime(2026, 10, 14, 13, 20);

  FoodBook book() => container.read(foodProvider);

  Meal meal(
    String id,
    DateTime at,
    List<String> foods, {
    MealRating? rating,
    MealKind kind = MealKind.lunch,
  }) =>
      Meal(
        id: id,
        at: at,
        kind: kind,
        foods: [for (final f in foods) MealFood(foodId: f, name: f)],
        rating: rating,
      );

  Future<void> openFood(WidgetTester tester, {FoodBook? start}) async {
    container = await pumpApp(tester, clock: () => now);
    if (start != null) container.read(foodProvider.notifier).replaceAll(start);
    await openTab(tester, 'Hub');
    await tester.tap(find.byTooltip('Food'));
    await tester.pumpAndSettle();
  }

  Future<void> tapTooltip(WidgetTester tester, String tooltip) async {
    await tester.tap(find.byTooltip(tooltip));
    await tester.pumpAndSettle();
  }

  Future<void> typeFood(WidgetTester tester, String name) async {
    await tester.enterText(find.byKey(const Key('mealFoodField')), name);
    await tester.testTextInput.receiveAction(TextInputAction.done);
    await tester.pumpAndSettle();
  }

  testWidgets('empty: today, no meals', (tester) async {
    await openFood(tester);
    expect(find.text('TODAY  ·  WED, 14 OCT'), findsOneWidget);
    expect(find.text('No meals logged'), findsOneWidget);
  });

  testWidgets(
      '+ logs a meal: kind from the time, foods typed (new ones join the '
      'list), rated; the card shows it', (tester) async {
    await openFood(tester);
    await tapTooltip(tester, 'Log a meal');
    expect(find.text('New meal'), findsOneWidget);
    final lunch =
        tester.widget<ChoiceChip>(find.byKey(const Key('mealKind-lunch')));
    expect(lunch.selected, isTrue, reason: '13:20 is lunch');
    await typeFood(tester, 'Sarma');
    await typeFood(tester, 'Bread');
    await typeFood(tester, 'sarma'); // the same food: not twice
    expect(book().foods.map((f) => f.name), ['Sarma', 'Bread']);
    // Round 47: its chip flashes instead (it's there already).
    await tester.enterText(find.byKey(const Key('mealFoodField')), 'Sarma');
    await tester.testTextInput.receiveAction(TextInputAction.done);
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.byKey(const ValueKey('flash-Sarma-2')), findsOneWidget);
    await tester.pumpAndSettle();
    expect(book().meals.single.foods.map((f) => f.name), ['Sarma', 'Bread']);
    // A tap on one takes it out.
    await typeFood(tester, 'Oops');
    await tester.tap(find.byKey(const Key('mealFood-Oops')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('rating-bad')));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.byKey(const Key('symptom-heartburn')));
    await tester.tap(find.byKey(const Key('symptom-heartburn')));
    await tester.pumpAndSettle();
    final saved = book().meals.single;
    expect(saved.rating, MealRating.bad);
    expect(saved.symptoms, {Symptom.heartburn});
    expect(saved.at, now);

    await pressBack(tester);
    expect(find.text('Sarma, Bread'), findsOneWidget);
    expect(find.text('Lunch  ·  13:20'), findsOneWidget);
    expect(find.byKey(Key('mealRating-${saved.id}')), findsOneWidget);
    expect(find.text('Heartburn'), findsOneWidget);
  });

  testWidgets('a new meal left empty is dropped', (tester) async {
    await openFood(tester);
    await tapTooltip(tester, 'Log a meal');
    await tester.tap(find.byKey(const Key('mealKind-dinner')));
    await tester.pumpAndSettle();
    await pressBack(tester);
    expect(book().meals, isEmpty);
    expect(find.text('No meals logged'), findsOneWidget);
  });

  testWidgets(
      'the index under the field (Round 47): foods most eaten first, '
      'narrowed as you type; the last meal repeated', (tester) async {
    await openFood(tester,
        start: FoodBook(foods: [
          Food(id: 'Eggs', name: 'Eggs'),
          Food(id: 'Toast', name: 'Toast'),
          Food(id: 'Kiwi', name: 'Kiwi'),
        ], meals: [
          meal('m1', DateTime(2026, 10, 13, 8), ['Eggs', 'Toast'],
              kind: MealKind.breakfast),
          meal('m2', DateTime(2026, 10, 12, 8), ['Toast']),
        ]));
    await tapTooltip(tester, 'Log a meal');
    expect(find.byKey(const Key('foodIndex')), findsNothing,
        reason: 'only while typing a food');
    await tester.tap(find.byKey(const Key('mealFoodField')));
    await tester.pumpAndSettle();
    final toast = tester.getTopLeft(find.byKey(const Key('indexFood-Toast')));
    final kiwi = tester.getTopLeft(find.byKey(const Key('indexFood-Kiwi')));
    expect(toast.dy, lessThan(kiwi.dy), reason: 'eaten twice: first');
    // Typing narrows it; a new name can be added from it.
    await tester.enterText(find.byKey(const Key('mealFoodField')), 'ki');
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('indexFood-Toast')), findsNothing);
    expect(find.byKey(const Key('indexNew-ki')), findsOneWidget);
    await tester.tap(find.byKey(const Key('indexFood-Kiwi')));
    await tester.pumpAndSettle();
    expect(book().meals.last.foods.map((f) => f.name), ['Kiwi']);
    expect(find.byKey(const Key('indexFood-Kiwi')), findsNothing,
        reason: 'in the meal now');

    // Another: Same as yesterday's breakfast.
    await pressBack(tester);
    await tapTooltip(tester, 'Log a meal');
    await tester.ensureVisible(find.byKey(const Key('repeatMeal-m1')));
    await tester.tap(find.byKey(const Key('repeatMeal-m1')));
    await tester.pumpAndSettle();
    expect(book().mealsOn(DateTime(2026, 10, 14)).last.foods.map((f) => f.name),
        ['Eggs', 'Toast']);
  });

  testWidgets(
      "the index's Ingredients: the recipes' ones not foods yet; picked, "
      'they become foods', (tester) async {
    await openFood(tester,
        start:
            FoodBook(foods: [Food(id: 'f1', name: 'Milk')], meals: const []));
    container.read(ingredientsProvider.notifier).replaceAll(IngredientBook([
          IngredientSection(id: 's1', name: 'Ingredients', items: const [
            Ingredient(id: 'i1', name: 'Flour'),
            Ingredient(id: 'i2', name: 'milk'),
          ]),
        ]));
    await tapTooltip(tester, 'Log a meal');
    expect(find.byKey(const Key('fromIngredients')), findsNothing,
        reason: 'no separate button (Round 47)');
    await tester.tap(find.byKey(const Key('mealFoodField')));
    await tester.pumpAndSettle();
    expect(find.text('INGREDIENTS'), findsOneWidget);
    expect(find.byKey(const Key('indexIngredient-Flour')), findsOneWidget);
    expect(find.byKey(const Key('indexIngredient-milk')), findsNothing,
        reason: 'a food already: under Foods');
    expect(find.byKey(const Key('indexFood-Milk')), findsOneWidget);
    await tester.tap(find.byKey(const Key('indexIngredient-Flour')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('indexFood-Milk')));
    await tester.pumpAndSettle();
    expect(book().meals.single.foods.map((f) => (f.foodId, f.name)),
        [(book().foodNamed('Flour')!.id, 'Flour'), ('f1', 'Milk')]);
    expect(book().foods, hasLength(2));
  });

  testWidgets(
      "the index's Recipes (Round 48): a tap opens its ingredients, all "
      'ticked, to choose which to add', (tester) async {
    await openFood(tester,
        start:
            FoodBook(foods: [Food(id: 'f1', name: 'Milk')], meals: const []));
    container.read(recipesProvider.notifier).replaceAll([
      Recipe(
        id: 'r1',
        name: 'Pancakes',
        ingredients: const [
          RecipeIngredient(name: 'Flour', quantity: '200 g'),
          RecipeIngredient(name: 'milk'),
          RecipeIngredient(name: 'Sugar'),
        ],
        createdAt: DateTime(2026, 10, 1),
      ),
      Recipe(id: 'r2', name: 'Tea', createdAt: DateTime(2026, 10, 1)),
    ]);
    await tapTooltip(tester, 'Log a meal');
    await tester.tap(find.byKey(const Key('mealFoodField')));
    await tester.pumpAndSettle();
    expect(find.text('RECIPES'), findsOneWidget);
    expect(find.byKey(const Key('indexRecipe-Tea')), findsNothing,
        reason: 'nothing in it to add');
    await tester.enterText(find.byKey(const Key('mealFoodField')), 'panc');
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('indexRecipe-Pancakes')));
    await tester.pumpAndSettle();
    expect(find.text('Add 3'), findsOneWidget, reason: 'all ticked');
    await tester.tap(find.byKey(const Key('recipeIngredient-Sugar')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('addFromRecipe')));
    await tester.pumpAndSettle();
    expect(book().meals.single.foods.map((f) => f.name), ['Flour', 'Milk'],
        reason: 'milk is the food Milk');
    expect(book().foods.map((f) => f.name), ['Milk', 'Flour']);
  });

  testWidgets(
      'the month calendar (Round 47): days coloured by their worst meal; a '
      "tap shows a day's meals; ‹ goes back a month", (tester) async {
    await openFood(tester,
        start: FoodBook(foods: const [], meals: [
          meal('a', DateTime(2026, 10, 12, 8), ['Oats'],
              rating: MealRating.great),
          meal('b', DateTime(2026, 10, 12, 13), ['Beans'],
              rating: MealRating.awful),
          meal('c', DateTime(2026, 9, 28, 13), ['Old soup']),
        ]));
    BoxDecoration dot(String key) =>
        tester.widget<Container>(find.byKey(Key(key))).decoration!
            as BoxDecoration;
    expect(find.text('October 2026'), findsOneWidget);
    expect(dot('foodDay-2026-10-12').color, const Color(0xFFEF5350),
        reason: 'awful wins');
    expect(dot('foodDay-2026-10-13').color, isNull);
    expect(tester.getSize(find.byKey(const Key('foodDay-2026-10-12'))).width,
        greaterThanOrEqualTo(40),
        reason: 'bigger than a line of dots');
    await tester.tap(find.byKey(const Key('foodDay-2026-10-12')));
    await tester.pumpAndSettle();
    expect(find.text('MON, 12 OCT'), findsOneWidget);
    expect(find.text('Oats'), findsOneWidget);
    expect(find.text('Beans'), findsOneWidget);
    await tapTooltip(tester, 'Month before');
    expect(find.text('September 2026'), findsOneWidget);
    await tester.tap(find.byKey(const Key('foodDay-2026-9-28')));
    await tester.pumpAndSettle();
    expect(find.text('Old soup'), findsOneWidget);
    // Days to come can't be picked.
    await tapTooltip(tester, 'Month after');
    await tester.tap(find.byKey(const Key('foodDay-2026-10-20')));
    await tester.pumpAndSettle();
    expect(find.text('MON, 28 SEP'), findsOneWidget);
  });

  testWidgets('a meal opened to rate later; deleted, with Undo',
      (tester) async {
    await openFood(tester,
        start: FoodBook(foods: const [], meals: [
          meal('a', DateTime(2026, 10, 14, 8), ['Oats'],
              kind: MealKind.breakfast),
        ]));
    expect(find.text('Not rated'), findsOneWidget);
    await tester.tap(find.text('Oats'));
    await tester.pumpAndSettle();
    expect(find.text('Meal'), findsOneWidget);
    await tester.tap(find.byKey(const Key('rating-good')));
    await tester.pumpAndSettle();
    expect(book().meals.single.rating, MealRating.good);
    // Tapped again: not rated.
    await tester.tap(find.byKey(const Key('rating-good')));
    await tester.pumpAndSettle();
    expect(book().meals.single.rating, isNull);

    // Faces from bad to good (Round 47).
    expect(tester.getCenter(find.byKey(const Key('rating-awful'))).dx,
        lessThan(tester.getCenter(find.byKey(const Key('rating-great'))).dx));
    // Delete at the end of the page, not in the top bar.
    expect(find.byTooltip('Delete meal'), findsNothing);
    await tester.scrollUntilVisible(find.byKey(const Key('deleteMeal')), 200,
        scrollable: find.byType(Scrollable).first);
    await tester.tap(find.byKey(const Key('deleteMeal')));
    await tester.pumpAndSettle();
    expect(book().meals, isEmpty);
    expect(find.text('Breakfast deleted'), findsOneWidget);
    await tester.tap(find.text('Undo'));
    await tester.pumpAndSettle();
    expect(book().meals, hasLength(1));
  });

  testWidgets('Foods: renamed (meals too), tagged, deleted with Undo',
      (tester) async {
    await openFood(tester,
        start: FoodBook(foods: [
          Food(id: 'Milk', name: 'Milk'),
          Food(id: 'Tea', name: 'Tea'),
        ], meals: [
          meal('a', DateTime(2026, 10, 14, 8), ['Milk']),
        ]));
    await tapTooltip(tester, 'Foods');
    await tester.tap(find.text('Milk'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Rename'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField).last, 'Oat milk');
    await tester.testTextInput.receiveAction(TextInputAction.done);
    await tester.pumpAndSettle();
    expect(book().meals.single.foods.single.name, 'Oat milk');

    await tester.tap(find.text('Tea'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Tags'));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('foodTag-caffeine')));
    await tester.pumpAndSettle();
    expect(book().foodById('Tea')!.tags, {FoodTag.caffeine});
    await tester.tapAt(const Offset(200, 100)); // closes the sheet
    await tester.pumpAndSettle();
    expect(find.text('Caffeine'), findsOneWidget);

    await tester.tap(find.text('Tea'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Delete'));
    await tester.pumpAndSettle();
    expect(book().foods.map((f) => f.name), ['Oat milk']);
    await tester.tap(find.text('Undo'));
    await tester.pumpAndSettle();
    expect(book().foods, hasLength(2));
  });

  testWidgets('Statistics: nothing rated says so; then verdicts with numbers',
      (tester) async {
    await openFood(tester);
    await tapTooltip(tester, 'Statistics');
    expect(find.text('Rate meals to see what agrees with you'), findsOneWidget);
    await pressBack(tester);

    final day = DateTime(2026, 10, 1, 12);
    container.read(foodProvider.notifier).replaceAll(FoodBook(
          foods: [
            Food(id: 'Onion', name: 'Onion', tags: {FoodTag.spicy})
          ],
          meals: [
            for (var i = 0; i < 5; i++)
              Meal(
                id: 'o$i',
                at: day.add(Duration(days: i)),
                kind: MealKind.lunch,
                foods: const [MealFood(foodId: 'Onion', name: 'Onion')],
                rating: MealRating.awful,
                symptoms: {Symptom.bloating},
              ),
            for (var i = 0; i < 6; i++)
              meal('r$i', day.add(Duration(days: i, hours: 6)), ['Rice'],
                  rating: MealRating.good),
            meal('t', day, ['Tofu'], rating: MealRating.good),
          ],
        ));
    await tapTooltip(tester, 'Statistics');
    expect(find.byKey(const Key('foodUsual')), findsOneWidget);
    expect(tester.widget<Text>(find.byKey(const Key('verdict-Onion'))).data,
        'Likely trouble');
    expect(tester.widget<Text>(find.byKey(const Key('verdict-Rice'))).data,
        'Seems fine');
    expect(tester.widget<Text>(find.byKey(const Key('verdict-Tofu'))).data,
        'Not enough data yet');
    // Round 49: what it needs, and the verdict centred on its lines.
    expect(tester.widget<Text>(find.byKey(const Key('needs-Tofu'))).data,
        'Needs 4 more rated with it');
    expect(
        tester.getCenter(find.byKey(const Key('verdict-Tofu'))).dy,
        moreOrLessEquals(
            tester.getCenter(find.byKey(const Key('finding-Tofu'))).dy,
            epsilon: 1));
    expect(find.byKey(const Key('needs-Onion')), findsNothing);
    expect(
        find.descendant(
            of: find.byKey(const Key('finding-Onion')),
            matching: find.text('5 rated meals, 5 bad · without it none')),
        findsOneWidget);
    expect(find.text('Bloating after 5'), findsWidgets);
    expect(find.text('BY KIND'), findsOneWidget);
    expect(find.byKey(const Key('verdict-Spicy')), findsOneWidget);

    // By symptom (Round 48): bloating after every onion meal, never
    // without it.
    expect(find.text('BY SYMPTOM'), findsOneWidget);
    await tester.scrollUntilVisible(
        find.byKey(const Key('symptomFood-bloating-Onion')), 200,
        scrollable: find.byType(Scrollable).last);
    expect(find.text('Bloating  ·  after 5 meals'), findsOneWidget);
    expect(find.text('after 5 of 5 · without it 0 of 7'), findsOneWidget);
    await tester.scrollUntilVisible(
        find.byKey(const Key('finding-Onion')), -200,
        scrollable: find.byType(Scrollable).last);

    // A food's own page (Round 47).
    await tester.tap(find.byKey(const Key('finding-Onion')));
    await tester.pumpAndSettle();
    expect(appBarTitle('Onion'), findsOneWidget);
    expect(tester.widget<Text>(find.byKey(const Key('findingVerdict'))).data,
        'Likely trouble');
    expect(find.textContaining('5 rated meals with it (5 bad or awful), 7 '),
        findsOneWidget);
    expect(find.byKey(const Key('ratingBar-awful')), findsOneWidget);
    expect(
        find.descendant(
            of: find.byKey(const Key('ratingBar-awful')),
            matching: find.text('5 · 0')),
        findsOneWidget);
    expect(
        find.descendant(
            of: find.byKey(const Key('symptomAfter-bloating')),
            matching: find.text('5 of 5 meals')),
        findsOneWidget);
    expect(find.text('MEALS WITH IT  ·  5'), findsOneWidget);
    // Its history, newest first, with dates; a tap opens the meal.
    await tester.scrollUntilVisible(find.byKey(const ValueKey('o4')), 200,
        scrollable: find.byType(Scrollable).last);
    await tester.drag(find.byType(Scrollable).last, const Offset(0, -200));
    await tester.pumpAndSettle();
    expect(find.textContaining('Mon, 5 Oct  ·  Lunch'), findsOneWidget);
    await tester.tap(find.textContaining('Mon, 5 Oct  ·  Lunch'));
    await tester.pumpAndSettle();
    expect(appBarTitle('Meal'), findsOneWidget);
  });
}
