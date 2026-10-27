import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:the_app/core/clock.dart';
import 'package:the_app/core/format.dart';
import 'package:the_app/core/theme.dart';
import 'package:the_app/models/food.dart';
import 'package:the_app/models/hub_tool.dart';
import 'package:the_app/pages/hub/food_calendar.dart';
import 'package:the_app/pages/hub/food_foods.dart';
import 'package:the_app/pages/hub/food_meal.dart';
import 'package:the_app/pages/hub/food_stats.dart';
import 'package:the_app/pages/hub/page_gate.dart';
import 'package:the_app/providers/food_provider.dart';
import 'package:the_app/widgets/bottom_actions.dart';
import 'package:the_app/widgets/pull_down_list.dart';
import 'package:the_app/widgets/selection.dart';

/// A rating's colour and face (Round 46).
extension MealRatingLook on MealRating {
  Color get colour => switch (this) {
        MealRating.great => RatingColours.great,
        MealRating.good => RatingColours.good,
        MealRating.ok => RatingColours.ok,
        MealRating.bad => RatingColours.bad,
        MealRating.awful => RatingColours.awful,
      };

  /// A face, from grinning to very unhappy.
  IconData get face => switch (this) {
        MealRating.great => Icons.sentiment_very_satisfied,
        MealRating.good => Icons.sentiment_satisfied,
        MealRating.ok => Icons.sentiment_neutral,
        MealRating.bad => Icons.sentiment_dissatisfied,
        MealRating.awful => Icons.sentiment_very_dissatisfied,
      };
}

/// Opens one of the food tracker's own pages, behind its lock.
void openFoodPage(BuildContext context, Widget page) {
  Navigator.of(context).push(
    MaterialPageRoute<void>(
      builder: (_) => PageGate(page: HubTool.food, child: page),
    ),
  );
}

/// The food tracker (O14, Round 46): a day at a time. A month calendar
/// on top (Round 47; each day coloured by its worst rated meal, a tap
/// picks one), the day's meals in order (a tap opens one to rate
/// or change it), and + logs a meal. Statistics and the foods list are
/// beside +. No reminders.
class FoodPage extends ConsumerStatefulWidget {
  const FoodPage({super.key});

  @override
  ConsumerState<FoodPage> createState() => _FoodPageState();
}

class _FoodPageState extends ConsumerState<FoodPage> {
  late DateTime _day = _today;

  DateTime get _today => dayOf(ref.read(clockProvider)());

  /// A new meal on the day shown: now if it's today, else at noon.
  void _add() {
    final now = ref.read(clockProvider)();
    final at = _day == dayOf(now)
        ? now
        : DateTime(_day.year, _day.month, _day.day, 12);
    openFoodPage(context, MealPage(at: at));
  }

  @override
  Widget build(BuildContext context) {
    final book = ref.watch(foodProvider);
    final today = _today;
    final meals = book.mealsOn(_day);
    final colors = context.colors;
    return Scaffold(
      appBar: AppBar(title: Text(HubTool.food.label)),
      body: PullDownList(
        bottomSpace: BottomActions.contentClearance,
        slivers: [
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.only(top: 4),
              child: FoodCalendar(
                book: book,
                today: today,
                picked: _day,
                onDay: (day) => setState(() => _day = day),
              ),
            ),
          ),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
              child: Text(
                key: const Key('foodDay'),
                _day == today
                    ? 'TODAY  ·  ${formatDay(_day, today: today)}'.toUpperCase()
                    : formatDay(_day, today: today).toUpperCase(),
                style: TextStyle(
                  color: colors.accent,
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 1,
                ),
              ),
            ),
          ),
          if (meals.isEmpty)
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
                child: Text(
                  'No meals logged',
                  style: TextStyle(color: colors.textMuted),
                ),
              ),
            ),
          SliverList.list(
            children: [
              for (final meal in meals)
                Padding(
                  key: ValueKey(meal.id),
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 3),
                  child: MealCard(
                    meal: meal,
                    onTap: () =>
                        openFoodPage(context, MealPage(mealId: meal.id)),
                  ),
                ),
            ],
          ),
        ],
      ),
      floatingActionButton: BottomActions(
        actions: [
          BottomAction(
            icon: Icons.insights,
            tooltip: 'Statistics',
            onPressed: () => openFoodPage(context, const FoodStatsPage()),
          ),
          BottomAction(
            icon: Icons.list_alt,
            tooltip: 'Foods',
            onPressed: () => openFoodPage(context, const FoodsPage()),
          ),
          BottomAction(
            icon: Icons.add,
            tooltip: 'Log a meal',
            primary: true,
            onPressed: _add,
          ),
        ],
      ),
    );
  }
}

/// A meal: its kind and time, its foods, and its rating (a coloured face)
/// or "Not rated". With [today] it shows its date too (a food's history,
/// Round 47).
class MealCard extends StatelessWidget {
  final Meal meal;
  final VoidCallback onTap;
  final DateTime? today;

  const MealCard({
    super.key,
    required this.meal,
    required this.onTap,
    this.today,
  });

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final local = meal.at.toLocal();
    final rating = meal.rating;
    return SelectableCard(
      selected: false,
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 12, 12, 12),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '${today == null ? '' : '${formatDay(local, today: today!)}  ·  '}'
                    '${meal.kind.label}  ·  '
                    '${formatMinutes(local.hour * 60 + local.minute)}',
                    style: TextStyle(color: colors.textSecondary, fontSize: 12),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    meal.foods.isEmpty
                        ? 'No foods'
                        : meal.foods.map((f) => f.name).join(', '),
                    style: TextStyle(color: colors.textPrimary, fontSize: 15),
                  ),
                  if (meal.symptoms.isNotEmpty) ...[
                    const SizedBox(height: 4),
                    Text(
                      meal.symptoms.map((s) => s.label).join(', '),
                      style: TextStyle(color: colors.textMuted, fontSize: 12),
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(width: 8),
            if (rating == null)
              Text(
                'Not rated',
                style: TextStyle(color: colors.textMuted, fontSize: 12),
              )
            else
              Container(
                key: Key('mealRating-${meal.id}'),
                width: 36,
                height: 36,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: rating.colour,
                ),
                child: Icon(
                  rating.face,
                  color: RatingColours.ink,
                  semanticLabel: rating.label,
                ),
              ),
          ],
        ),
      ),
    );
  }
}
