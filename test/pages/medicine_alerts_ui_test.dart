import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:the_app/models/notify_settings.dart';
import 'package:the_app/data/reminder_scheduler.dart';
import 'package:the_app/models/app_section.dart';
import 'package:the_app/models/hub_tool.dart';
import 'package:the_app/models/medicine.dart';
import 'package:the_app/providers/medicine_provider.dart';
import 'package:the_app/providers/preferences_provider.dart';
import 'package:the_app/providers/section_locks_provider.dart';
import 'package:the_app/providers/security_provider.dart';
import 'package:the_app/providers/session_provider.dart';

import '../helpers.dart';

/// Medicine settings (O12), reminders and the red dot (O13).
void main() {
  late ProviderContainer container;
  late DateTime now;
  late FakeReminderScheduler reminders;
  final today = DateTime(2026, 10, 12);
  final tomorrow = DateTime(2026, 10, 13);

  MedicineNotifier medicine() => container.read(medicineProvider.notifier);
  PreferencesNotifier preferences() =>
      container.read(preferencesProvider.notifier);

  /// The app at [at] (08:03 by default), [seed]ed, on the Hub.
  Future<void> start(
    WidgetTester tester, {
    DateTime? at,
    void Function()? seed,
  }) async {
    now = at ?? DateTime(2026, 10, 12, 8, 3);
    reminders = FakeReminderScheduler();
    container = await pumpApp(tester, clock: () => now, reminders: reminders);
    seed?.call();
    await openTab(tester, 'Hub');
  }

  Future<void> openMedicine(WidgetTester tester) async {
    await tester.tap(find.byTooltip('Medicine'));
    await tester.pumpAndSettle();
  }

  final hubDot = find.byKey(const Key('hubDot'));
  final toolDot = find.byKey(const Key('toolDot'));

  List<String> medicineReminders() => [
        for (final r in reminders.scheduled)
          if (r.kind == ReminderKind.medicine)
            '${r.at.day} ${r.at.hour}:${r.at.minute} ${r.title}: ${r.body}',
      ];

  group('settings (O12)', () {
    testWidgets(
        'no bell on the page (Round 55): on the Notifications page, from '
        'the menu; each is kept', (tester) async {
      await start(tester);
      await openMedicine(tester);
      expect(find.byTooltip('Notifications'), findsNothing);
      expect(find.byIcon(Icons.notifications_outlined), findsNothing);
      await pressBack(tester);
      await openMenu(tester);
      await tester.tap(find.text('Notifications'));
      await tester.pumpAndSettle();
      expect(appBarTitle('Notifications'), findsOneWidget);

      final on = find.byKey(const Key('notifyOn-medicine'));
      await reveal(tester, on);
      await tester.tap(on);
      await tester.pumpAndSettle();
      expect(container.read(preferencesProvider).medicineReminders, isFalse);

      await tester.tap(on);
      await tester.pumpAndSettle();
      expect(container.read(preferencesProvider).medicineReminders, isTrue);
      expect(reminders.asked, 1, reason: 'turned on: asks to notify');
    });

    testWidgets('pause for a day or more, and resume', (tester) async {
      await start(tester);
      await openMenu(tester);
      await tester.tap(find.text('Notifications'));
      await tester.pumpAndSettle();

      final pause = find.byKey(const Key('notifyPause-medicine'));
      await reveal(tester, pause);
      await tester.tap(pause);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Through tomorrow'));
      await tester.pumpAndSettle();
      expect(container.read(preferencesProvider).medicinePausedUntil, tomorrow);
      expect(find.text('Paused'), findsOneWidget);
      expect(find.textContaining('through Tue, 13 Oct'), findsOneWidget);

      await tester.tap(pause);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Resume now'));
      await tester.pumpAndSettle();
      expect(container.read(preferencesProvider).medicinePausedUntil, isNull);
      expect(find.text('Pause'), findsOneWidget);
    });
  });

  group('reminders (O13)', () {
    testWidgets('at each dose time, again later if set; ticking clears',
        (tester) async {
      await start(tester, seed: () {
        medicine().add('Pills', times: [600, 1200], from: today);
      });
      await tester.pumpAndSettle();
      expect(medicineReminders().take(2), [
        '12 10:0 Pills: Time to take it · 10:00',
        '12 20:0 Pills: Time to take it · 20:00',
      ]);

      // Its sheet: remind again 1 h later (Round 16).
      final id = container.read(medicineProvider).medicines.single.id;
      final m = container.read(medicineProvider).medicines.single;
      medicine()
          .update(id, name: m.name, times: m.times, from: m.from, followUp: 60);
      await tester.pumpAndSettle();
      expect(medicineReminders().take(3), [
        '12 10:0 Pills: Time to take it · 10:00',
        '12 11:0 Pills: Not taken yet · 10:00',
        '12 20:0 Pills: Time to take it · 20:00',
      ]);

      // Taken early: neither reminds.
      medicine().toggleDose(
          container.read(medicineProvider).medicines.single.id, today, 0);
      await tester.pumpAndSettle();
      expect(
          medicineReminders().first, '12 20:0 Pills: Time to take it · 20:00');

      preferences().pauseMedicineUntil(today);
      await tester.pumpAndSettle();
      expect(
          medicineReminders().first, '13 10:0 Pills: Time to take it · 10:00');

      preferences().setMedicineReminders(false);
      await tester.pumpAndSettle();
      expect(medicineReminders(), isEmpty);
    });

    testWidgets('Round 82: with the Hub locked, names still', (tester) async {
      await start(tester, seed: () {
        medicine().add('Pills', times: [600], from: today);
      });
      await tester.runAsync(() async {
        await container
            .read(securityProvider.notifier)
            .setPassword('password1');
        await container.read(sessionProvider.notifier).unlock('password1');
      });
      container.read(sectionLocksProvider.notifier).lock(AppSection.hub);
      await tester.pumpAndSettle();
      expect(medicineReminders().first, startsWith('12 10:0 Pills'));
    });

    testWidgets(
        'Round 82: the Medicine page locked, names still; set private, none',
        (tester) async {
      await start(tester, seed: () {
        medicine().add('Pills', times: [600], from: today);
      });
      await tester.runAsync(() async {
        await container
            .read(securityProvider.notifier)
            .setPassword('password1');
        await container.read(sessionProvider.notifier).unlock('password1');
      });
      container.read(pageLocksProvider.notifier).lock(HubTool.medicine);
      await tester.pumpAndSettle();
      expect(medicineReminders().first, startsWith('12 10:0 Pills'));
      container.read(preferencesProvider.notifier).setNotifyStyle(
          NotifyPage.medicine,
          container
              .read(preferencesProvider)
              .styleOf(NotifyPage.medicine)
              .copyWith(private: true));
      await tester.pumpAndSettle();
      expect(medicineReminders().first,
          '12 10:0 Medicine: A dose is due at 10:00');
    });

    testWidgets('adding a medicine asks to show notifications', (tester) async {
      await start(tester);
      await openMedicine(tester);
      await tester.tap(find.byTooltip('Add medicine'));
      await tester.pumpAndSettle();
      await tester.enterText(find.byKey(const Key('medicineName')), 'Pills');
      await tester.pump();
      await tester.tap(find.byKey(const Key('medicineSubmit')));
      await tester.pumpAndSettle();
      expect(reminders.asked, 1);
    });
  });

  group('the red dot (O13)', () {
    testWidgets('on the tile and the Hub tab while a dose is due',
        (tester) async {
      await start(tester, seed: () {
        medicine().add('Pills', times: [480], from: today, important: true);
      });
      await tester.pumpAndSettle();
      expect(hubDot, findsOneWidget);
      expect(toolDot, findsOneWidget);

      medicine().toggleDose(
          container.read(medicineProvider).medicines.single.id, today, 0);
      await tester.pumpAndSettle();
      expect(hubDot, findsNothing);
      expect(toolDot, findsNothing);
    });

    testWidgets("comes when a dose's time does", (tester) async {
      await start(
        tester,
        at: DateTime(2026, 10, 12, 7, 59),
        seed: () =>
            medicine().add('Pills', times: [480], from: today, important: true),
      );
      await tester.pumpAndSettle();
      expect(hubDot, findsNothing);

      now = DateTime(2026, 10, 12, 8);
      await tester.pump(const Duration(seconds: 30));
      await tester.pump();
      expect(hubDot, findsOneWidget);
      expect(toolDot, findsOneWidget);
    });

    testWidgets('marked missed or not sure: no dot', (tester) async {
      await start(tester, seed: () {
        medicine().add('Pills', times: [480], from: today, important: true);
      });
      final id = container.read(medicineProvider).medicines.single.id;
      medicine().setDose(id, today, 0, DoseState.missed);
      await tester.pumpAndSettle();
      expect(hubDot, findsNothing);
    });

    testWidgets('a medicine not important: no dot (Round 24)', (tester) async {
      await start(tester, seed: () {
        medicine().add('Vitamin C', times: [480], from: today);
      });
      await tester.pumpAndSettle();
      expect(hubDot, findsNothing);
      expect(toolDot, findsNothing);
    });

    testWidgets('paused: no dot', (tester) async {
      await start(tester, seed: () {
        medicine().add('Pills', times: [480], from: today, important: true);
      });
      preferences().pauseMedicineUntil(today);
      await tester.pumpAndSettle();
      expect(hubDot, findsNothing);

      // The pause is over the next day.
      now = DateTime(2026, 10, 13, 8, 3);
      await tester.pump(const Duration(seconds: 30));
      await tester.pump();
      expect(hubDot, findsOneWidget);
    });

    testWidgets('on the Hub tab even while the Hub is locked', (tester) async {
      await start(tester, seed: () {
        medicine().add('Pills', times: [480], from: today, important: true);
      });
      await tester.runAsync(() async {
        await container
            .read(securityProvider.notifier)
            .setPassword('password1');
        await container.read(sessionProvider.notifier).unlock('password1');
      });
      container.read(sectionLocksProvider.notifier).lock(AppSection.hub);
      container.read(sessionProvider.notifier).lock();
      await tester.pumpAndSettle();
      expect(find.text('Hub is locked'), findsOneWidget);
      expect(hubDot, findsOneWidget);
    });
  });
}
