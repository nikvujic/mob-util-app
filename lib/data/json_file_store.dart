import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:the_app/core/storage_error.dart';

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

  /// Why the last write failed; null once a write succeeds again.
  Object? _failure;

  /// The document whose write failed, kept for [retry].
  Object? _unsaved;

  /// Whether the last write failed (e.g. the phone's storage is full);
  /// false again once one succeeds.
  final failing = ValueNotifier<bool>(false);

  /// Set when the file couldn't be moved aside after a failed read: then
  /// it's never written, so whatever is in it isn't overwritten.
  bool _readOnly = false;

  /// Whether it couldn't be read at startup (and was set aside).
  bool get unreadable => _unreadable;
  bool _unreadable = false;

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

  /// Completes when all scheduled writes are on disk. Throws
  /// [StorageWriteException] if the last one failed: callers that must not
  /// go on unless it's saved (e.g. before changing the master password)
  /// can stop.
  Future<void> flush() async {
    await _running;
    final failure = _failure;
    if (failure != null) throw StorageWriteException(file.path, failure);
  }

  Future<void> _drain() async {
    try {
      while (_hasPending) {
        final json = _pending;
        _hasPending = false;
        _pending = null;
        // Kept as it was (see [quarantine]): not a failed save.
        if (_readOnly) continue;
        try {
          await _writeNow(json);
          _failure = null;
          _unsaved = null;
          failing.value = false;
        } catch (e, st) {
          // Keep the app running; the next change (or [retry]) tries
          // again, and flush() reports it.
          _failure = e;
          _unsaved = json;
          failing.value = true;
          debugPrint('Failed to write ${file.path}: $e\n$st');
        }
      }
    } finally {
      _running = null;
    }
  }

  /// Tries again to write what couldn't be written (e.g. once space was
  /// freed), unless something newer is on its way.
  Future<void> retry() {
    if (!failing.value || _hasPending) return _running ?? Future.value();
    return write(_unsaved!);
  }

  Future<void> _writeNow(Object? json) async {
    await file.parent.create(recursive: true);
    await _tempFile.writeAsString(jsonEncode(json), flush: true);
    await _tempFile.rename(file.path);
  }

  /// Moves an unreadable file aside (keeping it for manual recovery) so the
  /// app can start fresh without overwriting it. Returns the new path, or
  /// null if it couldn't be moved: then this store never writes, so the
  /// file stays as it is.
  Future<String?> quarantine() async {
    _unreadable = true;
    final stamp = DateTime.now().toIso8601String().replaceAll(':', '-');
    final target = '${file.path}.corrupt-$stamp';
    try {
      await file.rename(target);
      return target;
    } catch (e) {
      _readOnly = true;
      debugPrint('Could not move ${file.path} aside ($e); not writing it');
      return null;
    }
  }
}
