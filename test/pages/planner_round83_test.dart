import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:the_app/data/app_storage.dart';
import 'package:the_app/models/planner_task.dart';
import 'package:the_app/providers/planner_provider.dart';
import 'package:the_app/providers/routines_provider.dart';

import '../helpers.dart';

/// Round 83 (Nikola): new blocks and routines remind at their start; a
/// block can be moved to another day (its time changed to fit, after
/// saying so, if it's taken there).
void main() {
  late ProviderContainer container;

  /// Thursday, 8 October 2026, noon.
  final now = DateTime(2026, 10, 8, 12);
  final today = DateTime(2026, 10, 8);
  final tomorrow = DateTime(2026, 10, 9);

  Future<void> openPlanner(WidgetTester tester) async {
    container = await pumpApp(tester, clock: () => now);
    await openTab(tester, 'Planner');
  }

  PlannerNotifier planner() => container.read(plannerProvider.notifier);
  PlannerTask task(String title) =>
      container.read(plannerProvider).firstWhere((t) => t.title == title);

  Future<void> tapText(WidgetTester tester, String text) async {
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text(text).first);
    await tester.pumpAndSettle();
    await tester.tap(find.text(text).first);
    await tester.pumpAndSettle();
  }

  bool chosen(WidgetTester tester, String label) => tester
      .widget<ChoiceChip>(find.widgetWithText(ChoiceChip, label))
      .selected;

  group('fitTime', () {
    test('its own time if free; else the nearest as long; null if none', () {
      final free = [(start: 0, end: 600), (start: 720, end: 1440)];
      expect(fitTime(free, (start: 60, end: 120)), (start: 60, end: 120));
      // 10:00–11:00 against a block 10:00–12:00: 09:00 is nearer than 12:00.
      expect(fitTime(free, (start: 600, end: 660)), (start: 540, end: 600));
      // 11:00–12:00: 12:00 is nearer.
      expect(fitTime(free, (start: 660, end: 720)), (start: 720, end: 780));
      // As near either way: the earlier.
      expect(fitTime(free, (start: 630, end: 690)), (start: 540, end: 600));
      expect(fitTime([(start: 0, end: 30)], (start: 0, end: 60)), isNull);
      expect(fitTime([(start: 0, end: 59)], (start: 0, end: 60)), isNull);
      expect(fitTime([(start: 100, end: 160)], (start: 0, end: 60)),
          (start: 100, end: 160),
          reason: 'just as long fits');
    });
  });

  test('moveTask: to a day and time; refused where taken', () {
    final p = PlannerNotifier(AppStorage.inMemory())
      ..addTask(today, 'Work', start: 600, end: 660)
      ..addTask(tomorrow, 'Call', start: 630, end: 690);
    final id = p.state.first.id;
    expect(() => p.moveTask(id, tomorrow, start: 600, end: 660),
        throwsA(isA<TaskOverlapException>()));
    p.moveTask(id, tomorrow, start: 540, end: 600);
    final moved = p.state.firstWhere((t) => t.id == id);
    expect((moved.day, moved.start, moved.end, moved.title),
        (tomorrow, 540, 600, 'Work'));
  });

  testWidgets('a new block reminds at its start, unless set otherwise',
      (tester) async {
    await openPlanner(tester);
    await tapText(tester, 'Free · 00:00–24:00');
    expect(chosen(tester, 'At start'), isTrue);
    expect(chosen(tester, 'Off'), isFalse);
    await tester.enterText(find.byKey(const Key('taskTitle')), 'Read');
    await tapText(tester, 'Add');
    expect(task('Read').remind, 0);

    await tapText(tester, 'Free · 01:00–24:00');
    await tester.enterText(find.byKey(const Key('taskTitle')), 'Nap');
    await tapText(tester, 'Off');
    await tapText(tester, 'Add');
    expect(task('Nap').remind, isNull);
  });

  testWidgets('a new routine reminds at its start', (tester) async {
    await openPlanner(tester);
    await tester.tap(find.byTooltip('Routines'));
    await tester.pumpAndSettle();
    await tapText(tester, 'Free · 00:00–24:00');
    expect(chosen(tester, 'At start'), isTrue);
    await tester.enterText(find.byKey(const Key('taskTitle')), 'Walk');
    await tapText(tester, 'Add');
    expect(container.read(routinesProvider).routines.single.remind, 0);
  });

  group('Move to another day', () {
    Future<void> move(WidgetTester tester, String title) async {
      await tapText(tester, title);
      await tapText(tester, 'Move to another day');
    }

    testWidgets('tomorrow first; at its time, free there; Undo moves it back',
        (tester) async {
      await openPlanner(tester);
      planner().addTask(today, 'Work', start: 600, end: 660);
      await tester.pumpAndSettle();
      await move(tester, 'Work');
      expect(find.text('Move to'), findsOneWidget);
      await tapText(tester, 'OK');
      final moved = task('Work');
      expect((moved.day, moved.start, moved.end), (tomorrow, 600, 660));
      expect(find.text('Work moved to Fri, 9 Oct'), findsOneWidget);
      expect(find.text('Work', skipOffstage: false), findsNothing,
          reason: 'gone from today');

      await tester.tap(find.text('Undo'));
      await tester.pumpAndSettle();
      final back = task('Work');
      expect((back.day, back.start, back.end), (today, 600, 660));
    });

    testWidgets(
        'a missed one: tomorrow from today; taken there: says its time will '
        'change, and to what (Cancel: stays)', (tester) async {
      await openPlanner(tester);
      final missed = DateTime(2026, 10, 6);
      planner()
        ..addTask(missed, 'Late', start: 600, end: 660)
        ..addTask(tomorrow, 'Call', start: 630, end: 720);
      await tester.pumpAndSettle();
      await tester.tap(find.text('6'));
      await tester.pumpAndSettle();
      await move(tester, 'Late');
      await tapText(tester, 'OK');
      expect(find.text('That time is taken'), findsOneWidget);
      expect(
          find.text('10:00–11:00 is taken on Fri, 9 Oct, so its time will '
              'change to fit: 09:30–10:30.'),
          findsOneWidget);
      await tapText(tester, 'Cancel');
      expect(task('Late').day, missed);

      await move(tester, 'Late');
      await tapText(tester, 'OK');
      await tapText(tester, 'Move');
      final moved = task('Late');
      expect((moved.day, moved.start, moved.end), (tomorrow, 570, 630));
    });

    testWidgets('no free time that long there: says so, stays', (tester) async {
      await openPlanner(tester);
      planner()
        ..addTask(today, 'Work', start: 600, end: 720)
        ..addTask(tomorrow, 'Morning', start: 0, end: 700)
        ..addTask(tomorrow, 'Evening', start: 760, end: 1440);
      await tester.pumpAndSettle();
      await move(tester, 'Work');
      await tapText(tester, 'OK');
      expect(
          find.text('No free time that long on Fri, 9 Oct.'), findsOneWidget);
      expect(task('Work').day, today);
    });
  });
}
