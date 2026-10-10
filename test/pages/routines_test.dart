import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:the_app/providers/planner_provider.dart';
import 'package:the_app/providers/routines_provider.dart';
import 'package:the_app/widgets/day_strip.dart';

import '../helpers.dart';

/// Planner routines in the app (P8).
void main() {
  late ProviderContainer container;

  /// Thursday, 8 October 2026, noon.
  final now = DateTime(2026, 10, 8, 12);
  final today = DateTime(2026, 10, 8);
  final tomorrow = DateTime(2026, 10, 9);
  int at(num hours) => (hours * 60).round();

  Future<void> openPlanner(WidgetTester tester) async {
    container = await pumpApp(tester, clock: () => now);
    await openTab(tester, 'Planner');
  }

  RoutinesNotifier routines() => container.read(routinesProvider.notifier);

  /// Gym every day 18–19 from today.
  String addGym() => routines().add(
        title: 'Gym',
        start: at(18),
        end: at(19),
        weekdays: {1, 2, 3, 4, 5, 6, 7},
        from: today,
      )!;

  Future<void> tapText(WidgetTester tester, String text) async {
    await tester.ensureVisible(find.text(text).first);
    await tester.pumpAndSettle();
    await tester.tap(find.text(text).first);
    await tester.pumpAndSettle();
  }

  Future<void> showDay(WidgetTester tester, String label) async {
    final cell = find.descendant(
      of: find.byType(DayStrip),
      matching: find.bySemanticsLabel(RegExp(label)),
    );
    await tester.tap(cell.first);
    await tester.pumpAndSettle();
  }

  testWidgets('a task set to repeat becomes a routine, shown with ↻',
      (tester) async {
    await openPlanner(tester);
    await tapText(tester, 'Free · 00:00–24:00');
    await tester.enterText(find.byKey(const Key('taskTitle')), 'Read');
    await tester.tap(find.text('Every day'));
    await tester.pump();
    await tester.tap(find.widgetWithText(FilledButton, 'Add'));
    await tester.pumpAndSettle();

    expect(container.read(plannerProvider), isEmpty, reason: 'no one-off');
    final routine = container.read(routinesProvider).routines.single;
    expect((routine.title, routine.weekdays.length, routine.from),
        ('Read', 7, today));

    await showDay(tester, 'Friday 9 October');
    expect(find.text('Read'), findsOneWidget);
    expect(find.bySemanticsLabel(RegExp('Routine')), findsWidgets);
  });

  testWidgets('skip this day, with undo', (tester) async {
    await openPlanner(tester);
    final id = addGym();
    await tester.pump();

    await tapText(tester, 'Gym');
    await tapText(tester, 'Skip this day');
    expect(find.text('Gym'), findsNothing);
    expect(container.read(routinesProvider).dayOf(id, today)!.skipped, isTrue);

    await tester.tap(find.text('Undo'));
    await tester.pumpAndSettle();
    expect(find.text('Gym'), findsOneWidget);
  });

  testWidgets('change just this day: a one-off takes its place',
      (tester) async {
    await openPlanner(tester);
    final id = addGym();
    await tester.pump();

    await tapText(tester, 'Gym');
    await tapText(tester, 'Change just this day');
    await tester.enterText(find.byKey(const Key('taskTitle')), 'Gym (short)');
    await tester.tap(find.text('30 min'));
    await tester.pump();
    await tester.tap(find.widgetWithText(FilledButton, 'Save'));
    await tester.pumpAndSettle();

    final task = container.read(plannerProvider).single;
    expect((task.title, task.start, task.end), ('Gym (short)', at(18), 1110));
    expect(container.read(routinesProvider).dayOf(id, today)!.skipped, isTrue);
    expect(routinesOn(tomorrow, container.read(routinesProvider), const []),
        hasLength(1),
        reason: 'other days keep it');
  });

  testWidgets('edit routine from a day changes every day', (tester) async {
    await openPlanner(tester);
    addGym();
    await tester.pump();

    await tapText(tester, 'Gym');
    await tapText(tester, 'Edit routine');
    await tester.enterText(find.byKey(const Key('taskTitle')), 'Run');
    await tester.tap(find.widgetWithText(FilledButton, 'Save'));
    await tester.pumpAndSettle();

    expect(container.read(routinesProvider).routines.single.title, 'Run');
    await showDay(tester, 'Friday 9 October');
    expect(find.text('Run'), findsOneWidget);
  });

  testWidgets('ticking a routine off counts for that day only', (tester) async {
    await openPlanner(tester);
    final id = addGym();
    await tester.pump();

    await tester.ensureVisible(find.bySemanticsLabel('Done: Gym'));
    await tester.pumpAndSettle();
    await tester.tap(find.bySemanticsLabel('Done: Gym'));
    await tester.pumpAndSettle();
    final book = container.read(routinesProvider);
    expect(book.dayOf(id, today)!.done, isTrue);
    expect(book.dayOf(id, tomorrow), isNull);
  });

  group('the Routines screen', () {
    Future<void> openRoutines(WidgetTester tester) async {
      await openPlanner(tester);
      await tester.tap(find.byTooltip('Routines'));
      await tester.pumpAndSettle();
    }

    testWidgets('opens on today\'s weekday; days are picked below',
        (tester) async {
      await openRoutines(tester);
      routines().add(
        title: 'Swim',
        start: at(7),
        end: at(8),
        weekdays: {DateTime.tuesday},
        from: today,
      );
      await tester.pump();
      expect(find.text('Every Thursday'), findsOneWidget);
      expect(find.text('Swim'), findsNothing);

      await tester.tap(find.bySemanticsLabel('Tuesday'));
      await tester.pumpAndSettle();
      expect(find.text('Every Tuesday'), findsOneWidget);
      expect(find.text('Swim', skipOffstage: false), findsOneWidget);
    });

    testWidgets('free time adds a routine on that weekday', (tester) async {
      await openRoutines(tester);
      await tapText(tester, 'Free · 00:00–24:00');
      await tester.enterText(find.byKey(const Key('taskTitle')), 'Walk');
      await tester.tap(find.widgetWithText(FilterChip, 'Sat'));
      await tester.pump();
      await tester.tap(find.widgetWithText(FilledButton, 'Add'));
      await tester.pumpAndSettle();

      final walk = container.read(routinesProvider).routines.single;
      expect(walk.weekdays, {DateTime.thursday, DateTime.saturday});
      expect(walk.from, today);
      expect(find.text('Walk'), findsOneWidget);
    });

    testWidgets('a routine is deleted everywhere, after asking',
        (tester) async {
      await openRoutines(tester);
      addGym();
      await tester.pump();

      await tapText(tester, 'Gym');
      await tester.tap(find.text('Delete routine'));
      await tester.pumpAndSettle();
      expect(find.text('Delete routine?'), findsOneWidget);
      await tester.tap(find.widgetWithText(FilledButton, 'Delete'));
      await tester.pumpAndSettle();

      expect(container.read(routinesProvider).routines, isEmpty);
      expect(find.text('Gym'), findsNothing);
    });

    testWidgets('routines can\'t overlap on a day they share', (tester) async {
      await openRoutines(tester);
      routines().add(
        title: 'Swim',
        start: 0,
        end: at(1),
        weekdays: {DateTime.friday},
        from: today,
      );
      await tester.pump();

      // Thursday's free time starts at 00:00, and with Friday ticked too
      // the new routine (00:00–01:00) would meet Swim there.
      await tapText(tester, 'Free · 00:00–24:00');
      await tester.enterText(find.byKey(const Key('taskTitle')), 'Walk');
      await tester.tap(find.widgetWithText(FilterChip, 'Fri'));
      await tester.pump();
      await tester.tap(find.widgetWithText(FilledButton, 'Add'));
      await tester.pumpAndSettle();

      expect(
        find.text('Another routine has that time on one of those days.'),
        findsOneWidget,
      );
      expect(container.read(routinesProvider).routines.map((r) => r.title),
          ['Swim']);
    });
  });
}
