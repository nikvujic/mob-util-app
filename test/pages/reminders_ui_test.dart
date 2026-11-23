import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:the_app/models/notify_settings.dart';
import 'package:the_app/providers/preferences_provider.dart';
import 'package:the_app/models/app_section.dart';
import 'package:the_app/providers/planner_provider.dart';
import 'package:the_app/providers/section_locks_provider.dart';
import 'package:the_app/providers/security_provider.dart';

import '../helpers.dart';

/// Planner reminders in the app (P10).
void main() {
  late ProviderContainer container;
  late FakeReminderScheduler reminders;
  final now = DateTime(2026, 10, 8, 12);

  Future<void> openPlanner(WidgetTester tester) async {
    reminders = FakeReminderScheduler();
    container = await pumpApp(tester, clock: () => now, reminders: reminders);
    await openTab(tester, 'Planner');
  }

  /// Adds "Dentist" 13:00–14:00 from the sheet, with [remind].
  Future<void> addWithReminder(WidgetTester tester, String remind) async {
    final free = find.text('Free · 00:00–24:00');
    await tester.ensureVisible(free);
    await tester.pumpAndSettle();
    await tester.tap(free);
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const Key('taskTitle')), 'Dentist');
    await tester.pump();
    await tester.ensureVisible(find.text(remind));
    await tester.pumpAndSettle();
    await tester.tap(find.text(remind));
    await tester.pump();
    await tester.tap(find.widgetWithText(FilledButton, 'Add'));
    await tester.pumpAndSettle();
  }

  testWidgets('a reminder set in the sheet is scheduled; permission asked',
      (tester) async {
    await openPlanner(tester);
    // A new block reminds at its start; this adds one more.
    await addWithReminder(tester, '10 min before');

    final task = container.read(plannerProvider).single;
    expect(task.reminds, [0, 10]);
    expect(reminders.asked, 1);
    // It starts at 00:00 (the free time's start), already past today:
    // nothing to schedule.
    expect(reminders.scheduledReminders, isEmpty);
  });

  testWidgets('scheduled when ahead; follows changes', (tester) async {
    await openPlanner(tester);
    container.read(plannerProvider.notifier).addTask(
      DateTime(2026, 10, 8),
      'Dentist',
      start: 15 * 60,
      end: 16 * 60,
      reminds: [10],
    );
    await tester.pump();
    expect(reminders.scheduledReminders.single.title, 'Dentist');
    expect(
        reminders.scheduledReminders.single.at, DateTime(2026, 10, 8, 14, 50));
    expect(find.byIcon(Icons.notifications_none), findsOneWidget,
        reason: 'a bell on blocks with a reminder');

    container
        .read(plannerProvider.notifier)
        .toggleDone(container.read(plannerProvider).single.id);
    await tester.pump();
    expect(reminders.scheduledReminders, isEmpty, reason: 'ticked off');
  });

  testWidgets(
      'several reminders picked, the longer ones too; At start taken off; '
      'Off clears them', (tester) async {
    await openPlanner(tester);
    final free = find.text('Free · 00:00–24:00');
    await tester.ensureVisible(free);
    await tester.pumpAndSettle();
    await tester.tap(free);
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const Key('taskTitle')), 'Trip');
    Future<void> chip(String key) async {
      await tester.ensureVisible(find.byKey(Key(key)));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(Key(key)));
      await tester.pump();
    }

    for (final label in [
      '1 day before',
      '2 days before',
      '3 h before',
      '5 h before',
      '8 h before',
      '10 h before'
    ]) {
      expect(find.text(label), findsOneWidget, reason: label);
    }
    await chip('remind-0'); // At start off
    await chip('remind-1440');
    await chip('remind-120');
    await tester.tap(find.widgetWithText(FilledButton, 'Add'));
    await tester.pumpAndSettle();
    expect(container.read(plannerProvider).single.reminds, [120, 1440]);
  });

  testWidgets('no reminder: no permission asked', (tester) async {
    await openPlanner(tester);
    await addWithReminder(tester, 'Off');
    expect(reminders.asked, 0);
  });

  testWidgets('notifications refused: it says so', (tester) async {
    await openPlanner(tester);
    reminders.allowed = false;
    await addWithReminder(tester, '2 h before');
    expect(find.textContaining('reminders won\'t show'), findsOneWidget);
  });

  testWidgets(
      'a locked Planner still names its reminders; set private, '
      'they don\'t', (tester) async {
    await openPlanner(tester);
    await tester.runAsync(
      () => container.read(securityProvider.notifier).setPassword('password1'),
    );
    container.read(plannerProvider.notifier).addTask(
      DateTime(2026, 10, 8),
      'Therapy',
      start: 15 * 60,
      end: 16 * 60,
      reminds: [0],
    );
    container.read(sectionLocksProvider.notifier).lock(AppSection.planner);
    await tester.pump();
    expect(reminders.scheduledReminders.single.title, 'Therapy',
        reason: 'locked is no reason to hide it');
    final prefs = container.read(preferencesProvider.notifier);
    prefs.setNotifyStyle(
        NotifyPage.planner,
        container
            .read(preferencesProvider)
            .styleOf(NotifyPage.planner)
            .copyWith(private: true));
    await tester.pump();
    expect(reminders.scheduledReminders.single.title, 'Planner');
    expect(
        reminders.scheduledReminders.single.body, isNot(contains('Therapy')));
  });
}
