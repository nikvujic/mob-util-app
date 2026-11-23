import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:the_app/core/clock.dart';
import 'package:the_app/data/backup_folder.dart';
import 'package:the_app/providers/backup_provider.dart';
import 'package:the_app/providers/preferences_provider.dart';
import 'package:the_app/providers/section_locks_provider.dart';

/// What an automatic backup attempt did.
enum AutoBackupResult { off, notDue, locked, written, failed }

/// Automatic backup: once a day, when the app is opened (or
/// comes back), a backup into the folder picked, as *Export all data*
/// writes it (a zip, with the Documents page's pictures); the newest
/// [Preferences.autoBackupKeep] are kept there. Written under a temporary
/// name and renamed once complete: one cut short (the app closed) is
/// deleted the next time, and the last backup's time isn't moved, so it
/// runs again. Not while a section is locked (it needs the app unlocked):
/// then the next time it is.
class AutoBackup {
  final Ref _ref;

  AutoBackup(this._ref);

  /// How often; how many are kept in the folder by default, and at most.
  static const every = Duration(days: 1);
  static const keep = 7;
  static const maxKeep = 14;

  /// Its files' names start so (the folder may hold other files).
  static const prefix = 'the-app-auto-';

  /// "the-app-auto-2026-10-14-0905.zip": sorted by name, sorted by time.
  /// Older ones end in `.json` (the same order: the name's start).
  static String fileName(DateTime at) {
    String two(int n) => n.toString().padLeft(2, '0');
    return '$prefix${at.year}-${two(at.month)}-${two(at.day)}-'
        '${two(at.hour)}${two(at.minute)}.zip';
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
      final backup = await _ref.read(backupExporterProvider).full();
      final name = fileName(now);
      final storage = _ref.read(backupFolderProvider);
      final written = await storage.write(
        folder: folder,
        name: name,
        bytes: await backup.zip(),
        prefix: prefix,
        keep: preferences.autoBackupKeep,
      );
      final notifier = _ref.read(preferencesProvider.notifier);
      if (written) {
        final kept = await storage.list(folder: folder, prefix: prefix);
        notifier.autoBackedUp(
          now,
          name: name,
          pictures: backup.pictures.length,
          kept: kept?.map((b) => b.name),
        );
        return AutoBackupResult.written;
      }
      notifier.autoBackupFailed();
      return AutoBackupResult.failed;
    } finally {
      _running = false;
    }
  }
}

/// What the automatic backups' folder holds, for the Backup page.
class AutoBackupFolderState {
  final List<FolderBackup> backups;

  /// The pictures in them all (as each was counted when written).
  final int pictures;

  const AutoBackupFolderState(this.backups, this.pictures);

  int get bytes => backups.fold(0, (a, b) => a + b.bytes);
}

extension AutoBackupFolder on AutoBackup {
  /// The backups in the folder, or null if it's off or can't be read.
  Future<AutoBackupFolderState?> folderState() async {
    final preferences = _ref.read(preferencesProvider);
    final folder = preferences.autoBackupFolder;
    if (folder == null) return null;
    final backups = await _ref
        .read(backupFolderProvider)
        .list(folder: folder, prefix: AutoBackup.prefix);
    if (backups == null) return null;
    final counts = preferences.autoBackupPictures;
    return AutoBackupFolderState(
      backups,
      backups.fold(0, (a, b) => a + (counts[b.name] ?? 0)),
    );
  }

  /// Keeps [keep] backups from now on, deleting older ones beyond it.
  Future<void> setKeep(int keep) async {
    _ref.read(preferencesProvider.notifier).setAutoBackupKeep(keep);
    final folder = _ref.read(preferencesProvider).autoBackupFolder;
    if (folder == null) return;
    await _ref.read(backupFolderProvider).prune(
          folder: folder,
          prefix: AutoBackup.prefix,
          keep: _ref.read(preferencesProvider).autoBackupKeep,
        );
  }
}

final autoBackupFolderProvider =
    FutureProvider.autoDispose<AutoBackupFolderState?>((ref) {
  ref.watch(preferencesProvider.select((p) => (
        p.autoBackupFolder,
        p.lastAutoBackupAt,
        p.autoBackupKeep,
      )));
  return ref.read(autoBackupProvider).folderState();
});

final autoBackupProvider = Provider<AutoBackup>(AutoBackup.new);
