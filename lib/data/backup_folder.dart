import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// A folder for automatic backups: picked once with Android's
/// folder picker, which lets the app keep writing there.
typedef PickedFolder = ({String uri, String name});

/// A backup in the folder: its file name, size and when it was written.
typedef FolderBackup = ({String name, int bytes, DateTime? modified});

abstract interface class BackupFolder {
  /// Asks the user for a folder; null if they cancelled.
  Future<PickedFolder?> pick();

  /// Writes [bytes] as a new file [name] in [folder] (under a temporary
  /// name first, renamed once complete), then deletes the oldest files
  /// starting with [prefix] beyond [keep], and any left half-written.
  /// False if it couldn't (the folder gone, or its permission taken back).
  Future<bool> write({
    required String folder,
    required String name,
    required Uint8List bytes,
    required String prefix,
    required int keep,
  });

  /// The finished backups in [folder] starting with [prefix], newest
  /// first; those left half-written are deleted. Null if the folder can't
  /// be read.
  Future<List<FolderBackup>?> list({
    required String folder,
    required String prefix,
  });

  /// Deletes the oldest backups starting with [prefix] beyond [keep].
  Future<bool> prune({
    required String folder,
    required String prefix,
    required int keep,
  });
}

/// [BackupFolder] through the app's own Android code (MainActivity).
class AndroidBackupFolder implements BackupFolder {
  const AndroidBackupFolder();

  static const _channel = MethodChannel('the_app/backup_folder');

  @override
  Future<PickedFolder?> pick() async {
    final picked = await _channel.invokeMapMethod<String, String>('pick');
    final uri = picked?['uri'];
    if (uri == null) return null;
    return (uri: uri, name: picked?['name'] ?? 'Folder');
  }

  @override
  Future<bool> write({
    required String folder,
    required String name,
    required Uint8List bytes,
    required String prefix,
    required int keep,
  }) async {
    try {
      return await _channel.invokeMethod<bool>('write', {
            'folder': folder,
            'name': name,
            'bytes': bytes,
            'prefix': prefix,
            'keep': keep,
          }) ??
          false;
    } on PlatformException {
      return false;
    } on MissingPluginException {
      return false;
    }
  }

  @override
  Future<List<FolderBackup>?> list({
    required String folder,
    required String prefix,
  }) async {
    try {
      final found = await _channel.invokeListMethod<Map<Object?, Object?>>(
          'list', {'folder': folder, 'prefix': prefix});
      if (found == null) return null;
      return [
        for (final f in found)
          (
            name: f['name'] as String,
            bytes: (f['bytes'] as num?)?.toInt() ?? 0,
            modified: switch ((f['modified'] as num?)?.toInt()) {
              null || 0 => null,
              final ms => DateTime.fromMillisecondsSinceEpoch(ms),
            },
          ),
      ];
    } on PlatformException {
      return null;
    } on MissingPluginException {
      return null;
    }
  }

  @override
  Future<bool> prune({
    required String folder,
    required String prefix,
    required int keep,
  }) async {
    try {
      return await _channel.invokeMethod<bool>(
              'prune', {'folder': folder, 'prefix': prefix, 'keep': keep}) ??
          false;
    } on PlatformException {
      return false;
    } on MissingPluginException {
      return false;
    }
  }
}

final backupFolderProvider = Provider<BackupFolder>(
  (ref) => const AndroidBackupFolder(),
);
