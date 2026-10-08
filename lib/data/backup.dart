import 'dart:convert';

import 'package:the_app/models/note.dart';
import 'package:the_app/models/shop_item.dart';

/// Thrown when a backup file can't be read. [message] is shown to the user.
class BackupFormatException implements Exception {
  final String message;

  const BackupFormatException(this.message);

  @override
  String toString() => 'BackupFormatException: $message';
}

/// A snapshot of all app data, as written to (and read from) a backup file:
///
///     {
///       "format": "the-app-backup",
///       "version": 1,
///       "createdAt": "2026-10-08T07:30:00.000Z",
///       "appVersion": "0.7.0 (8)",
///       "data": { "notes": [...], "shopItems": [...] }
///     }
///
/// [version] goes up whenever the layout changes; [decode] must keep reading
/// every older version.
class Backup {
  static const format = 'the-app-backup';
  static const version = 1;

  final DateTime createdAt;
  final String appVersion;
  final List<Note> notes;
  final List<ShopItem> shopItems;

  const Backup({
    required this.createdAt,
    required this.appVersion,
    required this.notes,
    required this.shopItems,
  });

  /// Suggested file name, e.g. `the-app-backup-2026-10-08-0930.json`
  /// (local time, so it matches what the user sees).
  String get fileName {
    final t = createdAt.toLocal();
    String two(int n) => n.toString().padLeft(2, '0');
    return 'the-app-backup-${t.year}-${two(t.month)}-${two(t.day)}'
        '-${two(t.hour)}${two(t.minute)}.json';
  }

  Map<String, dynamic> toJson() => {
        'format': format,
        'version': version,
        'createdAt': createdAt.toUtc().toIso8601String(),
        'appVersion': appVersion,
        'data': {
          'notes': [for (final n in notes) n.toJson()],
          'shopItems': [for (final i in shopItems) i.toJson()],
        },
      };

  /// The file contents: indented JSON, readable in any text editor.
  String encode() => const JsonEncoder.withIndent('  ').convert(toJson());

  /// Reads a backup file. Throws [BackupFormatException] if [source] is not
  /// a backup this app can read.
  static Backup decode(String source) {
    final Object? json;
    try {
      json = jsonDecode(source);
    } on FormatException {
      throw const BackupFormatException('This file is not a backup.');
    }
    if (json is! Map<String, dynamic> || json['format'] != format) {
      throw const BackupFormatException('This file is not a backup.');
    }
    final fileVersion = json['version'];
    if (fileVersion is! int || fileVersion < 1) {
      throw const BackupFormatException('This backup is damaged.');
    }
    if (fileVersion > version) {
      throw const BackupFormatException(
        'This backup was made by a newer version of the app. '
        'Update the app to restore it.',
      );
    }
    try {
      final data = json['data'] as Map<String, dynamic>;
      return Backup(
        createdAt: DateTime.parse(json['createdAt'] as String),
        appVersion: json['appVersion'] as String,
        notes: [
          for (final n in data['notes'] as List<dynamic>)
            Note.fromJson(n as Map<String, dynamic>),
        ],
        shopItems: [
          for (final i in data['shopItems'] as List<dynamic>)
            ShopItem.fromJson(i as Map<String, dynamic>),
        ],
      );
    } on Object {
      // Wrong types, missing fields, bad dates: all mean a damaged file.
      throw const BackupFormatException('This backup is damaged.');
    }
  }
}
