// Design checks: Android accessibility guidelines on every screen, and the
// size relationships the requirements ask for. See docs/ARCHITECTURE.md.
import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:the_app/models/food.dart';
import 'package:the_app/models/recipe.dart';
import 'package:the_app/app/app.dart';
import 'package:the_app/core/crypto.dart';
import 'package:the_app/core/format.dart';
import 'package:the_app/core/theme.dart';
import 'package:the_app/data/backup.dart';
import 'package:the_app/models/app_section.dart';
import 'package:the_app/models/shop_item.dart';
import 'package:the_app/providers/counters_provider.dart';
import 'package:the_app/providers/notes_provider.dart';
import 'package:the_app/providers/medicine_provider.dart';
import 'package:the_app/providers/recipes_provider.dart';
import 'package:the_app/providers/pins_provider.dart';
import 'package:the_app/providers/planner_provider.dart';
import 'package:the_app/providers/preferences_provider.dart';
import 'package:the_app/providers/routines_provider.dart';
import 'package:the_app/providers/section_locks_provider.dart';
import 'package:the_app/providers/security_provider.dart';
import 'package:the_app/providers/food_provider.dart';
import 'package:the_app/providers/todo_provider.dart';
import 'package:the_app/providers/notification_log_provider.dart';
import 'package:the_app/data/reminder_scheduler.dart';
import 'package:the_app/providers/session_provider.dart';
import 'package:the_app/providers/shop_provider.dart';
import 'package:the_app/widgets/selection.dart';

import 'helpers.dart';

/// A fixed "now" (Thursday 8 October 2026, 09:00), so every screen looks
/// the same whenever the tests run (e.g. the planner opens around now).
DateTime designClock() => DateTime(2026, 10, 8, 9);

/// Sets a master password and opens "Forgot master password?" (L7).
Future<void> openForgotPassword(WidgetTester t) async {
  final container = ProviderScope.containerOf(t.element(find.byType(MyApp)));
  await t.runAsync(
    () => container.read(securityProvider.notifier).setPassword('password1'),
  );
  await openMenu(t);
  await t.tap(find.text('Security'));
  await t.pumpAndSettle();
  final tile = find.text('Forgot master password?');
  await t.ensureVisible(tile);
  await t.tap(tile);
  await t.pumpAndSettle();
  expect(find.text('Reset master password?'), findsOneWidget);
}

/// Seeds a few notes (one locked) and shop items (in both sections).
Future<void> seed(ProviderContainer container) async {
  // A backup due (D8): the menu's dot and Backup's red line are checked.
  container
      .read(preferencesProvider.notifier)
      .backedUp(designClock().subtract(const Duration(days: 10)));
  // A notification shown an hour ago (Round 31), for the history.
  container.read(notificationLogProvider.notifier).planned([
    Reminder(
      at: designClock().subtract(const Duration(hours: 1)),
      title: 'Dentist',
      body: 'Now · 09:00–10:00',
      target: 'planner|2026-10-08|480',
    ),
  ], designClock().subtract(const Duration(hours: 2)));
  // The to-do note's list (Round 28).
  container.read(todoProvider.notifier)
    ..add('Call the dentist')
    ..add('Pay rent');
  final notes = container.read(notesProvider.notifier)
    ..addNote(title: 'Bank', content: 'PIN')
    ..addNote(
      title: 'Groceries',
      // Markdown (N9): the styled text is checked too.
      content: '## Today\n- **milk**\n1. *eggs* ~~tea~~',
    )
    ..addNote(title: 'Trip plan');
  final bank = container.read(notesProvider).last.id;
  await notes.lockNote(bank, DataKey.fromBytes(List.filled(32, 1)));
  // Every format (N17): checked for contrast in each theme.
  notes.addNote(
    title: 'Formats',
    content: '#### Small heading\n> A quote\nSome `code` and ==a highlight==\n'
        '---\n```\nx = 1\n```\nend',
  );
  final shop = container.read(shopProvider.notifier)
    ..addItem('Milk')
    ..addItem('Bread')
    ..addItem('Eggs');
  shop.toggle(
    container.read(shopProvider).firstWhere((i) => i.name == 'Milk').id,
  );
  // Amounts (S7): Bread a count, Eggs a weight; Milk (bought) shows one.
  String shopId(String name) =>
      container.read(shopProvider).firstWhere((i) => i.name == name).id;
  shop
    ..setQuantity(shopId('Bread'), Quantity.count)
    ..setCount(shopId('Bread'), 2)
    ..setQuantity(shopId('Eggs'), Quantity.weight)
    ..setGrams(shopId('Eggs'), 1500)
    ..setQuantity(shopId('Milk'), Quantity.count);
  final today = designClock();
  final planner = container.read(plannerProvider.notifier)
    ..addTask(today, 'Gym', start: 8 * 60, end: 9 * 60)
    ..addTask(
      today,
      'Call the bank',
      start: 10 * 60,
      end: 11 * 60,
      color: 'blue', // a coloured block (P9) is checked too
      description: 'Ask about the card', // P20
    );
  planner.toggleDone(container.read(plannerProvider).first.id);
  // A routine (P8), sharing time with a task: side by side (P12).
  container.read(routinesProvider.notifier).add(
        title: 'Stand-up',
        start: 10 * 60 + 30,
        end: 11 * 60 + 30,
        weekdays: {1, 2, 3, 4, 5},
        from: DateTime(2026, 10, 1),
        color: 'purple',
      );
  // A 5-minute block: it stretches its hour (Round 10).
  container.read(plannerProvider.notifier).addTask(today, 'Pills',
      start: 20 * 60, end: 20 * 60 + 5, description: 'With water');
  // A reminder (P14): a mark beside the task and routine.
  container
      .read(pinsProvider.notifier)
      .add(today, 'Call mum', time: 10 * 60 + 40);
  container.read(countersProvider.notifier)
    ..add('Push-ups')
    ..add('Glasses of water')
    // With options (O5): a colour, a step and limits.
    ..add('Water', options: (
      name: 'Water',
      step: 250,
      color: 'blue',
      min: 0,
      max: 3000,
    ));
  // The medicine tracker (O6): one dose taken, one not; one ended. The
  // antibiotic is important (Round 24): the hold-to-take is checked too.
  final medicine = container.read(medicineProvider.notifier);
  final pills = medicine.add('Antibiotic',
      times: [480, 1200], from: addDays(today, -3), important: true)!;
  medicine
    ..toggleDose(pills, today, 0)
    ..add('Course',
        times: [540], from: addDays(today, -20), until: addDays(today, -10));
  // Recipes (Round 42): one with everything, the ingredients in sections.
  container.read(ingredientsProvider.notifier).replaceAll(IngredientBook([
        IngredientSection(id: 's1', name: 'Baking', items: const [
          Ingredient(id: 'i1', name: 'Flour'),
          Ingredient(id: 'i2', name: 'Sugar'),
        ]),
        IngredientSection(id: 's2', name: 'Dairy', items: const [
          Ingredient(id: 'i3', name: 'Milk'),
        ]),
      ]));
  container.read(recipesProvider.notifier).replaceAll([
    Recipe(
      id: 'r1',
      name: 'Pancakes',
      prepMinutes: 25,
      type: RecipeType.breakfast,
      ingredients: const [
        RecipeIngredient(ingredientId: 'i1', name: 'Flour', quantity: '200 g'),
        RecipeIngredient(ingredientId: 'i3', name: 'Milk'),
      ],
      method: '## Steps\n1. Mix\n2. Fry',
      createdAt: today,
    ),
  ]);
  // The food tracker (Round 46): a rated meal, one not rated, enough
  // for a verdict or two.
  container.read(foodProvider.notifier).replaceAll(FoodBook(
        foods: [
          Food(id: 'f1', name: 'Burek', tags: {FoodTag.fried})
        ],
        meals: [
          for (var i = 0; i < 6; i++)
            Meal(
              id: 'b$i',
              at: today.subtract(Duration(days: i, hours: 1)),
              kind: MealKind.breakfast,
              foods: const [MealFood(foodId: 'f1', name: 'Burek')],
              rating: MealRating.bad,
              symptoms: {Symptom.bloating},
            ),
          for (var i = 0; i < 6; i++)
            Meal(
              id: 's$i',
              at: today.subtract(Duration(days: i, hours: -4)),
              kind: MealKind.lunch,
              foods: const [MealFood(name: 'Soup')],
              rating: i == 0 ? null : MealRating.great,
            ),
        ],
      ));
}

/// A fake file picker that returns a small backup when importing.
FakeBackupFiles pickingBackup() => FakeBackupFiles()
  ..toPick = Uint8List.fromList(
    utf8.encode(
      Backup(
        createdAt: DateTime(2026, 10, 8),
        appVersion: '1',
        notes: const [],
        shopItems: const [ShopItem(id: 'i', name: 'Tea')],
      ).encode(),
    ),
  );

/// Checks the visible screen against Android's accessibility guidelines.
Future<void> expectAccessible(WidgetTester tester) async {
  await expectLater(tester, meetsGuideline(androidTapTargetGuideline));
  await expectLater(tester, meetsGuideline(labeledTapTargetGuideline));
  await expectLater(tester, meetsGuideline(textContrastGuideline));
}

void main() {
  group('accessibility guidelines', () {
    // Each case opens one screen of the seeded app.
    final screens = <String, Future<void> Function(WidgetTester)>{
      'notes list': (_) async {},
      'introduction': (t) async {
        await t.tap(find.byKey(const Key('introductionTile')));
        await t.pumpAndSettle();
        expect(find.byKey(const Key('introductionText')), findsOneWidget);
      },
      'to-do note': (t) async {
        await t.tap(find.byKey(const Key('todoTile')));
        await t.pumpAndSettle();
        expect(find.text('Pay rent'), findsOneWidget);
      },
      'to-do with its Waiting list': (t) async {
        await t.tap(find.byKey(const Key('todoTile')));
        await t.pumpAndSettle();
        await t.tap(find.byTooltip('To-do options'));
        await t.pumpAndSettle();
        await t.tap(find.byKey(const Key('todoWaiting')));
        await t.pumpAndSettle();
        expect(find.text('Waiting list'), findsOneWidget);
      },
      'notes selection mode': (t) async {
        await t.longPress(find.text('Groceries'));
        await t.pumpAndSettle();
      },
      'note editor': (t) async {
        await t.tap(find.text('Groceries'));
        await t.pumpAndSettle();
      },
      'lock needs a master password dialog': (t) async {
        await t.tap(find.text('Groceries'));
        await t.pumpAndSettle();
        await t.tap(find.byTooltip('Lock note'));
        await t.pumpAndSettle();
        expect(find.text('Set a master password?'), findsOneWidget);
      },
      'save changes dialog': (t) async {
        await t.tap(find.text('Groceries'));
        await t.pumpAndSettle();
        await t.enterText(find.byKey(const Key('noteContentField')), 'eggs');
        await t.pump();
        await t.pageBack();
        await t.pumpAndSettle();
        expect(find.text('Save changes?'), findsOneWidget);
      },
      'shop': (t) => openTab(t, 'Shop'),
      'shop amount sheet': (t) async {
        await openTab(t, 'Shop');
        await t.tap(find.bySemanticsLabel('Amount: 1.5 kg'));
        await t.pumpAndSettle();
      },
      'shop selection mode': (t) async {
        await openTab(t, 'Shop');
        await t.longPress(find.text('Milk'));
        await t.pumpAndSettle();
      },
      'planner': (t) => openTab(t, 'Planner'),
      'task menu': (t) async {
        await openTab(t, 'Planner');
        await t.tap(find.text('Call the bank'));
        await t.pumpAndSettle();
        expect(find.text('Edit'), findsOneWidget);
      },
      'routine choices': (t) async {
        await openTab(t, 'Planner');
        await t.tap(find.text('Stand-up'));
        await t.pumpAndSettle();
        expect(find.text('Skip this day'), findsOneWidget);
      },
      'add sheet with repeat': (t) async {
        await openTab(t, 'Planner');
        await t.tap(find.textContaining('Free · ').hitTestable().first);
        await t.pumpAndSettle();
        await t.tap(find.text('Weekdays'));
        await t.pumpAndSettle();
      },
      'routines screen': (t) async {
        await openTab(t, 'Planner');
        await t.tap(find.byTooltip('Routines'));
        await t.pumpAndSettle();
      },
      'routine sheet': (t) async {
        await openTab(t, 'Planner');
        await t.tap(find.byTooltip('Routines'));
        await t.pumpAndSettle();
        await t.tap(find.text('Stand-up').last);
        await t.pumpAndSettle();
        expect(find.text('Delete'), findsOneWidget);
      },
      'planner selection mode': (t) async {
        await openTab(t, 'Planner');
        await t.longPress(find.text('Gym'));
        await t.pumpAndSettle();
      },
      'reminder menu': (t) async {
        await openTab(t, 'Planner');
        await t.tap(find.bySemanticsLabel(RegExp('Reminder: Call mum')));
        await t.pumpAndSettle();
      },
      'undo message': (t) async {
        await openTab(t, 'Planner');
        await t.tap(find.bySemanticsLabel(RegExp('Reminder: Call mum')));
        await t.pumpAndSettle();
        await t.tap(find.bySemanticsLabel('Done: Call mum'));
        await t.pumpAndSettle();
        expect(find.text('Undo'), findsOneWidget);
      },
      'placard': (t) async {
        await openTab(t, 'Hub');
        await t.tap(find.byTooltip('Placard'));
        await t.pumpAndSettle();
      },
      'placard settings': (t) async {
        await openTab(t, 'Hub');
        await t.tap(find.byTooltip('Placard'));
        await t.pumpAndSettle();
        for (var i = 0; i < 5; i++) {
          await t.tap(find.byKey(const Key('placardCorner')));
          await t.pump(const Duration(milliseconds: 50));
        }
        await t.pumpAndSettle();
      },
      'hub': (t) => openTab(t, 'Hub'),
      'counters': (t) async {
        await openTab(t, 'Hub');
        await t.tap(find.byTooltip('Counters'));
        await t.pumpAndSettle();
      },
      'new counter sheet': (t) async {
        await openTab(t, 'Hub');
        await t.tap(find.byTooltip('Counters'));
        await t.pumpAndSettle();
        await t.tap(find.byTooltip('New counter'));
        await t.pumpAndSettle();
      },
      'food': (t) async {
        await openTab(t, 'Hub');
        await t.tap(find.byTooltip('Food'));
        await t.pumpAndSettle();
        expect(find.text('Burek'), findsOneWidget);
      },
      'food, a meal': (t) async {
        await openTab(t, 'Hub');
        await t.tap(find.byTooltip('Food'));
        await t.pumpAndSettle();
        await t.tap(find.text('Burek'));
        await t.pumpAndSettle();
      },
      'food statistics': (t) async {
        await openTab(t, 'Hub');
        await t.tap(find.byTooltip('Food'));
        await t.pumpAndSettle();
        await t.tap(find.byTooltip('Statistics'));
        await t.pumpAndSettle();
        expect(find.text('Likely trouble'), findsWidgets);
        await t.scrollUntilVisible(find.text('BY SYMPTOM'), 200,
            scrollable: find.byType(Scrollable).last);
      },
      "a food's statistics": (t) async {
        await openTab(t, 'Hub');
        await t.tap(find.byTooltip('Food'));
        await t.pumpAndSettle();
        await t.tap(find.byTooltip('Statistics'));
        await t.pumpAndSettle();
        await t.tap(find.byKey(const Key('finding-Burek')));
        await t.pumpAndSettle();
        expect(find.byKey(const Key('findingVerdict')), findsOneWidget);
      },
      'food, the index of foods': (t) async {
        await openTab(t, 'Hub');
        await t.tap(find.byTooltip('Food'));
        await t.pumpAndSettle();
        await t.tap(find.byTooltip('Log a meal'));
        await t.pumpAndSettle();
        await t.tap(find.byKey(const Key('mealFoodField')));
        await t.pumpAndSettle();
        expect(find.byKey(const Key('foodIndex')), findsOneWidget);
      },
      "food, a recipe's ingredients": (t) async {
        await openTab(t, 'Hub');
        await t.tap(find.byTooltip('Food'));
        await t.pumpAndSettle();
        await t.tap(find.byTooltip('Log a meal'));
        await t.pumpAndSettle();
        await t.tap(find.byKey(const Key('mealFoodField')));
        await t.pumpAndSettle();
        await t.tap(find.byKey(const Key('indexRecipe-Pancakes')));
        await t.pumpAndSettle();
        expect(find.byKey(const Key('addFromRecipe')), findsOneWidget);
      },
      'foods list': (t) async {
        await openTab(t, 'Hub');
        await t.tap(find.byTooltip('Food'));
        await t.pumpAndSettle();
        await t.tap(find.byTooltip('Foods'));
        await t.pumpAndSettle();
      },
      'recipes': (t) async {
        await openTab(t, 'Hub');
        await t.tap(find.byTooltip('Recipes'));
        await t.pumpAndSettle();
      },
      'recipe, view mode': (t) async {
        await openTab(t, 'Hub');
        await t.tap(find.byTooltip('Recipes'));
        await t.pumpAndSettle();
        await t.tap(find.text('Pancakes'));
        await t.pumpAndSettle();
      },
      'recipe, edit mode': (t) async {
        await openTab(t, 'Hub');
        await t.tap(find.byTooltip('Recipes'));
        await t.pumpAndSettle();
        await t.tap(find.text('Pancakes'));
        await t.pumpAndSettle();
        await t.tap(find.byTooltip('Edit'));
        await t.pumpAndSettle();
      },
      'recipe prep time sheet': (t) async {
        await openTab(t, 'Hub');
        await t.tap(find.byTooltip('Recipes'));
        await t.pumpAndSettle();
        await t.tap(find.text('Pancakes'));
        await t.pumpAndSettle();
        await t.tap(find.byTooltip('Edit'));
        await t.pumpAndSettle();
        await t.tap(find.byKey(const Key('recipePrepTime')));
        await t.pumpAndSettle();
      },
      'recipe type sheet': (t) async {
        await openTab(t, 'Hub');
        await t.tap(find.byTooltip('Recipes'));
        await t.pumpAndSettle();
        await t.tap(find.text('Pancakes'));
        await t.pumpAndSettle();
        await t.tap(find.byTooltip('Edit'));
        await t.pumpAndSettle();
        await t.tap(find.byKey(const Key('recipeType')));
        await t.pumpAndSettle();
      },
      'recipe, more sheet': (t) async {
        await openTab(t, 'Hub');
        await t.tap(find.byTooltip('Recipes'));
        await t.pumpAndSettle();
        await t.tap(find.text('Pancakes'));
        await t.pumpAndSettle();
        await t.tap(find.byTooltip('More'));
        await t.pumpAndSettle();
      },
      'recipe quantity sheet': (t) async {
        await openTab(t, 'Hub');
        await t.tap(find.byTooltip('Recipes'));
        await t.pumpAndSettle();
        await t.tap(find.text('Pancakes'));
        await t.pumpAndSettle();
        await t.tap(find.byTooltip('Edit'));
        await t.pumpAndSettle();
        await t.tap(find.byKey(const Key('recipeIngredientRow-0')));
        await t.pumpAndSettle();
        await t.tap(find.byKey(const Key('choice-quantity')));
        await t.pumpAndSettle();
      },
      'recipe, ingredients selected': (t) async {
        await openTab(t, 'Hub');
        await t.tap(find.byTooltip('Recipes'));
        await t.pumpAndSettle();
        await t.tap(find.text('Pancakes'));
        await t.pumpAndSettle();
        await t.tap(find.byTooltip('Edit'));
        await t.pumpAndSettle();
        await t.longPress(find.byKey(const Key('recipeIngredientRow-0')));
        await t.pumpAndSettle();
      },
      'ingredients': (t) async {
        await openTab(t, 'Hub');
        await t.tap(find.byTooltip('Recipes'));
        await t.pumpAndSettle();
        await t.tap(find.byTooltip('Ingredients'));
        await t.pumpAndSettle();
      },
      'ingredients, picking': (t) async {
        await openTab(t, 'Hub');
        await t.tap(find.byTooltip('Recipes'));
        await t.pumpAndSettle();
        await t.tap(find.text('Pancakes'));
        await t.pumpAndSettle();
        await t.tap(find.byTooltip('Edit'));
        await t.pumpAndSettle();
        await t.ensureVisible(find.byKey(const Key('recipeAddIngredients')));
        await t.pumpAndSettle();
        await t.tap(find.byKey(const Key('recipeAddIngredients')));
        await t.pumpAndSettle();
        await t.tap(find.text('Sugar'));
        await t.pumpAndSettle();
      },
      'medicine': (t) async {
        await openTab(t, 'Hub');
        await t.tap(find.byTooltip('Medicine'));
        await t.pumpAndSettle();
      },
      'medicine history': (t) async {
        await openTab(t, 'Hub');
        await t.tap(find.byTooltip('Medicine'));
        await t.pumpAndSettle();
        await t.tap(find.byTooltip('History'));
        await t.pumpAndSettle();
      },
      'medicine own history': (t) async {
        await openTab(t, 'Hub');
        await t.tap(find.byTooltip('Medicine'));
        await t.pumpAndSettle();
        await t.tap(find.text('Antibiotic'));
        await t.pumpAndSettle();
        await t.tap(find.text('History'));
        await t.pumpAndSettle();
      },
      'dose state sheet': (t) async {
        await openTab(t, 'Hub');
        await t.tap(find.byTooltip('Medicine'));
        await t.pumpAndSettle();
        await t.tap(find.text('Antibiotic'));
        await t.pumpAndSettle();
        await t.tap(find.text('History'));
        await t.pumpAndSettle();
        await t.tap(find.text('not set').first);
        await t.pumpAndSettle();
      },
      'notifications page': (t) async {
        await openMenu(t);
        await t.tap(find.text('Notifications'));
        await t.pumpAndSettle();
        expect(find.text('Dentist'), findsOneWidget, reason: 'recent');
      },
      'notifications page, further down': (t) async {
        await openMenu(t);
        await t.tap(find.text('Notifications'));
        await t.pumpAndSettle();
        await reveal(t, find.byKey(const Key('notifyColour-medicine')));
      },
      'notification history': (t) async {
        await openMenu(t);
        await t.tap(find.text('Notifications'));
        await t.pumpAndSettle();
        await t.tap(find.text('All 1'));
        await t.pumpAndSettle();
      },
      'medicine pause sheet': (t) async {
        await openMenu(t);
        await t.tap(find.text('Notifications'));
        await t.pumpAndSettle();
        final pause = find.byKey(const Key('notifyPause-medicine'));
        await reveal(t, pause);
        await t.tap(pause);
        await t.pumpAndSettle();
      },
      'medicine sheet': (t) async {
        await openTab(t, 'Hub');
        await t.tap(find.byTooltip('Medicine'));
        await t.pumpAndSettle();
        await t.tap(find.byTooltip('Add medicine'));
        await t.pumpAndSettle();
      },
      'medicine sheet, lower part': (t) async {
        await openTab(t, 'Hub');
        await t.tap(find.byTooltip('Medicine'));
        await t.pumpAndSettle();
        await t.tap(find.byTooltip('Add medicine'));
        await t.pumpAndSettle();
        final important = find.byKey(const Key('medicineImportant'));
        await t.scrollUntilVisible(important, 100,
            scrollable: find
                .descendant(
                    of: find.byType(BottomSheet),
                    matching: find.byType(Scrollable))
                .first);
        await t.pumpAndSettle();
      },
      'hold to take': (t) async {
        await openTab(t, 'Hub');
        await t.tap(find.byTooltip('Medicine'));
        await t.pumpAndSettle();
        await t.tap(find.byWidgetPredicate((w) =>
            w.key is ValueKey<String> &&
            (w.key! as ValueKey<String>).value.startsWith('dose-') &&
            (w.key! as ValueKey<String>).value.endsWith('-1')));
        await t.pumpAndSettle();
        expect(find.byKey(const Key('holdToTake')), findsOneWidget);
      },
      'note formats and the format bar': (t) async {
        t.view.physicalSize = const Size(1080, 2400);
        addTearDown(t.view.resetPhysicalSize);
        await t.pump();
        await t.tap(find.text('Formats'));
        await t.pumpAndSettle();
        await t.tap(find.byKey(const Key('noteContentField')));
        await t.pump();
        await t.tap(find.byTooltip('Format'));
        await t.pumpAndSettle();
        // Off the drawn lines: the cursor at the very end.
        final field =
            t.widget<TextField>(find.byKey(const Key('noteContentField')));
        field.controller!.selection =
            TextSelection.collapsed(offset: field.controller!.text.length);
        await t.pumpAndSettle();
      },
      'pip home': (t) async {
        await openTab(t, 'Hub');
        await t.tap(find.byTooltip('Pip'));
        await t.pumpAndSettle();
      },
      'pip rename': (t) async {
        await openTab(t, 'Hub');
        await t.tap(find.byTooltip('Pip'));
        await t.pumpAndSettle();
        await t.fling(
            find.byKey(const Key('pipCard')), const Offset(-400, 0), 1000);
        await t.pumpAndSettle();
        await t.tap(find.byKey(const Key('pipRename')));
        await t.pumpAndSettle();
      },
      'pip backgrounds': (t) async {
        await openTab(t, 'Hub');
        await t.tap(find.byTooltip('Pip'));
        await t.pumpAndSettle();
        await t.fling(
            find.byKey(const Key('pipCard')), const Offset(-400, 0), 1000);
        await t.pumpAndSettle();
        await t.tap(find.byKey(const Key('pipBackground')));
        await t.pumpAndSettle();
      },
      'pip animations': (t) async {
        await openTab(t, 'Hub');
        await t.tap(find.byTooltip('Pip'));
        await t.pumpAndSettle();
        await t.fling(
            find.byKey(const Key('pipCard')), const Offset(-400, 0), 1000);
        await t.pumpAndSettle();
        await t.tap(find.byKey(const Key('pipAnimations')));
        await t.pumpAndSettle();
      },
      'counters selection mode': (t) async {
        await openTab(t, 'Hub');
        await t.tap(find.byTooltip('Counters'));
        await t.pumpAndSettle();
        await t.longPress(find.text('Push-ups'));
        await t.pumpAndSettle();
      },
      'menu': openMenu,
      'backup': (t) async {
        await openMenu(t);
        await t.tap(find.text('Backup'));
        await t.pumpAndSettle();
      },
      'security': (t) async {
        await openMenu(t);
        await t.tap(find.text('Security'));
        await t.pumpAndSettle();
      },
      'export choice': (t) async {
        await openMenu(t);
        await t.tap(find.text('Backup'));
        await t.pumpAndSettle();
        await t.tap(find.text('Export all data'));
        await t.pumpAndSettle();
      },
      'import preview': (t) async {
        await openMenu(t);
        await t.tap(find.text('Backup'));
        await t.pumpAndSettle();
        await t.tap(find.text('Import from file')); // picks [backupFile]
        await t.pumpAndSettle();
        expect(find.text('Restore this backup?'), findsOneWidget);
      },
      'restore part': (t) async {
        await openMenu(t);
        await t.tap(find.text('Backup'));
        await t.pumpAndSettle();
        await t.tap(find.text('Restore part of a backup'));
        await t.pumpAndSettle();
        await t.tap(find.text('Tea'));
        await t.pumpAndSettle();
        expect(find.text('Restore 1'), findsOneWidget);
      },
      'settings': (t) async {
        await openMenu(t);
        await t.tap(find.text('Settings'));
        await t.pumpAndSettle();
      },
      'clear data': (t) async {
        await openMenu(t);
        await t.tap(find.text('Settings'));
        await t.pumpAndSettle();
        await t.tap(find.text('Clear data'));
        await t.pumpAndSettle();
        await t.tap(find.byKey(const Key('clear-notes')));
        await t.pump();
      },
      'clear data dialog': (t) async {
        await openMenu(t);
        await t.tap(find.text('Settings'));
        await t.pumpAndSettle();
        await t.tap(find.text('Clear data'));
        await t.pumpAndSettle();
        await t.tap(find.byKey(const Key('clear-notes')));
        await t.pump();
        await t.tap(find.byKey(const Key('clearData')));
        await t.pumpAndSettle();
      },
      'themes': (t) async {
        await openMenu(t);
        await t.tap(find.text('Themes'));
        await t.pumpAndSettle();
      },
      'forgot master password dialog': (t) => openForgotPassword(t),
      'set master password form': (t) async {
        await openMenu(t);
        await t.tap(find.text('Security'));
        await t.pumpAndSettle();
        await t.tap(find.text('Set master password'));
        await t.pumpAndSettle();
      },
    };

    // Every screen in every theme (G12): contrast depends on the palette.
    for (final theme in AppThemeChoice.values) {
      for (final MapEntry(key: name, value: open) in screens.entries) {
        testWidgets('$name (${theme.label})', (tester) async {
          final semantics = tester.ensureSemantics();
          final container = await pumpApp(tester,
              backupFiles: pickingBackup(),
              clock: designClock,
              // The Introduction at the top of Notes (N16), new.
              introduction: true);
          container.read(preferencesProvider.notifier).setTheme(theme.name);
          await seed(container);
          await tester.pump();
          await open(tester);
          await expectAccessible(tester);
          semantics.dispose();
        });
      }
    }
  });

  for (final unlock in [false, true]) {
    testWidgets(
        'accessibility guidelines: security with a master password, '
        '${unlock ? 'unlocked' : 'locked'}', (tester) async {
      final semantics = tester.ensureSemantics();
      final container = await pumpApp(tester, clock: designClock);
      await tester.runAsync(() async {
        await container
            .read(securityProvider.notifier)
            .setPassword('master password');
        if (unlock) {
          await container
              .read(sessionProvider.notifier)
              .unlock('master password');
        }
      });
      await openMenu(tester);
      await tester.tap(find.text('Security'));
      await tester.pumpAndSettle();
      await expectAccessible(tester);
      semantics.dispose();
    });
  }

  testWidgets('accessibility guidelines: a locked section', (tester) async {
    final semantics = tester.ensureSemantics();
    final container = await pumpApp(tester, clock: designClock);
    await tester.runAsync(() async {
      await container
          .read(securityProvider.notifier)
          .setPassword('master password');
      await container.read(sessionProvider.notifier).unlock('master password');
    });
    container.read(sectionLocksProvider.notifier).lock(AppSection.notes);
    container.read(sessionProvider.notifier).lock();
    await tester.pumpAndSettle();

    expect(find.text('Notes is locked'), findsOneWidget);
    await expectAccessible(tester);
    semantics.dispose();
  });

  group('compact shop rows (S4)', () {
    /// The card of the list row showing [text].
    Finder rowOf(String text) => find.ancestor(
          of: find.text(text),
          matching: find.byType(SelectableCard),
        );

    Future<void> pumpSeeded(WidgetTester tester) async {
      await seed(await pumpApp(tester, clock: designClock));
      await tester.pump();
    }

    testWidgets('are exactly one touch target high', (tester) async {
      await pumpSeeded(tester);
      await openTab(tester, 'Shop');

      for (final name in ['Milk', 'Bread', 'Eggs']) {
        expect(
          tester.getSize(rowOf(name)).height,
          kMinInteractiveDimension,
          reason: name,
        );
      }
    });

    testWidgets('are at least 20% smaller than note rows, with tighter gaps',
        (tester) async {
      await pumpSeeded(tester);
      final noteRow = tester.getSize(rowOf('Groceries')).height;
      final noteGap = tester.getTopLeft(rowOf('Groceries')).dy -
          tester.getBottomLeft(rowOf('Trip plan')).dy;

      await openTab(tester, 'Shop');
      final shopRow = tester.getSize(rowOf('Eggs')).height;
      // Bread and Eggs are adjacent in "To buy", in that order.
      final shopGap = tester.getTopLeft(rowOf('Eggs')).dy -
          tester.getBottomLeft(rowOf('Bread')).dy;

      expect(shopRow, lessThanOrEqualTo(noteRow * 0.8));
      expect(shopGap, greaterThanOrEqualTo(0), reason: 'rows in this order');
      expect(shopGap, lessThan(noteGap));
    });

    testWidgets('announce the checkbox together with the item name',
        (tester) async {
      final semantics = tester.ensureSemantics();
      await pumpSeeded(tester);
      await openTab(tester, 'Shop');

      expect(
        tester.getSemantics(find.text('Bread')),
        containsSemantics(
          label: 'Bread',
          hasCheckedState: true,
          isChecked: false,
          hasTapAction: true,
        ),
      );
      expect(
        tester.getSemantics(find.text('Milk')),
        containsSemantics(label: 'Milk', isChecked: true),
      );
      semantics.dispose();
    });
  });

  testWidgets('drag handles fill the row height and are easy to grab',
      (tester) async {
    await seed(await pumpApp(tester, clock: designClock));
    await tester.pump();

    Future<void> check(String text) async {
      final row = find.ancestor(
        of: find.text(text),
        matching: find.byType(SelectableCard),
      );
      final handle = find.descendant(
        of: row,
        matching: find.byType(ReorderableDragStartListener),
      );
      expect(tester.getSize(handle).height, tester.getSize(row).height,
          reason: text);
      expect(
        tester.getSize(handle).width,
        greaterThanOrEqualTo(ReorderOrSelectIndicator.width),
        reason: text,
      );
      // The icon stays near the right edge; the extra area is to its left.
      final icon = find.descendant(
        of: row,
        matching: find.byIcon(Icons.drag_handle),
      );
      expect(
        tester.getRect(icon).right,
        tester.getRect(handle).right - ReorderOrSelectIndicator.iconInset,
        reason: text,
      );
    }

    await check('Groceries');
    await openTab(tester, 'Shop');
    await check('Milk');
  });

  testWidgets('selection actions sit at the bottom, on the hand\'s side',
      (tester) async {
    await seed(await pumpApp(tester, clock: designClock));
    await tester.pump();
    final screen = tester.getSize(find.byType(MaterialApp));

    for (final (tab, item) in [('Notes', 'Groceries'), ('Shop', 'Milk')]) {
      await openTab(tester, tab);
      final row = tester.getRect(
        find.ancestor(
            of: find.text(item), matching: find.byType(SelectableCard)),
      );
      for (final right in [true, false]) {
        // Long-press on the right or the left half of the row.
        await tester.longPressAt(
          Offset(right ? row.right - 100 : row.left + 40, row.center.dy),
        );
        await tester.pumpAndSettle();

        // Shop's select button cycles ("Select all items", "Select both
        // lists", …).
        final select = find.byWidgetPredicate(
          (w) => w is Tooltip && (w.message ?? '').startsWith('Select '),
        );
        final buttons = {
          'Select all': tester.getCenter(select),
          'Delete': tester.getCenter(find.byTooltip('Delete')),
        };
        for (final MapEntry(key: t, value: c) in buttons.entries) {
          expect(c.dy, greaterThan(screen.height * 0.75), reason: t);
          expect(
            right ? c.dx > screen.width / 2 : c.dx < screen.width / 2,
            isTrue,
            reason: '$t on the ${right ? 'right' : 'left'}',
          );
          expect(
            find.descendant(
              of: find.byType(AppBar),
              matching: find.byTooltip(t),
            ),
            findsNothing,
            reason: '$t is not in the top bar',
          );
        }
        // Delete is outermost: mirrored on the left. No ✕.
        final outward = right ? 1 : -1;
        expect(
          outward * buttons['Delete']!.dx,
          greaterThan(outward * buttons['Select all']!.dx),
        );
        expect(find.byTooltip('Cancel selection'), findsNothing);

        await pressBack(tester); // leaves selection mode
      }
    }
  });

  testWidgets(
      'note editor: actions on the side it was opened from, and '
      'the text ends above them', (tester) async {
    await seed(await pumpApp(tester, clock: designClock));
    await tester.pump();
    final screen = tester.getSize(find.byType(MaterialApp));

    for (final right in [true, false]) {
      final row = tester.getRect(
        find.ancestor(
          of: find.text('Groceries'),
          matching: find.byType(SelectableCard),
        ),
      );
      await tester.tapAt(
        Offset(right ? row.right - 100 : row.left + 40, row.center.dy),
      );
      await tester.pumpAndSettle();

      final undo = tester.getRect(find.byTooltip('Undo'));
      final redo = tester.getRect(find.byTooltip('Redo'));
      final title = tester.getRect(find.byTooltip('Edit title'));
      expect(undo.center.dy, greaterThan(screen.height * 0.75));
      expect(
        right
            ? undo.center.dx > screen.width / 2
            : undo.center.dx < screen.width / 2,
        isTrue,
        reason: right ? 'right' : 'left',
      );
      // ↶ ↷ in that order on either side, as a pair outermost, under the
      // thumb; Edit title smaller, above the outermost button.
      final lock = tester.getRect(find.byTooltip('Lock note'));
      expect(undo.left, lessThan(redo.left), reason: '↶ left of ↷');
      expect(right ? lock.left < undo.left : lock.left > redo.left, isTrue,
          reason: 'the pair is outermost');
      final outermost = right ? redo : undo;
      expect(title.center.dx, closeTo(outermost.center.dx, 1));
      expect(title.bottom, lessThan(outermost.top));
      expect(title.width, lessThan(outermost.width));
      expect(
        find.descendant(
          of: find.byType(AppBar),
          matching: find.byType(FloatingActionButton),
        ),
        findsNothing,
      );

      // The editable text area stops above the buttons.
      final field = find.descendant(
        of: find.byKey(const Key('noteContentField')),
        matching: find.byType(EditableText),
      );
      expect(tester.getRect(field).bottom, lessThanOrEqualTo(title.top));

      await tester.pageBack();
      await tester.pumpAndSettle();
    }
  });

  group('touch feedback', () {
    /// Presses (without releasing) on [target] inside the row showing
    /// [text], and returns the layer a ripple would be drawn on.
    Future<Object> pressRow(
      WidgetTester tester,
      String text, {
      Finder? target,
    }) async {
      final row = find.ancestor(
        of: find.text(text),
        matching: find.byType(SelectableCard),
      );
      await tester.startGesture(tester.getCenter(target ?? row));
      await tester.pump(const Duration(milliseconds: 100));
      return Material.of(
        tester.element(
          find.descendant(of: row, matching: find.byType(InkWell)),
        ),
      );
    }

    testWidgets('pressing a row shows no ripple', (tester) async {
      await seed(await pumpApp(tester, clock: designClock));
      await tester.pump();
      final material = await pressRow(tester, 'Groceries');
      expect(material, isNot(paints..circle()));

      final theme = Theme.of(tester.element(find.text('Groceries')));
      expect(theme.splashFactory, NoSplash.splashFactory);
    });

    testWidgets("a shop row's icon only shows the state; the row takes the tap",
        (tester) async {
      await seed(await pumpApp(tester, clock: designClock));
      await openTab(tester, 'Shop');
      final icon = find.descendant(
        of: find.ancestor(
          of: find.text('Bread'),
          matching: find.byType(SelectableCard),
        ),
        matching: find.byKey(const Key('shopState')),
      );
      expect(tester.widget<Icon>(icon).icon, Icons.shopping_cart_outlined,
          reason: 'to buy: a cart');
      final material = await pressRow(tester, 'Bread', target: icon);
      expect(material, isNot(paints..circle()));
    });
  });

  testWidgets('a locked note row: same height, lock announced', (tester) async {
    final semantics = tester.ensureSemantics();
    await seed(await pumpApp(tester, clock: designClock));
    await tester.pump();
    Finder rowOf(String text) => find.ancestor(
          of: find.text(text),
          matching: find.byType(SelectableCard),
        );

    expect(
      tester.getSize(rowOf('Bank')).height,
      tester.getSize(rowOf('Groceries')).height,
    );
    // One element for screen readers, saying it's locked before the title.
    expect(
      tester.getSemantics(find.text('Bank')).label,
      matches(RegExp(r'^Locked\nBank\n')),
    );
    semantics.dispose();
  });

  testWidgets('selection is announced to screen readers', (tester) async {
    final semantics = tester.ensureSemantics();
    await seed(await pumpApp(tester, clock: designClock));
    await tester.pump();

    await tester.longPress(find.text('Groceries'));
    await tester.pump();
    expect(
      tester.getSemantics(find.text('Groceries')),
      containsSemantics(isSelected: true),
    );

    await openTab(tester, 'Shop');
    await tester.longPress(find.text('Bread'));
    await tester.pump();
    expect(
      tester.getSemantics(find.text('Bread')),
      containsSemantics(label: 'Bread', isSelected: true),
    );
    semantics.dispose();
  });

  testWidgets('the forgot password dialog copes with a very large font',
      (tester) async {
    tester.platformDispatcher.textScaleFactorTestValue = 2.0;
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
    await seed(await pumpApp(tester, clock: designClock));
    await tester.pump();
    await openForgotPassword(tester);
    expect(tester.takeException(), isNull);
    // Scrolls to reach the confirmation field.
    await tester.ensureVisible(find.byKey(const Key('resetConfirm')));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  });

  testWidgets('the task sheet with repeat days copes with a very large font',
      (tester) async {
    tester.platformDispatcher.textScaleFactorTestValue = 2.0;
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
    await seed(await pumpApp(tester, clock: designClock));
    await tester.pump();
    await openTab(tester, 'Planner');
    final free = find.text('Free · 11:30–20:00');
    await tester.ensureVisible(free);
    await tester.pumpAndSettle();
    await tester.tap(free);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Weekdays'));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    // Scrolls to the Add button.
    await tester.ensureVisible(find.widgetWithText(FilledButton, 'Add'));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  });

  testWidgets('lists cope with a very large system font', (tester) async {
    tester.platformDispatcher.textScaleFactorTestValue = 2.0;
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
    await seed(await pumpApp(tester, clock: designClock));
    await tester.pump();
    await openTab(tester, 'Shop');
    await openTab(tester, 'Planner');
    await openTab(tester, 'Hub');
    await tester.tap(find.byTooltip('Counters'));
    await tester.pumpAndSettle();
    await tester.pageBack();
    await tester.pumpAndSettle();
    await openTab(tester, 'Notes');
    // Layout overflow would have been reported as an exception.
    expect(tester.takeException(), isNull);
  });
}
