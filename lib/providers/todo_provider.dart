import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:the_app/core/id.dart';
import 'package:the_app/data/app_storage.dart';
import 'package:the_app/models/todo_item.dart';
import 'package:the_app/providers/introduction_provider.dart';
import 'package:the_app/providers/preferences_provider.dart';

/// The to-do note's list (Round 28), saved to `todo.json`: one ordered
/// list; "to do" and "Completed" (Round 30) are its things filtered by
/// [TodoItem.done], in list order, and "Waiting" (Round 45, when on) the
/// ones to do that are [TodoItem.waiting].
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

  /// Where each thing done was among the things to do (Round 83): its
  /// place, whether it was waiting, and the things to do as they were
  /// left (ids, waiting or not). Kept while the app runs.
  final _left = <String, (int, bool, List<(String, bool)>)>{};

  /// The things to do as they are: ids, waiting or not.
  List<(String, bool)> get _toDo => [
        for (final item in state)
          if (!item.done) (item.id, item.waiting),
      ];

  /// Done, or not done again: to the top of *Completed* (done most
  /// recently), or back to the end of the things to do. As Shop's toggle.
  /// Done, it's no longer waiting. Round 83 (Nikola): not done again,
  /// it goes back where it was (waiting again, if it was), unless the
  /// things to do changed since.
  void toggle(String id) {
    final index = state.indexWhere((item) => item.id == id);
    if (index == -1) return;
    final item = state[index];
    final others = [...state.take(index), ...state.skip(index + 1)];
    if (!item.done) {
      final toDo = _toDo;
      final at = toDo.indexWhere((t) => t.$1 == id);
      toDo.removeAt(at);
      _left[id] = (at, item.waiting, toDo);
      state = [item.copyWith(done: true, waiting: false), ...others];
      return;
    }
    final undone = item.copyWith(done: false, waiting: false);
    state = others;
    final left = _left.remove(id);
    if (left case (final at, final waiting, final toDo)
        when _same(toDo, _toDo)) {
      final back = undone.copyWith(waiting: waiting);
      // Before the thing to do that followed it (at the end: none did).
      final next = at < toDo.length
          ? others.indexWhere((i) => i.id == toDo[at].$1)
          : others.length;
      state = [...others.take(next), back, ...others.skip(next)];
    } else {
      state = [...others, undone];
    }
  }

  static bool _same(List<(String, bool)> a, List<(String, bool)> b) =>
      a.length == b.length &&
      [for (var i = 0; i < a.length; i++) a[i] == b[i]].every((s) => s);

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

  /// The things to do placed anew (Round 45: dragged within or between
  /// *To do* and *Waiting*): [toDo] then [waiting], by id, in order; each
  /// waiting or not by its list. Completed ones stay as they are; ids not
  /// given (or done) are left out of the move, kept after.
  void place({required List<String> toDo, required List<String> waiting}) {
    final byId = {
      for (final item in state)
        if (!item.done) item.id: item
    };
    final placed = <TodoItem>[
      for (final id in toDo)
        if (byId.remove(id) case final item?) item.copyWith(waiting: false),
      for (final id in waiting)
        if (byId.remove(id) case final item?) item.copyWith(waiting: true),
    ];
    state = [
      ...placed,
      for (final item in state)
        if (item.done || byId.containsKey(item.id)) item,
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
