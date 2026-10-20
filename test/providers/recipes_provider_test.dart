import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:the_app/core/app_info.dart';
import 'package:the_app/core/clock.dart';
import 'package:the_app/data/app_storage.dart';
import 'package:the_app/data/backup.dart';
import 'package:the_app/data/backup_files.dart';
import 'package:the_app/models/hub_tool.dart';
import 'package:the_app/models/recipe.dart';
import 'package:the_app/models/shop_item.dart';
import 'package:the_app/providers/backup_provider.dart';
import 'package:the_app/providers/recipes_provider.dart';
import 'package:the_app/providers/section_data_provider.dart';
import 'package:the_app/providers/shop_provider.dart';

import '../helpers.dart';

/// Recipes and the ingredients list (Round 42).
void main() {
  late ProviderContainer container;
  var now = DateTime(2026, 10, 14, 12);

  setUp(() {
    now = DateTime(2026, 10, 14, 12);
    container = ProviderContainer(
      overrides: [
        appStorageProvider.overrideWithValue(AppStorage.inMemory()),
        appVersionProvider.overrideWithValue('1.9.0 (44)'),
        backupFilesProvider.overrideWithValue(FakeBackupFiles()),
        clockProvider.overrideWithValue(() => now),
      ],
    );
    addTearDown(container.dispose);
  });

  RecipesNotifier recipes() => container.read(recipesProvider.notifier);
  IngredientsNotifier ingredients() =>
      container.read(ingredientsProvider.notifier);
  List<Recipe> all() => container.read(recipesProvider);
  IngredientBook book() => container.read(ingredientsProvider);

  group('recipes', () {
    test('a new one is empty, at the top', () {
      final first = recipes().add();
      final second = recipes().add();
      expect(all().map((r) => r.id), [second, first]);
      expect(all().first.isEmpty, isTrue);
      expect(all().first.createdAt, now);
    });

    test('saved: modified moves on only when something changed', () {
      final id = recipes().add();
      now = now.add(const Duration(minutes: 5));
      recipes().save(recipes().byId(id)!);
      expect(recipes().byId(id)!.modifiedAt, DateTime(2026, 10, 14, 12));
      recipes().save(recipes().byId(id)!.copyWith(name: 'Soup'));
      expect(recipes().byId(id)!.name, 'Soup');
      expect(recipes().byId(id)!.modifiedAt, now);
      expect(recipes().byId(id)!.isEmpty, isFalse);
    });

    test('duplicate: "… (Copy)" just below, its own id', () {
      final a = recipes().add();
      recipes().save(recipes().byId(a)!.copyWith(
        name: 'Soup',
        prepMinutes: () => 40,
        ingredients: const [RecipeIngredient(name: 'Leek')],
      ));
      final b = recipes().add();
      final copy = recipes().duplicate(a)!;
      expect(all().map((r) => r.id), [b, a, copy]);
      final duplicate = recipes().byId(copy)!;
      expect(duplicate.name, 'Soup (Copy)');
      expect(duplicate.prepMinutes, 40);
      expect(duplicate.ingredients.single.name, 'Leek');
    });

    test('removed and put back where they were', () {
      final a = recipes().add(), b = recipes().add(), c = recipes().add();
      final removed = recipes().remove({a, c});
      expect(all().map((r) => r.id), [b]);
      recipes().undoRemove(removed);
      expect(all().map((r) => r.id), [c, b, a]);
    });

    test('reordered', () {
      final a = recipes().add(), b = recipes().add(), c = recipes().add();
      recipes().reorder(0, 3);
      expect(all().map((r) => r.id), [b, a, c]);
    });
  });

  group('ingredients', () {
    test('Round 92: no two of the same (case and spaces aside)', () {
      final flour = ingredients().add('Flour')!;
      ingredients().add('Olive oil');
      expect(ingredients().add('flour'), isNull);
      expect(ingredients().add('  OLIVE   oil '), isNull);
      expect(book().all.map((i) => i.name), ['Olive oil', 'Flour']);
      expect(ingredients().named('olive  OIL')!.$1.name, 'Olive oil');
      expect(ingredients().named('Flour', except: flour), isNull);
      // Renamed to another's name: kept as it was; to its own, in
      // another case: fine.
      ingredients().rename(flour, 'Olive Oil');
      expect(book().all.map((i) => i.name), ['Olive oil', 'Flour']);
      ingredients().rename(flour, 'FLOUR');
      expect(book().all.map((i) => i.name), ['Olive oil', 'FLOUR']);
    });

    test('the first one makes a section; new ones go to its top', () {
      ingredients().add('Flour');
      ingredients().add('  Sugar ');
      expect(ingredients().add('  '), isNull);
      expect(book().sections.single.name, IngredientsNotifier.firstSectionName);
      expect(book().all.map((i) => i.name), ['Sugar', 'Flour']);
    });

    test(
        'the first section stays on top; new ones go under it '
        '(Round 43)', () {
      ingredients().add('Flour');
      final dairy = ingredients().addSection('Dairy')!;
      ingredients().addSection('Fruit');
      ingredients().add('Milk');
      expect(book().sections.map((s) => s.name),
          ['Ingredients', 'Fruit', 'Dairy']);
      expect(book().sections.first.items.map((i) => i.name), ['Milk', 'Flour']);
      // Sections move, never above the first; the first doesn't move.
      ingredients().moveSection(dairy, 0);
      expect(book().sections.map((s) => s.name),
          ['Ingredients', 'Dairy', 'Fruit']);
      ingredients().moveSection(book().sections.first.id, 2);
      expect(book().sections.first.name, 'Ingredients');
    });

    test('a section first made on an empty list comes under the default', () {
      ingredients().addSection('Dairy');
      expect(book().sections.map((s) => s.name), ['Ingredients', 'Dairy']);
    });

    test("1.9.0's lists: Ingredients goes back to the top", () {
      final storage = AppStorage.inMemory(
        initialIngredients: IngredientBook([
          IngredientSection(id: 'a', name: 'Dairy'),
          IngredientSection(id: 'b', name: 'Ingredients'),
        ]),
      );
      final restarted = ProviderContainer(overrides: [
        appStorageProvider.overrideWithValue(storage),
      ]);
      addTearDown(restarted.dispose);
      expect(restarted.read(ingredientsProvider).sections.map((s) => s.id),
          ['b', 'a']);
    });

    test('moved within and between sections', () {
      final flour = ingredients().add('Flour')!;
      ingredients().add('Sugar');
      final baking = book().sections.single.id;
      final dairy = ingredients().addSection('Dairy')!;
      ingredients().move(flour, sectionId: dairy, index: 0);
      expect(book().sections.last.items.single.name, 'Flour');
      ingredients().move(flour, sectionId: baking, index: 1);
      expect(
          book().sections.first.items.map((i) => i.name), ['Sugar', 'Flour']);
      expect(book().sections.last.items, isEmpty);
    });

    test('a deleted section gives its ingredients to the one above', () {
      ingredients().add('Flour');
      ingredients().addSection('Dairy');
      ingredients().add('Milk');
      ingredients().addSection('Fruit');
      ingredients().add('Apple');
      // Ingredients, Fruit, Dairy: Dairy's go to Fruit (above it).
      final dairy = book().sections[2].id;
      final before = ingredients().deleteSection(dairy);
      expect(book().sections.map((s) => s.name), ['Ingredients', 'Fruit']);
      // (All three went to the first section: it's where + adds.)
      expect(book().sections.first.items.map((i) => i.name),
          ['Apple', 'Milk', 'Flour']);
      // The first one stays (Round 43).
      expect(ingredients().deleteSection(book().sections.first.id), isNull);
      ingredients().replaceAll(before!);
      expect(book().sections, hasLength(3));
    });

    test('renamed: recipes that use it follow; deleted: recipes keep it', () {
      final flour = ingredients().add('Flour')!;
      final id = recipes().add();
      recipes().save(recipes().byId(id)!.copyWith(ingredients: [
        RecipeIngredient(ingredientId: flour, name: 'Flour', quantity: '1 kg'),
        const RecipeIngredient(name: 'Salt'),
      ]));
      ingredients().rename(flour, 'Rye flour');
      expect(book().all.single.name, 'Rye flour');
      expect(recipes().byId(id)!.ingredients.map((i) => i.name),
          ['Rye flour', 'Salt']);
      expect(recipes().byId(id)!.ingredients.first.quantity, '1 kg');
      ingredients().delete(flour);
      expect(book().all, isEmpty);
      expect(recipes().byId(id)!.ingredients.first.name, 'Rye flour');
    });
  });

  group('quantities (Round 43)', () {
    test('written as picked, read back', () {
      for (final (amount, text) in [
        ((kind: AmountKind.none, value: 0.0), ''),
        ((kind: AmountKind.count, value: 3.0), '3'),
        ((kind: AmountKind.weight, value: 200.0), '200 g'),
        ((kind: AmountKind.weight, value: 1500.0), '1.5 kg'),
        ((kind: AmountKind.teaspoon, value: 0.5), '½ tsp'),
        ((kind: AmountKind.teaspoon, value: 1.5), '1½ tsp'),
        ((kind: AmountKind.tablespoon, value: 2.0), '2 tbsp'),
      ]) {
        expect(amountText(amount), text);
        expect(readAmount(text), amount, reason: text);
      }
      expect(readAmount('a pinch'), isNull, reason: 'typed before');
      expect(readAmount('1.5'), isNull, reason: 'half a piece');
    });

    test(
        'stepped like Shop: weights through the common ones, spoons by '
        'halves', () {
      expect(amountUp((kind: AmountKind.weight, value: 200)), 250);
      expect(amountDown((kind: AmountKind.weight, value: 200)), 150);
      expect(amountUp((kind: AmountKind.count, value: 2)), 3);
      expect(amountDown((kind: AmountKind.count, value: 1)), isNull);
      expect(amountUp((kind: AmountKind.tablespoon, value: 1)), 1.5);
      expect(amountDown((kind: AmountKind.teaspoon, value: 0.5)), isNull);
      // Spoons aren't a Shop amount: typed there (Round 70).
      expect(shopQuantityOf('2 tbsp').quantity, Quantity.text);
      expect(shopQuantityOf('2 tbsp').text, '2 tbsp');
      expect(shopQuantityOf('1.5 kg').quantity, Quantity.weight);
    });
  });

  group('To Shop (Round 41)', () {
    test('quantities as Shop reads them', () {
      ({Quantity? q, Object n}) read(String text) {
        final r = shopQuantityOf(text);
        return (
          q: r.quantity,
          n: switch (r.quantity) {
            Quantity.weight => r.grams,
            Quantity.count => r.count,
            Quantity.text => r.text,
            null => 0,
          },
        );
      }

      expect(read('200 g'), (q: Quantity.weight, n: 200));
      expect(read('200g'), (q: Quantity.weight, n: 200));
      expect(read('1.5 kg'), (q: Quantity.weight, n: 1500));
      expect(read('0,5 KG'), (q: Quantity.weight, n: 500));
      expect(read('2'), (q: Quantity.count, n: 2));
      expect(read('3 pcs'), (q: Quantity.count, n: 3));
      expect(read('1.5'), (q: Quantity.text, n: '1.5'), reason: 'half a piece');
      expect(read('1 tbsp'), (q: Quantity.text, n: '1 tbsp'));
      expect(read(' a pinch '), (q: Quantity.text, n: 'a pinch'));
      expect(read('1-2'), (q: Quantity.text, n: '1-2'));
      expect(read(''), (q: null, n: 0));
      expect(read('  '), (q: null, n: 0));
      expect(read('300 ml'), (q: Quantity.text, n: '300 ml'));
    });

    test(
        'all to the to-buy list: put back, or added, a copy for another '
        'quantity', () {
      final shop = container.read(shopProvider.notifier);
      shop.replaceAll(const [
        // Bought, same quantity: put back.
        ShopItem(
            id: 'a',
            name: 'flour',
            toBuy: false,
            quantity: Quantity.weight,
            grams: 200),
        // Bought, another quantity: a copy beside it.
        ShopItem(
            id: 'b',
            name: 'Eggs',
            toBuy: false,
            quantity: Quantity.count,
            count: 6),
        // Already to buy, the same typed amount (any case, Round 70):
        // left as it is.
        ShopItem(
            id: 'c', name: 'Salt', quantity: Quantity.text, text: 'A pinch'),
        // Another typed amount.
        ShopItem(id: 'd', name: 'Milk', quantity: Quantity.text, text: '1 l'),
      ]);
      final recipe = Recipe(
        id: 'r',
        name: 'Pancakes',
        createdAt: now,
        ingredients: const [
          RecipeIngredient(name: 'Flour', quantity: '200 g'),
          RecipeIngredient(name: 'Eggs', quantity: '2'),
          RecipeIngredient(name: 'Salt', quantity: 'a pinch'),
          RecipeIngredient(name: 'Milk', quantity: '300 ml'),
        ],
      );
      final done = sendToShop(container.read, recipe);
      final items = container.read(shopProvider);
      expect((done.added, done.putBack), (2, 1));
      expect(items.firstWhere((i) => i.id == 'a').toBuy, isTrue);
      final eggs = items.where((i) => i.name == 'Eggs').toList();
      expect(eggs, hasLength(2));
      expect(eggs.last.toBuy, isTrue);
      expect((eggs.last.quantity, eggs.last.count), (Quantity.count, 2));
      expect(items.where((i) => i.name == 'Salt'), hasLength(1));
      final milk = items.lastWhere((i) => i.name == 'Milk');
      expect(milk.id, isNot('d'));
      expect((milk.toBuy, milk.quantity, milk.text),
          (true, Quantity.text, '300 ml'));
      // Undo: Shop as it was.
      shop.replaceAll(done.before);
      expect(container.read(shopProvider), hasLength(4));
    });
  });

  test('Clear data counts and empties recipes with the ingredients list', () {
    ingredients().add('Flour');
    recipes().add();
    final data = container.read(sectionDataProvider);
    expect(data.countOf(HubTool.recipes), 2);
    expect(HubTool.recipes.clearable, isTrue);
    expect(HubTool.recipes.lockable, isTrue);
    data.clearOf(HubTool.recipes);
    expect(all(), isEmpty);
    expect(book().sections, isEmpty);
  });

  group('backups', () {
    test('in a backup and back, with the ingredients list', () async {
      ingredients().add('Flour');
      final id = recipes().add();
      recipes().save(recipes().byId(id)!.copyWith(name: 'Bread'));
      final backup = container.read(backupExporterProvider).snapshot();
      final decoded = Backup.decode(backup.encode());
      expect(decoded.recipes.single.name, 'Bread');
      expect(decoded.ingredients.all.single.name, 'Flour');

      final importer = container.read(backupImporterProvider);
      recipes().replaceAll(const []);
      ingredients().replaceAll(IngredientBook.empty);
      final picked = importer
          .read(Uint8List.fromList(utf8.encode(backup.encode()))) as PlainPick;
      final undo = await importer.restore(picked.backup);
      expect(all().single.name, 'Bread');
      expect(book().all.single.name, 'Flour');
      await importer.undo(undo!);
      expect(all(), isEmpty);
      expect(book().sections, isEmpty);
    });

    test('part of a backup: a recipe brings the ingredients it needs',
        () async {
      final backup = Backup(
        createdAt: DateTime(2026, 10, 14),
        appVersion: '1.9.0 (44)',
        notes: const [],
        shopItems: const [],
        recipes: [
          Recipe(
            id: 'r1',
            name: 'Pancakes',
            createdAt: now,
            ingredients: const [
              RecipeIngredient(ingredientId: 'i1', name: 'Flour'),
              RecipeIngredient(ingredientId: 'i3', name: 'Milk'),
            ],
          ),
          Recipe(id: 'r2', name: 'Not wanted', createdAt: now),
        ],
        ingredients: IngredientBook([
          IngredientSection(id: 's1', name: 'Baking', items: const [
            Ingredient(id: 'i1', name: 'Flour'),
            Ingredient(id: 'i2', name: 'Sugar'),
          ]),
          IngredientSection(id: 's2', name: 'Dairy', items: const [
            Ingredient(id: 'i3', name: 'Milk'),
          ]),
        ]),
      );
      // Dairy is here already (by name), Milk not.
      ingredients().addSection('Dairy');
      ingredients().move(ingredients().add('Butter')!,
          sectionId: book().sections.last.id, index: 0);
      final importer = container.read(backupImporterProvider);
      final picked = importer
          .read(Uint8List.fromList(utf8.encode(backup.encode()))) as PlainPick;
      final done = await importer.restorePart(picked.backup, {
        BackupPart.recipes: {'r1'},
      });
      expect(all().single.name, 'Pancakes');
      expect(done!.added, 1);
      expect(book().sections.map((s) => s.name),
          ['Ingredients', 'Dairy', 'Baking']);
      expect(book().sections[1].items.map((i) => i.name), ['Butter', 'Milk']);
      expect(book().sections.last.items.map((i) => i.name), ['Flour'],
          reason: 'only what the recipe needs');

      // Again: a copy, and no ingredient twice.
      await importer.restorePart(picked.backup, {
        BackupPart.recipes: {'r1'},
      });
      expect(all().map((r) => r.name), ['Pancakes', 'Pancakes (Copy)']);
      expect(book().size, 3);
    });
  });
}
