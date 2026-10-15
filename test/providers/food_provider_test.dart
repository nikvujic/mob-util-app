import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:the_app/data/app_storage.dart';
import 'package:the_app/data/backup.dart';
import 'package:the_app/models/food.dart';
import 'package:the_app/models/food_stats.dart';
import 'package:the_app/models/hub_tool.dart';
import 'package:the_app/providers/backup_provider.dart';
import 'package:the_app/providers/food_provider.dart';
import 'package:the_app/core/app_info.dart';
import 'package:the_app/providers/section_data_provider.dart';

/// The food tracker's store (O14, Round 46).
void main() {
  late FoodNotifier food;

  setUp(() => food = FoodNotifier(AppStorage.inMemory()));

  Meal mealOf(String id, List<Food> foods) => Meal(
        id: id,
        at: DateTime(2026, 10, 14, 12),
        kind: MealKind.lunch,
        foods: [for (final f in foods) MealFood(foodId: f.id, name: f.name)],
      );

  test('a food by name: reused in any case, new ones added, blank ignored', () {
    final milk = food.foodNamed(' Milk ')!;
    expect(milk.name, 'Milk');
    expect(food.foodNamed('milk')!.id, milk.id);
    expect(food.foodNamed('  '), isNull);
    expect(food.state.foods, hasLength(1));
  });

  test('a meal saved as it goes: added once, then changed', () {
    final bread = food.foodNamed('Bread')!;
    final meal = mealOf('m1', [bread]);
    food.saveMeal(meal);
    food.saveMeal(meal.copyWith(rating: () => MealRating.good));
    expect(food.state.meals.single.rating, MealRating.good);
    final before = food.deleteMeal('m1');
    expect(food.state.meals, isEmpty);
    food.replaceAll(before);
    expect(food.state.meals, hasLength(1), reason: 'Undo');
  });

  test("renamed, its meals take the name; another food's name is refused", () {
    final milk = food.foodNamed('Milk')!;
    food.foodNamed('Oat milk');
    food.saveMeal(mealOf('m1', [milk]));
    expect(food.renameFood(milk.id, 'Oat milk'), isFalse);
    expect(food.renameFood(milk.id, '  '), isFalse);
    expect(food.renameFood(milk.id, 'Cow milk'), isTrue);
    expect(food.state.meals.single.foods.single.name, 'Cow milk');
  });

  test('deleted from the list, meals keep its name', () {
    final milk = food.foodNamed('Milk')!;
    food.saveMeal(mealOf('m1', [milk]));
    food.setTags(milk.id, {FoodTag.dairy});
    expect(food.state.foods.single.tags, {FoodTag.dairy});
    food.deleteFood(milk.id);
    expect(food.state.foods, isEmpty);
    expect(food.state.meals.single.foods.single.name, 'Milk');
  });

  test(
      'deleted, then added again by the same name: its meals are its own '
      'again (Round 49), not a second food', () {
    final milk = food.foodNamed('Milk')!;
    food.saveMeal(mealOf('m1', [milk]));
    food.deleteFood(milk.id);
    final again = food.foodNamed('milk')!;
    expect(again.id, milk.id);
    expect(again.name, 'milk', reason: 'as typed now');
    expect(FoodStats.foods(food.state), hasLength(1));
    // A new name gets a new id.
    expect(food.foodNamed('Tea')!.id, isNot(milk.id));
  });

  test(
      'merged (Round 50): its meals take the other (once per meal), tags '
      'joined, it leaves the list; Undo puts it back', () {
    final egg = food.foodNamed('Egg')!;
    final eggs = food.foodNamed('Eggs')!;
    final toast = food.foodNamed('Toast')!;
    food
      ..setTags(egg.id, {FoodTag.meat})
      ..setTags(eggs.id, {FoodTag.dairy})
      ..saveMeal(mealOf('m1', [egg, toast]))
      ..saveMeal(mealOf('m2', [egg, eggs]))
      ..saveMeal(mealOf('m3', [toast]));
    final before = food.mergeFood(egg.id, eggs.id);
    expect(food.state.foods.map((f) => f.name), ['Eggs', 'Toast']);
    expect(food.state.foodById(eggs.id)!.tags, {FoodTag.meat, FoodTag.dairy});
    List<String> namesOf(String id) =>
        food.state.mealById(id)!.foods.map((f) => f.name).toList();
    expect(namesOf('m1'), ['Eggs', 'Toast']);
    expect(namesOf('m2'), ['Eggs'], reason: 'once per meal');
    expect(namesOf('m3'), ['Toast']);
    food.replaceAll(before);
    expect(food.state.foods, hasLength(3));
  });

  test('saved to food.json and loaded back', () async {
    final dir = Directory.systemTemp.createTempSync('food');
    addTearDown(() => dir.deleteSync(recursive: true));
    final storage = await AppStorage.open(directory: dir);
    final notifier = FoodNotifier(storage);
    notifier.saveMeal(mealOf('m1', [notifier.foodNamed('Soup')!]));
    await storage.flush();
    expect(File('${dir.path}/food.json').readAsStringSync(),
        contains('"version":1'));
    final again = await AppStorage.open(directory: dir);
    expect(again.initialFood.meals.single.foods.single.name, 'Soup');
  });

  test('a Hub page: counted and cleared (Clear data), in backups', () {
    final container = ProviderContainer(overrides: [
      appVersionProvider.overrideWithValue('1.13.0 (49)'),
      appStorageProvider.overrideWithValue(AppStorage.inMemory(
        initialFood: FoodBook(
          foods: [Food(id: 'f1', name: 'Tea')],
          meals: [
            Meal(
              id: 'm1',
              at: DateTime(2026, 10, 14, 8),
              kind: MealKind.breakfast,
              foods: const [MealFood(foodId: 'f1', name: 'Tea')],
            ),
          ],
        ),
      )),
    ]);
    addTearDown(container.dispose);
    expect(HubTool.food.lockable, isTrue);
    expect(HubTool.food.clearable, isTrue);
    final snapshot = container.read(backupExporterProvider).snapshot();
    expect(Backup.decode(snapshot.encode()).food.meals.single.id, 'm1');
    final data = container.read(sectionDataProvider);
    expect(data.countOf(HubTool.food), 2);
    data.clearOf(HubTool.food);
    expect(container.read(foodProvider).size, 0);
  });
}
