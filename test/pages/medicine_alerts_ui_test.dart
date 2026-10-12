import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:the_app/data/reminder_scheduler.dart';
import 'package:the_app/models/app_section.dart';
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
    testWidgets('a gear in the top bar opens them; each is kept',
        (tester) async {
      await start(tester);
      await openMedicine(tester);
      await tester.tap(find.byTooltip('Medicine settings'));
      await tester.pumpAndSettle();
      expect(appBarTitle('Medicine settings'), findsOneWidget);

      await tester.tap(find.byKey(const Key('medicineFollowUp')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('4 h later'));
      await tester.pumpAndSettle();
      expect(container.read(preferencesProvider).medicineFollowUp, 240);
      expect(find.text('4 h later'), findsOneWidget, reason: 'shown');

      await tester.tap(find.byKey(const Key('medicineFollowUp')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Off').last);
      await tester.pumpAndSettle();
      expect(container.read(preferencesProvider).medicineFollowUp, isNull);

      await tester.tap(find.byKey(const Key('medicineDot')));
      await tester.pumpAndSettle();
      expect(container.read(preferencesProvider).medicineDot, isFalse);

      await tester.tap(find.byKey(const Key('medicineReminders')));
      await tester.pumpAndSettle();
      expect(container.read(preferencesProvider).medicineReminders, isFalse);
      // A second reminder needs the first.
      await tester.tap(find.byKey(const Key('medicineFollowUp')));
      await tester.pumpAndSettle();
      expect(find.text('Remind again'), findsNothing);

      await tester.tap(find.byKey(const Key('medicineReminders')));
      await tester.pumpAndSettle();
      expect(container.read(preferencesProvider).medicineReminders, isTrue);
      expect(reminders.asked, 1, reason: 'turned on: asks to notify');
    });

    testWidgets('pause for a day or more, and resume', (tester) async {
      await start(tester);
      await openMedicine(tester);
      await tester.tap(find.byTooltip('Medicine settings'));
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key('medicinePause')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Through tomorrow'));
      await tester.pumpAndSettle();
      expect(container.read(preferencesProvider).medicinePausedUntil, tomorrow);
      expect(find.text('Paused'), findsOneWidget);
      expect(find.textContaining('through Tue, 13 Oct'), findsOneWidget);

      await tester.tap(find.byKey(const Key('medicinePause')));
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

      preferences().setMedicineFollowUp(60);
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

    testWidgets('with the Hub locked, no names', (tester) async {
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
        medicine().add('Pills', times: [480], from: today);
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
        seed: () => medicine().add('Pills', times: [480], from: today),
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
        medicine().add('Pills', times: [480], from: today);
      });
      final id = container.read(medicineProvider).medicines.single.id;
      medicine().setDose(id, today, 0, DoseState.missed);
      await tester.pumpAndSettle();
      expect(hubDot, findsNothing);
    });

    testWidgets('off, or paused: no dot', (tester) async {
      await start(tester, seed: () {
        medicine().add('Pills', times: [480], from: today);
      });
      preferences().setMedicineDot(false);
      await tester.pumpAndSettle();
      expect(hubDot, findsNothing);
      expect(toolDot, findsNothing);

      preferences()
        ..setMedicineDot(true)
        ..pauseMedicineUntil(today);
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
        medicine().add('Pills', times: [480], from: today);
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
