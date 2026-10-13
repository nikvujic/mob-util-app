import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:the_app/core/app_info.dart';
import 'package:the_app/data/app_storage.dart';
import 'package:the_app/models/preferences.dart';

/// The user's preferences (theme, counter feedback). Saved on change.
class PreferencesNotifier extends StateNotifier<Preferences> {
  /// [started]: the app version this start is, which brings the
  /// Introduction up on a first start or an update (N16).
  PreferencesNotifier(AppStorage storage, {String? started})
      : super(
          started == null
              ? storage.initialPreferences
              : storage.initialPreferences.startedVersion(started),
        ) {
    addListener(storage.savePreferences, fireImmediately: false);
    // Kept at once, so the next start knows this version was seen.
    if (!identical(state, storage.initialPreferences)) {
      storage.savePreferences(state);
    }
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

  void setMedicineDot(bool on) => state = state.copyWith(medicineDot: on);

  /// The app started at [version] (N16): brings the Introduction up on
  /// a first start or an update.
  void startedVersion(String version) => state = state.startedVersion(version);

  /// Deletes the Introduction from Notes (false brings it back).
  void setIntroDeleted(bool deleted) =>
      state = state.copyWith(introDeleted: deleted);

  void setIntroOnUpdates(bool on) => state = state.copyWith(introOnUpdates: on);

  /// Greys out the password reset for a day (or until the next unlock).
  void blockReset(DateTime now) => state = state.copyWith(
        resetBlockedUntil: () => now.add(const Duration(days: 1)),
      );

  /// The app was unlocked: the reset may be used again.
  void unblockReset() {
    if (state.resetBlockedUntil != null) {
      state = state.copyWith(resetBlockedUntil: () => null);
    }
  }

  /// The Introduction was opened: no longer new.
  void readIntro() {
    if (state.introUnread) state = state.copyWith(introUnread: false);
  }

  /// Pauses medicine reminders and the dot through [day]; null resumes.
  void pauseMedicineUntil(DateTime? day) => state = state.copyWith(
        medicinePausedUntil: () =>
            day == null ? null : DateTime(day.year, day.month, day.day),
      );
}

final preferencesProvider =
    StateNotifierProvider<PreferencesNotifier, Preferences>(
  (ref) => PreferencesNotifier(
    ref.watch(appStorageProvider),
    started: ref.watch(startedVersionProvider),
  ),
);
