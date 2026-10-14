import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// A folder for automatic backups (Round 39): picked once with Android's
/// folder picker, which lets the app keep writing there.
typedef PickedFolder = ({String uri, String name});

abstract interface class BackupFolder {
  /// Asks the user for a folder; null if they cancelled.
  Future<PickedFolder?> pick();

  /// Writes [bytes] as a new file [name] in [folder], then deletes the
  /// oldest files starting with [prefix] beyond [keep]. False if it
  /// couldn't (the folder gone, or its permission taken back).
  Future<bool> write({
    required String folder,
    required String name,
    required Uint8List bytes,
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
}

final backupFolderProvider = Provider<BackupFolder>(
  (ref) => const AndroidBackupFolder(),
);
