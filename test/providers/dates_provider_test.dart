import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:the_app/core/app_info.dart';
import 'package:the_app/data/app_storage.dart';
import 'package:the_app/data/backup.dart';
import 'package:the_app/data/backup_files.dart';
import 'package:the_app/models/date_entry.dart';
import 'package:the_app/models/hub_tool.dart';
import 'package:the_app/providers/backup_provider.dart';
import 'package:the_app/providers/dates_provider.dart';
import 'package:the_app/providers/section_data_provider.dart';

import '../helpers.dart';

/// Birthdays & dates' store (Round 57).
void main() {
  DateEntry ana({String title = 'Ana'}) => DateEntry(
        id: 'd1',
        title: title,
        type: DateType.birthday,
        day: 24,
        month: 10,
        year: 1995,
      );

  test('saved as it goes: added once, then changed; deleted with Undo', () {
    final dates = DatesNotifier(AppStorage.inMemory());
    dates.save(ana());
    dates.save(ana(title: 'Ana B.'));
    expect(dates.state.dates.single.title, 'Ana B.');
    final before = dates.delete('d1');
    expect(dates.state.dates, isEmpty);
    dates.replaceAll(before);
    expect(dates.state.dates, hasLength(1), reason: 'Undo');
  });

  test('saved to dates.json and loaded back', () async {
    final dir = Directory.systemTemp.createTempSync('dates');
    addTearDown(() => dir.deleteSync(recursive: true));
    final storage = await AppStorage.open(directory: dir);
    DatesNotifier(storage).save(ana());
    await storage.flush();
    expect(File('${dir.path}/dates.json').readAsStringSync(),
        contains('"version":4'));
    final again = await AppStorage.open(directory: dir);
    expect(again.initialDates.dates.single.toJson(), ana().toJson());
  });

  test('a Hub page: lockable, counted and cleared (Clear data), in backups',
      () {
    final container = ProviderContainer(overrides: [
      appVersionProvider.overrideWithValue('1.18.0 (61)'),
      appStorageProvider.overrideWithValue(
          AppStorage.inMemory(initialDates: DateBook([ana()]))),
    ]);
    addTearDown(container.dispose);
    expect(HubTool.dates.lockable, isTrue);
    expect(HubTool.dates.clearable, isTrue);
    final snapshot = container.read(backupExporterProvider).snapshot();
    expect(Backup.decode(snapshot.encode()).dates.dates.single.id, 'd1');
    final data = container.read(sectionDataProvider);
    expect(data.countOf(HubTool.dates), 1);
    data.clearOf(HubTool.dates);
    expect(container.read(datesProvider).dates, isEmpty);
  });

  group('backups', () {
    late ProviderContainer container;

    setUp(() {
      container = ProviderContainer(overrides: [
        appStorageProvider.overrideWithValue(AppStorage.inMemory()),
        appVersionProvider.overrideWithValue('1.18.0 (61)'),
        backupFilesProvider.overrideWithValue(FakeBackupFiles()),
      ]);
      addTearDown(container.dispose);
    });

    Backup backupWith(List<DateEntry> dates) => Backup(
          createdAt: DateTime(2026, 10, 15),
          appVersion: '1.18.0 (61)',
          notes: const [],
          shopItems: const [],
          dates: DateBook(dates),
        );

    PlainPick read(Backup backup) => container
        .read(backupImporterProvider)
        .read(Uint8List.fromList(utf8.encode(backup.encode()))) as PlainPick;

    test('restored whole, and Undo', () async {
      container.read(datesProvider.notifier).save(ana(title: 'Here'));
      final importer = container.read(backupImporterProvider);
      final undo = await importer.restore(read(backupWith([
        ana(),
        DateEntry(
            id: 'd2', title: 'Bo', type: DateType.event, day: 1, month: 1),
      ])).backup);
      expect(container.read(datesProvider).dates.map((d) => d.title),
          ['Ana', 'Bo']);
      await importer.undo(undo!);
      expect(container.read(datesProvider).dates.single.title, 'Here');
    });

    test('part of a backup: the dates picked; one here already: a copy',
        () async {
      container.read(datesProvider.notifier).save(ana(title: 'Here'));
      final importer = container.read(backupImporterProvider);
      final pick = read(backupWith([
        ana(),
        DateEntry(
            id: 'd2', title: 'Bo', type: DateType.event, day: 1, month: 1),
      ]));
      final done = await importer.restorePart(pick.backup, {
        BackupPart.dates: {'d1'},
      });
      expect(done!.added, 1);
      expect(done.copies, 1);
      final titles = container.read(datesProvider).dates.map((d) => d.title);
      expect(titles, ['Here', 'Ana (Copy)']);
      expect(container.read(datesProvider).dates.last.id, isNot('d1'));
    });
  });
}
