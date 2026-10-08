// Every data format the app has ever written must stay readable, so an
// update can never lose a user's data. The files in test/fixtures/ are
// frozen copies of real output; see test/fixtures/README.md.
import 'dart:convert';
import 'dart:io';

import 'package:cryptography/cryptography.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:the_app/data/app_storage.dart';
import 'package:the_app/data/backup.dart';

void main() {
  const password = 'fixture password';

  /// A scratch copy of a fixture folder (loading may move files aside).
  Directory copyOf(String path) {
    final dir = Directory.systemTemp.createTempSync('compat');
    addTearDown(() => dir.deleteSync(recursive: true));
    for (final f in Directory(path).listSync().whereType<File>()) {
      f.copySync('${dir.path}/${f.uri.pathSegments.last}');
    }
    return dir;
  }

  group('v1', () {
    test('app data loads completely', () async {
      final storage = await AppStorage.open(
        directory: copyOf('test/fixtures/v1/storage'),
      );

      final notes = storage.initialNotes;
      expect(notes.map((n) => n.title), ['Groceries', 'Untitled']);
      expect(notes.first.content, 'milk\neggs\nčaj, ćevapi 🥙');
      expect(notes.first.modifiedAt, DateTime.utc(2026, 10, 8, 7, 30));
      // Local time without a zone, as the app writes it.
      expect(notes.last.modifiedAt, DateTime(2026, 10, 7, 21, 16, 30, 500));

      expect(
        storage.initialShopItems.map((i) => '${i.name}:${i.toBuy}'),
        ['Milk:true', 'Coffee:false'],
      );

      final verifier = storage.initialMasterPassword!;
      expect(await verifier.unlock(password), isNotNull);
      expect(await verifier.unlock('wrong'), isNull);
      // v1 master passwords had no data key; it's added on first unlock.
      expect(verifier.hasDataKey, isFalse);
    });

    test('nothing was moved aside as unreadable', () async {
      final dir = copyOf('test/fixtures/v1/storage');
      await AppStorage.open(directory: dir);
      final names = dir.listSync().map((f) => f.uri.pathSegments.last);
      expect(names.where((n) => n.contains('corrupt')), isEmpty);
    });

    test('plain backup restores', () {
      final file = BackupFile.parse(
        File('test/fixtures/v1/backup-plain.json').readAsStringSync(),
      ) as PlainBackupFile;
      expect(file.backup.notes, hasLength(2));
      expect(file.backup.shopItems, hasLength(2));
    });

    test('encrypted backup opens with its password', () async {
      final file = BackupFile.parse(
        File('test/fixtures/v1/backup-encrypted.json').readAsStringSync(),
      ) as EncryptedBackupFile;
      final backup = await file.open(password);
      expect(backup!.notes.first.title, 'Groceries');
      expect(await file.open('wrong'), isNull);
    });
  });

  test('a file from a newer format is kept aside, not misread', () async {
    final dir = Directory.systemTemp.createTempSync('compat_newer');
    addTearDown(() => dir.deleteSync(recursive: true));
    final newer =
        jsonEncode({'version': AppStorage.formatVersion + 1, 'notes': []});
    File('${dir.path}/notes.json').writeAsStringSync(newer);

    final storage = await AppStorage.open(directory: dir);

    expect(storage.initialNotes, isEmpty);
    final kept = dir
        .listSync()
        .whereType<File>()
        .singleWhere((f) => f.path.contains('notes.json.corrupt-'));
    expect(kept.readAsStringSync(), newer, reason: 'kept intact');
  });

  test('the fixtures are the frozen originals', () async {
    // Guards against "fixing" a fixture instead of the code: these are the
    // SHA-256 hashes of the files as first written.
    const expected = {
      'test/fixtures/v1/backup-encrypted.json':
          '2869f75b7b564146048f266de1ee33a77f30d71f97faba4e4a4abe3a5076aeb4',
      'test/fixtures/v1/backup-plain.json':
          'fa73019263647212a988a8a4f9c9aa00bd49f923e1b7248adf1cf6fff43b49f8',
      'test/fixtures/v1/storage/notes.json':
          '275102f2b322a18baca21c6a44f3ebc4332c01be0b3da0ce6ed4d8481f5e5f6e',
      'test/fixtures/v1/storage/security.json':
          '60a13aad885197272595c40c3ff4b9dec427abe0db9c9c47ba6fa9467c9522de',
      'test/fixtures/v1/storage/shop.json':
          '7188622d7ea03d5c34f3215938067caf037f3085d17d252c173585420e4b0c6b',
    };
    for (final MapEntry(key: path, value: hash) in expected.entries) {
      final digest = await Sha256().hash(File(path).readAsBytesSync());
      final hex =
          digest.bytes.map((b) => b.toRadixString(16).padLeft(2, '0')).join();
      expect(hex, hash, reason: '$path was changed');
    }
  });
}
