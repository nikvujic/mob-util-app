import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:the_app/core/app_info.dart';
import 'package:the_app/data/app_storage.dart';
import 'package:the_app/data/backup.dart';
import 'package:the_app/data/backup_files.dart';
import 'package:the_app/providers/backup_provider.dart';
import 'package:the_app/providers/notes_provider.dart';
import 'package:the_app/providers/shop_provider.dart';

import '../helpers.dart';

void main() {
  final now = DateTime(2026, 10, 8, 9, 5);
  late FakeBackupFiles files;
  late ProviderContainer container;

  setUp(() {
    files = FakeBackupFiles();
    container = ProviderContainer(
      overrides: [
        appStorageProvider.overrideWithValue(AppStorage.inMemory()),
        appVersionProvider.overrideWithValue('0.7.0 (8)'),
        backupFilesProvider.overrideWithValue(files),
        backupExporterProvider.overrideWith(
          (ref) => BackupExporter(ref, now: () => now),
        ),
      ],
    );
    addTearDown(container.dispose);

    container.read(notesProvider.notifier)
      ..addNote(title: 'First', content: 'one')
      ..addNote(title: 'Second');
    container.read(shopProvider.notifier)
      ..addItem('Milk')
      ..addItem('Eggs');
  });

  BackupExporter exporter() => container.read(backupExporterProvider);

  test('saves everything the app holds, in order', () async {
    expect(await exporter().export(), ExportResult.saved);

    final file = files.saved.single;
    expect(file.fileName, 'the-app-backup-2026-10-08-0905.json');

    final backup = Backup.decode(utf8.decode(file.bytes));
    expect(backup.appVersion, '0.7.0 (8)');
    expect(backup.createdAt.isAtSameMomentAs(now), isTrue);
    expect(backup.notes.map((n) => n.toJson()),
        container.read(notesProvider).map((n) => n.toJson()));
    expect(backup.shopItems.map((i) => i.toJson()),
        container.read(shopProvider).map((i) => i.toJson()));
  });

  test('reports a cancelled save dialog', () async {
    files.cancel = true;
    expect(await exporter().export(), ExportResult.cancelled);
    expect(files.saved, isEmpty);
  });

  test('passes save errors on to the caller', () async {
    files.error = Exception('disk full');
    expect(exporter().export(), throwsException);
  });

  test('does not change any data', () async {
    final notes = container.read(notesProvider);
    final shop = container.read(shopProvider);
    await exporter().export();
    expect(identical(container.read(notesProvider), notes), isTrue);
    expect(identical(container.read(shopProvider), shop), isTrue);
  });
}
