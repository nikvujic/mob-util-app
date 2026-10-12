import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:the_app/providers/planner_provider.dart';
import 'package:the_app/providers/routines_provider.dart';
import 'package:the_app/widgets/selection.dart';

import '../helpers.dart';

/// Descriptions on tasks and routines (P20).
void main() {
  late ProviderContainer container;
  final today = DateTime(2026, 10, 8);
  int at(num hours) => (hours * 60).round();

  Future<void> openPlanner(WidgetTester tester) async {
    container = await pumpApp(tester, clock: () => DateTime(2026, 10, 8, 9));
    await openTab(tester, 'Planner');
  }

  PlannerNotifier planner() => container.read(plannerProvider.notifier);

  testWidgets('typed in the sheet, kept trimmed; blank is none',
      (tester) async {
    await openPlanner(tester);
    await tester.ensureVisible(find.text('Free · 00:00–24:00'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Free · 00:00–24:00'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const Key('taskTitle')), 'Dentist');
    await tester.enterText(
        find.byKey(const Key('taskDescription')), '  Bring the X-ray  ');
    await tester.pump();
    await tester.tap(find.widgetWithText(FilledButton, 'Add'));
    await tester.pumpAndSettle();
    expect(
        container.read(plannerProvider).single.description, 'Bring the X-ray');

    planner().addTask(today, 'Plain',
        start: at(20), end: at(21), description: '   ');
    expect(
      container
          .read(plannerProvider)
          .firstWhere((t) => t.title == 'Plain')
          .description,
      isNull,
    );
  });

  testWidgets('on blocks, as many lines as fit; in full in the menu',
      (tester) async {
    await openPlanner(tester);
    const long = 'One line, then another, and then a third line that goes on '
        'long enough to wrap a few times on a phone';
    planner()
      ..addTask(today, 'Long', start: at(10), end: at(12), description: long)
      ..addTask(today, 'Short', start: at(13), end: at(13.5), description: long)
      ..addTask(today, 'Tiny',
          start: at(14), end: at(14) + 5, description: long);
    await tester.pump();

    int lines(String title) {
      final block = find.ancestor(
        of: find.text(title),
        matching: find.byType(SelectableCard),
      );
      return tester
          .widget<Text>(find.descendant(of: block, matching: find.text(long)))
          .maxLines!;
    }

    expect(lines('Long'), greaterThan(1));
    expect(lines('Short'), 1, reason: 'beside-the-title layout: one line');
    expect(lines('Tiny'), 1, reason: 'even the smallest block (Round 12)');

    await tester.ensureVisible(find.text('Short'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Short'));
    await tester.pumpAndSettle();
    final menu = find.byType(BottomSheet);
    expect(
      tester
          .widget<Text>(find.descendant(of: menu, matching: find.text(long)))
          .maxLines,
      isNull,
      reason: 'in full',
    );
  });

  testWidgets('a routine has one too; changing just a day keeps it',
      (tester) async {
    await openPlanner(tester);
    container.read(routinesProvider.notifier).add(
          title: 'Pills',
          start: at(10),
          end: at(11),
          weekdays: {1, 2, 3, 4, 5, 6, 7},
          from: today,
          description: 'One with water',
        );
    await tester.pump();
    expect(find.text('One with water'), findsOneWidget);

    await tester.tap(find.text('Pills'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Change just this day'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilledButton, 'Save'));
    await tester.pumpAndSettle();

    expect(
        container.read(plannerProvider).single.description, 'One with water');
  });
}
