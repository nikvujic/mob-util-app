import 'dart:convert';

import 'package:the_app/core/crypto.dart' hide open;
import 'package:the_app/core/crypto.dart' as crypto show open;
import 'package:the_app/models/counter.dart';
import 'package:the_app/models/note.dart';
import 'package:the_app/models/planner_task.dart';
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
///       "version": 2,
///       "createdAt": "2026-10-08T07:30:00.000Z",
///       "appVersion": "0.7.0 (8)",
///       "data": { "notes": [...], "shopItems": [...],
///                 "plannerTasks": [...], "counters": [...],
///                 "masterPassword": {...} }
///     }
///
/// `masterPassword` (since version 2) is only there if some notes are
/// locked: it's the master password record (as in `security.json`), which
/// holds the key of the locked notes, itself encrypted with the password.
/// Locked notes stay encrypted in every backup, plain or not.
///
/// An encrypted backup keeps the same header but replaces `data` with the
/// whole plain document, sealed with a key from the master password:
///
///     {
///       "format": "the-app-backup", "version": 2, "encrypted": true,
///       "createdAt": "…", "appVersion": "…",
///       "kdf": {Argon2id parameters}, "sealed": {AES-256-GCM box}
///     }
///
/// [version] goes up whenever the layout changes; [BackupFile.parse] must
/// keep reading every older version.
class Backup {
  /// Authenticated with the encrypted data, so nothing else sealed with the
  /// same key can be passed off as a backup.
  static const sealContext = 'the-app/backup';

  static const format = 'the-app-backup';

  /// History: 1 = first format; 2 = notes may be locked
  /// (`lockedContent`); 3 = planner tasks and counters (`plannerTasks`,
  /// `counters`; older backups have none); 4 = planner tasks have start
  /// and end times, and the Džoni count (`dzoniCount`).
  static const version = 4;

  final DateTime createdAt;
  final String appVersion;
  final List<Note> notes;
  final List<ShopItem> shopItems;
  final List<PlannerTask> plannerTasks;
  final List<Counter> counters;

  /// The count on the Džoni page (O4); 0 in backups from before it.
  final int dzoniCount;

  /// The master password record the locked notes need, if any are locked.
  final PasswordVerifier? masterPassword;

  const Backup({
    required this.createdAt,
    required this.appVersion,
    required this.notes,
    required this.shopItems,
    this.plannerTasks = const [],
    this.counters = const [],
    this.dzoniCount = 0,
    this.masterPassword,
  });

  /// Suggested file name, e.g. `the-app-backup-2026-10-08-0930.json` or
  /// `…-0930-encrypted.json` (local time, so it matches what the user sees).
  String fileName({bool encrypted = false}) {
    final t = createdAt.toLocal();
    String two(int n) => n.toString().padLeft(2, '0');
    return 'the-app-backup-${t.year}-${two(t.month)}-${two(t.day)}'
        '-${two(t.hour)}${two(t.minute)}${encrypted ? '-encrypted' : ''}.json';
  }

  Map<String, dynamic> _header() => {
        'format': format,
        'version': version,
        'createdAt': createdAt.toUtc().toIso8601String(),
        'appVersion': appVersion,
      };

  Map<String, dynamic> toJson() => {
        ..._header(),
        'data': {
          'notes': [for (final n in notes) n.toJson()],
          'shopItems': [for (final i in shopItems) i.toJson()],
          'plannerTasks': [for (final t in plannerTasks) t.toJson()],
          'counters': [for (final c in counters) c.toJson()],
          'dzoniCount': dzoniCount,
          if (masterPassword != null)
            'masterPassword': masterPassword!.toJson(),
        },
      };

  static const _indented = JsonEncoder.withIndent('  ');

  /// The file contents: indented JSON, readable in any text editor.
  String encode() => _indented.convert(toJson());

  /// The file contents of an encrypted backup, sealed with [key] (derived
  /// from the master password). Only the header stays readable.
  Future<String> encodeEncrypted(PasswordKey key) async {
    final sealed = await seal(
      utf8.encode(jsonEncode(toJson())),
      key,
      context: sealContext,
    );
    return _indented.convert({
      ..._header(),
      'encrypted': true,
      'kdf': key.params.toJson(),
      'sealed': sealed.toJson(),
    });
  }

  /// Reads a plain backup. Throws [BackupFormatException] if [source] is not
  /// a plain backup this app can read.
  static Backup decode(String source) {
    final json = _parseHeader(source);
    if (json['encrypted'] == true) {
      throw const BackupFormatException('This backup is encrypted.');
    }
    return _fromJson(json);
  }

  /// Parses [source] as JSON and checks the header (format and version).
  static Map<String, dynamic> _parseHeader(String source) {
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
    return json;
  }

  static Backup _fromJson(Map<String, dynamic> json) {
    final Backup backup;
    try {
      final data = json['data'] as Map<String, dynamic>;
      backup = Backup(
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
        plannerTasks: [
          for (final t in data['plannerTasks'] as List<dynamic>? ?? const [])
            PlannerTask.fromJson(t as Map<String, dynamic>),
        ],
        counters: [
          for (final c in data['counters'] as List<dynamic>? ?? const [])
            Counter.fromJson(c as Map<String, dynamic>),
        ],
        dzoniCount: data['dzoniCount'] as int? ?? 0,
        masterPassword: data['masterPassword'] == null
            ? null
            : PasswordVerifier.fromJson(
                data['masterPassword'] as Map<String, dynamic>,
              ),
      );
    } on Object {
      // Wrong types, missing fields, bad dates: all mean a damaged file.
      throw const BackupFormatException('This backup is damaged.');
    }
    // Ids must be unique: lists use them as keys, and duplicates would make
    // the app misbehave after restoring.
    bool unique(Iterable<String> ids) => ids.toSet().length == ids.length;
    if (!unique(backup.notes.map((n) => n.id)) ||
        !unique(backup.shopItems.map((i) => i.id)) ||
        !unique(backup.plannerTasks.map((t) => t.id)) ||
        !unique(backup.counters.map((c) => c.id))) {
      throw const BackupFormatException('This backup is damaged.');
    }
    return backup;
  }
}

/// A backup file as read from disk: either plain (ready to use) or encrypted
/// (needs the master password it was made with).
sealed class BackupFile {
  /// When the backup was made (readable even if encrypted).
  DateTime get createdAt;

  /// Reads [source]. Throws [BackupFormatException] if it isn't a backup
  /// this app can read.
  static BackupFile parse(String source) {
    final json = Backup._parseHeader(source);
    if (json['encrypted'] != true) {
      return PlainBackupFile(Backup._fromJson(json));
    }
    try {
      return EncryptedBackupFile._(
        createdAt: DateTime.parse(json['createdAt'] as String),
        kdf: KdfParams.fromJson(json['kdf'] as Map<String, dynamic>),
        sealed: SealedBox.fromJson(json['sealed'] as Map<String, dynamic>),
      );
    } on Object {
      throw const BackupFormatException('This backup is damaged.');
    }
  }
}

class PlainBackupFile extends BackupFile {
  final Backup backup;

  PlainBackupFile(this.backup);

  @override
  DateTime get createdAt => backup.createdAt;
}

class EncryptedBackupFile extends BackupFile {
  @override
  final DateTime createdAt;
  final KdfParams _kdf;
  final SealedBox _sealed;

  EncryptedBackupFile._({
    required this.createdAt,
    required KdfParams kdf,
    required SealedBox sealed,
  })  : _kdf = kdf,
        _sealed = sealed;

  /// The backup inside, or null if [password] is wrong. Throws
  /// [BackupFormatException] if the decrypted contents are damaged.
  Future<Backup?> open(String password) async =>
      (await openWithKey(password))?.backup;

  /// Like [open], but also returns the key derived from [password]: it
  /// usually also opens the backup's [Backup.masterPassword] record, as the
  /// backup was encrypted with that password's key.
  Future<({Backup backup, PasswordKey key})?> openWithKey(
    String password,
  ) async {
    final key = await PasswordKey.derive(password, _kdf);
    final List<int> plain;
    try {
      plain = await crypto.open(_sealed, key, context: Backup.sealContext);
    } on DecryptionException {
      return null;
    }
    final backup = Backup.decode(utf8.decode(plain, allowMalformed: true));
    return (backup: backup, key: key);
  }
}
