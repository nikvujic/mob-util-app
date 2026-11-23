import 'dart:typed_data';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:the_app/core/id.dart';
import 'package:the_app/data/app_storage.dart';
import 'package:the_app/data/document_files.dart';
import 'package:the_app/models/document_item.dart';

/// The Documents page (spec `docs/DOCUMENTS_SPEC.md`), saved to
/// `documents.json`, its pictures in [DocumentFiles]. A document is saved
/// as it's edited (upserted); a new one goes first. Their order is the
/// user's, set by dragging.
class DocumentsNotifier extends StateNotifier<DocumentBook> {
  final AppStorage _storage;

  DocumentsNotifier(this._storage) : super(_read(_storage.initialDocuments)) {
    addListener(_save, fireImmediately: false);
  }

  static DocumentBook _read(Map<String, dynamic>? json) {
    if (json == null || json['documents'] == null) return DocumentBook.empty;
    return DocumentBook.fromJson(json);
  }

  void _save(DocumentBook book) => _storage.saveDocuments(book.toJson());

  DocumentFiles get files => _storage.documentFiles;

  /// [item] as it is now: added (first) if new, else replaced.
  void save(DocItem item) {
    final known = state.byId(item.id) != null;
    state = DocumentBook([
      if (!known) item,
      for (final d in state.items)
        if (d.id == item.id) item else d,
    ]);
  }

  /// Deletes [id]; returns the book before, for Undo. Its pictures stay
  /// until [cleanUp] (after Undo has gone).
  DocumentBook delete(String id) {
    final before = state;
    state = DocumentBook([
      for (final d in state.items)
        if (d.id != id) d,
    ]);
    return before;
  }

  /// [id] moved to [to]'s place, the others shifting.
  void moveTo(String id, int to) {
    final list = [...state.items];
    final from = list.indexWhere((d) => d.id == id);
    if (from == -1 || to < 0 || to >= list.length || from == to) return;
    list.insert(to, list.removeAt(from));
    state = DocumentBook(list);
  }

  void replaceAll(DocumentBook book) => state = book;

  /// Stores a picture's [bytes] and returns its id.
  Future<String> addPicture(List<int> bytes) async {
    final id = generateId();
    await files.write(id, bytes);
    return id;
  }

  /// A picture's bytes, ready to show; null if it's missing.
  Future<Uint8List?> readPicture(String id) => files.read(id);

  /// Deletes pictures no document refers to (a document deleted and its
  /// Undo gone, a picture taken out, a crash mid-way). Never while
  /// `documents.json` couldn't be read: its pictures are kept for it.
  Future<void> cleanUp() async {
    if (!_storage.documentsReadable) return;
    await files.keepOnly(state.fileIds);
  }

  /// Deletes every document and picture (Clear data).
  Future<void> clearAll() async {
    state = DocumentBook.empty;
    await files.clear();
  }
}

final documentsProvider =
    StateNotifierProvider<DocumentsNotifier, DocumentBook>(
  (ref) => DocumentsNotifier(ref.watch(appStorageProvider)),
);
