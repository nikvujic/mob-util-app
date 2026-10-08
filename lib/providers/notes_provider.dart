import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:the_app/core/crypto.dart';
import 'package:the_app/core/id.dart';
import 'package:the_app/data/app_storage.dart';
import 'package:the_app/models/note.dart';

/// Notes in user-defined display order (index 0 is shown first). Every
/// change is saved to [AppStorage].
class NotesNotifier extends StateNotifier<List<Note>> {
  NotesNotifier(AppStorage storage) : super(storage.initialNotes) {
    addListener(storage.saveNotes, fireImmediately: false);
  }

  static const defaultTitle = 'New Note';

  /// Creates a note at the top of the list and returns its id.
  String addNote({String title = defaultTitle, String content = ''}) {
    final now = DateTime.now();
    final note = Note(
      id: generateId(),
      title: title,
      content: content,
      createdAt: now,
      modifiedAt: now,
    );
    state = [note, ...state];
    return note.id;
  }

  /// Updates a note. `modifiedAt` only changes if something actually changed.
  ///
  /// The content of a locked note can only be changed with
  /// [updateLockedNote], so it's never stored unencrypted by accident.
  void updateNote(String id, {String? title, String? content}) {
    if (content != null && _find(id)?.isLocked == true) {
      throw StateError('Locked note $id: use updateLockedNote');
    }
    state = [
      for (final note in state)
        if (note.id == id &&
            ((title != null && title != note.title) ||
                (content != null && content != note.content)))
          note.copyWith(
            title: title,
            content: content,
            modifiedAt: DateTime.now(),
          )
        else
          note,
    ];
  }

  // --- Locked notes (N6, N7): content sealed with the data key ---

  /// Purpose a note's content is sealed for; includes the id, so one note's
  /// sealed content can't be moved into another note.
  static String sealContext(String noteId) => 'the-app/note/$noteId';

  Note? _find(String id) => state.where((n) => n.id == id).firstOrNull;

  Future<Map<String, dynamic>> _seal(String id, String content, DataKey key) =>
      seal(utf8.encode(content), key, context: sealContext(id))
          .then((box) => box.toJson());

  void _replace(Note updated) {
    state = [
      for (final note in state)
        if (note.id == updated.id) updated else note,
    ];
  }

  /// The text of [note]: as is, or decrypted with [key] if it's locked.
  /// Throws [DecryptionException] if [key] can't open it.
  Future<String> readContent(Note note, DataKey key) async {
    final sealed = note.lockedContent;
    if (sealed == null) return note.content;
    final SealedBox box;
    try {
      box = SealedBox.fromJson(sealed);
    } on FormatException {
      throw const DecryptionException();
    }
    final plain = await open(box, key, context: sealContext(note.id));
    return utf8.decode(plain);
  }

  /// Locks a note: its content is sealed with [key] and the plain text is
  /// dropped. Doesn't change its modified time.
  Future<void> lockNote(String id, DataKey key) async {
    final note = _find(id);
    if (note == null || note.isLocked) return;
    final sealed = await _seal(id, note.content, key);
    final current = _find(id);
    if (current == null || current.isLocked) return;
    // Seal what's there now, in case it changed while sealing.
    _replace(
      current.locked(
        current.content == note.content
            ? sealed
            : await _seal(id, current.content, key),
      ),
    );
  }

  /// Unlocks a note for good: its content is stored in the clear again.
  /// Throws [DecryptionException] if [key] can't open it.
  Future<void> unlockNote(String id, DataKey key) async {
    final note = _find(id);
    if (note == null || !note.isLocked) return;
    final content = await readContent(note, key);
    final current = _find(id);
    if (current == null || !current.isLocked) return;
    _replace(current.unlocked(content));
  }

  /// Updates a locked note: [content] is sealed with [key]. Like
  /// [updateNote], nothing changes (not even the modified time) unless the
  /// title or content actually differ.
  Future<void> updateLockedNote(
    String id, {
    String? title,
    String? content,
    required DataKey key,
  }) async {
    final note = _find(id);
    if (note == null || !note.isLocked) return;
    final titleChanged = title != null && title != note.title;
    final contentChanged =
        content != null && content != await readContent(note, key);
    if (!titleChanged && !contentChanged) return;

    final sealed = contentChanged ? await _seal(id, content, key) : null;
    final current = _find(id);
    if (current == null || !current.isLocked) return;
    final updated = current.copyWith(
      title: title,
      modifiedAt: DateTime.now(),
    );
    _replace(sealed == null ? updated : updated.locked(sealed));
  }

  /// Puts back an earlier version of a note exactly as it was, including
  /// its modified time (used to discard edits).
  void restoreNote(Note snapshot) {
    state = [
      for (final note in state)
        if (note.id == snapshot.id) snapshot else note,
    ];
  }

  /// Replaces everything (used when restoring a backup).
  void replaceAll(List<Note> notes) {
    state = List.unmodifiable(notes);
  }

  void removeNotes(Set<String> ids) {
    state = state.where((note) => !ids.contains(note.id)).toList();
  }

  /// Moves the note at [oldIndex] to [newIndex]. Indices follow
  /// `ReorderableListView.onReorder` semantics.
  void reorder(int oldIndex, int newIndex) {
    if (newIndex > oldIndex) newIndex--;
    if (oldIndex == newIndex) return;
    final notes = [...state];
    final note = notes.removeAt(oldIndex);
    notes.insert(newIndex, note);
    state = notes;
  }
}

final notesProvider = StateNotifierProvider<NotesNotifier, List<Note>>((ref) {
  return NotesNotifier(ref.watch(appStorageProvider));
});
