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

  testWidgets('foods suggested most eaten first; the last meal repeated',
      (tester) async {
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
    final toast =
        tester.getTopLeft(find.byKey(const Key('foodSuggestion-Toast')));
    final kiwi =
        tester.getTopLeft(find.byKey(const Key('foodSuggestion-Kiwi')));
    expect(toast.dx, lessThan(kiwi.dx), reason: 'eaten twice: first');
    // Typing narrows them.
    await tester.enterText(find.byKey(const Key('mealFoodField')), 'ki');
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('foodSuggestion-Toast')), findsNothing);
    await tester.tap(find.byKey(const Key('foodSuggestion-Kiwi')));
    await tester.pumpAndSettle();
    expect(book().meals.last.foods.map((f) => f.name), ['Kiwi']);

    // Another: Same as yesterday's breakfast.
    await pressBack(tester);
    await tapTooltip(tester, 'Log a meal');
    await tester.ensureVisible(find.byKey(const Key('repeatMeal-m1')));
    await tester.tap(find.byKey(const Key('repeatMeal-m1')));
    await tester.pumpAndSettle();
    expect(book().mealsOn(DateTime(2026, 10, 14)).last.foods.map((f) => f.name),
        ['Eggs', 'Toast']);
  });

  testWidgets('From ingredients: picked ones become foods (same names reused)',
      (tester) async {
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
    await tester.tap(find.byKey(const Key('fromIngredients')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Flour'));
    await tester.tap(find.text('milk'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilledButton, 'Add 2'));
    await tester.pumpAndSettle();
    expect(book().meals.single.foods.map((f) => (f.foodId, f.name)),
        [(book().foodNamed('Flour')!.id, 'Flour'), ('f1', 'Milk')]);
    expect(book().foods, hasLength(2));
  });

  testWidgets(
      'the week strip: days coloured by their worst meal; a tap shows a '
      "day's meals; arrows move a week", (tester) async {
    await openFood(tester,
        start: FoodBook(foods: const [], meals: [
          meal('a', DateTime(2026, 10, 12, 8), ['Oats'],
              rating: MealRating.great),
          meal('b', DateTime(2026, 10, 12, 13), ['Beans'],
              rating: MealRating.awful),
          meal('c', DateTime(2026, 10, 7, 13), ['Old soup']),
        ]));
    BoxDecoration dot(String key) => tester
        .widget<Container>(find.descendant(
            of: find.byKey(Key(key)), matching: find.byType(Container)))
        .decoration! as BoxDecoration;
    expect(dot('foodDay-2026-10-12').color, const Color(0xFFEF5350),
        reason: 'awful wins');
    expect(dot('foodDay-2026-10-13').color, isNull);
    await tester.tap(find.byKey(const Key('foodDay-2026-10-12')));
    await tester.pumpAndSettle();
    expect(find.text('MON, 12 OCT'), findsOneWidget);
    expect(find.text('Oats'), findsOneWidget);
    expect(find.text('Beans'), findsOneWidget);
    await tapTooltip(tester, 'Week before');
    expect(find.text('MON, 5 OCT'), findsOneWidget);
    await tester.tap(find.byKey(const Key('foodDay-2026-10-7')));
    await tester.pumpAndSettle();
    expect(find.text('Old soup'), findsOneWidget);
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

    await tapTooltip(tester, 'Delete meal');
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
    expect(
        find.descendant(
            of: find.byKey(const Key('finding-Onion')),
            matching: find.text('5 rated meals, 5 bad · without it none')),
        findsOneWidget);
    expect(find.text('Bloating after 5'), findsWidgets);
    expect(find.text('BY KIND'), findsOneWidget);
    expect(find.byKey(const Key('verdict-Spicy')), findsOneWidget);
  });
}
