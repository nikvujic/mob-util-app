import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
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
      expect(json['version'], 1);
      expect(json['createdAt'], created.toUtc().toIso8601String());
      expect(json['appVersion'], '0.7.0 (8)');
      expect((json['data']['notes'] as List).single['title'], 'Kupovina 🛒');
      expect(json['data']['shopItems'], hasLength(2));
    });

    test('is human-readable (indented)', () {
      expect(backup.encode(), contains('\n  "format": "the-app-backup"'));
    });

    test('suggests a dated file name', () {
      expect(backup.fileName, 'the-app-backup-2026-10-08-0905.json');
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
        errorFor(validJson()..['version'] = 2),
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

      final wrongType = validJson();
      (wrongType['data']['shopItems'] as List).first['toBuy'] = 'yes';
      expect(errorFor(wrongType), damaged);
    });
  });
}
