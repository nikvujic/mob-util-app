import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:the_app/models/preferences.dart';
import 'package:the_app/pages/planner/timeline.dart';
import 'package:the_app/providers/planner_provider.dart';
import 'package:the_app/providers/preferences_provider.dart';
import 'package:the_app/widgets/selection.dart';

import '../helpers.dart';

/// Timeline zoom (Round 9, E): one button cycles Normal → Large → Extra
/// large, so short blocks become big enough; no pinch.
void main() {
  late ProviderContainer container;
  final today = DateTime(2026, 10, 8);

  Future<void> openPlanner(WidgetTester tester) async {
    container = await pumpApp(tester, clock: () => DateTime(2026, 10, 8, 12));
    await openTab(tester, 'Planner');
  }

  Future<void> zoom(WidgetTester tester, String now) async {
    await tester.tap(find.byTooltip('Zoom: $now'));
    await tester.pumpAndSettle();
  }

  String saved() => container.read(preferencesProvider).plannerZoom;

  double heightOf(WidgetTester tester, String title) => tester
      .getSize(find.ancestor(
        of: find.text(title),
        matching: find.byType(SelectableCard),
      ))
      .height;

  testWidgets('cycles through three sizes and back, remembered',
      (tester) async {
    await openPlanner(tester);
    // Pills: 5 minutes, the shortest a block can be.
    container
        .read(plannerProvider.notifier)
        .addTask(today, 'Pills', start: 12 * 60, end: 12 * 60 + 5);
    await tester.pump();
    final normal = heightOf(tester, 'Pills');

    await zoom(tester, 'Normal');
    expect(saved(), 'large');
    expect(heightOf(tester, 'Pills'), closeTo(normal * 2 + 6, 0.5));

    await zoom(tester, 'Large');
    expect(saved(), 'extraLarge');
    expect(heightOf(tester, 'Pills'), greaterThanOrEqualTo(48),
        reason: '5 minutes is one touch target');
    expect(
      tester.getSize(find.bySemanticsLabel('Done: Pills')).height,
      greaterThanOrEqualTo(48),
      reason: 'its checkbox has a full touch target',
    );

    await zoom(tester, 'Extra large');
    expect(saved(), 'normal');
    expect(heightOf(tester, 'Pills'), closeTo(normal, 0.5));
  });

  testWidgets('the time in the middle stays in view', (tester) async {
    await openPlanner(tester);
    container
        .read(plannerProvider.notifier)
        .addTask(today, 'Lunch', start: 13 * 60, end: 14 * 60);
    await tester.pump();
    // Lunch's title in the middle of the view.
    await Scrollable.ensureVisible(
      tester.element(find.text('Lunch')),
      alignment: 0.5,
    );
    await tester.pumpAndSettle();
    final middle = tester.getCenter(find.byType(SingleChildScrollView)).dy;

    /// The minute at the middle of the view, from where Lunch (13:00) is.
    double middleMinute(TimelineZoom zoom) {
      final top = tester
              .getRect(find.ancestor(
                of: find.text('Lunch'),
                matching: find.byType(SelectableCard),
              ))
              .top -
          PlannerTimeline.gap / 2;
      return 13 * 60 + (middle - top) / zoom.hourHeight * 60;
    }

    final before = middleMinute(TimelineZoom.normal);
    for (final (now, next) in [
      ('Normal', TimelineZoom.large),
      ('Large', TimelineZoom.extraLarge),
      ('Extra large', TimelineZoom.normal),
    ]) {
      await zoom(tester, now);
      expect(middleMinute(next), closeTo(before, 1), reason: 'after $now');
    }
  });

  testWidgets('zoomed in, times between the hours are marked', (tester) async {
    await openPlanner(tester);
    expect(find.text('12:30'), findsNothing);
    await zoom(tester, 'Normal');
    expect(find.text('12:30'), findsOneWidget);
    expect(find.text('12:15'), findsNothing);
    await zoom(tester, 'Large');
    expect(find.text('12:15'), findsOneWidget);
  });

  testWidgets('the Routines screen has the same zoom', (tester) async {
    await openPlanner(tester);
    await zoom(tester, 'Normal');
    await tester.tap(find.byTooltip('Routines'));
    await tester.pumpAndSettle();

    expect(find.byTooltip('Zoom: Large'), findsOneWidget);
    expect(
      tester.widget<PlannerTimeline>(find.byType(PlannerTimeline)).zoom,
      TimelineZoom.large,
    );
  });

  test('saved with the preferences; older files open at normal', () {
    expect(Preferences.fromJson(const {}).plannerZoom, 'normal');
    final saved = const Preferences(plannerZoom: 'large').toJson();
    expect(Preferences.fromJson(saved).plannerZoom, 'large');
    expect(TimelineZoom.fromName('unknown'), TimelineZoom.normal);
  });
}
