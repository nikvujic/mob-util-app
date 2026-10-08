import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:the_app/core/app_info.dart';
import 'package:the_app/core/crypto.dart';
import 'package:the_app/data/app_storage.dart';
import 'package:the_app/data/backup.dart';
import 'package:the_app/data/backup_files.dart';
import 'package:the_app/providers/notes_provider.dart';
import 'package:the_app/providers/shop_provider.dart';

/// Outcome of an export, for the UI to report.
enum ExportResult { saved, cancelled }

/// Creates backups of all app data.
class BackupExporter {
  final Ref _ref;

  /// Injectable clock, so tests get stable timestamps.
  final DateTime Function() _now;

  BackupExporter(this._ref, {DateTime Function()? now})
      : _now = now ?? DateTime.now;

  /// A snapshot of everything the app holds right now.
  Backup snapshot() => Backup(
        createdAt: _now(),
        appVersion: _ref.read(appVersionProvider),
        notes: _ref.read(notesProvider),
        shopItems: _ref.read(shopProvider),
      );

  /// Writes a plain (readable) snapshot to a file the user picks. Errors
  /// (e.g. storage full) are passed on to the caller.
  Future<ExportResult> export() async {
    final backup = snapshot();
    return _save(backup.fileName(), backup.encode());
  }

  /// Like [export], but the file is encrypted with [key] (from the master
  /// password) and can only be restored with that password.
  Future<ExportResult> exportEncrypted(PasswordKey key) async {
    final backup = snapshot();
    return _save(
      backup.fileName(encrypted: true),
      await backup.encodeEncrypted(key),
    );
  }

  Future<ExportResult> _save(String fileName, String contents) async {
    final saved = await _ref.read(backupFilesProvider).save(
          fileName: fileName,
          bytes: utf8.encode(contents),
        );
    return saved ? ExportResult.saved : ExportResult.cancelled;
  }
}

final backupExporterProvider = Provider<BackupExporter>(BackupExporter.new);

/// A user-facing reason why a file can't be imported.
class ImportException implements Exception {
  final String message;

  const ImportException(this.message);

  @override
  String toString() => 'ImportException: $message';
}

/// A backup that can be restored, with what to show before restoring.
class RestorableBackup {
  final Backup _backup;

  RestorableBackup._(this._backup);

  DateTime get createdAt => _backup.createdAt;
  int get noteCount => _backup.notes.length;
  int get shopItemCount => _backup.shopItems.length;
}

/// A picked backup file: plain (ready) or encrypted (needs its password).
sealed class PickedBackup {}

class PlainPick extends PickedBackup {
  final RestorableBackup backup;

  PlainPick._(this.backup);
}

class EncryptedPick extends PickedBackup {
  final EncryptedBackupFile _file;

  EncryptedPick._(this._file);

  /// The backup, or null if [password] is wrong. Throws [ImportException]
  /// if the right password reveals damaged contents.
  Future<RestorableBackup?> unlock(String password) async {
    try {
      final backup = await _file.open(password);
      return backup == null ? null : RestorableBackup._(backup);
    } on BackupFormatException catch (e) {
      throw ImportException(e.message);
    }
  }
}

/// What [BackupImporter.restore] replaced, to undo it.
class RestoreUndo {
  final Backup _previous;

  RestoreUndo._(this._previous);
}

/// Reads backup files and restores them (D2, D2a).
class BackupImporter {
  /// Larger files can't be backups of this app; refuse before decoding.
  static const maxFileBytes = 20 * 1024 * 1024;

  final Ref _ref;

  BackupImporter(this._ref);

  /// Lets the user pick a file. Null if they cancelled. Throws
  /// [ImportException] if it isn't a backup this app can read.
  Future<PickedBackup?> pick() async {
    final bytes = await _ref.read(backupFilesProvider).pick();
    return bytes == null ? null : read(bytes);
  }

  /// Parses file contents. Throws [ImportException] if they aren't a
  /// backup this app can read.
  PickedBackup read(Uint8List bytes) {
    const notABackup = ImportException('This file is not a backup.');
    if (bytes.length > maxFileBytes) throw notABackup;
    final String source;
    try {
      source = utf8.decode(bytes);
    } on FormatException {
      throw notABackup;
    }
    try {
      return switch (BackupFile.parse(source)) {
        PlainBackupFile(:final backup) =>
          PlainPick._(RestorableBackup._(backup)),
        final EncryptedBackupFile file => EncryptedPick._(file),
      };
    } on BackupFormatException catch (e) {
      throw ImportException(e.message);
    }
  }

  /// Replaces all notes and shop items with [backup]'s, and waits until
  /// they're saved. Returns what it replaced, for [undo].
  Future<RestoreUndo> restore(RestorableBackup backup) async {
    final previous = _ref.read(backupExporterProvider).snapshot();
    await _apply(backup._backup);
    return RestoreUndo._(previous);
  }

  /// Puts back the data a [restore] replaced.
  Future<void> undo(RestoreUndo undo) => _apply(undo._previous);

  Future<void> _apply(Backup backup) async {
    _ref.read(notesProvider.notifier).replaceAll(backup.notes);
    _ref.read(shopProvider.notifier).replaceAll(backup.shopItems);
    await _ref.read(appStorageProvider).flush();
  }
}

final backupImporterProvider = Provider<BackupImporter>(BackupImporter.new);
