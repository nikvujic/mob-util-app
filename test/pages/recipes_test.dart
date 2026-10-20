import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:the_app/core/screen.dart';
import 'package:the_app/models/recipe.dart';
import 'package:the_app/models/shop_item.dart';
import 'package:the_app/providers/recipe_read_provider.dart';
import 'package:the_app/providers/recipes_provider.dart';
import 'package:the_app/providers/shop_provider.dart';
import 'package:the_app/widgets/selection.dart';

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

    testWidgets(
        'typing its name, the page stays still (Round 64: it bounced at '
        'every key)', (tester) async {
      tester.view.physicalSize = const Size(1080, 2340);
      tester.view.devicePixelRatio = 2.625;
      addTearDown(tester.view.reset);
      await openRecipes(tester);
      await tapTooltip(tester, 'New recipe');
      // The keyboard up.
      tester.view.viewInsets = const FakeViewPadding(bottom: 800);
      await tester.pumpAndSettle();
      final name = find.byKey(const Key('recipeName'));
      final at = tester.getTopLeft(name).dy;
      var text = '';
      for (final c in 'Pancakes'.split('')) {
        text += c;
        tester.testTextInput.updateEditingValue(TextEditingValue(
            text: text,
            selection: TextSelection.collapsed(offset: text.length)));
        for (var i = 0; i < 12; i++) {
          await tester.pump(const Duration(milliseconds: 16));
          expect(tester.getTopLeft(name).dy, at, reason: '"$text", frame $i');
        }
      }
      expect(find.text('Pancakes'), findsOneWidget);
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

    testWidgets(
        'open 5 minutes, it counts as read (Round 53: Pip eats after), '
        'marked again each minute it stays open', (tester) async {
      var now = DateTime(2026, 10, 15, 18);
      container = await pumpApp(tester, clock: () => now);
      container.read(recipesProvider.notifier).replaceAll([pancakes()]);
      await openTab(tester, 'Hub');
      await tester.tap(find.byTooltip('Recipes'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Pancakes'));
      await tester.pumpAndSettle();
      await tester.pump(const Duration(minutes: 4, seconds: 30));
      expect(container.read(recipeReadProvider), isNull, reason: 'not yet');
      await tester.pump(const Duration(seconds: 30));
      expect(container.read(recipeReadProvider), now);
      now = now.add(const Duration(minutes: 1));
      await tester.pump(const Duration(minutes: 1));
      expect(container.read(recipeReadProvider), now);
      await pressBack(tester);
      final left = container.read(recipeReadProvider);
      await tester.pump(const Duration(minutes: 3));
      expect(container.read(recipeReadProvider), left, reason: 'closed');
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

    testWidgets(
        'or typed as text (Round 70): "1-2", kept, and read back as text',
        (tester) async {
      await openEdit(tester);
      await options(tester, 1, 'quantity');
      final field = find.byKey(const Key('amountTypedText'));
      expect(field, findsNothing);
      await tester.tap(find.byKey(const Key('amount-text')));
      await tester.pump();
      expect(tester.widget<TextField>(field).controller!.text, '2',
          reason: 'starts from the amount picked');
      expect(find.byTooltip('More'), findsNothing);
      await tester.enterText(field, ' 1-2 ');
      await tester.testTextInput.receiveAction(TextInputAction.done);
      await tester.pumpAndSettle();
      expect(recipes().single.ingredients[1].quantity, '1-2');

      await options(tester, 1, 'quantity');
      expect(tester.widget<TextField>(field).controller!.text, '1-2');
      expect(
          tester
              .widget<ChoiceChip>(find.byKey(const Key('amount-text')))
              .selected,
          isTrue);
      await tester.tap(find.byKey(const Key('amount-count')));
      await tester.pump();
      expect(field, findsNothing);
      await pressBack(tester);
      expect(recipes().single.ingredients[1].quantity, '1');
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

    testWidgets(
        'Round 92: one already there isn\'t added again: said where it is, '
        'the sheet kept; renaming to another\'s name the same', (tester) async {
      await openList(tester);
      await tapTooltip(tester, 'Add ingredients');
      await tester.enterText(find.byType(TextField).last, ' milk ');
      await tester.testTextInput.receiveAction(TextInputAction.done);
      await tester.pumpAndSettle();
      expect(find.text('Milk is already in Dairy'), findsOneWidget);
      expect(find.text(' milk '), findsOneWidget, reason: 'kept to fix');
      expect(book().all.where((i) => i.name.toLowerCase() == 'milk'),
          hasLength(1));
      await tester.enterText(find.byType(TextField).last, 'Butter');
      await tester.pump();
      expect(find.byKey(const Key('textInputProblem')), findsNothing,
          reason: 'gone once changed');
      await tester.testTextInput.receiveAction(TextInputAction.done);
      await tester.pumpAndSettle();
      await pressBack(tester);
      expect(book().sections.first.items.first.name, 'Butter');

      await tester.longPress(find.text('Sugar'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Rename'));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField).last, 'flour');
      await tester.testTextInput.receiveAction(TextInputAction.done);
      await tester.pumpAndSettle();
      expect(find.text('Flour is already in Baking'), findsOneWidget);
      expect(book().all.map((i) => i.name), contains('Sugar'));
    });

    testWidgets(
        'Round 92: a section dragged only from its right edge (no handle '
        'drawn); dropped only between sections, where a line shows; the '
        'first stays', (tester) async {
      await openList(tester);
      container.read(ingredientsProvider.notifier).addSection('Fruit');
      await tester.pumpAndSettle();
      List<String> names() => book().sections.map((s) => s.name).toList();
      expect(names(), ['Baking', 'Fruit', 'Dairy']);
      Finder handleOf(String id) => find.byKey(Key('sectionHandle-$id'));
      expect(handleOf('s1'), findsNothing, reason: 'the first stays');
      expect(
          find.descendant(
              of: find.byKey(const ValueKey('section-s2')),
              matching: find.byIcon(Icons.drag_handle)),
          findsNothing,
          reason: 'no handle drawn');
      final handle = tester.getRect(handleOf('s2'));
      final name = tester.getRect(find.byKey(const ValueKey('section-s2')));
      expect(handle.right, name.right, reason: 'at the right edge');
      expect(handle.width, ReorderOrSelectIndicator.width);
      expect(handle.height, greaterThanOrEqualTo(kMinInteractiveDimension));
      // Adding a section: a list with a plus, not a folder.
      expect(
          find.descendant(
              of: find.byTooltip('Add a section'),
              matching: find.byIcon(Icons.playlist_add)),
          findsOneWidget);

      Future<TestGesture> dragTo(String id, Finder over) async {
        final from = tester.getCenter(handleOf(id));
        final to = Offset(from.dx, tester.getCenter(over).dy);
        final drag = await tester.startGesture(from);
        await tester.pump();
        for (var i = 1; i <= 10; i++) {
          await drag.moveTo(Offset.lerp(from, to, i / 10)!);
          await tester.pump(const Duration(milliseconds: 30));
        }
        return drag;
      }

      double line(int before) =>
          tester.getSize(find.byKey(Key('sectionDropLine-$before'))).height;

      // From its name: no drag (a tap gives its options).
      final byName = await tester
          .startGesture(tester.getCenter(find.textContaining('DAIRY')));
      await tester.pump();
      await byName.moveBy(const Offset(0, -150));
      await tester.pump();
      await byName.up();
      await tester.pumpAndSettle();
      expect(names(), ['Baking', 'Fruit', 'Dairy']);

      // Dairy over Fruit's name: a line above Fruit; let go, it's there.
      var drag = await dragTo('s2', find.textContaining('FRUIT'));
      await tester.pumpAndSettle();
      expect(line(1), greaterThan(0));
      await drag.up();
      await tester.pumpAndSettle();
      expect(names(), ['Baking', 'Dairy', 'Fruit']);
      expect(line(1), 0, reason: 'gone once dropped');

      // Over one of Baking's ingredients: after Baking (it can't go above
      // the first; it's there already: nothing moves).
      drag = await dragTo('s2', find.text('Flour'));
      await tester.pumpAndSettle();
      await drag.up();
      await tester.pumpAndSettle();
      expect(names(), ['Baking', 'Dairy', 'Fruit']);

      final fruit = book().sections.last.id;
      // Fruit dragged over Dairy's ingredient (Milk): after Dairy.
      container.read(ingredientsProvider.notifier).moveSection(fruit, 1);
      await tester.pumpAndSettle();
      expect(names(), ['Baking', 'Fruit', 'Dairy']);
      drag = await dragTo(fruit, find.text('Milk'));
      await tester.pumpAndSettle();
      expect(line(3), greaterThan(0), reason: 'the end line');
      await drag.up();
      await tester.pumpAndSettle();
      expect(names(), ['Baking', 'Dairy', 'Fruit']);

      // Over the first's name: right under it (never above), the line
      // there.
      drag = await dragTo(fruit, find.textContaining('BAKING'));
      await tester.pumpAndSettle();
      expect(line(1), greaterThan(0));
      expect(
          find.byKey(const Key('sectionDropLine-0')).evaluate().isEmpty
              ? 0.0
              : line(0),
          0);
      await drag.up();
      await tester.pumpAndSettle();
      expect(names(), ['Baking', 'Fruit', 'Dairy']);

      // Down past one: a fourth, Fruit over its name, lands just above it.
      container.read(ingredientsProvider.notifier).addSection('Meat');
      await tester.pumpAndSettle();
      container.read(ingredientsProvider.notifier).moveSection(
          book().sections.firstWhere((s) => s.name == 'Meat').id, 3);
      await tester.pumpAndSettle();
      expect(names(), ['Baking', 'Fruit', 'Dairy', 'Meat']);
      drag = await dragTo(fruit, find.textContaining('MEAT'));
      await tester.pumpAndSettle();
      await drag.up();
      await tester.pumpAndSettle();
      expect(names(), ['Baking', 'Dairy', 'Fruit', 'Meat']);
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
        "a tap on a section's name opens its menu (Round 45); delete moves "
        'its ingredients up', (tester) async {
      await openList(tester);
      await tester.tap(find.text('DAIRY  ·  2'));
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
