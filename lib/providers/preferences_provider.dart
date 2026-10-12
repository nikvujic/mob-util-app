import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:the_app/data/app_storage.dart';
import 'package:the_app/models/preferences.dart';

/// The user's preferences (theme, counter feedback). Saved on change.
class PreferencesNotifier extends StateNotifier<Preferences> {
  PreferencesNotifier(AppStorage storage) : super(storage.initialPreferences) {
    addListener(storage.savePreferences, fireImmediately: false);
  }

  void setTheme(String theme) => state = state.copyWith(theme: theme);

  void setCounterFeedback(bool on) =>
      state = state.copyWith(counterFeedback: on);

  void setNoteLineNumbers(bool on) =>
      state = state.copyWith(noteLineNumbers: on);

  /// Which master password's key the fingerprint opens (L6); null: off.
  void setFingerprintFor(String? salt) =>
      state = state.copyWith(fingerprintFor: () => salt);

  void setMedicineReminders(bool on) =>
      state = state.copyWith(medicineReminders: on);

  /// Minutes after the dose to remind again; null: off.
  void setMedicineFollowUp(int? minutes) =>
      state = state.copyWith(medicineFollowUp: () => minutes);

  void setMedicineDot(bool on) => state = state.copyWith(medicineDot: on);

  /// Pauses medicine reminders and the dot through [day]; null resumes.
  void pauseMedicineUntil(DateTime? day) => state = state.copyWith(
        medicinePausedUntil: () =>
            day == null ? null : DateTime(day.year, day.month, day.day),
      );
}

final preferencesProvider =
    StateNotifierProvider<PreferencesNotifier, Preferences>(
  (ref) => PreferencesNotifier(ref.watch(appStorageProvider)),
);
