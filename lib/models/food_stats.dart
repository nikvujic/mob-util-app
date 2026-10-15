import 'package:the_app/models/food.dart';

/// What the statistics make of a food or a tag (O14, Round 46).
enum FoodVerdict {
  /// Bad or awful clearly more often with it than without it.
  trouble,
  fine,

  /// Too few rated meals with it (or without it) to say.
  unknown,
}

/// How rated meals went with one food (or tag) against without it.
class FoodFinding {
  /// The food's name, or the tag's label.
  final String label;

  /// The food (null for a tag), and its key in meals ([MealFood.key]).
  final String? foodId;
  final String? foodKey;
  final FoodTag? tag;

  /// Rated meals with it, and how many of them were bad or awful.
  final int meals;
  final int bad;

  /// The same for the rated meals without it.
  final int mealsWithout;
  final int badWithout;

  /// The symptom that most often followed it (twice or more), if any.
  final Symptom? symptom;
  final int symptomCount;

  const FoodFinding({
    required this.label,
    this.foodId,
    this.foodKey,
    this.tag,
    required this.meals,
    required this.bad,
    required this.mealsWithout,
    required this.badWithout,
    this.symptom,
    this.symptomCount = 0,
  });

  /// Rated meals still needed with it, and without it, for a verdict
  /// (Round 49: so "5 rated meals" and "not enough data" don't clash).
  int get missingWith =>
      meals >= FoodStats.enoughMeals ? 0 : FoodStats.enoughMeals - meals;
  int get missingWithout => mealsWithout >= FoodStats.enoughMeals
      ? 0
      : FoodStats.enoughMeals - mealsWithout;

  double get badShare => meals == 0 ? 0 : bad / meals;
  double get badShareWithout =>
      mealsWithout == 0 ? 0 : badWithout / mealsWithout;

  /// Too few rated meals with it, or without it (nothing to compare
  /// with: eaten almost every time), means no verdict.
  FoodVerdict get verdict {
    if (meals < FoodStats.enoughMeals || mealsWithout < FoodStats.enoughMeals) {
      return FoodVerdict.unknown;
    }
    final worse = badShare - badShareWithout >= FoodStats.clearlyWorse;
    return worse && bad >= FoodStats.enoughBad
        ? FoodVerdict.trouble
        : FoodVerdict.fine;
  }
}

/// The food tracker's statistics, the point of it: plain functions of the
/// meals. Honest about uncertainty: a food seen a few times is never
/// "trouble".
abstract final class FoodStats {
  /// Rated meals with a food before it gets a verdict.
  static const enoughMeals = 5;

  /// Bad meals with it, at least, to call it trouble.
  static const enoughBad = 3;

  /// How much more often bad (as a share of meals) counts as clearly.
  static const clearlyWorse = 0.25;

  /// Every food eaten, trouble first (the biggest difference first), then
  /// fine, then not enough data (most meals first).
  static List<FoodFinding> foods(FoodBook book) {
    final names = <String, String>{};
    final ids = <String, String?>{};
    for (final m in book.meals) {
      for (final f in m.foods) {
        final food = f.foodId == null ? null : book.foodById(f.foodId!);
        names[f.key] = food?.name ?? f.name;
        ids[f.key] = f.foodId;
      }
    }
    return _sorted([
      for (final key in names.keys)
        _finding(book.meals, (m) => m.foods.any((f) => f.key == key),
            label: names[key]!, foodId: ids[key], foodKey: key),
    ]);
  }

  /// The same by tag, for tags of foods eaten.
  static List<FoodFinding> tags(FoodBook book) {
    bool has(Meal meal, FoodTag tag) => meal.foods.any((f) =>
        f.foodId != null &&
        (book.foodById(f.foodId!)?.tags.contains(tag) ?? false));
    return _sorted([
      for (final tag in FoodTag.values)
        if (book.meals.any((m) => has(m, tag)))
          _finding(book.meals, (m) => has(m, tag), label: tag.label, tag: tag),
    ]);
  }

  /// By symptom (Round 48), kept apart from the verdicts: for each
  /// symptom logged (most often first), how many meals it followed, and
  /// the foods it follows clearly more often than without them (the same
  /// test as [FoodFinding.verdict]: there [FoodFinding.bad] counts the
  /// meals with the symptom), the biggest difference first.
  static List<(Symptom, int, List<FoodFinding>)> bySymptom(FoodBook book) {
    final keys = <String, (String, String?)>{};
    for (final m in book.meals) {
      for (final f in m.foods) {
        final food = f.foodId == null ? null : book.foodById(f.foodId!);
        keys[f.key] = (food?.name ?? f.name, f.foodId);
      }
    }
    final result = <(Symptom, int, List<FoodFinding>)>[];
    for (final symptom in Symptom.values) {
      final after = book.meals.where((m) => m.symptoms.contains(symptom));
      if (after.isEmpty) continue;
      final likely = [
        for (final MapEntry(key: key, value: (name, id)) in keys.entries)
          _finding(
            book.meals,
            (m) => m.foods.any((f) => f.key == key),
            label: name,
            foodId: id,
            foodKey: key,
            counted: (_) => true,
            outcome: (m) => m.symptoms.contains(symptom),
          ),
      ].where((f) => f.verdict == FoodVerdict.trouble).toList();
      result.add((symptom, after.length, _sorted(likely)));
    }
    result.sort((a, b) => b.$2.compareTo(a.$2));
    return result;
  }

  /// How many rated meals there are, and how many were bad or awful: the
  /// usual, to compare with.
  static (int, int) usual(FoodBook book) {
    final rated = book.meals.where((m) => m.rating != null);
    return (rated.length, rated.where((m) => m.rating!.isBad).length);
  }

  static FoodFinding _finding(
    List<Meal> meals,
    bool Function(Meal) has, {
    required String label,
    String? foodId,
    String? foodKey,
    FoodTag? tag,
    bool Function(Meal)? counted,
    bool Function(Meal)? outcome,
  }) {
    // By default rated meals count, and bad ones are the outcome; by
    // symptom (Round 48) every meal counts, and the symptom is.
    counted ??= (m) => m.rating != null;
    outcome ??= (m) => m.rating!.isBad;
    var withIt = 0, bad = 0, without = 0, badWithout = 0;
    final symptoms = <Symptom, int>{};
    for (final m in meals) {
      final contains = has(m);
      if (contains) {
        for (final s in m.symptoms) {
          symptoms[s] = (symptoms[s] ?? 0) + 1;
        }
      }
      if (!counted(m)) continue;
      final hit = outcome(m);
      if (contains) {
        withIt++;
        if (hit) bad++;
      } else {
        without++;
        if (hit) badWithout++;
      }
    }
    Symptom? symptom;
    var symptomCount = 0;
    for (final s in Symptom.values) {
      final n = symptoms[s] ?? 0;
      if (n >= 2 && n > symptomCount) (symptom, symptomCount) = (s, n);
    }
    return FoodFinding(
      label: label,
      foodId: foodId,
      foodKey: foodKey,
      tag: tag,
      meals: withIt,
      bad: bad,
      mealsWithout: without,
      badWithout: badWithout,
      symptom: symptom,
      symptomCount: symptomCount,
    );
  }

  /// The meals with [finding]'s food (or tag), newest first (Round 47: a
  /// food's own page).
  static List<Meal> mealsWith(FoodBook book, FoodFinding finding) => [
        for (final m in book.meals.reversed)
          if (_has(book, finding, m)) m,
      ];

  /// The same, without it.
  static List<Meal> mealsWithout(FoodBook book, FoodFinding finding) => [
        for (final m in book.meals.reversed)
          if (!_has(book, finding, m)) m,
      ];

  static bool _has(FoodBook book, FoodFinding finding, Meal meal) {
    final tag = finding.tag;
    if (tag != null) {
      return meal.foods.any((f) =>
          f.foodId != null &&
          (book.foodById(f.foodId!)?.tags.contains(tag) ?? false));
    }
    return meal.foods.any((f) => f.key == finding.foodKey);
  }

  /// How [meals] were rated: a count for each rating (unrated left out).
  static Map<MealRating, int> ratings(Iterable<Meal> meals) => {
        for (final rating in MealRating.values)
          rating: meals.where((m) => m.rating == rating).length,
      };

  /// The symptoms after [meals], most often first, with how many meals.
  static List<(Symptom, int)> symptoms(Iterable<Meal> meals) => [
        for (final s in Symptom.values)
          if (meals.where((m) => m.symptoms.contains(s)).length case final n
              when n > 0)
            (s, n),
      ]..sort((a, b) => b.$2.compareTo(a.$2));

  /// The other foods eaten in [meals] with [finding]'s food, most often
  /// first (at most [count]), with how many of those meals were bad.
  static List<(String, int, int)> eatenWith(
    FoodBook book,
    Iterable<Meal> meals,
    FoodFinding finding, {
    int count = 5,
  }) {
    final names = <String, String>{};
    final together = <String, int>{};
    final bad = <String, int>{};
    for (final m in meals) {
      for (final f in m.foods) {
        if (finding.foodKey != null && f.key == finding.foodKey) continue;
        final food = f.foodId == null ? null : book.foodById(f.foodId!);
        names[f.key] = food?.name ?? f.name;
        together[f.key] = (together[f.key] ?? 0) + 1;
        if (m.rating?.isBad ?? false) bad[f.key] = (bad[f.key] ?? 0) + 1;
      }
    }
    final keys = together.keys.toList()
      ..sort((a, b) {
        final byCount = together[b]!.compareTo(together[a]!);
        return byCount != 0
            ? byCount
            : names[a]!.toLowerCase().compareTo(names[b]!.toLowerCase());
      });
    return [
      for (final k in keys.take(count)) (names[k]!, together[k]!, bad[k] ?? 0),
    ];
  }

  static List<FoodFinding> _sorted(List<FoodFinding> findings) => findings
    ..sort((a, b) {
      final byVerdict = a.verdict.index.compareTo(b.verdict.index);
      if (byVerdict != 0) return byVerdict;
      if (a.verdict == FoodVerdict.trouble) {
        final byGap = (b.badShare - b.badShareWithout)
            .compareTo(a.badShare - a.badShareWithout);
        if (byGap != 0) return byGap;
      }
      final byMeals = b.meals.compareTo(a.meals);
      return byMeals != 0
          ? byMeals
          : a.label.toLowerCase().compareTo(b.label.toLowerCase());
    });
}
