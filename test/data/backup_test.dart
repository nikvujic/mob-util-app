import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:the_app/core/crypto.dart';
import 'package:the_app/data/backup.dart';
import 'package:the_app/models/note.dart';
import 'package:the_app/models/shop_item.dart';

void main() {
  final created = DateTime(2026, 10, 8, 9, 5);
  final backup = Backup(
    createdAt: created,
    appVersion: '0.7.0 (8)',
    notes: [
      Note(
        id: 'n1',
        title: 'Kupovina 🛒',
        content: 'mleko, jaja\nčaj, ćevapi',
        createdAt: DateTime(2026, 10, 1, 8),
        modifiedAt: DateTime(2026, 10, 7, 21, 30),
      ),
    ],
    shopItems: const [
      ShopItem(id: 's1', name: 'Milk'),
      ShopItem(id: 's2', name: 'Eggs', toBuy: false),
    ],
  );

  /// Decodes [json] (a map) and returns the error message, if any.
  String? errorFor(Object json) {
    try {
      Backup.decode(jsonEncode(json));
      return null;
    } on BackupFormatException catch (e) {
      return e.message;
    }
  }

  Map<String, dynamic> validJson() =>
      jsonDecode(backup.encode()) as Map<String, dynamic>;

  group('encode', () {
    test('writes the documented layout', () {
      final json = validJson();
      expect(json['format'], 'the-app-backup');
      expect(json['version'], Backup.version);
      expect(json['createdAt'], created.toUtc().toIso8601String());
      expect(json['appVersion'], '0.7.0 (8)');
      expect((json['data']['notes'] as List).single['title'], 'Kupovina 🛒');
      expect(json['data']['shopItems'], hasLength(2));
    });

    test('is human-readable (indented)', () {
      expect(backup.encode(), contains('\n  "format": "the-app-backup"'));
    });

    test('suggests a dated file name', () {
      expect(backup.fileName(), 'the-app-backup-2026-10-08-0905.json');
      expect(
        backup.fileName(encrypted: true),
        'the-app-backup-2026-10-08-0905-encrypted.json',
      );
    });
  });

  group('decode', () {
    test('round-trips everything, including non-ASCII text', () {
      // Through bytes, as when written to and read from a file.
      final bytes = utf8.encode(backup.encode());
      final decoded = Backup.decode(utf8.decode(bytes));
      expect(decoded.toJson(), backup.toJson());
      expect(decoded.notes.single.content, 'mleko, jaja\nčaj, ćevapi');
      expect(decoded.shopItems.map((i) => i.toBuy), [true, false]);
    });

    test('round-trips an empty backup', () {
      final empty = Backup(
        createdAt: created,
        appVersion: '1',
        notes: const [],
        shopItems: const [],
      );
      expect(Backup.decode(empty.encode()).toJson(), empty.toJson());
    });

    test('rejects files that are not backups', () {
      expect(
        () => Backup.decode('not json at all'),
        throwsA(isA<BackupFormatException>()),
      );
      expect(errorFor([1, 2, 3]), 'This file is not a backup.');
      expect(errorFor({'notes': []}), 'This file is not a backup.');
      expect(
        errorFor(validJson()..['format'] = 'other-app'),
        'This file is not a backup.',
      );
    });

    test('rejects backups from a newer app version', () {
      expect(
        errorFor(validJson()..['version'] = Backup.version + 1),
        contains('newer version of the app'),
      );
    });

    test('rejects damaged backups', () {
      const damaged = 'This backup is damaged.';
      expect(errorFor(validJson()..['version'] = 'one'), damaged);
      expect(errorFor(validJson()..['version'] = 0), damaged);
      expect(errorFor(validJson()..remove('data')), damaged);
      expect(errorFor(validJson()..['createdAt'] = 'yesterday'), damaged);

      final missingField = validJson();
      (missingField['data']['notes'] as List).first.remove('title');
      expect(errorFor(missingField), damaged);

      final duplicateNote = validJson();
      final notes = duplicateNote['data']['notes'] as List;
      notes.add(Map<String, dynamic>.from(notes.first as Map));
      expect(errorFor(duplicateNote), damaged, reason: 'duplicate note id');

      final duplicateItem = validJson();
      final items = duplicateItem['data']['shopItems'] as List;
      items.last['id'] = items.first['id'];
      expect(errorFor(duplicateItem), damaged, reason: 'duplicate item id');

      final wrongType = validJson();
      (wrongType['data']['shopItems'] as List).first['toBuy'] = 'yes';
      expect(errorFor(wrongType), damaged);
    });
  });

  group('encrypted', () {
    const password = 'master password';

    /// A key with cheap parameters (the real ones are tested in crypto).
    Future<PasswordKey> key([String pw = password]) => PasswordKey.derive(
          pw,
          KdfParams(
            memoryKiB: 64,
            iterations: 1,
            parallelism: 1,
            salt: KdfParams.generate().salt,
          ),
        );

    test('round-trips through BackupFile.parse with the password', () async {
      final source = await backup.encodeEncrypted(await key());

      final file = BackupFile.parse(source);
      expect(file, isA<EncryptedBackupFile>());
      expect(file.createdAt.isAtSameMomentAs(created), isTrue);

      final opened = await (file as EncryptedBackupFile).open(password);
      expect(opened!.toJson(), backup.toJson());
    });

    test('a wrong password opens nothing', () async {
      final file = BackupFile.parse(await backup.encodeEncrypted(await key()))
          as EncryptedBackupFile;
      expect(await file.open('wrong password'), isNull);
    });

    test('keeps only the header readable', () async {
      final source = await backup.encodeEncrypted(await key());
      expect(source, isNot(contains('Kupovina')));
      expect(source, isNot(contains('Milk')));
      expect(source, isNot(contains('"data"')));

      final json = jsonDecode(source) as Map<String, dynamic>;
      expect(json['format'], 'the-app-backup');
      expect(json['encrypted'], isTrue);
      expect(json['appVersion'], '0.7.0 (8)');
      expect(json['kdf']['algorithm'], 'argon2id');
    });

    test('detects tampering', () async {
      final json = jsonDecode(await backup.encodeEncrypted(await key()))
          as Map<String, dynamic>;
      final text = json['sealed']['cipherText'] as String;
      // Change one base64 character of the encrypted data.
      json['sealed']['cipherText'] =
          (text[0] == 'A' ? 'B' : 'A') + text.substring(1);

      final file = BackupFile.parse(jsonEncode(json)) as EncryptedBackupFile;
      expect(await file.open(password), isNull);
    });

    test('rejects damaged encryption headers', () async {
      final json = jsonDecode(await backup.encodeEncrypted(await key()))
          as Map<String, dynamic>;
      for (final damage in <void Function(Map<String, dynamic>)>[
        (j) => j.remove('kdf'),
        (j) => j['kdf'] = {'algorithm': 'md5'},
        (j) => j.remove('sealed'),
        (j) => j['sealed'] = {'cipher': 'rot13'},
      ]) {
        final copy = jsonDecode(jsonEncode(json)) as Map<String, dynamic>;
        damage(copy);
        expect(
          () => BackupFile.parse(jsonEncode(copy)),
          throwsA(isA<BackupFormatException>()),
        );
      }
    });

    test('plain decode refuses encrypted files', () async {
      final source = await backup.encodeEncrypted(await key());
      expect(
        () => Backup.decode(source),
        throwsA(
          isA<BackupFormatException>().having(
            (e) => e.message,
            'message',
            'This backup is encrypted.',
          ),
        ),
      );
    });

    test('BackupFile.parse reads plain files as plain', () {
      final file = BackupFile.parse(backup.encode());
      expect((file as PlainBackupFile).backup.toJson(), backup.toJson());
    });
  });
}
