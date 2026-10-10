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

  /// Sets the Džoni count (restoring a backup).
  void setDzoniCount(int count) => state = state.copyWith(dzoniCount: count);

  /// Which master password's key the fingerprint opens (L6); null: off.
  void setFingerprintFor(String? salt) =>
      state = state.copyWith(fingerprintFor: () => salt);

  void countDzoni() => state = state.copyWith(dzoniCount: state.dzoniCount + 1);
}

final preferencesProvider =
    StateNotifierProvider<PreferencesNotifier, Preferences>(
  (ref) => PreferencesNotifier(ref.watch(appStorageProvider)),
);
