import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:the_app/core/app_info.dart';
import 'package:the_app/core/clock.dart';
import 'package:the_app/data/app_storage.dart';
import 'package:the_app/data/backup.dart';
import 'package:the_app/data/backup_files.dart';
import 'package:the_app/data/reminder_scheduler.dart';
import 'package:the_app/models/hub_tool.dart';
import 'package:the_app/models/notify_settings.dart';
import 'package:the_app/models/subscription.dart';
import 'package:the_app/providers/backup_provider.dart';
import 'package:the_app/providers/preferences_provider.dart';
import 'package:the_app/providers/reminders_provider.dart';
import 'package:the_app/providers/section_data_provider.dart';
import 'package:the_app/providers/subscriptions_provider.dart';

import '../helpers.dart';

/// Subscriptions' store (Round 79).
void main() {
  Subscription claude({String name = 'Claude'}) => Subscription(
        id: 's1',
        name: name,
        price: 20,
        date: DateTime(2026, 10, 25),
      );

  test('saved as it goes: added once, then changed; deleted with Undo', () {
    final subs = SubscriptionsNotifier(AppStorage.inMemory());
    subs.save(claude());
    subs.save(claude(name: 'Claude Pro'));
    expect(subs.state.subscriptions.single.name, 'Claude Pro');
    final before = subs.delete('s1');
    expect(subs.state.isEmpty, isTrue);
    subs.replaceAll(before);
    expect(subs.state.subscriptions, hasLength(1), reason: 'Undo');
  });

  test('saved to subscriptions.json and loaded back', () async {
    final dir = Directory.systemTemp.createTempSync('subscriptions');
    addTearDown(() => dir.deleteSync(recursive: true));
    final storage = await AppStorage.open(directory: dir);
    SubscriptionsNotifier(storage).save(claude());
    await storage.flush();
    expect(File('${dir.path}/subscriptions.json').readAsStringSync(),
        contains('"version":1'));
    final again = await AppStorage.open(directory: dir);
    expect(again.initialSubscriptions.subscriptions.single, claude());
  });

  test('a Hub page: lockable, counted and cleared (Clear data), in backups',
      () {
    final container = ProviderContainer(overrides: [
      appVersionProvider.overrideWithValue('1.36.0 (82)'),
      appStorageProvider.overrideWithValue(AppStorage.inMemory(
          initialSubscriptions: SubscriptionBook([claude()]))),
    ]);
    addTearDown(container.dispose);
    expect(HubTool.subscriptions.lockable, isTrue);
    expect(HubTool.subscriptions.clearable, isTrue);
    final snapshot = container.read(backupExporterProvider).snapshot();
    final back = Backup.decode(snapshot.encode());
    expect(back.subscriptions.subscriptions.single, claude());
    expect(jsonDecode(snapshot.encode())['version'], greaterThanOrEqualTo(29));
    final data = container.read(sectionDataProvider);
    expect(data.countOf(HubTool.subscriptions), 1);
    data.clearOf(HubTool.subscriptions);
    expect(container.read(subscriptionsProvider).isEmpty, isTrue);
  });

  test('a backup with two of one id is damaged', () {
    final backup = Backup(
      createdAt: DateTime(2026, 10, 19),
      appVersion: '1.36.0 (82)',
      notes: const [],
      shopItems: const [],
      subscriptions: SubscriptionBook([claude(), claude(name: 'Twin')]),
    );
    expect(() => Backup.decode(backup.encode()),
        throwsA(isA<BackupFormatException>()));
  });

  group('backups', () {
    late ProviderContainer container;

    setUp(() {
      container = ProviderContainer(overrides: [
        appStorageProvider.overrideWithValue(AppStorage.inMemory()),
        appVersionProvider.overrideWithValue('1.36.0 (82)'),
        backupFilesProvider.overrideWithValue(FakeBackupFiles()),
      ]);
      addTearDown(container.dispose);
    });

    Backup backupWith(List<Subscription> subs) => Backup(
          createdAt: DateTime(2026, 10, 19),
          appVersion: '1.36.0 (82)',
          notes: const [],
          shopItems: const [],
          subscriptions: SubscriptionBook(subs),
        );

    PlainPick read(Backup backup) => container
        .read(backupImporterProvider)
        .read(Uint8List.fromList(utf8.encode(backup.encode()))) as PlainPick;

    test('restored whole, and Undo', () async {
      container.read(subscriptionsProvider.notifier).save(claude(name: 'Here'));
      final importer = container.read(backupImporterProvider);
      final undo = await importer.restore(read(backupWith([
        claude(),
        Subscription(id: 's2', name: 'Grok'),
      ])).backup);
      expect(
          container
              .read(subscriptionsProvider)
              .subscriptions
              .map((s) => s.name),
          ['Claude', 'Grok']);
      await importer.undo(undo!);
      expect(container.read(subscriptionsProvider).subscriptions.single.name,
          'Here');
    });

    test('part of a backup: the ones picked; one here already: a copy',
        () async {
      container.read(subscriptionsProvider.notifier).save(claude(name: 'Here'));
      final importer = container.read(backupImporterProvider);
      final pick = read(backupWith([
        claude(),
        Subscription(id: 's2', name: 'Grok'),
      ]));
      expect(pick.backup.subscriptions.map((s) => s.name), ['Claude', 'Grok']);
      final done = await importer.restorePart(pick.backup, {
        BackupPart.subscriptions: {'s1'},
      });
      expect(done!.added, 1);
      expect(done.copies, 1);
      final names = container
          .read(subscriptionsProvider)
          .subscriptions
          .map((s) => s.name);
      expect(names, ['Here', 'Claude (Copy)']);
    });
  });

  group('their notifications, planned', () {
    late ProviderContainer container;
    late FakeReminderScheduler scheduler;

    setUp(() {
      scheduler = FakeReminderScheduler();
      container = ProviderContainer(overrides: [
        appStorageProvider.overrideWithValue(AppStorage.inMemory()),
        reminderSchedulerProvider.overrideWithValue(scheduler),
        clockProvider.overrideWithValue(() => DateTime(2026, 10, 19, 12)),
      ]);
      addTearDown(container.dispose);
    });

    List<Reminder> ours() => [
          for (final r in scheduler.scheduled)
            if (r.kind == ReminderKind.subscriptions) r,
        ];

    test('a change plans them again; off, none; their page\'s', () async {
      container.read(reminderPlannerProvider);
      container.read(subscriptionsProvider.notifier).save(claude());
      await container.read(reminderPlannerProvider).refresh();
      expect(ours().single.title, 'Claude');
      expect(ours().single.at, DateTime(2026, 10, 25, 9));
      expect(pageOf(ReminderKind.subscriptions), NotifyPage.subscriptions);

      container
          .read(preferencesProvider.notifier)
          .setSubscriptionsReminders(false);
      await container.read(reminderPlannerProvider).refresh();
      expect(ours(), isEmpty);
      container
          .read(preferencesProvider.notifier)
          .setSubscriptionsReminders(true);
      container
          .read(preferencesProvider.notifier)
          .pauseSubscriptionsUntil(DateTime(2026, 10, 30));
      await container.read(reminderPlannerProvider).refresh();
      expect(ours(), isEmpty);
    });
  });
}
