import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:the_app/core/app_info.dart';
import 'package:the_app/core/crypto.dart';
import 'package:the_app/data/app_storage.dart';
import 'package:the_app/data/backup_files.dart';
import 'package:the_app/data/document_files.dart';
import 'package:the_app/models/document_item.dart';
import 'package:the_app/models/hub_tool.dart';
import 'package:the_app/models/preferences.dart';
import 'package:the_app/providers/backup_provider.dart';
import 'package:the_app/providers/document_alerts_provider.dart';
import 'package:the_app/providers/documents_provider.dart';
import 'package:the_app/providers/section_data_provider.dart';
import 'package:the_app/providers/section_locks_provider.dart';
import 'package:the_app/providers/security_provider.dart';
import 'package:the_app/providers/session_provider.dart';

import '../helpers.dart';

/// Locking Documents encrypts them (spec: locking and encryption): with
/// real files, the list and every picture sealed with the master
/// password's data key, nothing readable while locked, opened again with
/// it; a run cut short finished later; backups locked, restored under
/// the same or another password; the password removed opens them.
void main() {
  late FakeBackupFiles files;
  setUp(() => files = FakeBackupFiles());

  Directory temp() {
    final dir = Directory.systemTemp.createTempSync('doclock');
    addTearDown(() => dir.deleteSync(recursive: true));
    return dir;
  }

  /// A phone on [dir]'s storage, its master password [password] set
  /// (and the app unlocked) if given.
  Future<ProviderContainer> phone(Directory dir, {String? password}) async {
    final storage = await AppStorage.open(directory: dir);
    final c = ProviderContainer(overrides: [
      appStorageProvider.overrideWithValue(storage),
      appVersionProvider.overrideWithValue('2.9.0 (148)'),
      backupFilesProvider.overrideWithValue(files),
    ]);
    addTearDown(c.dispose);
    c.read(documentsProvider);
    if (password != null) {
      if (c.read(securityProvider) == null) {
        await c.read(securityProvider.notifier).setPassword(password);
      }
      await c.read(sessionProvider.notifier).unlock(password);
    }
    return c;
  }

  DocumentsNotifier docs(ProviderContainer c) =>
      c.read(documentsProvider.notifier);

  /// Lets the notifier's work in the background finish.
  Future<void> settle(ProviderContainer c) async {
    for (var i = 0; i < 5; i++) {
      await docs(c).saved;
      await docs(c).reconcile();
      await Future<void>.delayed(const Duration(milliseconds: 5));
    }
    await c.read(appStorageProvider).flush();
  }

  final photo = Uint8List.fromList(List.generate(4000, (i) => (i * 7) % 256));

  /// The bytes of [needle] somewhere in [hay].
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

  /// A passport with two pictures and a reminder, on [c].
  Future<List<String>> passport(ProviderContainer c) async {
    final a = await docs(c).addPicture(photo);
    final b = await docs(c).addPicture([1, 2, 3, 4, 5]);
    docs(c).save(DocItem(
      id: 'p',
      kind: DocKind.document,
      name: 'Pasoš Marka',
      note: 'secret note',
      pictures: [DocPicture(a), DocPicture(b)],
      expires: DateTime(2031, 3, 3),
      remind: DocRemind.sixMonths,
      createdAt: DateTime(2026, 11, 23),
    ));
    await settle(c);
    return [a, b];
  }

  File documentsJson(Directory dir) => File('${dir.path}/documents.json');
  List<File> pictureFiles(Directory dir) =>
      Directory('${dir.path}/documents').listSync().whereType<File>().toList();

  test(
      'locked: the list and every picture sealed on disk, nothing readable; '
      'opened again with the password; unlocked: all plain again', () async {
    final dir = temp();
    var c = await phone(dir, password: 'master one');
    final ids = await passport(c);
    expect(documentsJson(dir).readAsStringSync(), contains('Pasoš'));

    c.read(pageLocksProvider.notifier).lock(HubTool.documents);
    await settle(c);
    expect(docs(c).encrypted, isTrue);
    expect(c.read(documentsProvider).items.single.name, 'Pasoš Marka',
        reason: 'still open while unlocked');
    final json = documentsJson(dir).readAsStringSync();
    expect(json, isNot(contains('Pasoš')));
    expect(json, isNot(contains('secret')));
    expect(jsonDecode(json), containsPair('sealed', isA<Map>()));
    for (final f in pictureFiles(dir)) {
      final bytes = f.readAsBytesSync();
      expect(DocumentFiles.isSealed(bytes), isTrue, reason: f.path);
      expect(hasRun(bytes, photo.sublist(100, 140)), isFalse);
    }

    // The app closed and opened again: locked, nothing open.
    c.dispose();
    c = await phone(dir);
    expect(docs(c).isOpen, isFalse);
    expect(c.read(documentsProvider).items, isEmpty);
    expect(c.read(sectionDataProvider).countOf(HubTool.documents), 1,
        reason: 'counted from its index');
    expect(await docs(c).readPicture(ids.first), isNull);
    // Clean-up while locked keeps every picture.
    await docs(c).cleanUp();
    expect(pictureFiles(dir), hasLength(2));
    // Its reminder still planned, without its name.
    final reminders = planDocumentReminders(
      now: DateTime(2030, 9, 1),
      book: docs(c).forReminders,
      preferences: const Preferences(),
      days: 14,
      hideNames: true,
    );
    expect(reminders.single.body,
        'A document expires in 6 months'.replaceFirst('6 months', '182 days'));

    // Unlocked: open again.
    await c.read(sessionProvider.notifier).unlock('master one');
    await settle(c);
    expect(c.read(documentsProvider).items.single.note, 'secret note');
    expect(await docs(c).readPicture(ids.first), photo);
    // Edited while locked and open: saved sealed.
    docs(c).save(c.read(documentsProvider).items.single.copyWith(name: 'ID'));
    await settle(c);
    expect(documentsJson(dir).readAsStringSync(), isNot(contains('"ID"')));

    // The lock off: everything plain again.
    c.read(pageLocksProvider.notifier).unlock(HubTool.documents);
    await settle(c);
    expect(docs(c).encrypted, isFalse);
    expect(documentsJson(dir).readAsStringSync(), contains('"ID"'));
    for (final f in pictureFiles(dir)) {
      expect(DocumentFiles.isSealed(f.readAsBytesSync()), isFalse);
    }
    expect(File('${dir.path}/documents/${ids.first}').readAsBytesSync(), photo);
  });

  test(
      'a lock cut short (some pictures sealed, some not): read fine, and '
      'finished the next time the app is unlocked', () async {
    final dir = temp();
    var c = await phone(dir, password: 'master one');
    final ids = await passport(c);
    c.read(pageLocksProvider.notifier).lock(HubTool.documents);
    await settle(c);
    final key = c.read(sessionProvider)!.dataKey;
    // As if the app had stopped after the list and one picture.
    final second = File('${dir.path}/documents/${ids[1]}');
    second.writeAsBytesSync(
        await DocumentFiles.openBytes(second.readAsBytesSync(), key));
    File('${dir.path}/documents/${ids[1]}.tmp').writeAsBytesSync([9]);
    c.dispose();

    c = await phone(dir, password: 'master one');
    await settle(c);
    expect(await docs(c).readPicture(ids[1]), [1, 2, 3, 4, 5]);
    for (final f in pictureFiles(dir)) {
      expect(DocumentFiles.isSealed(f.readAsBytesSync()), isTrue,
          reason: '${f.path} sealed now');
    }
    expect(pictureFiles(dir), hasLength(2), reason: 'the .tmp gone');
  });

  test('a new picture while locked is sealed as it is stored', () async {
    final dir = temp();
    final c = await phone(dir, password: 'master one');
    c.read(pageLocksProvider.notifier).lock(HubTool.documents);
    await settle(c);
    final id = await docs(c).addPicture(photo);
    final stored = File('${dir.path}/documents/$id').readAsBytesSync();
    expect(DocumentFiles.isSealed(stored), isTrue);
    expect(await docs(c).readPicture(id), photo);
  });

  test(
      'a picture stored, its document not saved yet: kept by a cleanup '
      '(once opened, a cleanup ran while one was written)', () async {
    final dir = temp();
    final c = await phone(dir, password: 'master one');
    await settle(c);
    final id = await docs(c).addPicture(photo);
    await docs(c).cleanUp();
    expect(File('${dir.path}/documents/$id').existsSync(), isTrue);
    // Saved, then taken out: no longer kept.
    docs(c).save(DocItem(
      id: 'p',
      kind: DocKind.document,
      name: 'Card',
      pictures: [DocPicture(id)],
      createdAt: DateTime(2026, 11, 27),
    ));
    await docs(c).cleanUp();
    docs(c).save(DocItem(
      id: 'p',
      kind: DocKind.document,
      name: 'Card',
      createdAt: DateTime(2026, 11, 27),
    ));
    await docs(c).cleanUp();
    expect(File('${dir.path}/documents/$id').existsSync(), isFalse);
  });

  group('backups', () {
    Future<Uint8List> lockedBackup({bool encrypted = false}) async {
      final c = await phone(temp(), password: 'old phone');
      await passport(c);
      c.read(pageLocksProvider.notifier).lock(HubTool.documents);
      await settle(c);
      final exporter = c.read(backupExporterProvider);
      if (encrypted) {
        await exporter.exportEncrypted(c.read(sessionProvider)!.passwordKey);
      } else {
        await exporter.export();
      }
      return files.saved.last.bytes;
    }

    test('locked: sealed in it, with the master password record', () async {
      final bytes = await lockedBackup();
      final text = backupText(bytes);
      expect(text, contains('"documentsSealed"'));
      expect(text, contains('"masterPassword"'));
      expect(text, isNot(contains('Pasoš')));
      expect(hasRun(bytes, photo.sublist(100, 140)), isFalse);
    });

    test('restored on the same phone: open, and sealed there', () async {
      final dir = temp();
      final c = await phone(dir, password: 'old phone');
      await passport(c);
      c.read(pageLocksProvider.notifier).lock(HubTool.documents);
      await settle(c);
      await c.read(backupExporterProvider).export();
      docs(c).clearAll();
      await settle(c);
      expect(pictureFiles(dir), isEmpty);

      final importer = c.read(backupImporterProvider);
      final pick = importer.read(files.saved.last.bytes) as PlainPick;
      expect(await importer.restore(pick.backup), isNotNull);
      await settle(c);
      expect(c.read(documentsProvider).items.single.name, 'Pasoš Marka');
      for (final f in pictureFiles(dir)) {
        expect(DocumentFiles.isSealed(f.readAsBytesSync()), isTrue);
      }
    });

    test(
        'restored on another phone, another password: asks the backup\'s, '
        'then sealed again under this one\'s (or plain, unlocked)', () async {
      final bytes = await lockedBackup();
      // Locked here too, under another password.
      final dir = temp();
      final c = await phone(dir, password: 'new phone');
      c.read(pageLocksProvider.notifier).lock(HubTool.documents);
      await settle(c);
      final importer = c.read(backupImporterProvider);
      var asked = 0;
      Future<DataKey?> backupKey(PasswordVerifier record) async {
        asked++;
        final key = await record.unlock('old phone');
        return key == null ? null : record.unwrapDataKey(key);
      }

      // Cancelled: nothing changes.
      var pick = importer.read(bytes) as PlainPick;
      expect(await importer.restore(pick.backup, backupKey: (_) async => null),
          isNull);
      expect(c.read(documentsProvider).items, isEmpty);

      pick = importer.read(bytes) as PlainPick;
      expect(
          await importer.restore(pick.backup, backupKey: backupKey), isNotNull);
      expect(asked, 1);
      await settle(c);
      final restored = c.read(documentsProvider).items.single;
      expect(restored.name, 'Pasoš Marka');
      expect(await docs(c).readPicture(restored.pictures.first.id), photo);
      final ours = c.read(sessionProvider)!.dataKey;
      for (final f in pictureFiles(dir)) {
        final stored = f.readAsBytesSync();
        expect(DocumentFiles.isSealed(stored), isTrue);
        await DocumentFiles.openBytes(stored, ours); // this phone's key
      }

      // On a phone not locked: plain.
      final plainDir = temp();
      final p = await phone(plainDir, password: 'third phone');
      final other = p.read(backupImporterProvider);
      pick = other.read(bytes) as PlainPick;
      await other.restore(pick.backup, backupKey: backupKey);
      await settle(p);
      expect(p.read(documentsProvider).items.single.name, 'Pasoš Marka');
      for (final f in pictureFiles(plainDir)) {
        expect(DocumentFiles.isSealed(f.readAsBytesSync()), isFalse);
      }
    });

    test('an encrypted backup opens its locked documents with its password',
        () async {
      final bytes = await lockedBackup(encrypted: true);
      final c = await phone(temp(), password: 'new phone');
      final importer = c.read(backupImporterProvider);
      final pick = importer.read(bytes) as EncryptedPick;
      final backup = (await pick.unlock('old phone'))!;
      expect(await importer.restore(backup), isNotNull,
          reason: 'no prompt: the file\'s password opens them');
      await settle(c);
      expect(c.read(documentsProvider).items.single.name, 'Pasoš Marka');
    });

    test('part of it: locked documents opened to pick from, then added',
        () async {
      final bytes = await lockedBackup();
      final c = await phone(temp(), password: 'new phone');
      final importer = c.read(backupImporterProvider);
      final pick = importer.read(bytes) as PlainPick;
      expect(pick.backup.documentsLocked, isTrue);
      expect(pick.backup.documents, isEmpty);
      expect(
          await importer.openDocuments(pick.backup,
              backupKey: (record) async =>
                  record.unwrapDataKey((await record.unlock('old phone'))!)),
          isTrue);
      expect(pick.backup.documents.single.name, 'Pasoš Marka');
      final done = await importer.restorePart(pick.backup, {
        BackupPart.documents: {'p'},
      });
      expect(done!.added, 1);
      await settle(c);
      final d = c.read(documentsProvider).items.single;
      expect(await docs(c).readPicture(d.pictures.first.id), photo);
    });

    test('a wrong password for them says so', () async {
      final bytes = await lockedBackup();
      final c = await phone(temp(), password: 'new phone');
      final importer = c.read(backupImporterProvider);
      final pick = importer.read(bytes) as PlainPick;
      // Another key: doesn't open.
      await expectLater(
          importer.openDocuments(pick.backup,
              backupKey: (_) async => DataKey.generate()),
          throwsA(isA<ImportException>()));
    });
  });

  test('the master password removed: Documents opened first, lock gone',
      () async {
    final dir = temp();
    final c = await phone(dir, password: 'master one');
    final ids = await passport(c);
    c.read(pageLocksProvider.notifier).lock(HubTool.documents);
    await settle(c);
    c.read(sessionProvider.notifier).lock();
    await settle(c);
    await c.read(securityProvider.notifier).removePassword('master one');
    await settle(c);
    expect(c.read(securityProvider), isNull);
    expect(c.read(pageLocksProvider), isEmpty);
    expect(docs(c).encrypted, isFalse);
    expect(c.read(documentsProvider).items.single.name, 'Pasoš Marka');
    expect(File('${dir.path}/documents/${ids.first}').readAsBytesSync(), photo);
    expect(documentsJson(dir).readAsStringSync(), contains('Pasoš'));
  });
}
