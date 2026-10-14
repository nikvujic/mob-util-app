import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:the_app/core/clock.dart';
import 'package:the_app/data/backup_folder.dart';
import 'package:the_app/providers/backup_provider.dart';
import 'package:the_app/providers/preferences_provider.dart';
import 'package:the_app/providers/section_locks_provider.dart';

/// What an automatic backup attempt did.
enum AutoBackupResult { off, notDue, locked, written, failed }

/// Automatic backup (Round 39): once a day, when the app is opened (or
/// comes back), a backup into the folder picked, as *Export all data*
/// writes it; the newest [keep] are kept there. Not while a section is
/// locked (it needs the app unlocked): then the next time it is.
class AutoBackup {
  final Ref _ref;

  AutoBackup(this._ref);

  /// How often, and how many are kept in the folder.
  static const every = Duration(days: 1);
  static const keep = 7;

  /// Its files' names start so (the folder may hold other files).
  static const prefix = 'the-app-auto-';

  /// "the-app-auto-2026-10-14-0905.json": sorted by name, sorted by time.
  static String fileName(DateTime at) {
    String two(int n) => n.toString().padLeft(2, '0');
    return '$prefix${at.year}-${two(at.month)}-${two(at.day)}-'
        '${two(at.hour)}${two(at.minute)}.json';
  }

  bool _running = false;

  /// Asks for a folder and backs up into it straight away: false if
  /// cancelled.
  Future<AutoBackupResult?> pickFolder() async {
    final picked = await _ref.read(backupFolderProvider).pick();
    if (picked == null) return null;
    _ref.read(preferencesProvider.notifier).setAutoBackupFolder(picked);
    return run(force: true);
  }

  /// Off: nothing more is written (what's in the folder stays).
  void turnOff() =>
      _ref.read(preferencesProvider.notifier).setAutoBackupFolder(null);

  /// Writes one if it's due (or [force]d: *Back up now*).
  Future<AutoBackupResult> run({bool force = false}) async {
    final preferences = _ref.read(preferencesProvider);
    final folder = preferences.autoBackupFolder;
    if (folder == null) return AutoBackupResult.off;
    final now = _ref.read(clockProvider)();
    final last = preferences.lastAutoBackupAt;
    if (!force && last != null && now.difference(last) < every) {
      return AutoBackupResult.notDue;
    }
    if (_ref.read(anySectionClosedProvider)) return AutoBackupResult.locked;
    if (_running) return AutoBackupResult.notDue;
    _running = true;
    try {
      final backup = _ref.read(backupExporterProvider).snapshot();
      final written = await _ref.read(backupFolderProvider).write(
            folder: folder,
            name: fileName(now),
            bytes: utf8.encode(backup.encode()),
            prefix: prefix,
            keep: keep,
          );
      final notifier = _ref.read(preferencesProvider.notifier);
      if (written) {
        notifier.autoBackedUp(now);
        return AutoBackupResult.written;
      }
      notifier.autoBackupFailed();
      return AutoBackupResult.failed;
    } finally {
      _running = false;
    }
  }
}

final autoBackupProvider = Provider<AutoBackup>(AutoBackup.new);
