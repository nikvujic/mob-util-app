import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Where backup files go and come from: the system file dialogs, so the user
/// chooses the location (Downloads, Google Drive, …).
abstract interface class BackupFiles {
  /// Asks the user where to save [bytes] as [fileName]. Returns `false` if
  /// they cancelled.
  Future<bool> save({required String fileName, required Uint8List bytes});

  /// Lets the user pick a file and returns its contents, or null if they
  /// cancelled.
  Future<Uint8List?> pick();
}

/// [BackupFiles] using Android's storage access framework via file_picker.
class SystemBackupFiles implements BackupFiles {
  const SystemBackupFiles();

  @override
  Future<bool> save({
    required String fileName,
    required Uint8List bytes,
  }) async {
    final saved = await FilePicker.saveFile(
      fileName: fileName,
      bytes: bytes,
    );
    return saved != null;
  }

  @override
  Future<Uint8List?> pick() async {
    final result = await FilePicker.pickFiles(withData: true);
    return result?.files.single.bytes;
  }
}

final backupFilesProvider = Provider<BackupFiles>(
  (ref) => const SystemBackupFiles(),
);
