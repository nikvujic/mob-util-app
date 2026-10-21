import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:the_app/core/id.dart';
import 'package:the_app/data/app_storage.dart';
import 'package:the_app/models/packing.dart';

/// Packing (Round 94), saved to `packing.json`: the lists, in the user's
/// order, and the default sections a new one starts with.
class PackingNotifier extends StateNotifier<PackingBook> {
  PackingNotifier(AppStorage storage) : super(storage.initialPacking) {
    addListener(storage.savePacking, fireImmediately: false);
  }

  PackingList? byId(String id) => state.byId(id);

  /// A new list, not kept yet ([save] keeps it, at the top), with the
  /// default sections.
  PackingList draft() =>
      PackingList(id: generateId(), name: '', sections: state.sections);

  /// [list] as it is now (from its editor, or ticked); a new one goes on
  /// top.
  void save(PackingList list) {
    final old = byId(list.id);
    if (identical(old, list)) return;
    state = old == null
        ? state.copyWith(lists: [list, ...state.lists])
        : state.withList(list);
  }

  /// [itemId] in [listId] ticked, or unticked.
  void toggle(String listId, String itemId) {
    final list = byId(listId);
    if (list == null) return;
    state = state.withList(list.toggled(itemId));
  }

  /// Everything in [listId] unticked.
  void reset(String listId) {
    final list = byId(listId);
    if (list == null) return;
    state = state.withList(list.reset());
  }

  /// A copy of [id] called [name], just below it, with only its sections
  /// [sectionIds] and their things, none ticked; returns its id.
  String? copy(String id, String name, Set<String> sectionIds) {
    final index = state.lists.indexWhere((l) => l.id == id);
    if (index == -1) return null;
    final from = state.lists[index];
    final groups = [
      for (final g in from.grouped())
        if (sectionIds.contains(g.$1.id)) g,
    ];
    final copy = PackingList(
      id: generateId(),
      name: name,
      // At least one, as every list.
      sections: groups.isEmpty
          ? [from.sections.first]
          : [for (final (s, _) in groups) s],
      items: [
        for (final (section, items) in groups)
          for (final i in items)
            i.copyWith(id: generateId(), sectionId: section.id, packed: false),
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

  // The default sections (Round 95): what a new list starts with; the
  // lists there are keep their own.

  /// A new default section called [name], last; returns its id.
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

  /// Default section [id] deleted (not the last one); returns the
  /// sections as they were (for Undo), or null if it stayed.
  List<PackingSection>? removeSection(String id) {
    if (state.sections.length <= 1) return null;
    final before = state.sections;
    state = state.copyWith(sections: [
      for (final s in state.sections)
        if (s.id != id) s,
    ]);
    return before;
  }

  /// The default sections reordered (`onReorder` semantics).
  void reorderSections(int oldIndex, int newIndex) {
    final list = [...state.sections];
    if (oldIndex < 0 || oldIndex >= list.length) return;
    if (newIndex > oldIndex) newIndex--;
    newIndex = newIndex.clamp(0, list.length - 1);
    if (oldIndex == newIndex) return;
    list.insert(newIndex, list.removeAt(oldIndex));
    state = state.copyWith(sections: list);
  }

  void restoreSections(List<PackingSection> sections) =>
      state = state.copyWith(sections: sections);

  /// Replaces everything (restoring a backup, Clear data).
  void replaceAll(PackingBook book) => state = book;
}

final packingProvider = StateNotifierProvider<PackingNotifier, PackingBook>(
  (ref) => PackingNotifier(ref.watch(appStorageProvider)),
);
