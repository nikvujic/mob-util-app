import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:the_app/core/theme.dart';
import 'package:the_app/providers/planner_provider.dart';
import 'package:the_app/providers/routines_provider.dart';
import 'package:the_app/widgets/selection.dart';

import '../helpers.dart';

/// Block colours in the planner (P9).
void main() {
  late ProviderContainer container;
  final now = DateTime(2026, 10, 8, 12);
  final today = DateTime(2026, 10, 8);

  Future<void> openPlanner(WidgetTester tester) async {
    container = await pumpApp(tester, clock: () => now);
    await openTab(tester, 'Planner');
  }

  Future<void> tapText(WidgetTester tester, String text) async {
    await tester.ensureVisible(find.text(text).first);
    await tester.pumpAndSettle();
    await tester.tap(find.text(text).first);
    await tester.pumpAndSettle();
  }

  Color? background(WidgetTester tester, String title) {
    final card = find.ancestor(
      of: find.text(title),
      matching: find.byType(SelectableCard),
    );
    return tester.widget<SelectableCard>(card).color;
  }

  testWidgets('a colour picked in the sheet is kept and shown', (tester) async {
    await openPlanner(tester);
    await tapText(tester, 'Free · 00:00–24:00');
    await tester.enterText(find.byKey(const Key('taskTitle')), 'Dentist');
    await tester.tap(find.bySemanticsLabel('Colour: Blue'));
    await tester.pump();
    await tester.tap(find.widgetWithText(FilledButton, 'Add'));
    await tester.pumpAndSettle();

    expect(container.read(plannerProvider).single.color, 'blue');
    expect(background(tester, 'Dentist'), BlockColor.blue.fill);

    // Back to no colour.
    await tapText(tester, 'Dentist');
    await tester.tap(find.bySemanticsLabel('Colour: none'));
    await tester.pump();
    await tester.tap(find.widgetWithText(FilledButton, 'Save'));
    await tester.pumpAndSettle();
    expect(container.read(plannerProvider).single.color, isNull);
    expect(background(tester, 'Dentist'), isNull);
  });

  testWidgets('routines have colours too; a changed day keeps it',
      (tester) async {
    await openPlanner(tester);
    container.read(routinesProvider.notifier).add(
          title: 'Gym',
          start: 18 * 60,
          end: 19 * 60,
          weekdays: {1, 2, 3, 4, 5, 6, 7},
          from: today,
          color: 'green',
        );
    await tester.pump();
    expect(background(tester, 'Gym'), BlockColor.green.fill);

    await tapText(tester, 'Gym');
    await tapText(tester, 'Change just this day');
    await tester.tap(find.widgetWithText(FilledButton, 'Save'));
    await tester.pumpAndSettle();
    expect(container.read(plannerProvider).single.color, 'green');
  });
}
