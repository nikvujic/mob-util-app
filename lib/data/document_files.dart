import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:the_app/core/crypto.dart';

/// The Documents page's pictures (spec: storage), one file each, by id.
/// Plain (a JPEG or PNG as saved) or sealed with the master password's
/// data key while the page is locked ([sealBytes]).
abstract class DocumentFiles {
  /// Writes [bytes] as [id], replacing it whole or not at all.
  Future<void> write(String id, List<int> bytes);

  /// [id]'s bytes, or null if there's no such file.
  Future<Uint8List?> read(String id);

  Future<void> delete(String id);

  /// Every id stored.
  Future<Set<String>> ids();

  /// Their size in all, in bytes.
  Future<int> totalBytes();

  /// Deletes every file but [keep] (left by a crash mid-delete, or a
  /// document deleted while its Undo was open).
  Future<void> keepOnly(Set<String> keep) async {
    for (final id in await ids()) {
      if (!keep.contains(id)) await delete(id);
    }
  }

  /// Deletes them all (Clear data).
  Future<void> clear() => keepOnly(const {});

  // ---- Sealing (spec: locking and encryption) ----

  static final _magic = utf8.encode('TASEAL1');
  static const _context = 'the-app/document-picture';
  static const _nonceLength = 12;
  static const _macLength = 16;

  /// Whether [bytes] are a sealed picture.
  static bool isSealed(List<int> bytes) {
    if (bytes.length < _magic.length + _nonceLength + _macLength) return false;
    for (var i = 0; i < _magic.length; i++) {
      if (bytes[i] != _magic[i]) return false;
    }
    return true;
  }

  /// [plain] sealed with [key]: the marker, the nonce, the tag, then the
  /// encrypted bytes.
  static Future<Uint8List> sealBytes(List<int> plain, CipherKey key) async {
    final box = await seal(plain, key, context: _context);
    return Uint8List.fromList(
        [..._magic, ...box.nonce, ...box.mac, ...box.cipherText]);
  }

  /// [sealed] opened with [key]. Throws [DecryptionException] if the key is
  /// wrong or the bytes were changed.
  static Future<Uint8List> openBytes(List<int> sealed, CipherKey key) async {
    if (!isSealed(sealed)) throw const DecryptionException();
    var at = _magic.length;
    final nonce = sealed.sublist(at, at += _nonceLength);
    final mac = sealed.sublist(at, at += _macLength);
    final cipherText = sealed.sublist(at);
    return Uint8List.fromList(await open(
      SealedBox(nonce: nonce, cipherText: cipherText, mac: mac),
      key,
      context: _context,
    ));
  }
}

/// On disk: `<app data>/documents/<id>`, written to a temporary name and
/// renamed, so a file is never half-written.
class DiskDocumentFiles extends DocumentFiles {
  final Directory dir;

  DiskDocumentFiles(this.dir);

  File _file(String id) => File('${dir.path}/$id');

  @override
  Future<void> write(String id, List<int> bytes) async {
    await dir.create(recursive: true);
    final temp = File('${dir.path}/$id.tmp');
    await temp.writeAsBytes(bytes, flush: true);
    await temp.rename(_file(id).path);
  }

  @override
  Future<Uint8List?> read(String id) async {
    final file = _file(id);
    return await file.exists() ? await file.readAsBytes() : null;
  }

  @override
  Future<void> delete(String id) async {
    final file = _file(id);
    if (await file.exists()) await file.delete();
  }

  @override
  Future<Set<String>> ids() async {
    if (!await dir.exists()) return {};
    final found = <String>{};
    await for (final entity in dir.list()) {
      if (entity is! File) continue;
      final name = entity.uri.pathSegments.last;
      if (name.endsWith('.tmp')) {
        // A write the app didn't finish: nothing refers to it.
        await entity.delete();
        continue;
      }
      found.add(name);
    }
    return found;
  }

  @override
  Future<int> totalBytes() async {
    var total = 0;
    for (final id in await ids()) {
      total += await _file(id).length();
    }
    return total;
  }
}

/// In memory (tests, and storage without a folder).
class MemoryDocumentFiles extends DocumentFiles {
  final Map<String, Uint8List> files = {};

  @override
  Future<void> write(String id, List<int> bytes) async =>
      files[id] = Uint8List.fromList(bytes);

  @override
  Future<Uint8List?> read(String id) async => files[id];

  @override
  Future<void> delete(String id) async => files.remove(id);

  @override
  Future<Set<String>> ids() async => files.keys.toSet();

  @override
  Future<int> totalBytes() async =>
      files.values.fold<int>(0, (a, b) => a + b.length);
}
