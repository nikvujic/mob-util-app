import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:the_app/core/app_info.dart';
import 'package:the_app/core/crypto.dart';
import 'package:the_app/data/app_storage.dart';
import 'package:the_app/data/backup.dart';
import 'package:the_app/data/backup_files.dart';
import 'package:the_app/models/note.dart';
import 'package:the_app/models/shop_item.dart';
import 'package:the_app/providers/backup_provider.dart';
import 'package:the_app/providers/notes_provider.dart';
import 'package:the_app/providers/shop_provider.dart';

import '../helpers.dart';

void main() {
  late FakeBackupFiles files;

  ProviderContainer containerWith(AppStorage storage) {
    final container = ProviderContainer(
      overrides: [
        appStorageProvider.overrideWithValue(storage),
        appVersionProvider.overrideWithValue('0.10.0 (11)'),
        backupFilesProvider.overrideWithValue(files),
      ],
    );
    addTearDown(container.dispose);
    return container;
  }

  setUp(() => files = FakeBackupFiles());

  final backup = Backup(
    createdAt: DateTime(2026, 10, 8, 9, 30),
    appVersion: '0.9.0 (10)',
    notes: [
      Note(
        id: 'b1',
        title: 'From backup',
        content: 'restored',
        createdAt: DateTime(2026, 1, 1),
        modifiedAt: DateTime(2026, 1, 2),
      ),
    ],
    shopItems: const [ShopItem(id: 'i1', name: 'Coffee', toBuy: false)],
  );

  Uint8List bytesOf(String s) => Uint8List.fromList(utf8.encode(s));

  group('reading', () {
    late BackupImporter importer;
    setUp(() {
      importer =
          containerWith(AppStorage.inMemory()).read(backupImporterProvider);
    });

    test('plain and encrypted files', () async {
      final plain = importer.read(bytesOf(backup.encode())) as PlainPick;
      expect(plain.backup.noteCount, 1);
      expect(plain.backup.shopItemCount, 1);
      expect(plain.backup.createdAt.isAtSameMomentAs(backup.createdAt), isTrue);

      final key = await PasswordKey.derive(
        'pw',
        KdfParams(
          memoryKiB: 64,
          iterations: 1,
          parallelism: 1,
          salt: KdfParams.generate().salt,
        ),
      );
      final encrypted = importer.read(
        bytesOf(await backup.encodeEncrypted(key)),
      ) as EncryptedPick;
      expect(await encrypted.unlock('wrong'), isNull);
      expect((await encrypted.unlock('pw'))!.noteCount, 1);
    });

    test('rejects binary and oversized files without decoding them', () {
      final notAText = Uint8List.fromList([0xff, 0xfe, 0x00, 0xc3]);
      expect(() => importer.read(notAText), throwsA(isA<ImportException>()));

      final huge = Uint8List(BackupImporter.maxFileBytes + 1);
      expect(() => importer.read(huge), throwsA(isA<ImportException>()));
    });

    test('pick returns null when cancelled, else the parsed file', () async {
      expect(await importer.pick(), isNull);

      files.toPick = bytesOf(backup.encode());
      expect(await importer.pick(), isA<PlainPick>());

      files.toPick = bytesOf('{"hello": "world"}');
      expect(
        importer.pick(),
        throwsA(
          isA<ImportException>().having(
            (e) => e.message,
            'message',
            'This file is not a backup.',
          ),
        ),
      );
    });
  });

  group('restoring', () {
    late ProviderContainer container;
    setUp(() {
      container = containerWith(AppStorage.inMemory());
      container.read(notesProvider.notifier).addNote(title: 'Current');
      container.read(shopProvider.notifier).addItem('Bread');
    });

    BackupImporter importer() => container.read(backupImporterProvider);
    RestorableBackup restorable() =>
        (importer().read(bytesOf(backup.encode())) as PlainPick).backup;
    List<String> noteTitles() =>
        container.read(notesProvider).map((n) => n.title).toList();
    List<String> itemNames() =>
        container.read(shopProvider).map((i) => i.name).toList();

    test('replaces all notes and shop items', () async {
      await importer().restore(restorable());

      expect(container.read(notesProvider).single.toJson(),
          backup.notes.single.toJson());
      expect(itemNames(), ['Coffee']);
    });

    test('can be undone', () async {
      final undo = await importer().restore(restorable());
      await importer().undo(undo);

      expect(noteTitles(), ['Current']);
      expect(itemNames(), ['Bread']);
    });
  });

  test('export then import gives back exactly the same data', () async {
    final source = containerWith(AppStorage.inMemory());
    source.read(notesProvider.notifier)
      ..addNote(title: 'One', content: 'ćevapi 🥙')
      ..addNote(title: 'Two');
    source.read(shopProvider.notifier)
      ..addItem('Milk')
      ..addItem('Eggs');
    await source.read(backupExporterProvider).export();

    final target = containerWith(AppStorage.inMemory());
    final file = target
        .read(backupImporterProvider)
        .read(files.saved.single.bytes) as PlainPick;
    await target.read(backupImporterProvider).restore(file.backup);

    expect(
      target.read(notesProvider).map((n) => n.toJson()),
      source.read(notesProvider).map((n) => n.toJson()),
    );
    expect(
      target.read(shopProvider).map((i) => i.toJson()),
      source.read(shopProvider).map((i) => i.toJson()),
    );
  });

  test('a restore is on disk when it completes', () async {
    final dir = Directory.systemTemp.createTempSync('import_test');
    addTearDown(() => dir.deleteSync(recursive: true));

    final container = containerWith(await AppStorage.open(directory: dir));
    final importer = container.read(backupImporterProvider);
    await importer.restore(
      (importer.read(bytesOf(backup.encode())) as PlainPick).backup,
    );

    final reopened = await AppStorage.open(directory: dir);
    expect(reopened.initialNotes.single.title, 'From backup');
    expect(reopened.initialShopItems.single.name, 'Coffee');
  });
}
