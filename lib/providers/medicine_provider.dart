import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:the_app/core/clock.dart';
import 'package:the_app/core/id.dart';
import 'package:the_app/data/app_storage.dart';
import 'package:the_app/models/medicine.dart';

/// The medicine tracker (O6): medicines and the doses marked taken, saved
/// to `medicine.json` on every change.
class MedicineNotifier extends StateNotifier<MedicineBook> {
  final DateTime Function() _now;

  MedicineNotifier(AppStorage storage, this._now)
      : super(storage.initialMedicine) {
    addListener(storage.saveMedicine, fireImmediately: false);
  }

  /// Adds a medicine and returns its id; null for a blank name or no
  /// times.
  String? add(
    String name, {
    required List<int> times,
    required DateTime from,
    DateTime? until,
  }) {
    final trimmed = name.trim();
    if (trimmed.isEmpty || times.isEmpty) return null;
    final medicine = Medicine(
      id: generateId(),
      name: trimmed,
      times: times,
      from: from,
      until: until,
    );
    state = MedicineBook(
      medicines: [...state.medicines, medicine],
      taken: state.taken,
    );
    return medicine.id;
  }

  /// Changes a medicine; its history stays. Doses it no longer has (fewer
  /// a day now) keep their marks on the days they were taken.
  void update(
    String id, {
    required String name,
    required List<int> times,
    required DateTime from,
    DateTime? until,
  }) {
    if (times.isEmpty) return;
    state = MedicineBook(
      medicines: [
        for (final m in state.medicines)
          if (m.id == id)
            Medicine(
              id: id,
              name: name.trim().isEmpty ? m.name : name.trim(),
              times: times,
              from: from,
              until: until,
            )
          else
            m,
      ],
      taken: state.taken,
    );
  }

  /// Deletes a medicine and its history; returns what's needed to undo.
  MedicineBook remove(String id) {
    final before = state;
    state = MedicineBook(
      medicines: state.medicines.where((m) => m.id != id).toList(),
      taken: state.taken.where((t) => t.medicine != id).toList(),
    );
    return before;
  }

  /// Moves a medicine among [shown] (the ids in the order they're listed,
  /// e.g. today's), from [oldIndex] to [newIndex]
  /// (`ReorderableListView.onReorder` style); the others keep their places.
  void reorder(List<String> shown, int oldIndex, int newIndex) {
    if (newIndex > oldIndex) newIndex--;
    if (oldIndex == newIndex) return;
    final moved = [...shown];
    moved.insert(newIndex, moved.removeAt(oldIndex));
    final next = moved.iterator;
    final byId = {for (final m in state.medicines) m.id: m};
    state = MedicineBook(
      medicines: [
        for (final m in state.medicines)
          if (shown.contains(m.id)) byId[(next..moveNext()).current]! else m,
      ],
      taken: state.taken,
    );
  }

  /// Marks [dose] of [medicine] on [day] taken now, or unmarks it (a
  /// dose set missed or not sure is marked taken).
  void toggleDose(String medicine, DateTime day, int dose) {
    final taken = state.takenFor(medicine, day, dose) != null;
    setDose(medicine, day, dose, taken ? null : DoseState.taken);
  }

  /// Sets what became of [dose] of [medicine] on [day] (from the
  /// history, O13); null: no mark. Taken now stamps the time, unless
  /// it's for another day (set afterwards: no time).
  void setDose(String medicine, DateTime day, int dose, DoseState? to) {
    final now = _now();
    final sameDay =
        now.year == day.year && now.month == day.month && now.day == day.day;
    state = MedicineBook(
      medicines: state.medicines,
      taken: [
        for (final t in state.taken)
          if (!t.isFor(medicine, day, dose)) t,
        if (to != null)
          DoseTaken(
            medicine: medicine,
            day: day,
            dose: dose,
            state: to,
            at: to == DoseState.taken && sameDay ? now : null,
          ),
      ],
    );
  }

  /// Marks every dose of [medicine] from its start up to yesterday taken
  /// where nothing is set yet (O13: starting in the past, then setting
  /// the odd missed day). Returns how many it marked.
  int fillPast(String medicine) {
    final m = state.medicines.where((m) => m.id == medicine).firstOrNull;
    if (m == null) return 0;
    final today = _now();
    final added = <DoseTaken>[];
    for (var d = m.from;
        d.isBefore(DateTime(today.year, today.month, today.day));
        d = DateTime(d.year, d.month, d.day + 1)) {
      if (!m.isOn(d)) continue;
      for (var dose = 0; dose < m.dosesADay; dose++) {
        if (state.markFor(medicine, d, dose) == null) {
          added.add(DoseTaken(medicine: medicine, day: d, dose: dose));
        }
      }
    }
    if (added.isEmpty) return 0;
    state = MedicineBook(
      medicines: state.medicines,
      taken: [...state.taken, ...added],
    );
    return added.length;
  }

  /// Replaces everything (a backup restored, an undo, Clear data).
  void replaceAll(MedicineBook book) => state = book;
}

final medicineProvider = StateNotifierProvider<MedicineNotifier, MedicineBook>(
  (ref) => MedicineNotifier(
    ref.watch(appStorageProvider),
    ref.watch(clockProvider),
  ),
);
