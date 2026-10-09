import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:the_app/core/id.dart';
import 'package:the_app/data/app_storage.dart';
import 'package:the_app/models/counter.dart';

/// Counters (O2), in user-defined order. Every change is saved to
/// [AppStorage].
class CountersNotifier extends StateNotifier<List<Counter>> {
  CountersNotifier(AppStorage storage) : super(storage.initialCounters) {
    addListener(storage.saveCounters, fireImmediately: false);
  }

  /// Adds a counter at 0, at the end. Blank names are ignored.
  void add(String name) {
    final trimmed = name.trim();
    if (trimmed.isEmpty) return;
    state = [...state, Counter(id: generateId(), name: trimmed)];
  }

  /// Adds [by] (negative to count down; values may go below 0).
  void step(String id, int by) =>
      _update(id, (c) => c.copyWith(value: c.value + by));

  void rename(String id, String name) {
    final trimmed = name.trim();
    if (trimmed.isEmpty) return;
    _update(id, (c) => c.copyWith(name: trimmed));
  }

  void reset(Set<String> ids) {
    state = [
      for (final c in state)
        if (ids.contains(c.id)) c.copyWith(value: 0) else c,
    ];
  }

  void remove(Set<String> ids) {
    state = state.where((c) => !ids.contains(c.id)).toList();
  }

  /// Replaces everything (used when restoring a backup).
  void replaceAll(List<Counter> counters) {
    state = List.unmodifiable(counters);
  }

  /// Indices follow `ReorderableListView.onReorder` semantics.
  void reorder(int oldIndex, int newIndex) {
    if (newIndex > oldIndex) newIndex--;
    if (oldIndex == newIndex) return;
    final counters = [...state];
    counters.insert(newIndex, counters.removeAt(oldIndex));
    state = counters;
  }

  void _update(String id, Counter Function(Counter) change) {
    state = [
      for (final c in state)
        if (c.id == id) change(c) else c,
    ];
  }
}

final countersProvider = StateNotifierProvider<CountersNotifier, List<Counter>>(
  (ref) => CountersNotifier(ref.watch(appStorageProvider)),
);
