import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:the_app/core/id.dart';
import 'package:the_app/models/note.dart';

/// Notes in user-defined display order (index 0 is shown first).
class NotesNotifier extends StateNotifier<List<Note>> {
  NotesNotifier() : super([]);

  /// Creates a note at the top of the list and returns its id.
  String addNote({required String title, String content = ''}) {
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
  void updateNote(String id, {String? title, String? content}) {
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
  return NotesNotifier();
});
