import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:the_app/data/app_storage.dart';
import 'package:the_app/data/reminder_scheduler.dart';
import 'package:the_app/models/notification_target.dart';
import 'package:the_app/models/preferences.dart';
import 'package:the_app/providers/backup_reminder_provider.dart';
import 'package:the_app/providers/notes_provider.dart';
import 'package:the_app/providers/preferences_provider.dart';

import '../helpers.dart';

/// The weekly backup reminder (D8, Round 23).
void main() {
  /// Tuesday 13 October 2026, 10:00.
  final now = DateTime(2026, 10, 13, 10);

  group('when it comes', () {
    List<DateTime> times(Preferences preferences, {int days = 14}) => [
          for (final r in planBackupReminders(
            now: now,
            preferences: preferences,
            days: days,
          ))
            r.at,
        ];

    test('the first evening once due, then every three days', () {
      final preferences = Preferences(lastBackupAt: DateTime(2026, 10, 8, 9));
      expect(preferences.backupDueAt, DateTime(2026, 10, 15, 9));
      expect(times(preferences, days: 7), [
        DateTime(2026, 10, 15, 19),
        DateTime(2026, 10, 18, 19),
      ]);
    });

    test('due after 19:00: the next evening', () {
      final preferences = Preferences(lastBackupAt: DateTime(2026, 10, 7, 21));
      expect(times(preferences, days: 3).first, DateTime(2026, 10, 15, 19));
    });

    test('long overdue: only the coming ones', () {
      final preferences = Preferences(lastBackupAt: DateTime(2026, 9, 1));
      final first = times(preferences).first;
      expect(first.isAfter(now), isTrue);
      expect(first.hour, 19);
      expect(times(preferences), hasLength(5), reason: 'every 3rd day');
    });

    test('off, or nothing to count from: none', () {
      expect(
          times(Preferences(
            lastBackupAt: DateTime(2026, 9, 1),
            backupReminder: false,
          )),
          isEmpty);
      expect(times(const Preferences()), isEmpty);
    });

    test('never backed up: counted from the first start', () {
      final started = const Preferences().startedAt(DateTime(2026, 10, 1));
      expect(started.backupCountFrom, DateTime(2026, 10, 1));
      expect(started.backupDueBy(now), isTrue);
      expect(started.startedAt(now).backupCountFrom, DateTime(2026, 10, 1),
          reason: 'only the first');
      final backedUp = Preferences(lastBackupAt: DateTime(2026, 10, 12));
      expect(backedUp.startedAt(now).backupCountFrom, isNull);
      expect(backedUp.backupDueBy(now), isFalse);
    });

    test('kept in preferences.json', () {
      final preferences = Preferences(
        lastBackupAt: DateTime(2026, 10, 12, 18, 30),
        backupCountFrom: DateTime(2026, 10, 1),
        backupReminder: false,
      );
      final read = Preferences.fromJson(preferences.toJson());
      expect(read.lastBackupAt, preferences.lastBackupAt);
      expect(read.backupCountFrom, preferences.backupCountFrom);
      expect(read.backupReminder, isFalse);
      expect(Preferences.fromJson(const {}).backupReminder, isTrue);
    });
  });

  group('in the app', () {
    late ProviderContainer container;
    late FakeReminderScheduler scheduler;
    late FakeBackupFiles files;

    Future<void> start(WidgetTester tester, Preferences saved) async {
      scheduler = FakeReminderScheduler();
      files = FakeBackupFiles();
      container = await pumpApp(
        tester,
        clock: () => now,
        reminders: scheduler,
        backupFiles: files,
        overrides: [
          appStorageProvider.overrideWithValue(
            AppStorage.inMemory(initialPreferences: saved),
          ),
        ],
      );
      container.read(notesProvider.notifier).addNote(title: 'Groceries');
      await tester.pumpAndSettle();
    }

    final menuDot = find.byKey(const Key('menuDot'));
    final backupDot = find.byKey(const Key('backupDot'));
    List<Reminder> backupReminders() => [
          for (final r in scheduler.scheduled)
            if (r.kind == ReminderKind.backup) r,
        ];

    testWidgets(
        'a week without one: dots on the menu and Backup; exporting clears '
        'them', (tester) async {
      await start(tester, Preferences(lastBackupAt: DateTime(2026, 10, 5)));
      expect(menuDot, findsOneWidget);
      expect(backupReminders().first.target, const BackupTarget().payload);

      await openMenu(tester);
      expect(backupDot, findsOneWidget);
      expect(find.text('Time for a new one'), findsOneWidget);
      await tester.tap(find.text('Backup'));
      await tester.pumpAndSettle();
      expect(find.text('Last backup: 2026-10-05 00:00 (8 days ago)'),
          findsOneWidget);

      await tester.tap(find.text('Export all data'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Plain file'));
      await tester.pumpAndSettle();
      expect(container.read(preferencesProvider).lastBackupAt, now);
      expect(
          find.text('Last backup: 2026-10-13 10:00 (today)'), findsOneWidget);
      expect(backupReminders().first.at, DateTime(2026, 10, 20, 19),
          reason: 'a week from now');
      await tester.pageBack();
      await tester.pumpAndSettle();
      expect(backupDot, findsNothing);
    });

    testWidgets('a cancelled export counts for nothing', (tester) async {
      await start(tester, Preferences(lastBackupAt: DateTime(2026, 10, 5)));
      await openMenu(tester);
      await tester.tap(find.text('Backup'));
      await tester.pumpAndSettle();
      files.cancel = true;
      await tester.tap(find.text('Export all data'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Plain file'));
      await tester.pumpAndSettle();
      expect(container.read(preferencesProvider).lastBackupAt,
          DateTime(2026, 10, 5));
    });

    testWidgets('not yet due: no dot', (tester) async {
      await start(tester, Preferences(lastBackupAt: DateTime(2026, 10, 10)));
      expect(menuDot, findsNothing);
    });

    testWidgets('the switch on Backup turns it off', (tester) async {
      await start(tester, Preferences(lastBackupAt: DateTime(2026, 10, 5)));
      await openMenu(tester);
      await tester.tap(find.text('Backup'));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('backupReminder')));
      await tester.pumpAndSettle();
      expect(container.read(preferencesProvider).backupReminder, isFalse);
      expect(backupReminders(), isEmpty);
      await tester.pageBack();
      await tester.pumpAndSettle();
      expect(backupDot, findsNothing);
    });

    testWidgets('tapping the notification opens Backup', (tester) async {
      await start(tester, Preferences(lastBackupAt: DateTime(2026, 10, 5)));
      scheduler.taps.add(const BackupTarget().payload);
      await tester.pumpAndSettle();
      expect(appBarTitle('Backup'), findsOneWidget);
      expect(find.text('Export all data'), findsOneWidget);
    });
  });
}
