import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:the_app/core/clock.dart';
import 'package:the_app/core/format.dart';
import 'package:the_app/core/theme.dart';
import 'package:the_app/models/food.dart';
import 'package:the_app/models/hub_tool.dart';
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

/// The food tracker (O14, Round 46): a day at a time. A week strip on
/// top (each day coloured by its worst rated meal; a tap picks one, the
/// arrows move a week), the day's meals in order (a tap opens one to rate
/// or change it), and + logs a meal. Statistics and the foods list are
/// beside +. No reminders (Nikola).
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
            child: _WeekStrip(
              day: _day,
              today: today,
              book: book,
              onPick: (day) => setState(() => _day = day),
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
                  child: _MealCard(
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

/// A week, Monday to Sunday, around the day shown: each day's number on
/// its worst rating's colour (none rated: plain), the picked day ringed.
class _WeekStrip extends StatelessWidget {
  final DateTime day;
  final DateTime today;
  final FoodBook book;
  final ValueChanged<DateTime> onPick;

  const _WeekStrip({
    required this.day,
    required this.today,
    required this.book,
    required this.onPick,
  });

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final monday = addDays(day, 1 - day.weekday);
    return Padding(
      padding: const EdgeInsets.fromLTRB(4, 8, 4, 0),
      child: Row(
        children: [
          IconButton(
            tooltip: 'Week before',
            icon: const Icon(Icons.chevron_left),
            onPressed: () => onPick(addDays(day, -7)),
          ),
          for (var i = 0; i < 7; i++)
            Expanded(
              child: _DayDot(
                day: addDays(monday, i),
                picked: addDays(monday, i) == day,
                isToday: addDays(monday, i) == today,
                worst: book.worstOn(addDays(monday, i)),
                logged: book.mealsOn(addDays(monday, i)).isNotEmpty,
                onTap: () => onPick(addDays(monday, i)),
              ),
            ),
          IconButton(
            tooltip: 'Week after',
            icon: const Icon(Icons.chevron_right),
            color: colors.textSecondary,
            onPressed: () => onPick(addDays(day, 7)),
          ),
        ],
      ),
    );
  }
}

class _DayDot extends StatelessWidget {
  final DateTime day;
  final bool picked;
  final bool isToday;
  final MealRating? worst;
  final bool logged;
  final VoidCallback onTap;

  const _DayDot({
    required this.day,
    required this.picked,
    required this.isToday,
    required this.worst,
    required this.logged,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final fill = worst?.colour;
    return Semantics(
      button: true,
      selected: picked,
      label: '${formatDayLong(day)}'
          '${worst == null ? (logged ? ', not rated' : '') : ', ${worst!.label}'}',
      excludeSemantics: true,
      child: InkResponse(
        key: Key('foodDay-${day.year}-${day.month}-${day.day}'),
        onTap: onTap,
        child: SizedBox(
          height: kMinInteractiveDimension + 18,
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                weekdayShort(day).substring(0, 1),
                style: TextStyle(
                  color: isToday ? colors.accent : colors.textMuted,
                  fontSize: 11,
                ),
              ),
              const SizedBox(height: 4),
              Container(
                width: 32,
                height: 32,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: fill,
                  border: Border.all(
                    color: picked
                        ? colors.accent
                        : logged && fill == null
                            ? colors.textMuted
                            : Colors.transparent,
                    width: picked ? 2.5 : 1,
                  ),
                ),
                child: Text(
                  '${day.day}',
                  style: TextStyle(
                    color:
                        fill == null ? colors.textPrimary : RatingColours.ink,
                    fontWeight: isToday ? FontWeight.w700 : FontWeight.w400,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// A meal: its kind and time, its foods, and its rating (a coloured face)
/// or "Not rated".
class _MealCard extends StatelessWidget {
  final Meal meal;
  final VoidCallback onTap;

  const _MealCard({required this.meal, required this.onTap});

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
