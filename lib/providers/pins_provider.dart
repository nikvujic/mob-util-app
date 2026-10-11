import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:the_app/core/id.dart';
import 'package:the_app/data/app_storage.dart';
import 'package:the_app/models/planner_pin.dart';

/// Planner reminders (P14): a title at a time, no end. Saved to
/// `pins.json` on every change. Ticking one off deletes it ([remove]),
/// with [restore] to undo.
class PinsNotifier extends StateNotifier<List<PlannerPin>> {
  PinsNotifier(AppStorage storage) : super(storage.initialPins) {
    addListener(storage.savePins, fireImmediately: false);
  }

  /// Adds a reminder and returns its id; null for a blank title.
  String? add(DateTime day, String title, {required int time}) {
    final trimmed = title.trim();
    if (trimmed.isEmpty) return null;
    final pin = PlannerPin(
      id: generateId(),
      title: trimmed,
      day: day,
      time: time,
    );
    state = [...state, pin];
    return pin.id;
  }

  /// Changes a reminder's title and time; a blank title keeps the old one.
  void update(String id, {required String title, required int time}) {
    state = [
      for (final p in state)
        if (p.id == id)
          PlannerPin(
            id: id,
            title: title.trim().isEmpty ? p.title : title.trim(),
            day: p.day,
            time: time,
          )
        else
          p,
    ];
  }

  /// Deletes a reminder (also what ticking it off does) and returns it,
  /// for [restore].
  PlannerPin remove(String id) {
    final pin = state.firstWhere((p) => p.id == id);
    state = state.where((p) => p.id != id).toList();
    return pin;
  }

  /// Puts back a reminder [remove] took (undo).
  void restore(PlannerPin pin) {
    if (state.any((p) => p.id == pin.id)) return;
    state = [...state, pin];
  }

  /// Replaces everything (restoring a backup).
  void replaceAll(List<PlannerPin> pins) => state = List.unmodifiable(pins);
}

final pinsProvider = StateNotifierProvider<PinsNotifier, List<PlannerPin>>(
  (ref) => PinsNotifier(ref.watch(appStorageProvider)),
);
