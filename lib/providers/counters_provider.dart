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

  /// Adds a counter at the end, starting at 0 (or the nearest limit).
  /// Blank names are ignored (null); otherwise returns its id.
  String? add(String name, {CounterOptions? options}) {
    final trimmed = (options?.name ?? name).trim();
    if (trimmed.isEmpty) return null;
    final counter = _withOptions(
      Counter(id: generateId(), name: trimmed),
      options,
    );
    state = [...state, counter.copyWith(value: counter.start)];
    return counter.id;
  }

  /// Changes a counter's name and options (O5); its value is kept, moved
  /// within the new limits if needed. A blank name keeps the old one.
  void edit(String id, CounterOptions options) => _update(id, (c) {
        final changed = _withOptions(c, options);
        return changed.copyWith(value: changed.clamped(c.value));
      });

  /// [counter] with [options]: a step of at least 1, and limits that make
  /// sense (a min above the max swaps them).
  static Counter _withOptions(Counter counter, CounterOptions? options) {
    if (options == null) return counter;
    var (min, max) = (options.min, options.max);
    if (min != null && max != null && min > max) (min, max) = (max, min);
    final name = options.name.trim();
    return Counter(
      id: counter.id,
      name: name.isEmpty ? counter.name : name,
      value: counter.value,
      step: options.step < 1 ? 1 : options.step,
      color: options.color,
      min: min,
      max: max,
    );
  }

  /// One tap: [direction] 1 counts up by the counter's step, -1 down,
  /// never past its limits (without limits it may go below 0).
  void step(String id, int direction) => _update(
        id,
        (c) => c.copyWith(value: c.clamped(c.value + direction * c.step)),
      );

  void rename(String id, String name) {
    final trimmed = name.trim();
    if (trimmed.isEmpty) return;
    _update(id, (c) => c.copyWith(name: trimmed));
  }

  void reset(Set<String> ids) {
    state = [
      for (final c in state)
        if (ids.contains(c.id)) c.copyWith(value: c.start) else c,
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
