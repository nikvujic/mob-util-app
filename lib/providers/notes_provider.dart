import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:the_app/models/note.dart';

class NotesNotifier extends StateNotifier<List<Note>> {
  NotesNotifier()
      : super([]);
  
  String createNewNote() {
    final newNote = Note(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      title: 'New Note',
      content: '',
      createdAt: DateTime.now(),
      modifiedAt: DateTime.now(),
    );

    state = [...state, newNote];
    return newNote.id;
  }

  void updateNote(
    String id, {
      String? title,
      String? content
    }) {
      state = [
        for (final note in state)
          if (note.id == id)
            note.copyWith(
              title: title ?? note.title,
              content: content ?? note.content,
              modifiedAt: DateTime.now()
            )
          else
            note
      ];
  }

  void removeNote(String id) {
    state = state.where((note) => note.id != id).toList();
  }
}

final notesProvider =
    StateNotifierProvider<NotesNotifier, List<Note>>((ref) {
  return NotesNotifier();
});