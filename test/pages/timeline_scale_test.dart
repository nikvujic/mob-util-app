import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:the_app/pages/planner/timeline.dart';
import 'package:the_app/providers/planner_provider.dart';
import 'package:the_app/widgets/selection.dart';

import '../helpers.dart';

/// Short blocks stretch the timeline where they are (Round 10): every
/// block gets at least a touch target; the rest keeps its scale.
void main() {
  int at(num hours) => (hours * 60).round();
  const hour = PlannerTimeline.hourHeight;
  const least = PlannerTimeline.minBlockHeight;

  group('TimeScale', () {
    test('with nothing short, an hour is an hour', () {
      final scale = TimeScale.forBlocks([(start: at(9), end: at(10))]);
      expect(scale.y(at(1)), hour);
      expect(scale.y(at(24)), 24 * hour);
    });

    test('a 5-minute block makes its hour taller, and only that hour', () {
      final scale = TimeScale.forBlocks([(start: at(11), end: at(11) + 5)]);
      expect(scale.y(at(11) + 5) - scale.y(at(11)), closeTo(least, 0.001));
      final stretched = scale.y(at(12)) - scale.y(at(11));
      expect(stretched, greaterThan(hour));
      expect(scale.y(at(11)), closeTo(11 * hour, 0.001), reason: 'before');
      expect(scale.y(at(13)) - scale.y(at(12)), closeTo(hour, 0.001),
          reason: 'after');
    });

    test('short blocks side by side with a long one each get their room', () {
      final scale = TimeScale.forBlocks([
        (start: at(10), end: at(12)), // a task
        (start: at(11), end: at(11) + 5), // a routine beside it
        (start: at(11) + 5, end: at(11) + 10), // and another
      ]);
      expect(scale.y(at(11) + 5) - scale.y(at(11)),
          greaterThanOrEqualTo(least - 0.001));
      expect(scale.y(at(11) + 10) - scale.y(at(11) + 5),
          greaterThanOrEqualTo(least - 0.001));
    });
  });

  testWidgets('on the planner, a 5-minute block is a full block',
      (tester) async {
    final ProviderContainer container =
        await pumpApp(tester, clock: () => DateTime(2026, 10, 8, 10));
    await openTab(tester, 'Planner');
    container.read(plannerProvider.notifier).addTask(
        DateTime(2026, 10, 8), 'Shower',
        start: at(11), end: at(11) + 5);
    await tester.pump();

    final card = find.ancestor(
      of: find.text('Shower'),
      matching: find.byType(SelectableCard),
    );
    expect(tester.getSize(card).height, greaterThanOrEqualTo(48));
    expect(find.bySemanticsLabel('Done: Shower'), findsOneWidget);
    // 11:00 to 12:00 is taller than 12:00 to 13:00.
    double top(String label) => tester.getTopLeft(find.text(label)).dy;
    await tester.ensureVisible(find.text('13:00'));
    await tester.pumpAndSettle();
    expect(
        top('12:00') - top('11:00'), greaterThan(top('13:00') - top('12:00')));
  });
}
