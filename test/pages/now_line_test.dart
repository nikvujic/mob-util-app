import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:the_app/pages/planner/timeline.dart';
import 'package:the_app/providers/planner_provider.dart';
import 'package:the_app/widgets/day_strip.dart';

import '../helpers.dart';

/// A line marks the time now on today's timeline (P21).
void main() {
  late DateTime now;
  final nowLine = find.byKey(const Key('nowLine'));

  Future<void> openPlanner(WidgetTester tester) async {
    await pumpApp(tester, clock: () => now);
    await openTab(tester, 'Planner');
  }

  /// Where the line is, from the timeline's top.
  double lineY(WidgetTester tester) =>
      tester.getTopLeft(nowLine).dy -
      tester.getTopLeft(find.byType(PlannerTimeline)).dy;

  double expectedY(int minutes) =>
      PlannerTimeline.offsetOf(minutes, PlannerTimeline.scaleFor(const [])) - 1;

  setUp(() => now = DateTime(2026, 10, 8, 12, 30));

  testWidgets('today shows it at the time now', (tester) async {
    await openPlanner(tester);
    expect(nowLine, findsOneWidget);
    expect(lineY(tester), moreOrLessEquals(expectedY(12 * 60 + 30)));
  });

  testWidgets('it moves on as time passes', (tester) async {
    await openPlanner(tester);
    now = DateTime(2026, 10, 8, 12, 45);
    await tester.pump(const Duration(seconds: 15));
    expect(lineY(tester), moreOrLessEquals(expectedY(12 * 60 + 45)));
  });

  testWidgets('it goes once the day is over (app left open)', (tester) async {
    await openPlanner(tester);
    now = DateTime(2026, 10, 9, 0, 1);
    await tester.pump(const Duration(seconds: 15));
    expect(nowLine, findsNothing);
  });

  testWidgets('it follows stretched hours', (tester) async {
    final container = await pumpApp(tester, clock: () => now);
    // A 5-minute block before now stretches the 11:00 hour.
    container
        .read(plannerProvider.notifier)
        .addTask(DateTime(2026, 10, 8), 'Shower', start: 660, end: 665);
    await openTab(tester, 'Planner');
    final scale = PlannerTimeline.scaleFor([
      TimelineBlock(
          id: 'x', title: 'Shower', start: 660, end: 665, onTap: () {}),
    ]);
    expect(lineY(tester),
        moreOrLessEquals(PlannerTimeline.offsetOf(750, scale) - 1));
  });

  testWidgets('other days have no line', (tester) async {
    await openPlanner(tester);
    await tester.tap(find.descendant(
      of: find.byType(DayStrip),
      matching: find.bySemanticsLabel(RegExp('Friday 9 October 2026')),
    ));
    await tester.pumpAndSettle();
    expect(nowLine, findsNothing);
  });
}
