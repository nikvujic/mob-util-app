import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:the_app/data/app_storage.dart';
import 'package:the_app/models/placard.dart';

/// Placard's text and count (O4), saved to `placard.json`.
class PlacardNotifier extends StateNotifier<Placard> {
  PlacardNotifier(AppStorage storage) : super(storage.initialPlacard) {
    addListener(storage.savePlacard, fireImmediately: false);
  }

  /// The largest count kept (it's shown big; nine digits fit).
  static const maxCount = 999999999;

  /// One more (holding the page).
  void count() {
    if (state.count < maxCount) state = state.copyWith(count: state.count + 1);
  }

  /// From the settings: a blank text goes back to the default one.
  void set({required String text, required int count}) {
    final trimmed = text.trim();
    state = Placard(
      text: trimmed.isEmpty ? Placard.defaultText : trimmed,
      count: count.clamp(0, maxCount),
    );
  }

  void replace(Placard placard) => state = placard;
}

final placardProvider = StateNotifierProvider<PlacardNotifier, Placard>(
  (ref) => PlacardNotifier(ref.watch(appStorageProvider)),
);
