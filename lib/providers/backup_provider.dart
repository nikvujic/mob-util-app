import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:the_app/core/app_info.dart';
import 'package:the_app/core/crypto.dart';
import 'package:the_app/data/app_storage.dart';
import 'package:the_app/data/backup.dart';
import 'package:the_app/data/backup_files.dart';
import 'package:the_app/models/note.dart';
import 'package:the_app/models/planner_task.dart';
import 'package:the_app/models/shop_item.dart';
import 'package:the_app/providers/notes_provider.dart';
import 'package:the_app/providers/planner_provider.dart';
import 'package:the_app/providers/security_provider.dart';
import 'package:the_app/providers/session_provider.dart';
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

  /// A snapshot of everything the app holds right now. Includes the master
  /// password record if some notes are locked: it holds their key.
  Backup snapshot() {
    final notes = _ref.read(notesProvider);
    return Backup(
      createdAt: _now(),
      appVersion: _ref.read(appVersionProvider),
      notes: notes,
      shopItems: _ref.read(shopProvider),
      plannerTasks: _ref.read(plannerProvider),
      masterPassword:
          notes.any((n) => n.isLocked) ? _ref.read(securityProvider) : null,
    );
  }

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

  /// For an encrypted backup: the key from its password, which usually
  /// also opens its master password record.
  final PasswordKey? _fileKey;

  RestorableBackup._(this._backup, [this._fileKey]);

  DateTime get createdAt => _backup.createdAt;
  int get noteCount => _backup.notes.length;
  int get lockedNoteCount => _backup.notes.where((n) => n.isLocked).length;
  int get shopItemCount => _backup.shopItems.length;
  int get plannerTaskCount => _backup.plannerTasks.length;
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
      final opened = await _file.openWithKey(password);
      return opened == null
          ? null
          : RestorableBackup._(opened.backup, opened.key);
    } on BackupFormatException catch (e) {
      throw ImportException(e.message);
    }
  }
}

/// What [BackupImporter.restore] replaced, to undo it.
class RestoreUndo {
  final Backup _previous;
  final PasswordVerifier? _previousMasterPassword;

  /// Whether the restore took over the backup's master password (this app
  /// had none), so its locked notes open with that password.
  final bool adoptedMasterPassword;

  RestoreUndo._(
    this._previous,
    this._previousMasterPassword, {
    required this.adoptedMasterPassword,
  });
}

/// Asks the user for this app's master password (unlocking it) and returns
/// the key of locked notes; null if they cancel.
typedef AskThisAppKey = Future<DataKey?> Function();

/// Asks the user for the master password the backup was made with, checked
/// against [record], and returns the key it protects; null if they cancel.
typedef AskBackupKey = Future<DataKey?> Function(PasswordVerifier record);

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
  /// they're saved. Returns what it replaced, for [undo]; null if the user
  /// cancelled a password prompt (nothing changed then).
  ///
  /// Locked notes (D3) stay locked:
  /// - If this app has no master password, it takes over the backup's, so
  ///   they open with the password they were locked with.
  /// - Otherwise they must open with this app's key ([thisAppKey]; e.g. a
  ///   backup from this phone), or else with the backup's ([backupKey], or
  ///   the encrypted file's password if it fits); then they are re-locked
  ///   under this app's key.
  ///
  /// Throws [ImportException] if locked notes can't be restored.
  Future<RestoreUndo?> restore(
    RestorableBackup backup, {
    AskThisAppKey thisAppKey = _cancelled,
    AskBackupKey backupKey = _cancelledFor,
  }) async {
    final security = _ref.read(securityProvider.notifier);
    final previousMasterPassword = _ref.read(securityProvider);
    final previous = _ref.read(backupExporterProvider).snapshot();
    final source = backup._backup;
    var notes = source.notes;
    var adopt = false;

    if (notes.any((n) => n.isLocked)) {
      final record = source.masterPassword;
      if (previousMasterPassword == null) {
        if (record == null) throw _missingKey;
        adopt = true;
      } else {
        final relocked = await _relock(
          notes,
          record,
          fileKey: backup._fileKey,
          thisAppKey: thisAppKey,
          backupKey: backupKey,
        );
        if (relocked == null) return null;
        notes = relocked;
      }
    }

    if (adopt) {
      // The password first: locked notes must never be saved without it.
      security.restore(source.masterPassword);
      await _ref.read(appStorageProvider).flush();
    }
    await _apply(notes, source.shopItems, source.plannerTasks);
    return RestoreUndo._(
      previous,
      previousMasterPassword,
      adoptedMasterPassword: adopt,
    );
  }

  /// Puts back the data (and master password) a [restore] replaced.
  Future<void> undo(RestoreUndo undo) async {
    await _apply(
      undo._previous.notes,
      undo._previous.shopItems,
      undo._previous.plannerTasks,
    );
    if (undo.adoptedMasterPassword) {
      _ref.read(securityProvider.notifier).restore(
            undo._previousMasterPassword,
          );
      await _ref.read(appStorageProvider).flush();
    }
  }

  static Future<DataKey?> _cancelled() async => null;
  static Future<DataKey?> _cancelledFor(PasswordVerifier _) async => null;

  static const _missingKey = ImportException(
    "This backup's locked notes can't be restored: the backup doesn't "
    'include their key.',
  );

  /// [notes] with every locked one under this app's key; null if the user
  /// cancelled a prompt.
  Future<List<Note>?> _relock(
    List<Note> notes,
    PasswordVerifier? record, {
    required PasswordKey? fileKey,
    required AskThisAppKey thisAppKey,
    required AskBackupKey backupKey,
  }) async {
    final ours = _ref.read(sessionProvider)?.dataKey ?? await thisAppKey();
    if (ours == null) return null;

    final locked = notes.where((n) => n.isLocked).toList();
    if (await _allOpen(locked, ours)) return notes; // already ours

    if (record == null) throw _missingKey;
    var theirs = fileKey == null ? null : await record.unwrapDataKey(fileKey);
    theirs ??= await backupKey(record);
    if (theirs == null) return null;

    final relocked = <String, Note>{};
    for (final note in locked) {
      final String content;
      try {
        content = await NotesNotifier.openContent(note, theirs);
      } on DecryptionException {
        throw const ImportException(
          "Some locked notes in this backup can't be opened with its "
          'master password.',
        );
      }
      relocked[note.id] = await NotesNotifier.lockedCopy(note, content, ours);
    }
    return [for (final n in notes) relocked[n.id] ?? n];
  }

  static Future<bool> _allOpen(List<Note> notes, DataKey key) async {
    try {
      for (final note in notes) {
        await NotesNotifier.openContent(note, key);
      }
      return true;
    } on DecryptionException {
      return false;
    }
  }

  Future<void> _apply(
    List<Note> notes,
    List<ShopItem> shopItems,
    List<PlannerTask> plannerTasks,
  ) async {
    _ref.read(notesProvider.notifier).replaceAll(notes);
    _ref.read(shopProvider.notifier).replaceAll(shopItems);
    _ref.read(plannerProvider.notifier).replaceAll(plannerTasks);
    await _ref.read(appStorageProvider).flush();
  }
}

final backupImporterProvider = Provider<BackupImporter>(BackupImporter.new);
