import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:the_app/core/id.dart';
import 'package:the_app/data/app_storage.dart';
import 'package:the_app/models/todo_item.dart';
import 'package:the_app/providers/introduction_provider.dart';
import 'package:the_app/providers/preferences_provider.dart';

/// The to-do note's list (Round 28), in order, saved to `todo.json`.
class TodoNotifier extends StateNotifier<List<TodoItem>> {
  TodoNotifier(AppStorage storage) : super(storage.initialTodo) {
    addListener(storage.saveTodo, fireImmediately: false);
  }

  /// Adds [text] at the end and returns its id; blank text is ignored
  /// (null).
  String? add(String text) {
    final trimmed = text.trim();
    if (trimmed.isEmpty) return null;
    final item = TodoItem(id: generateId(), text: trimmed);
    state = [...state, item];
    return item.id;
  }

  /// Done: takes it off the list. Returns where it was, to [restore] it
  /// (Undo); null if it's not there.
  int? complete(String id) {
    final index = state.indexWhere((item) => item.id == id);
    if (index == -1) return null;
    state = [...state.take(index), ...state.skip(index + 1)];
    return index;
  }

  /// Puts [item] back at [index] (or the end, if the list got shorter).
  void restore(TodoItem item, int index) {
    if (state.any((i) => i.id == item.id)) return;
    final at = index.clamp(0, state.length);
    state = [...state.take(at), item, ...state.skip(at)];
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

  /// Follows `ReorderableListView.onReorder` semantics.
  void reorder(int oldIndex, int newIndex) {
    if (newIndex > oldIndex) newIndex--;
    if (oldIndex == newIndex) return;
    final items = [...state];
    items.insert(newIndex, items.removeAt(oldIndex));
    state = items;
  }

  /// Replaces everything (restoring a backup, clearing Notes).
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
