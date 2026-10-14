import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:the_app/core/app_info.dart';
import 'package:the_app/core/clock.dart';
import 'package:the_app/data/app_storage.dart';
import 'package:the_app/models/notify_settings.dart';
import 'package:the_app/models/preferences.dart';

/// The user's preferences (theme, counter feedback). Saved on change.
class PreferencesNotifier extends StateNotifier<Preferences> {
  /// [started]: the app version this start is, which brings the
  /// Introduction up on a first start or an update (N16); [now], when it
  /// started (the backup reminder counts from the first one, D8).
  PreferencesNotifier(AppStorage storage, {String? started, DateTime? now})
      : super(
          started == null
              ? storage.initialPreferences
              : storage.initialPreferences
                  .startedVersion(started)
                  .startedAt(now ?? DateTime.now()),
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

  /// The app started at [version] (N16): brings the Introduction up on
  /// a first start or an update.
  void startedVersion(String version) => state = state.startedVersion(version);

  /// Deletes the Introduction from Notes (false brings it back).
  void setIntroDeleted(bool deleted) => state = state.copyWith(
        introDeleted: deleted,
        // Restored: from the top (Round 29).
        introScroll: deleted ? null : 0,
      );

  /// Where the Introduction was left, scrolled (Round 29).
  void setIntroScroll(double offset) {
    if (offset != state.introScroll) {
      state = state.copyWith(introScroll: offset);
    }
  }

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

  /// A backup was exported at [at] (D8): the reminder counts from it.
  void backedUp(DateTime at) => state = state.copyWith(lastBackupAt: () => at);

  void setBackupReminder(bool on) => state = state.copyWith(backupReminder: on);

  /// The to-do note on or off (Round 28).
  void setTodoNote(bool on) => state = state.copyWith(todoNote: on);

  void setPipBackground(String id) => state = state.copyWith(pipBackground: id);

  /// The Introduction was opened: no longer new.
  void readIntro() {
    if (state.introUnread) state = state.copyWith(introUnread: false);
  }

  /// The planner's notifications on or off (Round 31).
  void setPlannerReminders(bool on) =>
      state = state.copyWith(plannerReminders: on);

  /// Pauses the planner's notifications through [day]; null resumes.
  void pausePlannerUntil(DateTime? day) => state = state.copyWith(
        plannerPausedUntil: () =>
            day == null ? null : DateTime(day.year, day.month, day.day),
      );

  /// How [page]'s notifications look and sound (Round 31).
  void setNotifyStyle(NotifyPage page, NotifyStyle style) =>
      state = state.copyWith(
        notifyStyles: {...state.notifyStyles, page: style},
      );

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
    now: ref.read(clockProvider)(),
  ),
);
