import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';

/// Reads and writes one JSON document to a file.
///
/// Writes are crash-safe: data goes to a temporary file first, which then
/// replaces the real file in a single rename, so the file is always either
/// the old or the new version, never half-written. Writes run one at a time;
/// if several are requested while one is in flight, only the latest is
/// written.
class JsonFileStore {
  final File file;

  JsonFileStore(this.file);

  File get _tempFile => File('${file.path}.tmp');

  Object? _pending;
  bool _hasPending = false;
  Future<void>? _running;

  /// Returns the decoded document, or null if the file does not exist.
  /// Throws [FormatException] if the file is not valid JSON.
  Future<Object?> read() async {
    if (!await file.exists()) return null;
    return jsonDecode(await file.readAsString());
  }

  /// Schedules [json] to be written. Returns a future that completes once
  /// this (or a newer) document is on disk.
  Future<void> write(Object json) {
    _pending = json;
    _hasPending = true;
    return _running ??= _drain();
  }

  /// Completes when all scheduled writes are on disk.
  Future<void> flush() => _running ?? Future.value();

  Future<void> _drain() async {
    try {
      while (_hasPending) {
        final json = _pending;
        _hasPending = false;
        _pending = null;
        try {
          await _writeNow(json);
        } catch (e, st) {
          // Keep the app running; the next change will try again.
          debugPrint('Failed to write ${file.path}: $e\n$st');
        }
      }
    } finally {
      _running = null;
    }
  }

  Future<void> _writeNow(Object? json) async {
    await file.parent.create(recursive: true);
    await _tempFile.writeAsString(jsonEncode(json), flush: true);
    await _tempFile.rename(file.path);
  }

  /// Moves an unreadable file aside (keeping it for manual recovery) so the
  /// app can start fresh without overwriting it. Returns the new path.
  Future<String> quarantine() async {
    final stamp = DateTime.now().toIso8601String().replaceAll(':', '-');
    final target = '${file.path}.corrupt-$stamp';
    await file.rename(target);
    return target;
  }
}
