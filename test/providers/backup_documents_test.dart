import 'dart:typed_data';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:the_app/core/app_info.dart';
import 'package:the_app/core/clock.dart';
import 'package:the_app/core/crypto.dart';
import 'package:the_app/data/app_storage.dart';
import 'package:the_app/data/backup.dart';
import 'package:the_app/data/backup_files.dart';
import 'package:the_app/data/backup_folder.dart';
import 'package:the_app/models/document_item.dart';
import 'package:the_app/providers/auto_backup_provider.dart';
import 'package:the_app/providers/backup_provider.dart';
import 'package:the_app/providers/documents_provider.dart';
import 'package:the_app/providers/preferences_provider.dart';

import '../helpers.dart';

/// Backups with the Documents page (spec: backups): one zip, the
/// pictures beside the document, plain or sealed; restored in full or in
/// part; the automatic backups' folder counted and kept.
void main() {
  late FakeBackupFiles files;
  late FakeBackupFolder folder;
  var now = DateTime(2026, 11, 23, 9, 5);

  ProviderContainer phone() {
    final container = ProviderContainer(overrides: [
      appStorageProvider.overrideWithValue(AppStorage.inMemory()),
      appVersionProvider.overrideWithValue('2.6.0 (145)'),
      backupFilesProvider.overrideWithValue(files),
      backupFolderProvider.overrideWithValue(folder),
      clockProvider.overrideWithValue(() => now),
    ]);
    addTearDown(container.dispose);
    return container;
  }

  setUp(() {
    files = FakeBackupFiles();
    folder = FakeBackupFolder(picks: (uri: 'content://tree/B', name: 'B'));
    now = DateTime(2026, 11, 23, 9, 5);
  });

  final picture = Uint8List.fromList(List.generate(3000, (i) => i % 256));

  /// A phone with a passport of two pictures and a library card.
  Future<ProviderContainer> withDocuments() async {
    final c = phone();
    final docs = c.read(documentsProvider.notifier);
    final a = await docs.addPicture(picture);
    final b = await docs.addPicture([7, 7, 7]);
    final code = await docs.addPicture([8, 8]);
    docs.save(DocItem(
      id: 'p',
      kind: DocKind.document,
      name: 'Passport',
      pictures: [DocPicture(a), DocPicture(b, turns: 2)],
      expires: DateTime(2031, 3, 3),
      createdAt: now,
    ));
    docs.save(DocItem(
      id: 'c',
      kind: DocKind.barcode,
      name: 'Library card',
      pictures: [DocPicture(code)],
      barcode: code,
      createdAt: now,
    ));
    return c;
  }

  Future<Map<String, Uint8List>> stored(ProviderContainer c) async {
    final f = c.read(documentsProvider.notifier).files;
    return {for (final id in await f.ids()) id: (await f.read(id))!};
  }

  test('export writes one zip: the document and every picture', () async {
    final old = await withDocuments();
    await old.read(backupExporterProvider).export();
    final saved = files.saved.single;
    expect(saved.fileName, matches(r'^the-app-backup-[0-9-]+\.zip$'));
    expect(BackupFile.isZip(saved.bytes), isTrue);
    expect(backupText(saved.bytes), contains('"Passport"'));
    final backup = (BackupFile.read(saved.bytes) as PlainBackupFile).backup;
    expect(backup.documents!.items.map((d) => d.name),
        ['Library card', 'Passport']);
    expect(backup.pictures, await stored(old));
  });

  test(
      'restored on a new phone: documents and pictures; Undo puts back '
      'what was there', () async {
    final old = await withDocuments();
    await old.read(backupExporterProvider).export();

    final fresh = phone();
    final docs = fresh.read(documentsProvider.notifier);
    final own = await docs.addPicture([1]);
    docs.save(DocItem(
        id: 'mine',
        kind: DocKind.receipt,
        name: 'Mine',
        pictures: [DocPicture(own)],
        createdAt: now));

    final importer = fresh.read(backupImporterProvider);
    final pick = importer.read(files.saved.single.bytes) as PlainPick;
    expect(pick.backup.documentCount, 2);
    final undo = (await importer.restore(pick.backup))!;
    expect(fresh.read(documentsProvider).items.map((d) => d.name),
        ['Library card', 'Passport']);
    final pictures = await stored(fresh);
    for (final MapEntry(:key, :value) in (await stored(old)).entries) {
      expect(pictures[key], value);
    }
    expect(pictures, contains(own), reason: 'kept for Undo');

    await importer.undo(undo);
    expect(fresh.read(documentsProvider).items.single.name, 'Mine');
    expect(await docs.readPicture(own), [1]);

    await docs.cleanUp();
    expect((await stored(fresh)).keys, [own],
        reason: "the backup's pictures, unused now, go on clean-up");
  });

  test('a backup from before Documents leaves them as they are', () async {
    final c = await withDocuments();
    final before = c.read(documentsProvider);
    final old = Backup(
        createdAt: now, appVersion: '2.5.4', notes: const [], shopItems: []);
    final importer = c.read(backupImporterProvider);
    final pick =
        importer.read(Uint8List.fromList(old.encode().codeUnits)) as PlainPick;
    await importer.restore(pick.backup);
    expect(c.read(documentsProvider), same(before));
  });

  test('encrypted: the pictures are sealed too, and open with the password',
      () async {
    final old = await withDocuments();
    final key = await PasswordKey.derive(
      'pw',
      KdfParams(
          memoryKiB: 64,
          iterations: 1,
          parallelism: 1,
          salt: KdfParams.generate().salt),
    );
    await old.read(backupExporterProvider).exportEncrypted(key);
    final bytes = files.saved.single.bytes;
    expect(files.saved.single.fileName, endsWith('-encrypted.zip'));
    // The picture's bytes appear nowhere in the file.
    final sample = picture.sublist(1000, 1032);
    bool hasRun(List<int> hay, List<int> needle) {
      outer:
      for (var i = 0; i + needle.length <= hay.length; i++) {
        for (var j = 0; j < needle.length; j++) {
          if (hay[i + j] != needle[j]) continue outer;
        }
        return true;
      }
      return false;
    }

    expect(hasRun(bytes, sample), isFalse);
    expect(backupText(bytes), isNot(contains('Passport')));

    final file = BackupFile.read(bytes) as EncryptedBackupFile;
    expect(await file.open('wrong'), isNull);
    final opened = (await file.open('pw'))!;
    expect(opened.pictures, await stored(old));
    expect(opened.documents!.size, 2);
  });

  test('a damaged or foreign zip is not a backup', () {
    final c = phone();
    final importer = c.read(backupImporterProvider);
    expect(() => importer.read(Uint8List.fromList([0x50, 0x4b, 3, 4, 1, 2])),
        throwsA(isA<ImportException>()));
  });

  test(
      'part of it: picked documents come with their pictures; one still '
      'here comes as a copy', () async {
    final old = await withDocuments();
    await old.read(backupExporterProvider).export();

    final here = phone();
    final importer = here.read(backupImporterProvider);
    var pick = importer.read(files.saved.single.bytes) as PlainPick;
    var done = (await importer.restorePart(pick.backup, {
      BackupPart.documents: {'p'},
    }))!;
    expect(done.added, 1);
    expect(here.read(documentsProvider).items.single.name, 'Passport');
    final passport = here.read(documentsProvider).items.single;
    expect(
        await here
            .read(documentsProvider.notifier)
            .readPicture(passport.pictures.first.id),
        picture);
    expect((await stored(here)).length, 2, reason: "the card's isn't wanted");

    pick = importer.read(files.saved.single.bytes) as PlainPick;
    done = (await importer.restorePart(pick.backup, {
      BackupPart.documents: {'p'},
    }))!;
    expect(done.copies, 1);
    expect(here.read(documentsProvider).items.map((d) => d.name),
        ['Passport (Copy)', 'Passport']);
  });

  group('automatic backups', () {
    test('a zip with the pictures; the folder counted for the chip', () async {
      final c = await withDocuments();
      final auto = c.read(autoBackupProvider);
      expect(await auto.pickFolder(), AutoBackupResult.written);
      expect(folder.files.keys.single, 'the-app-auto-2026-11-23-0905.zip');
      now = now.add(const Duration(days: 1));
      expect(await auto.run(), AutoBackupResult.written);

      final state = (await auto.folderState())!;
      expect(state.backups.map((b) => b.name), [
        'the-app-auto-2026-11-24-0905.zip',
        'the-app-auto-2026-11-23-0905.zip',
      ]);
      expect(state.pictures, 6, reason: '3 pictures in each');
      expect(state.bytes, folder.files.values.fold(0, (a, b) => a + b.length));
    });

    test('how many to keep: 1 to 14, fewer deletes the oldest', () async {
      final c = phone();
      final auto = c.read(autoBackupProvider);
      await auto.pickFolder();
      for (var i = 1; i < 5; i++) {
        now = now.add(const Duration(days: 1));
        await auto.run();
      }
      expect(folder.files, hasLength(5));
      await auto.setKeep(2);
      expect(c.read(preferencesProvider).autoBackupKeep, 2);
      expect(
          folder.files.keys,
          unorderedEquals([
            'the-app-auto-2026-11-27-0905.zip',
            'the-app-auto-2026-11-26-0905.zip',
          ]));
      await auto.setKeep(0);
      expect(c.read(preferencesProvider).autoBackupKeep, 1);
      await auto.setKeep(40);
      expect(c.read(preferencesProvider).autoBackupKeep, 14);
      now = now.add(const Duration(days: 1));
      await auto.run();
      expect(folder.written.last.keep, 14);
    });

    test("a backup that couldn't be written doesn't move the last time",
        () async {
      final c = phone();
      final auto = c.read(autoBackupProvider);
      await auto.pickFolder();
      final last = c.read(preferencesProvider).lastAutoBackupAt;
      folder.works = false;
      now = now.add(const Duration(days: 2));
      expect(await auto.run(), AutoBackupResult.failed);
      expect(c.read(preferencesProvider).lastAutoBackupAt, last);
      folder.works = true;
      expect(await auto.run(), AutoBackupResult.written,
          reason: 'it simply runs again');
    });
  });
}
