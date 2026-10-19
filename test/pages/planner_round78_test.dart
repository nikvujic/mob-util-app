import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:the_app/data/app_storage.dart';
import 'package:the_app/models/planner_task.dart';
import 'package:the_app/providers/planner_provider.dart';
import 'package:the_app/providers/routines_provider.dart';

import '../helpers.dart';

/// Round 78 (Nikola): routines are just there (nothing to tick off, not
/// on past days); a past day's ticked-off blocks are deleted.
void main() {
  late ProviderContainer container;

  /// Thursday, 8 October 2026.
  var now = DateTime(2026, 10, 8, 12);
  final today = DateTime(2026, 10, 8);

  Future<void> openPlanner(WidgetTester tester) async {
    now = DateTime(2026, 10, 8, 12);
    container = await pumpApp(tester, clock: () => now);
    await openTab(tester, 'Planner');
  }

  PlannerNotifier planner() => container.read(plannerProvider.notifier);

  void everyDay(String title, {int hour = 18}) =>
      container.read(routinesProvider.notifier).add(
          title: title,
          start: hour * 60,
          end: hour * 60 + 60,
          weekdays: {1, 2, 3, 4, 5, 6, 7},
          from: DateTime(2026, 10, 1));

  test('the provider: only ticked-off tasks before today go', () {
    final storage = PlannerNotifier(AppStorage.inMemory());
    storage
      ..addTask(DateTime(2026, 10, 6), 'Past, done', start: 600, end: 660)
      ..addTask(DateTime(2026, 10, 6), 'Past, open', start: 700, end: 760)
      ..addTask(today, 'Today, done', start: 600, end: 660);
    String id(String t) => storage.state.firstWhere((x) => x.title == t).id;
    storage
      ..toggleDone(id('Past, done'))
      ..toggleDone(id('Today, done'));
    final gone = storage.dropDoneBefore(today);
    expect(gone.map((t) => t.title), ['Past, done']);
    expect(storage.state.map((t) => t.title), ['Past, open', 'Today, done']);
    expect(storage.dropDoneBefore(today), isEmpty);
  });

  testWidgets('a routine has no box to tick; a block does', (tester) async {
    await openPlanner(tester);
    everyDay('Gym');
    planner().addTask(today, 'Work', start: 13 * 60, end: 14 * 60);
    await tester.pumpAndSettle();
    expect(find.text('Gym'), findsWidgets);
    expect(find.byType(Checkbox), findsOneWidget, reason: "Work's only");
  });

  testWidgets(
      'a past day (an unfinished block there): its block, no routines; '
      'ticked off, the block is deleted (Undo: back, not done)',
      (tester) async {
    await openPlanner(tester);
    everyDay('Gym', hour: 9);
    planner().addTask(DateTime(2026, 10, 6), 'Late', start: 720, end: 780);
    await tester.pumpAndSettle();
    await tester.tap(find.text('6'));
    await tester.pumpAndSettle();
    expect(find.text('Tue, 6 Oct'), findsOneWidget);
    expect(find.text('Late'), findsOneWidget);
    expect(find.text('Gym'), findsNothing, reason: 'not on a past day');

    await tester.tap(find.byType(Checkbox));
    await tester.pumpAndSettle();
    expect(container.read(plannerProvider).map((t) => (t.title, t.done, t.day)),
        isEmpty,
        reason: 'deleted');
    expect(find.text('Late done and cleared'), findsOneWidget);
    expect(find.text('Today · Thu, 8 Oct'), findsOneWidget,
        reason: 'nothing left in the past');

    await tester.tap(find.text('Undo'));
    await tester.pumpAndSettle();
    final back = container.read(plannerProvider).single;
    expect((back.title, back.done), ('Late', false));
  });

  testWidgets('today: ticked off, it stays (till a later day)', (tester) async {
    await openPlanner(tester);
    planner().addTask(today, 'Work', start: 13 * 60, end: 14 * 60);
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.byType(Checkbox));
    await tester.tap(find.byType(Checkbox));
    await tester.pumpAndSettle();
    expect(container.read(plannerProvider).single.done, isTrue);
    expect(find.text('Work done and cleared'), findsNothing);

    // The next day, the app comes back: gone.
    now = DateTime(2026, 10, 9, 8);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.hidden);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
    await tester.pump();
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.hidden);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await tester.pumpAndSettle();
    expect(container.read(plannerProvider), isEmpty);
  });

  testWidgets('opened: a past day\'s ticked-off blocks are gone',
      (tester) async {
    final done = PlannerTask(
      id: 'old',
      title: 'Old',
      day: DateTime(2026, 10, 5),
      start: 600,
      end: 660,
      done: true,
    );
    final open = PlannerTask(
      id: 'open',
      title: 'Open',
      day: DateTime(2026, 10, 5),
      start: 700,
      end: 760,
    );
    container = await pumpApp(tester,
        clock: () => DateTime(2026, 10, 8, 12), plannerTasks: [done, open]);
    await tester.pumpAndSettle();
    expect(container.read(plannerProvider).map((t) => t.id), ['open']);
  });
}
