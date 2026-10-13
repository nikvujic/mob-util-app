import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:the_app/models/app_section.dart';
import 'package:the_app/models/notification_target.dart';
import 'package:the_app/models/planner_task.dart';
import 'package:the_app/models/routine.dart';
import 'package:the_app/providers/notification_target_provider.dart';
import 'package:the_app/providers/planner_provider.dart';
import 'package:the_app/providers/reminders_provider.dart';
import 'package:the_app/providers/section_locks_provider.dart';
import 'package:the_app/providers/security_provider.dart';
import 'package:the_app/providers/session_provider.dart';

import '../helpers.dart';

/// Tapping a notification opens what it's about (Round 19).
void main() {
  late ProviderContainer container;
  late FakeReminderScheduler scheduler;

  /// Thursday 8 October 2026, 09:00.
  final now = DateTime(2026, 10, 8, 9);
  final today = DateTime(2026, 10, 8);
  final tomorrow = DateTime(2026, 10, 9);

  Future<void> start(WidgetTester tester, {String? launch}) async {
    scheduler = FakeReminderScheduler()..launch = launch;
    container = await pumpApp(tester, clock: () => now, reminders: scheduler);
    await tester.pumpAndSettle();
  }

  Future<void> tapNotification(WidgetTester tester, String target) async {
    scheduler.taps.add(target);
    await tester.pumpAndSettle();
  }

  group('what a notification carries', () {
    test('a target in a few words, read back the same', () {
      final planner = PlannerTarget(tomorrow, 15 * 60);
      expect(planner.payload, 'planner|2026-10-09|900');
      expect(NotificationTarget.parse(planner.payload), planner);
      expect(NotificationTarget.parse('medicine'), isA<MedicineTarget>());
      expect(NotificationTarget.parse(null), isNull);
      expect(NotificationTarget.parse('planner|soon|x'), isNull);
      expect(NotificationTarget.parse('something else'), isNull);
    });

    test('blocks, routines and reminders lead to their day and time', () {
      final reminders = planReminders(
        now: now,
        tasks: [
          PlannerTask(
            id: 'd',
            title: 'Dentist',
            day: tomorrow,
            start: 15 * 60,
            end: 16 * 60,
            remind: 10,
          ),
        ],
        routines: RoutineBook.empty,
      );
      expect(reminders.single.target, 'planner|2026-10-09|900');
    });
  });

  testWidgets('a block: the planner, on its day, scrolled to it',
      (tester) async {
    await start(tester);
    container
        .read(plannerProvider.notifier)
        .addTask(tomorrow, 'Dentist', start: 22 * 60, end: 23 * 60, remind: 10);
    await tester.pump();
    expect(find.text('Notes'), findsWidgets, reason: 'on Notes');

    await tapNotification(tester, PlannerTarget(tomorrow, 22 * 60).payload);
    expect(find.textContaining('Tomorrow · Fri, 9 Oct'), findsOneWidget);
    expect(find.text('Dentist').hitTestable(), findsOneWidget,
        reason: 'late in the day, scrolled into view');
    expect(container.read(pendingTargetProvider), isNull, reason: 'done');
  });

  testWidgets('from another page on top, back to the planner', (tester) async {
    await start(tester);
    await openMenu(tester);
    await tester.tap(find.text('Settings'));
    await tester.pumpAndSettle();
    await tapNotification(tester, PlannerTarget(today, 20 * 60).payload);
    expect(appBarTitle('Settings'), findsNothing);
    expect(find.textContaining('Today · Thu, 8 Oct'), findsOneWidget);
    // 20:00 in view (the labels are under the left edge's tap area).
    final y = tester.getCenter(find.text('20:00').first).dy;
    expect(y, inInclusiveRange(0, tester.view.physicalSize.height));
    expect(tester.getCenter(find.text('08:00').first).dy, lessThan(0),
        reason: 'not opened around now (09:00)');
  });

  testWidgets('a medicine: the Medicine page', (tester) async {
    await start(tester);
    await tapNotification(tester, const MedicineTarget().payload);
    expect(appBarTitle('Medicine'), findsOneWidget);
    expect(container.read(pendingTargetProvider), isNull);
  });

  testWidgets('one that started the app goes there too', (tester) async {
    await start(tester, launch: const MedicineTarget().payload);
    expect(appBarTitle('Medicine'), findsOneWidget);
  });

  testWidgets(
      'a locked Planner asks first; not unlocked, it waits for the next '
      'visit', (tester) async {
    await start(tester);
    container
        .read(plannerProvider.notifier)
        .addTask(tomorrow, 'Dentist', start: 22 * 60, end: 23 * 60);
    await tester.runAsync(() async {
      await container
          .read(securityProvider.notifier)
          .setPassword('master password');
      await container.read(sessionProvider.notifier).unlock('master password');
    });
    container.read(sectionLocksProvider.notifier).lock(AppSection.planner);
    container.read(sessionProvider.notifier).lock();
    await tester.pumpAndSettle();

    await tapNotification(tester, PlannerTarget(tomorrow, 22 * 60).payload);
    expect(find.text('Planner is locked'), findsOneWidget);
    expect(find.text('Dentist'), findsNothing);

    // Away and back, still locked: still waiting.
    await openTab(tester, 'Notes');
    await openTab(tester, 'Planner');
    expect(container.read(pendingTargetProvider), isNotNull);

    // Unlocked: there it goes.
    await tester.runAsync(() =>
        container.read(sessionProvider.notifier).unlock('master password'));
    await tester.pumpAndSettle();
    expect(find.textContaining('Tomorrow · Fri, 9 Oct'), findsOneWidget);
    expect(find.text('Dentist').hitTestable(), findsOneWidget);
    expect(container.read(pendingTargetProvider), isNull);
  });
}
