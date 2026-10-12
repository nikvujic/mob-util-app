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

  /// Marks [dose] of [medicine] on [day] taken now, or unmarks it.
  void toggleDose(String medicine, DateTime day, int dose) {
    final mark = state.takenFor(medicine, day, dose);
    state = MedicineBook(
      medicines: state.medicines,
      taken: mark != null
          ? state.taken.where((t) => !identical(t, mark)).toList()
          : [
              ...state.taken,
              DoseTaken(medicine: medicine, day: day, dose: dose, at: _now()),
            ],
    );
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
