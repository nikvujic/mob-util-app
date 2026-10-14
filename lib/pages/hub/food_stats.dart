import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:the_app/core/theme.dart';
import 'package:the_app/models/food_stats.dart';
import 'package:the_app/providers/food_provider.dart';
import 'package:the_app/widgets/empty_state.dart';
import 'package:the_app/widgets/pull_down_list.dart';

/// The food tracker's statistics (Round 46), the point of it: for each
/// food, and each tag, how rated meals with it went against meals without
/// it: *likely trouble*, *seems fine* or *not enough data yet*, with the
/// numbers behind it and the symptom that most often followed.
class FoodStatsPage extends ConsumerWidget {
  const FoodStatsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final book = ref.watch(foodProvider);
    final colors = context.colors;
    final (rated, bad) = FoodStats.usual(book);
    final foods = FoodStats.foods(book);
    final tags = FoodStats.tags(book);

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
      body: rated == 0
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
                const SizedBox(height: 24),
              ],
            ),
    );
  }
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
    final (label, colour) = switch (f.verdict) {
      FoodVerdict.trouble => ('Likely trouble', DoseColours.missed),
      FoodVerdict.fine => ('Seems fine', DoseColours.taken),
      FoodVerdict.unknown => ('Not enough data yet', colors.textMuted),
    };
    final numbers = '${f.meals} rated ${f.meals == 1 ? 'meal' : 'meals'}, '
        '${f.bad} bad · without it ${_share(f.badWithout, f.mealsWithout)}';
    return Padding(
      key: Key('finding-${f.label}'),
      padding: const EdgeInsets.fromLTRB(16, 6, 16, 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
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
    );
  }
}
