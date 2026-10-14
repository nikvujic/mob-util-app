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

  /// The food (null for a tag).
  final String? foodId;
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
    this.tag,
    required this.meals,
    required this.bad,
    required this.mealsWithout,
    required this.badWithout,
    this.symptom,
    this.symptomCount = 0,
  });

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
            label: names[key]!, foodId: ids[key]),
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
    FoodTag? tag,
  }) {
    var withIt = 0, bad = 0, without = 0, badWithout = 0;
    final symptoms = <Symptom, int>{};
    for (final m in meals) {
      final contains = has(m);
      if (contains) {
        for (final s in m.symptoms) {
          symptoms[s] = (symptoms[s] ?? 0) + 1;
        }
      }
      final rating = m.rating;
      if (rating == null) continue;
      if (contains) {
        withIt++;
        if (rating.isBad) bad++;
      } else {
        without++;
        if (rating.isBad) badWithout++;
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
      tag: tag,
      meals: withIt,
      bad: bad,
      mealsWithout: without,
      badWithout: badWithout,
      symptom: symptom,
      symptomCount: symptomCount,
    );
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
