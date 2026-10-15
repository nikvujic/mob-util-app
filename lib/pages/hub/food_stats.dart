import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:the_app/core/clock.dart';
import 'package:the_app/core/format.dart';
import 'package:the_app/core/theme.dart';
import 'package:the_app/models/food.dart';
import 'package:the_app/models/food_stats.dart';
import 'package:the_app/pages/hub/food.dart';
import 'package:the_app/pages/hub/food_meal.dart';
import 'package:the_app/providers/food_provider.dart';
import 'package:the_app/widgets/empty_state.dart';
import 'package:the_app/widgets/pull_down_list.dart';

/// The food tracker's statistics (Round 46), the point of it: for each
/// food, and each tag, how rated meals with it went against meals without
/// it: *likely trouble*, *seems fine* or *not enough data yet*, with the
/// numbers behind it and the symptom that most often followed. A tap on
/// one opens its own page (Round 47).
class FoodStatsPage extends ConsumerWidget {
  const FoodStatsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final book = ref.watch(foodProvider);
    final colors = context.colors;
    final (rated, bad) = FoodStats.usual(book);
    final foods = FoodStats.foods(book);
    final tags = FoodStats.tags(book);
    final bySymptom = FoodStats.bySymptom(book);

    Widget heading(String text) => Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 6),
          child: Text(
            text,
            style: TextStyle(
              color: colors.accent,
              fontSize: 12,
              fontWeight: FontWeight.w600,
              letterSpacing: 1,
            ),
          ),
        );

    return Scaffold(
      appBar: AppBar(title: const Text('Statistics')),
      body: rated == 0 && bySymptom.isEmpty
          ? const EmptyState(
              icon: Icons.insights,
              message: 'Rate meals to see what agrees with you',
            )
          : PullDownList.children(
              children: [
                Padding(
                  key: const Key('foodUsual'),
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
                  child: Text(
                    '$rated rated ${rated == 1 ? 'meal' : 'meals'}, '
                    '$bad bad or awful '
                    '(usually ${_share(bad, rated)}). A food needs '
                    '${FoodStats.enoughMeals} rated meals before it gets a '
                    'verdict.',
                    style: TextStyle(color: colors.textSecondary),
                  ),
                ),
                heading('FOODS'),
                for (final f in foods) _FindingRow(finding: f),
                if (tags.isNotEmpty) ...[
                  heading('BY KIND'),
                  for (final f in tags) _FindingRow(finding: f),
                ],
                // Round 48: apart from the verdicts above (those come
                // from the faces alone).
                if (bySymptom.isNotEmpty) ...[
                  heading('BY SYMPTOM'),
                  for (final (symptom, count, likely) in bySymptom)
                    _SymptomBlock(
                      symptom: symptom,
                      count: count,
                      likely: likely,
                    ),
                ],
                const SizedBox(height: 24),
              ],
            ),
    );
  }
}

/// A symptom, how many meals it followed, and the foods it follows
/// clearly more often than without them (a tap opens the food's page).
class _SymptomBlock extends StatelessWidget {
  final Symptom symptom;
  final int count;
  final List<FoodFinding> likely;

  const _SymptomBlock({
    required this.symptom,
    required this.count,
    required this.likely,
  });

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Column(
      key: Key('bySymptom-${symptom.name}'),
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 6, 16, 2),
          child: Text(
            '${symptom.label}  ·  after $count '
            '${count == 1 ? 'meal' : 'meals'}',
            style: TextStyle(
              color: colors.textPrimary,
              fontSize: 15,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
        if (likely.isEmpty)
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 6),
            child: Text(
              'No food stands out yet',
              style: TextStyle(color: colors.textMuted, fontSize: 12),
            ),
          ),
        for (final f in likely)
          InkWell(
            key: Key('symptomFood-${symptom.name}-${f.label}'),
            onTap: () => openFoodPage(
              context,
              FoodFindingPage(foodKey: f.foodKey, label: f.label),
            ),
            child: ConstrainedBox(
              constraints:
                  const BoxConstraints(minHeight: kMinInteractiveDimension),
              child: Padding(
                padding: const EdgeInsets.fromLTRB(28, 4, 16, 4),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        f.label,
                        style: TextStyle(color: colors.textPrimary),
                      ),
                    ),
                    Text(
                      'after ${f.bad} of ${f.meals} · without it '
                      '${f.badWithout} of ${f.mealsWithout}',
                      style:
                          TextStyle(color: colors.textSecondary, fontSize: 12),
                    ),
                  ],
                ),
              ),
            ),
          ),
      ],
    );
  }
}

/// What a food without a verdict still needs (Round 49).
String _needs(FoodFinding f) {
  final parts = [
    if (f.missingWith > 0) '${f.missingWith} more rated with it',
    if (f.missingWithout > 0) '${f.missingWithout} more rated without it',
  ];
  return 'Needs ${parts.join(', ')}';
}

/// "1 in 5" (rounded), or "none".
String _share(int part, int whole) {
  if (whole == 0 || part == 0) return 'none';
  if (part == whole) return 'all';
  return '1 in ${(whole / part).round()}';
}

class _FindingRow extends StatelessWidget {
  final FoodFinding finding;

  const _FindingRow({required this.finding});

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final f = finding;
    final (label, colour) = verdictLook(context, f.verdict);
    final numbers = '${f.meals} rated ${f.meals == 1 ? 'meal' : 'meals'}, '
        '${f.bad} bad · without it ${_share(f.badWithout, f.mealsWithout)}';
    return InkWell(
      key: Key('finding-${f.label}'),
      onTap: () => openFoodPage(
        context,
        FoodFindingPage(foodKey: f.foodKey, tag: f.tag, label: f.label),
      ),
      child: ConstrainedBox(
        constraints: const BoxConstraints(minHeight: kMinInteractiveDimension),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 6, 16, 6),
          // The verdict centred on the food's lines (Round 49).
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      f.label,
                      style: TextStyle(color: colors.textPrimary, fontSize: 15),
                    ),
                    Text(
                      numbers,
                      style: TextStyle(color: colors.textMuted, fontSize: 12),
                    ),
                    if (f.symptom case final symptom?)
                      Text(
                        '${symptom.label} after ${f.symptomCount}',
                        style: TextStyle(color: colors.textMuted, fontSize: 12),
                      ),
                    if (f.verdict == FoodVerdict.unknown)
                      Text(
                        key: Key('needs-${f.label}'),
                        _needs(f),
                        style: TextStyle(color: colors.textMuted, fontSize: 12),
                      ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Text(
                label,
                key: Key('verdict-${f.label}'),
                style: TextStyle(
                  color: colour,
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// What [verdict] is called, and its colour.
(String, Color) verdictLook(BuildContext context, FoodVerdict verdict) =>
    switch (verdict) {
      FoodVerdict.trouble => ('Likely trouble', DoseColours.missed),
      FoodVerdict.fine => ('Seems fine', DoseColours.taken),
      FoodVerdict.unknown => ('Not enough data yet', context.colors.textMuted),
    };

/// One food's (or kind's) statistics (Round 47, "extensive"): its
/// verdict and why, how its meals were rated against meals without it
/// (a bar per face), the symptoms after it, what it was eaten with, and
/// every meal with it, newest first (a tap opens one).
class FoodFindingPage extends ConsumerWidget {
  /// The food ([MealFood.key]), or else the [tag].
  final String? foodKey;
  final FoodTag? tag;

  /// Its name, for the title (and if it's gone meanwhile).
  final String label;

  const FoodFindingPage({
    super.key,
    this.foodKey,
    this.tag,
    required this.label,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final book = ref.watch(foodProvider);
    final today = dayOf(ref.watch(clockProvider)());
    final colors = context.colors;
    final finding = [
      ...FoodStats.foods(book),
      ...FoodStats.tags(book),
    ]
        .where((f) => tag != null ? f.tag == tag : f.foodKey == foodKey)
        .firstOrNull;
    final title = finding?.label ?? label;
    if (finding == null) {
      return Scaffold(
        appBar: AppBar(title: Text(title)),
        body: const EmptyState(icon: Icons.insights, message: 'No meals'),
      );
    }
    final withIt = FoodStats.mealsWith(book, finding);
    final without = FoodStats.mealsWithout(book, finding);
    final (verdict, colour) = verdictLook(context, finding.verdict);
    final symptoms = FoodStats.symptoms(withIt);
    final eatenWith = FoodStats.eatenWith(book, withIt, finding);

    Widget heading(String text) => Padding(
          padding: const EdgeInsets.fromLTRB(16, 20, 16, 8),
          child: Text(
            text,
            style: TextStyle(
              color: colors.accent,
              fontSize: 12,
              fontWeight: FontWeight.w600,
              letterSpacing: 1,
            ),
          ),
        );
    String percent(int part, int whole) =>
        whole == 0 ? '–' : '${(100 * part / whole).round()}%';

    return Scaffold(
      appBar: AppBar(title: Text(title)),
      body: PullDownList.children(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
            child: Text(
              verdict,
              key: const Key('findingVerdict'),
              style: TextStyle(
                color: colour,
                fontSize: 18,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          Padding(
            key: const Key('findingWhy'),
            padding: const EdgeInsets.fromLTRB(16, 6, 16, 0),
            child: Text(
              _why(finding),
              style: TextStyle(color: colors.textSecondary),
            ),
          ),
          heading('HOW MEALS WENT'),
          _Comparison(
            withIt: FoodStats.ratings(withIt),
            without: FoodStats.ratings(without),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
            child: Text(
              'Bad or awful: ${percent(finding.bad, finding.meals)} with it, '
              '${percent(finding.badWithout, finding.mealsWithout)} without.'
              '${withIt.length > finding.meals ? ' ${withIt.length - finding.meals} not rated.' : ''}',
              style: TextStyle(color: colors.textMuted, fontSize: 12),
            ),
          ),
          if (symptoms.isNotEmpty) ...[
            heading('AFTER IT'),
            for (final (symptom, n) in symptoms)
              _Line(
                key: Key('symptomAfter-${symptom.name}'),
                label: symptom.label,
                value: '$n of ${withIt.length} '
                    '${withIt.length == 1 ? 'meal' : 'meals'}',
              ),
          ],
          if (eatenWith.isNotEmpty) ...[
            heading('EATEN WITH'),
            for (final (name, n, bad) in eatenWith)
              _Line(
                key: Key('eatenWith-$name'),
                label: name,
                value: '$n× · $bad bad',
              ),
          ],
          heading('MEALS WITH IT  ·  ${withIt.length}'),
          for (final meal in withIt)
            Padding(
              key: ValueKey(meal.id),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 3),
              child: MealCard(
                meal: meal,
                today: today,
                onTap: () => openFoodPage(context, MealPage(mealId: meal.id)),
              ),
            ),
          const SizedBox(height: 24),
        ],
      ),
    );
  }

  /// Why the verdict, in words.
  static String _why(FoodFinding f) {
    final rated = '${f.meals} rated ${f.meals == 1 ? 'meal' : 'meals'} '
        'with it (${f.bad} bad or awful), ${f.mealsWithout} without it '
        '(${f.badWithout} bad or awful).';
    return switch (f.verdict) {
      FoodVerdict.trouble =>
        '$rated Meals with it went badly clearly more often.',
      FoodVerdict.fine => '$rated No clear difference.',
      FoodVerdict.unknown => '$rated A verdict needs '
          '${FoodStats.enoughMeals} rated meals with it and '
          '${FoodStats.enoughMeals} without.',
    };
  }
}

/// A label and a value on one line.
class _Line extends StatelessWidget {
  final String label;
  final String value;

  const _Line({super.key, required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 4),
      child: Row(
        children: [
          Expanded(
            child: Text(label, style: TextStyle(color: colors.textPrimary)),
          ),
          Text(value, style: TextStyle(color: colors.textSecondary)),
        ],
      ),
    );
  }
}

/// A bar per face, bad to good: with it (in the face's colour) above
/// without it (faint), each as a share of its rated meals.
class _Comparison extends StatelessWidget {
  final Map<MealRating, int> withIt;
  final Map<MealRating, int> without;

  const _Comparison({required this.withIt, required this.without});

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final totalWith = withIt.values.fold(0, (a, b) => a + b);
    final totalWithout = without.values.fold(0, (a, b) => a + b);
    Widget bar(double share, Color colour) => LayoutBuilder(
          builder: (context, box) => Align(
            alignment: Alignment.centerLeft,
            child: Container(
              width: box.maxWidth * share,
              height: 10,
              decoration: BoxDecoration(
                color: colour,
                borderRadius: BorderRadius.circular(3),
              ),
            ),
          ),
        );
    return Column(
      children: [
        for (final rating in MealRating.values.reversed)
          Padding(
            key: Key('ratingBar-${rating.name}'),
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 4),
            child: Row(
              children: [
                Icon(rating.face, color: rating.colour, size: 22),
                const SizedBox(width: 8),
                Expanded(
                  child: Column(
                    children: [
                      bar(totalWith == 0 ? 0 : withIt[rating]! / totalWith,
                          rating.colour),
                      const SizedBox(height: 3),
                      bar(
                          totalWithout == 0
                              ? 0
                              : without[rating]! / totalWithout,
                          colors.textHint),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                SizedBox(
                  width: 56,
                  child: Text(
                    '${withIt[rating]} · ${without[rating]}',
                    textAlign: TextAlign.end,
                    style: TextStyle(color: colors.textSecondary, fontSize: 12),
                  ),
                ),
              ],
            ),
          ),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 4, 16, 0),
          child: Text(
            'Coloured: with it  ·  grey: without  ·  counts: with · without',
            style: TextStyle(color: colors.textMuted, fontSize: 12),
          ),
        ),
      ],
    );
  }
}
