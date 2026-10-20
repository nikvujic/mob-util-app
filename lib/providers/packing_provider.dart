import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:the_app/core/id.dart';
import 'package:the_app/data/app_storage.dart';
import 'package:the_app/models/packing.dart';

/// Packing (Round 94), saved to `packing.json`: the lists, in the user's
/// order, and the sections they share.
class PackingNotifier extends StateNotifier<PackingBook> {
  PackingNotifier(AppStorage storage) : super(storage.initialPacking) {
    addListener(storage.savePacking, fireImmediately: false);
  }

  PackingList? byId(String id) => state.byId(id);

  /// A new, empty list at the top; returns its id.
  String add() {
    final list = PackingList(id: generateId(), name: '');
    state = state.copyWith(lists: [list, ...state.lists]);
    return list.id;
  }

  /// [list] as it is now (from its editor, or ticked).
  void save(PackingList list) {
    final old = byId(list.id);
    if (old == null || identical(old, list)) return;
    state = state.withList(list);
  }

  /// [itemId] in [listId] ticked, or unticked.
  void toggle(String listId, String itemId) {
    final list = byId(listId);
    if (list == null) return;
    state = state.withList(list.toggled(itemId));
  }

  /// Everything in [listId] unticked; returns it as it was (for Undo).
  PackingList? reset(String listId) {
    final list = byId(listId);
    if (list == null) return null;
    state = state.withList(list.reset());
    return list;
  }

  /// A copy of [id] called [name], just below it, with only its items in
  /// [sectionIds], none ticked; returns its id.
  String? copy(String id, String name, Set<String> sectionIds) {
    final index = state.lists.indexWhere((l) => l.id == id);
    if (index == -1) return null;
    final copy = PackingList(
      id: generateId(),
      name: name,
      items: [
        // As shown: one whose section is gone is in Other.
        for (final (section, items)
            in state.lists[index].grouped(state.sections))
          if (sectionIds.contains(section.id))
            for (final i in items)
              i.copyWith(
                  id: generateId(), sectionId: section.id, packed: false),
      ],
    );
    state = state.copyWith(lists: [
      ...state.lists.take(index + 1),
      copy,
      ...state.lists.skip(index + 1),
    ]);
    return copy.id;
  }

  /// Removes [ids]; returns what was removed with where it was (for Undo).
  List<(int, PackingList)> remove(Set<String> ids) {
    final removed = [
      for (var i = 0; i < state.lists.length; i++)
        if (ids.contains(state.lists[i].id)) (i, state.lists[i]),
    ];
    if (removed.isNotEmpty) {
      state = state.copyWith(lists: [
        for (final l in state.lists)
          if (!ids.contains(l.id)) l,
      ]);
    }
    return removed;
  }

  /// Puts back what [remove] removed, where it was.
  void undoRemove(List<(int, PackingList)> removed) {
    final lists = [...state.lists];
    for (final (index, list) in removed) {
      if (lists.any((l) => l.id == list.id)) continue;
      lists.insert(index.clamp(0, lists.length), list);
    }
    state = state.copyWith(lists: lists);
  }

  /// `ReorderableListView.onReorder` semantics.
  void reorder(int oldIndex, int newIndex) {
    if (newIndex > oldIndex) newIndex--;
    if (oldIndex == newIndex) return;
    final lists = [...state.lists];
    lists.insert(newIndex, lists.removeAt(oldIndex));
    state = state.copyWith(lists: lists);
  }

  // The sections every list shares.

  /// A new section called [name], last before Other; returns its id.
  String addSection(String name) {
    final section = PackingSection(id: generateId(), name: name.trim());
    state = state.copyWith(sections: [...state.sections, section]);
    return section.id;
  }

  void renameSection(String id, String name) {
    state = state.copyWith(sections: [
      for (final s in state.sections)
        if (s.id == id) s.copyWith(name: name.trim()) else s,
    ]);
  }

  /// Section [id] deleted, its items moved to Other; returns the book as
  /// it was (for Undo).
  PackingBook removeSection(String id) {
    final before = state;
    state = state.withoutSection(id);
    return before;
  }

  /// Sections reordered (`onReorder` semantics), Other not among them:
  /// it stays last.
  void reorderSections(int oldIndex, int newIndex) {
    final movable = [
      for (final s in state.sections)
        if (!s.isOther) s,
    ];
    if (oldIndex < 0 || oldIndex >= movable.length) return;
    if (newIndex > oldIndex) newIndex--;
    newIndex = newIndex.clamp(0, movable.length - 1);
    if (oldIndex == newIndex) return;
    movable.insert(newIndex, movable.removeAt(oldIndex));
    state = state.copyWith(sections: movable);
  }

  /// Replaces everything (restoring a backup, Clear data, Undo).
  void replaceAll(PackingBook book) => state = book;
}

final packingProvider = StateNotifierProvider<PackingNotifier, PackingBook>(
  (ref) => PackingNotifier(ref.watch(appStorageProvider)),
);
