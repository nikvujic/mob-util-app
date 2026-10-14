import 'package:flutter_test/flutter_test.dart';
import 'package:the_app/models/food.dart';
import 'package:the_app/models/food_stats.dart';

/// The food tracker's data and statistics (O14, Round 46).
void main() {
  Meal meal(
    String id,
    List<String> foods, {
    MealRating? rating,
    Set<Symptom> symptoms = const {},
    DateTime? at,
  }) =>
      Meal(
        id: id,
        at: at ??
            DateTime(2026, 10, 1, 12).add(Duration(hours: id.hashCode % 500)),
        kind: MealKind.lunch,
        foods: [
          for (final f in foods) MealFood(foodId: f, name: f.toUpperCase())
        ],
        rating: rating,
        symptoms: symptoms,
      );

  group('the data', () {
    test('a meal kind is guessed from the time', () {
      MealKind at(int hour) => MealKind.at(DateTime(2026, 10, 14, hour));
      expect([
        at(7),
        at(12),
        at(19),
        at(23),
        at(3)
      ], [
        MealKind.breakfast,
        MealKind.lunch,
        MealKind.dinner,
        MealKind.snack,
        MealKind.snack,
      ]);
    });

    test('kept as JSON and read back; unknown values (a newer app) skipped',
        () {
      final book = FoodBook(foods: [
        Food(id: 'f1', name: 'Milk', tags: {FoodTag.dairy}),
      ], meals: [
        Meal(
          id: 'm1',
          at: DateTime.utc(2026, 10, 14, 7, 30),
          kind: MealKind.breakfast,
          foods: const [MealFood(foodId: 'f1', name: 'Milk')],
          rating: MealRating.bad,
          symptoms: {Symptom.bloating},
          note: 'too much',
        ),
      ]);
      final again = FoodBook.fromJson(book.toJson());
      expect(again.toJson(), book.toJson());
      final odd = FoodBook.fromJson({
        'foods': [
          {
            'id': 'f1',
            'name': 'X',
            'tags': ['dairy', 'newTag']
          },
        ],
        'meals': [
          {
            'id': 'm1',
            'at': '2026-10-14T07:30:00.000Z',
            'kind': 'brunch',
            'foods': [],
            'rating': 'meh',
            'symptoms': ['bloating', 'hiccups'],
          },
        ],
      });
      expect(odd.foods.single.tags, {FoodTag.dairy});
      expect(odd.meals.single.kind, MealKind.snack);
      expect(odd.meals.single.rating, isNull);
      expect(odd.meals.single.symptoms, {Symptom.bloating});
      expect(
          const {'rating', 'symptoms', 'note'}.any((k) =>
              Meal(id: 'x', at: DateTime(2026), kind: MealKind.snack)
                  .toJson()
                  .containsKey(k)),
          isFalse,
          reason: 'only when set');
    });

    test("a day's meals and its worst rating", () {
      final day = DateTime(2026, 10, 14);
      final book = FoodBook(foods: const [], meals: [
        meal('a', ['x'],
            rating: MealRating.good, at: DateTime(2026, 10, 14, 8)),
        meal('b', ['x'],
            rating: MealRating.bad, at: DateTime(2026, 10, 14, 13)),
        meal('c', ['x'], at: DateTime(2026, 10, 14, 19)),
        meal('d', ['x'],
            rating: MealRating.awful, at: DateTime(2026, 10, 15, 8)),
      ]);
      expect(book.mealsOn(day).map((m) => m.id), ['a', 'b', 'c']);
      expect(book.worstOn(day), MealRating.bad);
      expect(book.worstOn(DateTime(2026, 10, 13)), isNull);
    });

    test('foods most eaten first; the last different meals to repeat', () {
      final book = FoodBook(foods: [
        Food(id: 'a', name: 'Apple'),
        Food(id: 'b', name: 'Bread'),
        Food(id: 'c', name: 'Cheese'),
      ], meals: [
        meal('1', ['b'], at: DateTime(2026, 10, 1)),
        meal('2', ['c', 'b'], at: DateTime(2026, 10, 2)),
        meal('3', ['b', 'c'], at: DateTime(2026, 10, 3)),
        meal('4', ['c'], at: DateTime(2026, 10, 4)),
      ]);
      expect(book.foodsByUse.map((f) => f.name), ['Bread', 'Cheese', 'Apple']);
      expect(book.recentMeals().map((m) => m.id), ['4', '3', '1'],
          reason: '2 has the same foods as 3');
    });

    test('a food found by name in any case', () {
      final book =
          FoodBook(foods: [Food(id: 'a', name: 'Apple')], meals: const []);
      expect(book.foodNamed(' aPPle ')?.id, 'a');
      expect(book.foodNamed('Pear'), isNull);
    });
  });

  group('the statistics', () {
    FoodFinding of(List<FoodFinding> list, String label) =>
        list.firstWhere((f) => f.label == label);

    test('a food seen a few times is never trouble', () {
      final book = FoodBook(foods: const [], meals: [
        for (var i = 0; i < 4; i++)
          meal('o$i', ['onion'], rating: MealRating.awful),
        for (var i = 0; i < 10; i++)
          meal('r$i', ['rice'], rating: MealRating.good),
      ]);
      expect(of(FoodStats.foods(book), 'ONION').verdict, FoodVerdict.unknown);
    });

    test('clearly worse with it than without: likely trouble; else fine', () {
      final book = FoodBook(foods: const [], meals: [
        // Onion: 4 of 6 bad. Without it: 1 of 10.
        for (var i = 0; i < 4; i++)
          meal('o$i', ['onion', 'rice'],
              rating: MealRating.bad, symptoms: {Symptom.bloating}),
        for (var i = 0; i < 2; i++)
          meal('g$i', ['onion'], rating: MealRating.good),
        meal('x', ['rice'], rating: MealRating.awful),
        for (var i = 0; i < 9; i++)
          meal('r$i', ['rice'], rating: MealRating.great),
      ]);
      final foods = FoodStats.foods(book);
      final onion = of(foods, 'ONION');
      expect(onion.verdict, FoodVerdict.trouble);
      expect((onion.meals, onion.bad, onion.mealsWithout, onion.badWithout),
          (6, 4, 10, 1));
      expect(onion.symptom, Symptom.bloating);
      expect(onion.symptomCount, 4);
      expect(of(foods, 'RICE').verdict, FoodVerdict.unknown,
          reason: 'in all but 2 meals: nothing to compare it with');
      expect(foods.first.label, 'ONION', reason: 'trouble first');
      expect(FoodStats.usual(book), (16, 5));
    });

    test('two bad meals are not enough to call it trouble', () {
      final book = FoodBook(foods: const [], meals: [
        for (var i = 0; i < 2; i++)
          meal('b$i', ['kiwi'], rating: MealRating.bad),
        for (var i = 0; i < 3; i++)
          meal('g$i', ['kiwi'], rating: MealRating.good),
        for (var i = 0; i < 10; i++)
          meal('r$i', ['rice'], rating: MealRating.good),
      ]);
      final kiwi = of(FoodStats.foods(book), 'KIWI');
      expect(kiwi.badShare - kiwi.badShareWithout, greaterThan(0.25));
      expect(kiwi.verdict, FoodVerdict.fine);
    });

    test('by kind: the tags of the foods eaten', () {
      final book = FoodBook(foods: [
        Food(id: 'milk', name: 'Milk', tags: {FoodTag.dairy}),
        Food(id: 'cheese', name: 'Cheese', tags: {FoodTag.dairy}),
        Food(id: 'rice', name: 'Rice'),
      ], meals: [
        for (var i = 0; i < 3; i++)
          meal('m$i', ['milk'], rating: MealRating.awful),
        for (var i = 0; i < 3; i++)
          meal('c$i', ['cheese'], rating: MealRating.bad),
        for (var i = 0; i < 6; i++)
          meal('r$i', ['rice'], rating: MealRating.good),
      ]);
      final tags = FoodStats.tags(book);
      expect(tags.map((t) => t.tag), [FoodTag.dairy],
          reason: 'only those eaten');
      expect(tags.single.verdict, FoodVerdict.trouble);
      expect(tags.single.meals, 6);
    });

    test('unrated meals count for symptoms, not for verdicts', () {
      final book = FoodBook(foods: const [], meals: [
        meal('a', ['beans'], symptoms: {Symptom.cramps}),
        meal('b', ['beans'], symptoms: {Symptom.cramps}),
      ]);
      final beans = FoodStats.foods(book).single;
      expect(beans.meals, 0);
      expect(beans.symptom, Symptom.cramps);
      final once = FoodBook(foods: const [], meals: [
        meal('a', ['beans'], symptoms: {Symptom.cramps}),
      ]);
      expect(FoodStats.foods(once).single.symptom, isNull,
          reason: 'once is no pattern');
    });

    test(
        "a food's own page (Round 47): its meals, ratings, symptoms, "
        'what it was eaten with', () {
      final book = FoodBook(foods: [
        Food(id: 'milk', name: 'Milk', tags: {FoodTag.dairy}),
      ], meals: [
        meal('1', ['milk', 'bread'],
            rating: MealRating.bad,
            symptoms: {Symptom.cramps},
            at: DateTime(2026, 10, 1)),
        meal('2', ['milk', 'bread', 'jam'],
            rating: MealRating.good,
            symptoms: {Symptom.bloating, Symptom.cramps},
            at: DateTime(2026, 10, 2)),
        meal('3', ['milk'], at: DateTime(2026, 10, 3)),
        meal('4', ['rice'],
            rating: MealRating.awful, at: DateTime(2026, 10, 4)),
      ]);
      final milk = FoodStats.foods(book).firstWhere((f) => f.foodId == 'milk');
      expect(FoodStats.mealsWith(book, milk).map((m) => m.id), ['3', '2', '1'],
          reason: 'newest first, unrated too');
      expect(FoodStats.mealsWithout(book, milk).map((m) => m.id), ['4']);
      final ratings = FoodStats.ratings(FoodStats.mealsWith(book, milk));
      expect(ratings[MealRating.bad], 1);
      expect(ratings[MealRating.good], 1);
      expect(ratings.values.fold(0, (a, b) => a + b), 2);
      expect(FoodStats.symptoms(FoodStats.mealsWith(book, milk)),
          [(Symptom.cramps, 2), (Symptom.bloating, 1)],
          reason: 'most often first');
      expect(FoodStats.eatenWith(book, FoodStats.mealsWith(book, milk), milk),
          [('BREAD', 2, 1), ('JAM', 1, 0)]);
      // By kind: the same, through the food's tags.
      final dairy = FoodStats.tags(book).single;
      expect(
          FoodStats.mealsWith(book, dairy).map((m) => m.id), ['3', '2', '1']);
      expect(
          FoodStats.eatenWith(book, FoodStats.mealsWith(book, dairy), dairy)
              .map((e) => e.$1),
          contains('Milk'),
          reason: 'a kind lists its foods');
    });
  });
}
