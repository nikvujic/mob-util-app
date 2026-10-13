import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:the_app/core/app_info.dart';
import 'package:the_app/data/app_storage.dart';
import 'package:the_app/data/backup.dart';
import 'package:the_app/data/backup_files.dart';
import 'package:the_app/models/pip_life.dart';
import 'package:the_app/providers/backup_provider.dart';
import 'package:the_app/providers/pip_life_provider.dart';

import '../helpers.dart';

/// Pip, the pet (Round 34): hatched once, his age from his birthday.
void main() {
  test('an egg until hatched; hatched once, on that day', () {
    final pip = PipLifeNotifier(AppStorage.inMemory());
    expect(pip.state.hatched, isFalse);
    expect(pip.state.ageOn(DateTime(2026, 10, 14)), isNull);
    pip.hatch(DateTime(2026, 10, 14, 21, 30));
    pip.hatch(DateTime(2026, 10, 20)); // only once
    expect(pip.state.born, DateTime(2026, 10, 14, 21, 30));
    expect(pip.state.name, 'Pip');
  });

  test('his age in days: the day he hatched is day 1', () {
    final pip = PipLife(born: DateTime(2026, 10, 14, 23, 50));
    expect(pip.ageOn(DateTime(2026, 10, 14, 23, 59)), 1);
    expect(pip.ageOn(DateTime(2026, 10, 15, 0, 1)), 2);
    expect(pip.ageOn(DateTime(2027, 10, 14, 12)), 366);
    // Across a clock change (late October in Europe): still whole days.
    expect(
        PipLife(born: DateTime(2026, 10, 24, 12))
            .ageOn(DateTime(2026, 10, 26, 1)),
        3);
    expect(PipLife.ageText(1), '1 DAY');
    expect(PipLife.ageText(12), '12 DAYS');
  });

  test('renamed: trimmed, at most 12 letters; blank keeps his', () {
    final pip = PipLifeNotifier(AppStorage.inMemory());
    pip.rename('  Bip  ');
    expect(pip.state.name, 'Bip');
    pip.rename('   ');
    expect(pip.state.name, 'Bip');
    pip.rename('Abcdefghijklmnop');
    expect(pip.state.name, 'Abcdefghijkl');
  });

  group('in backups', () {
    late ProviderContainer container;
    setUp(() {
      container = ProviderContainer(overrides: [
        appStorageProvider.overrideWithValue(AppStorage.inMemory()),
        appVersionProvider.overrideWithValue('1'),
        backupFilesProvider.overrideWithValue(FakeBackupFiles()),
      ]);
      addTearDown(container.dispose);
    });

    RestorableBackup open(Backup b) => (container
            .read(backupImporterProvider)
            .read(Uint8List.fromList(utf8.encode(b.encode()))) as PlainPick)
        .backup;

    test('restored with his birthday (so his real age), undone too', () async {
      container.read(pipLifeProvider.notifier).hatch(DateTime(2026, 10, 20));
      final saved = Backup(
        createdAt: DateTime(2026, 10, 21),
        appVersion: '1',
        notes: const [],
        shopItems: const [],
        pip: PipLife(born: DateTime(2026, 1, 1), name: 'Old'),
      );
      final undo =
          await container.read(backupImporterProvider).restore(open(saved));
      expect(container.read(pipLifeProvider).born, DateTime(2026, 1, 1));
      expect(container.read(pipLifeProvider).name, 'Old');
      await container.read(backupImporterProvider).undo(undo!);
      expect(container.read(pipLifeProvider).born, DateTime(2026, 10, 20));
    });

    test('a backup from before him leaves him as he is', () async {
      container.read(pipLifeProvider.notifier).hatch(DateTime(2026, 10, 20));
      await container.read(backupImporterProvider).restore(open(Backup(
            createdAt: DateTime(2026, 10, 21),
            appVersion: '1',
            notes: const [],
            shopItems: const [],
          )));
      expect(container.read(pipLifeProvider).hatched, isTrue);
    });
  });
}
