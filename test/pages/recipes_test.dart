import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:the_app/core/screen.dart';
import 'package:the_app/models/recipe.dart';
import 'package:the_app/models/shop_item.dart';
import 'package:the_app/providers/recipes_provider.dart';
import 'package:the_app/providers/shop_provider.dart';

import '../helpers.dart';

/// Hub → Recipes, a recipe's view and edit modes, the ingredients list
/// (Round 42).
void main() {
  late ProviderContainer container;

  /// What the screen was last told: kept on or not.
  bool? screenOn;

  setUp(() {
    screenOn = null;
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(KeepScreenOn.channel, (call) async {
      if (call.method == 'keepOn') screenOn = call.arguments as bool;
      return null;
    });
  });
  tearDown(() => TestDefaultBinaryMessengerBinding
      .instance.defaultBinaryMessenger
      .setMockMethodCallHandler(KeepScreenOn.channel, null));

  List<Recipe> recipes() => container.read(recipesProvider);
  IngredientBook book() => container.read(ingredientsProvider);

  Recipe pancakes() => Recipe(
        id: 'r1',
        name: 'Pancakes',
        prepMinutes: 25,
        type: RecipeType.breakfast,
        ingredients: const [
          RecipeIngredient(
              ingredientId: 'i1', name: 'Flour', quantity: '200 g'),
          RecipeIngredient(ingredientId: 'i2', name: 'Eggs', quantity: '2'),
        ],
        method: '1. Mix\n2. Fry',
        createdAt: DateTime(2026, 10, 14),
      );

  IngredientBook sampleBook() => IngredientBook([
        IngredientSection(id: 's1', name: 'Baking', items: const [
          Ingredient(id: 'i1', name: 'Flour'),
          Ingredient(id: 'i3', name: 'Sugar'),
        ]),
        IngredientSection(id: 's2', name: 'Dairy', items: const [
          Ingredient(id: 'i2', name: 'Eggs'),
          Ingredient(id: 'i4', name: 'Milk'),
        ]),
      ]);

  Future<void> openRecipes(
    WidgetTester tester, {
    List<Recipe> start = const [],
    IngredientBook? ingredients,
  }) async {
    container = await pumpApp(tester);
    container.read(recipesProvider.notifier).replaceAll(start);
    container
        .read(ingredientsProvider.notifier)
        .replaceAll(ingredients ?? IngredientBook.empty);
    await openTab(tester, 'Hub');
    await tester.tap(find.byTooltip('Recipes'));
    await tester.pumpAndSettle();
  }

  Future<void> tapTooltip(WidgetTester tester, String tooltip) async {
    await tester.tap(find.byTooltip(tooltip));
    await tester.pumpAndSettle();
  }

  group('the Recipes page', () {
    testWidgets('lists name and "prep time · type"; empty says so',
        (tester) async {
      await openRecipes(tester);
      expect(appBarTitle('Recipes'), findsOneWidget);
      expect(find.text('No recipes'), findsOneWidget);

      container.read(recipesProvider.notifier).replaceAll([pancakes()]);
      await tester.pumpAndSettle();
      expect(find.text('Pancakes'), findsOneWidget);
      // As chips (Round 44).
      expect(
          find.descendant(
              of: find.byKey(const Key('recipeChip-time')),
              matching: find.text('25 min')),
          findsOneWidget);
      expect(
          find.descendant(
              of: find.byKey(const Key('recipeChip-type')),
              matching: find.text('Breakfast')),
          findsOneWidget);
    });

    testWidgets('+ opens a new one in edit mode; left empty, it is dropped',
        (tester) async {
      await openRecipes(tester);
      await tapTooltip(tester, 'New recipe');
      expect(appBarTitle('Edit recipe'), findsOneWidget);
      expect(recipes(), hasLength(1));
      await pressBack(tester); // the keyboard's field first
      await pressBack(tester);
      expect(appBarTitle('Recipes'), findsOneWidget);
      expect(recipes(), isEmpty);
    });

    testWidgets('a new one named, Done: view mode, and in the list',
        (tester) async {
      await openRecipes(tester);
      await tapTooltip(tester, 'New recipe');
      await tester.enterText(find.byKey(const Key('recipeName')), 'Soup');
      await tester.pump();
      await tapTooltip(tester, 'Done');
      expect(appBarTitle('Soup'), findsOneWidget);
      expect(find.byTooltip('More'), findsOneWidget);
      expect(recipes().single.name, 'Soup');
      await pressBack(tester);
      expect(find.text('Soup'), findsOneWidget);
    });

    testWidgets('selected and deleted, asked first', (tester) async {
      await openRecipes(tester, start: [pancakes()]);
      await tester.longPress(find.text('Pancakes'));
      await tester.pumpAndSettle();
      await tapTooltip(tester, 'Delete');
      await tester.tap(find.text('Delete').last);
      await tester.pumpAndSettle();
      expect(recipes(), isEmpty);
    });

    testWidgets('the Ingredients button opens the list to manage it',
        (tester) async {
      await openRecipes(tester);
      await tapTooltip(tester, 'Ingredients');
      expect(appBarTitle('Ingredients'), findsOneWidget);
      expect(find.byTooltip('Add a section'), findsOneWidget);
    });
  });

  group('view mode', () {
    testWidgets(
        'time, type, ingredients with quantities, the method; the '
        'screen kept on while open', (tester) async {
      await openRecipes(tester, start: [pancakes()]);
      await tester.tap(find.text('Pancakes'));
      await tester.pumpAndSettle();
      expect(screenOn, isTrue);
      expect(appBarTitle('Pancakes'), findsOneWidget);
      expect(find.text('25 min'), findsOneWidget);
      expect(find.text('Breakfast'), findsOneWidget);
      expect(find.text('INGREDIENTS  ·  2'), findsOneWidget);
      expect(find.text('200 g'), findsOneWidget);
      expect(find.text('Eggs'), findsOneWidget);
      final method =
          tester.widget<TextField>(find.byKey(const Key('recipeMethodView')));
      expect(method.readOnly, isTrue);
      expect(method.controller!.text, '1. Mix\n2. Fry');
      // No reach mode here (Nikola).
      expect(find.byKey(const Key('recipeView')), findsOneWidget);

      await pressBack(tester);
      expect(screenOn, isFalse, reason: 'off on leaving');
    });

    testWidgets('To Shop puts them on the to-buy list, with Undo',
        (tester) async {
      await openRecipes(tester, start: [pancakes()]);
      container.read(shopProvider.notifier).replaceAll(const [
        ShopItem(
            id: 'x',
            name: 'Eggs',
            toBuy: false,
            quantity: Quantity.count,
            count: 2),
      ]);
      await tester.tap(find.text('Pancakes'));
      await tester.pumpAndSettle();
      await tapTooltip(tester, 'More');
      await tester.tap(find.byKey(const Key('choice-shop')));
      await tester.pumpAndSettle();
      expect(
          find.text('1 added to Shop, 1 put back on the list'), findsOneWidget);
      final shop = container.read(shopProvider);
      expect(shop.every((i) => i.toBuy), isTrue);
      final flour = shop.singleWhere((i) => i.name == 'Flour');
      expect((flour.quantity, flour.grams), (Quantity.weight, 200.0));

      await tester.tap(find.text('Undo'));
      await tester.pumpAndSettle();
      expect(container.read(shopProvider).single.toBuy, isFalse);
    });

    testWidgets('the menu: duplicate opens the copy in edit mode',
        (tester) async {
      await openRecipes(tester, start: [pancakes()]);
      await tester.tap(find.text('Pancakes'));
      await tester.pumpAndSettle();
      await tapTooltip(tester, 'More');
      await tester.tap(find.byKey(const Key('choice-duplicate')));
      await tester.pumpAndSettle();
      expect(appBarTitle('Edit recipe'), findsOneWidget);
      expect(recipes().map((r) => r.name), ['Pancakes', 'Pancakes (Copy)']);
      expect(screenOn, isTrue, reason: 'the copy keeps it on');
      expect(
        tester
            .widget<TextField>(find.byKey(const Key('recipeName')))
            .controller!
            .text,
        'Pancakes (Copy)',
      );
    });

    testWidgets('the menu: copied to the clipboard as plain text',
        (tester) async {
      String? copied;
      tester.binding.defaultBinaryMessenger
          .setMockMethodCallHandler(SystemChannels.platform, (call) async {
        if (call.method == 'Clipboard.setData') {
          copied = (call.arguments as Map)['text'] as String;
        }
        return null;
      });
      addTearDown(() => tester.binding.defaultBinaryMessenger
          .setMockMethodCallHandler(SystemChannels.platform, null));
      await openRecipes(tester, start: [pancakes()]);
      await tester.tap(find.text('Pancakes'));
      await tester.pumpAndSettle();
      await tapTooltip(tester, 'More');
      await tester.tap(find.byKey(const Key('choice-copy')));
      await tester.pumpAndSettle();
      expect(
        copied,
        'Pancakes\n\n25 min · Breakfast\n\n'
        'Ingredients\n- Flour: 200 g\n- Eggs: 2\n\n'
        'Method\n1. Mix\n2. Fry',
      );
    });

    testWidgets('the menu: deleted, with Undo', (tester) async {
      await openRecipes(tester, start: [pancakes()]);
      await tester.tap(find.text('Pancakes'));
      await tester.pumpAndSettle();
      await tapTooltip(tester, 'More');
      await tester.tap(find.byKey(const Key('choice-delete')));
      await tester.pumpAndSettle();
      expect(appBarTitle('Recipes'), findsOneWidget);
      expect(recipes(), isEmpty);
      await tester.tap(find.text('Undo'));
      await tester.pumpAndSettle();
      expect(recipes().single.name, 'Pancakes');
    });
  });

  group('edit mode', () {
    Future<void> openEdit(WidgetTester tester) async {
      await openRecipes(tester, start: [pancakes()], ingredients: sampleBook());
      await tester.tap(find.text('Pancakes'));
      await tester.pumpAndSettle();
      await tapTooltip(tester, 'Edit');
    }

    testWidgets('prep time from the picker, type from the list',
        (tester) async {
      await openEdit(tester);
      await tester.tap(find.byKey(const Key('recipePrepTime')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('prepTimeMore')));
      await tester.pump();
      expect(find.text('30 min'), findsWidgets);
      await tester.tap(find.byKey(const Key('prepTime-90')));
      await tester.pump();
      await tester.tap(find.byKey(const Key('prepTimeSet')));
      await tester.pumpAndSettle();
      expect(recipes().single.prepMinutes, 90);
      expect(find.text('1 h 30'), findsOneWidget);

      await tester.tap(find.byKey(const Key('recipeType')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('recipeType-cake')));
      await tester.pumpAndSettle();
      expect(recipes().single.type, RecipeType.cake);

      await tester.tap(find.byKey(const Key('recipePrepTime')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('prepTimeClear')));
      await tester.pumpAndSettle();
      expect(recipes().single.prepMinutes, isNull);
    });

    testWidgets('+ Add picks from the list; those in it ticked and greyed',
        (tester) async {
      await openEdit(tester);
      await tester.ensureVisible(find.byKey(const Key('recipeAddIngredients')));
      await tester.tap(find.byKey(const Key('recipeAddIngredients')));
      await tester.pumpAndSettle();
      expect(appBarTitle('Pick ingredients'), findsOneWidget);
      // Flour is in it already: ticked, and a tap does nothing.
      await tester.tap(find.text('Flour'));
      await tester.pump();
      expect(find.text('Add'), findsOneWidget, reason: 'none picked');
      expect(
          find.descendant(
              of: find.byKey(const Key('ingredient-i1')),
              matching: find.byIcon(Icons.check_box)),
          findsOneWidget);
      await tester.tap(find.text('Milk'));
      await tester.tap(find.text('Sugar'));
      await tester.pump();
      expect(find.text('Add 2'), findsOneWidget);
      await tester.tap(find.byKey(const Key('addPicked')));
      await tester.pumpAndSettle();
      expect(recipes().single.ingredients.map((i) => i.name),
          ['Flour', 'Eggs', 'Sugar', 'Milk'],
          reason: 'at the end, in the list order');
    });

    testWidgets(
        'from picking, Edit adds a missing one; back returns to '
        'picking', (tester) async {
      await openEdit(tester);
      await tester.ensureVisible(find.byKey(const Key('recipeAddIngredients')));
      await tester.tap(find.byKey(const Key('recipeAddIngredients')));
      await tester.pumpAndSettle();
      await tapTooltip(tester, 'Edit ingredients');
      expect(appBarTitle('Ingredients'), findsOneWidget);
      await tapTooltip(tester, 'Add ingredients');
      await tester.enterText(find.byType(TextField).last, 'Butter');
      await tester.testTextInput.receiveAction(TextInputAction.done);
      await tester.pumpAndSettle();
      await pressBack(tester); // the sheet
      await pressBack(tester);
      expect(appBarTitle('Pick ingredients'), findsOneWidget);
      expect(find.text('Butter'), findsOneWidget);
      expect(book().sections.first.items.first.name, 'Butter');
    });

    Future<void> options(WidgetTester tester, int index, String choice) async {
      await tester.tap(find.byKey(Key('recipeIngredientRow-$index')));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('choice-quantity')), findsOneWidget);
      expect(tester.getCenter(find.byKey(const Key('choice-quantity'))).dy,
          lessThan(tester.getCenter(find.byKey(const Key('choice-delete'))).dy),
          reason: 'Quantity, then Delete (Round 43)');
      await tester.tap(find.byKey(Key('choice-$choice')));
      await tester.pumpAndSettle();
    }

    testWidgets(
        'a tap gives Quantity and Delete; quantities picked like Shop’s, '
        'spoons too (Round 43)', (tester) async {
      await openEdit(tester);
      // No quantity button on the rows: only the quantity, quietly.
      expect(find.text('Quantity'), findsNothing);
      await options(tester, 1, 'quantity');
      // "2" read as a count; one more.
      expect(find.byKey(const Key('amountValue')), findsOneWidget);
      await tester.tap(find.byTooltip('More'));
      await tester.pump();
      expect(find.text('3'), findsWidgets);
      await tester.tap(find.byKey(const Key('amount-tablespoon')));
      await tester.pump();
      await tester.tap(find.byTooltip('More'));
      await tester.pump();
      await pressBack(tester);
      expect(recipes().single.ingredients[1].quantity, '1½ tbsp');
      expect(find.text('1½ tbsp'), findsOneWidget);

      await options(tester, 0, 'delete');
      expect(recipes().single.ingredients.map((i) => i.name), ['Eggs']);
      await tester.tap(find.text('Undo'));
      await tester.pumpAndSettle();
      expect(
          recipes().single.ingredients.map((i) => i.name), ['Flour', 'Eggs']);
    });

    testWidgets('holding selects (no hold-to-delete); several removed at once',
        (tester) async {
      await openEdit(tester);
      await tester.longPress(find.byKey(const Key('recipeIngredientRow-0')));
      await tester.pumpAndSettle();
      expect(recipes().single.ingredients, hasLength(2), reason: 'kept');
      await tester.tap(find.byKey(const Key('recipeIngredientRow-1')));
      await tester.pumpAndSettle();
      await tapTooltip(tester, 'Remove selected');
      expect(recipes().single.ingredients, isEmpty);
      await tester.tap(find.text('Undo'));
      await tester.pumpAndSettle();
      expect(recipes().single.ingredients, hasLength(2));
    });

    testWidgets(
        'after a sheet the page stays where it was, the method not '
        'typed in (Round 43)', (tester) async {
      await openEdit(tester);
      final method = find.byKey(const Key('recipeMethod'));
      await tester.ensureVisible(method);
      await tester.tap(method);
      await tester.pumpAndSettle();
      final focus = tester.widget<TextField>(method).focusNode!;
      expect(focus.hasFocus, isTrue);
      await tester.drag(
          find.byKey(const Key('recipeName')), const Offset(0, 200));
      await tester.pumpAndSettle();
      final nameAt = tester.getTopLeft(find.byKey(const Key('recipeName')));
      await tester.tap(find.byKey(const Key('recipeType')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('recipeType-cake')));
      await tester.pumpAndSettle();
      expect(focus.hasFocus, isFalse, reason: 'no cursor back in the method');
      expect(tester.getTopLeft(find.byKey(const Key('recipeName'))), nameAt,
          reason: 'no jump');
    });

    testWidgets('closing the keyboard ends typing in the method, as in notes',
        (tester) async {
      await openEdit(tester);
      final method = find.byKey(const Key('recipeMethod'));
      await tester.ensureVisible(method);
      await tester.tap(method);
      await tester.pumpAndSettle();
      final focus = tester.widget<TextField>(method).focusNode!;
      tester.view.viewInsets = const FakeViewPadding(bottom: 300);
      addTearDown(tester.view.resetViewInsets);
      await tester.pumpAndSettle();
      expect(focus.hasFocus, isTrue);
      tester.view.viewInsets = FakeViewPadding.zero;
      await tester.pumpAndSettle();
      expect(focus.hasFocus, isFalse);
    });

    testWidgets('Undo steps back; Discard goes back to before Edit',
        (tester) async {
      await openEdit(tester);
      await tester.enterText(find.byKey(const Key('recipeName')), 'Crêpes');
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('recipeType')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('recipeType-none')));
      await tester.pumpAndSettle();
      expect(recipes().single.type, isNull);
      await tapTooltip(tester, 'Undo');
      expect(recipes().single.type, RecipeType.breakfast);

      await tapTooltip(tester, 'Discard changes');
      await tester.tap(find.text('Discard'));
      await tester.pumpAndSettle();
      expect(recipes().single.name, 'Pancakes');
      expect(
        tester
            .widget<TextField>(find.byKey(const Key('recipeName')))
            .controller!
            .text,
        'Pancakes',
      );
    });

    testWidgets('the method is written as a note is (Markdown)',
        (tester) async {
      await openEdit(tester);
      final method = find.byKey(const Key('recipeMethod'));
      await tester.ensureVisible(method);
      await tester.enterText(method, '- Mix\n- Fry');
      await tester.pump(const Duration(seconds: 1));
      expect(recipes().single.method, '- Mix\n- Fry');
      await tester.tap(method);
      await tester.pump();
      expect(find.byTooltip('Format'), findsOneWidget);
    });

    testWidgets('an ingredient renamed in the list is renamed in recipes',
        (tester) async {
      await openRecipes(tester, start: [pancakes()], ingredients: sampleBook());
      container.read(ingredientsProvider.notifier).rename('i1', 'Rye flour');
      await tester.tap(find.text('Pancakes'));
      await tester.pumpAndSettle();
      expect(find.text('Rye flour'), findsOneWidget);
    });
  });

  group('the ingredients list', () {
    Future<void> openList(WidgetTester tester) async {
      await openRecipes(tester, ingredients: sampleBook());
      await tapTooltip(tester, 'Ingredients');
    }

    testWidgets('sections with their ingredients', (tester) async {
      await openList(tester);
      expect(find.text('BAKING  ·  2'), findsOneWidget);
      expect(find.text('DAIRY  ·  2'), findsOneWidget);
      expect(find.text('Milk'), findsOneWidget);
    });

    testWidgets(
        '+ adds to the top of the first section; Section adds one '
        'under it (Round 43)', (tester) async {
      await openList(tester);
      await tapTooltip(tester, 'Add ingredients');
      await tester.enterText(find.byType(TextField).last, 'Salt');
      await tester.testTextInput.receiveAction(TextInputAction.done);
      await tester.pumpAndSettle();
      await pressBack(tester);
      expect(book().sections.first.items.first.name, 'Salt');

      await tapTooltip(tester, 'Add a section');
      await tester.enterText(find.byType(TextField).last, 'Fruit');
      await tester.testTextInput.receiveAction(TextInputAction.done);
      await tester.pumpAndSettle();
      expect(book().sections.map((s) => s.name), ['Baking', 'Fruit', 'Dairy']);
    });

    testWidgets("a section moved by its handle; the first one has none",
        (tester) async {
      await openList(tester);
      Finder handleOf(String id) => find.descendant(
            of: find.byKey(ValueKey('section-$id')),
            matching: find.byIcon(Icons.drag_handle),
          );
      expect(handleOf('s1'), findsNothing, reason: 'the first stays');
      // Level with the name (Round 44), its touch area still full height.
      expect(
          tester.getCenter(handleOf('s2')).dy,
          moreOrLessEquals(tester.getCenter(find.text('DAIRY  ·  2')).dy,
              epsilon: 3));
      expect(tester.getSize(find.byKey(const Key('sectionHandle-s2'))).height,
          greaterThanOrEqualTo(kMinInteractiveDimension));
      // Adding a section: a list with a plus, not a folder.
      expect(
          find.descendant(
              of: find.byTooltip('Add a section'),
              matching: find.byIcon(Icons.playlist_add)),
          findsOneWidget);
      final handle = handleOf('s2');
      expect(handle, findsOneWidget);
      // Dairy dragged above Baking's ingredients: it can't pass the first.
      final gesture = await tester.startGesture(tester.getCenter(handle));
      await tester.pump(const Duration(milliseconds: 100));
      await gesture.moveTo(tester.getCenter(find.text('BAKING  ·  2')));
      await tester.pump(const Duration(milliseconds: 500));
      await gesture.up();
      await tester.pumpAndSettle();
      expect(book().sections.map((s) => s.name), ['Baking', 'Dairy']);

      // A third, under the first, then Dairy dragged to the end.
      container.read(ingredientsProvider.notifier).addSection('Fruit');
      await tester.pumpAndSettle();
      expect(book().sections.map((s) => s.name), ['Baking', 'Fruit', 'Dairy']);
      // Dairy dragged up onto Fruit's name: between Baking and Fruit.
      final drag = await tester.startGesture(tester.getCenter(handleOf('s2')));
      await tester.pump(const Duration(milliseconds: 100));
      final from = tester.getCenter(handleOf('s2'));
      final to =
          Offset(from.dx, tester.getTopLeft(find.textContaining('FRUIT')).dy);
      for (var i = 1; i <= 10; i++) {
        await drag.moveTo(Offset.lerp(from, to, i / 10)!);
        await tester.pump(const Duration(milliseconds: 50));
      }
      await tester.pump(const Duration(milliseconds: 500));
      await drag.up();
      await tester.pumpAndSettle();
      expect(book().sections.map((s) => s.name), ['Baking', 'Dairy', 'Fruit']);
    });

    testWidgets('holding one renames or deletes it', (tester) async {
      await openList(tester);
      await tester.longPress(find.text('Sugar'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Delete'));
      await tester.pumpAndSettle();
      expect(book().all.map((i) => i.name), isNot(contains('Sugar')));
      await tester.tap(find.text('Undo'));
      await tester.pumpAndSettle();
      expect(book().all.map((i) => i.name), contains('Sugar'));

      await tester.longPress(find.text('Milk'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Rename'));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField).last, 'Oat milk');
      await tester.testTextInput.receiveAction(TextInputAction.done);
      await tester.pumpAndSettle();
      expect(book().byId('i4')!.name, 'Oat milk');
    });

    testWidgets(
        "holding a section's name deletes it, its ingredients "
        'moved up', (tester) async {
      await openList(tester);
      await tester.longPress(find.text('DAIRY  ·  2'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Delete section'));
      await tester.pumpAndSettle();
      expect(book().sections.single.items.map((i) => i.name),
          ['Flour', 'Sugar', 'Eggs', 'Milk']);
    });

    testWidgets('dragged into another section', (tester) async {
      await openList(tester);
      final handle = find.descendant(
        of: find.byKey(const Key('ingredient-i1')),
        matching: find.byIcon(Icons.drag_handle),
      );
      final milk = tester.getCenter(find.text('Milk'));
      final gesture = await tester.startGesture(tester.getCenter(handle));
      await tester.pump(const Duration(milliseconds: 100));
      await gesture.moveTo(Offset(tester.getCenter(handle).dx, milk.dy + 30));
      await tester.pump(const Duration(milliseconds: 500));
      await gesture.up();
      await tester.pumpAndSettle();
      expect(book().sections.first.items.map((i) => i.name), ['Sugar']);
      expect(book().sections.last.items.map((i) => i.name), contains('Flour'),
          reason: 'now in Dairy');
    });
  });
}
