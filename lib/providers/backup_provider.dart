import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:the_app/core/app_info.dart';
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

  /// Writes a snapshot to a file the user picks. Errors (e.g. storage full)
  /// are passed on to the caller.
  Future<ExportResult> export() async {
    final backup = snapshot();
    final saved = await _ref.read(backupFilesProvider).save(
          fileName: backup.fileName,
          bytes: utf8.encode(backup.encode()),
        );
    return saved ? ExportResult.saved : ExportResult.cancelled;
  }
}

final backupExporterProvider = Provider<BackupExporter>(BackupExporter.new);
