import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:the_app/core/id.dart';
import 'package:the_app/data/app_storage.dart';
import 'package:the_app/models/todo_item.dart';
import 'package:the_app/providers/introduction_provider.dart';
import 'package:the_app/providers/preferences_provider.dart';

/// The to-do note's list (Round 28), saved to `todo.json`: one ordered
/// list; "to do" and "Completed" (Round 30) are its things filtered by
/// [TodoItem.done], in list order.
class TodoNotifier extends StateNotifier<List<TodoItem>> {
  TodoNotifier(AppStorage storage) : super(storage.initialTodo) {
    addListener(storage.saveTodo, fireImmediately: false);
  }

  /// Adds [text] at the end of the things to do and returns its id; blank
  /// text is ignored (null).
  String? add(String text) {
    final trimmed = text.trim();
    if (trimmed.isEmpty) return null;
    final item = TodoItem(id: generateId(), text: trimmed);
    state = [...state, item];
    return item.id;
  }

  /// Done, or not done again: to the top of *Completed* (done most
  /// recently), or back to the end of the things to do. As Shop's toggle.
  void toggle(String id) {
    final index = state.indexWhere((item) => item.id == id);
    if (index == -1) return;
    final moved = state[index].copyWith(done: !state[index].done);
    final others = [...state.take(index), ...state.skip(index + 1)];
    state = moved.done ? [moved, ...others] : [...others, moved];
  }

  /// Deletes the completed things; returns them (for Undo).
  List<TodoItem> deleteCompleted() {
    final done = [
      for (final item in state)
        if (item.done) item
    ];
    if (done.isNotEmpty) {
      state = [
        for (final i in state)
          if (!i.done) i,
      ];
    }
    return done;
  }

  /// A new text for [id]; blank text leaves it as it was.
  void edit(String id, String text) {
    final trimmed = text.trim();
    if (trimmed.isEmpty) return;
    state = [
      for (final item in state)
        if (item.id == id) item.copyWith(text: trimmed) else item,
    ];
  }

  /// Reorders within one list ([done] or not). [oldIndex] and [newIndex]
  /// are positions inside it, with `ReorderableListView.onReorder`
  /// semantics; the other list stays as it is.
  void reorder({
    required bool done,
    required int oldIndex,
    required int newIndex,
  }) {
    if (newIndex > oldIndex) newIndex--;
    if (oldIndex == newIndex) return;
    final section = state.where((i) => i.done == done).toList();
    section.insert(newIndex, section.removeAt(oldIndex));
    final reordered = section.iterator;
    state = [
      for (final item in state)
        if (item.done == done) (reordered..moveNext()).current else item,
    ];
  }

  /// Replaces everything (restoring a backup, clearing Notes, Undo).
  void replaceAll(List<TodoItem> items) => state = List.unmodifiable(items);
}

final todoProvider = StateNotifierProvider<TodoNotifier, List<TodoItem>>(
  (ref) => TodoNotifier(ref.watch(appStorageProvider)),
);

/// Whether the to-do note shows at the top of Notes: on in Settings, and,
/// like the Introduction, only in the app as started (or a test asking),
/// so most tests' Notes list holds only their own notes.
final todoShownProvider = Provider<bool>(
  (ref) =>
      ref.watch(introductionAvailableProvider) &&
      ref.watch(preferencesProvider.select((p) => p.todoNote)),
);
