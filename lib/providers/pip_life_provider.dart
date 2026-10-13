import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:the_app/data/app_storage.dart';
import 'package:the_app/models/pip_life.dart';

/// Pip, the pet (Round 34): an egg until hatched, then his birthday and
/// name. Saved to `pip.json`.
class PipLifeNotifier extends StateNotifier<PipLife> {
  PipLifeNotifier(AppStorage storage) : super(storage.initialPip) {
    addListener(storage.savePip, fireImmediately: false);
  }

  /// He's out, at [now]: that's his birthday. Once only.
  void hatch(DateTime now) {
    if (!state.hatched) state = state.copyWith(born: now);
  }

  /// A new name: trimmed, at most [maxName] letters; blank keeps his.
  static const maxName = 12;
  void rename(String name) {
    final trimmed = name.trim();
    if (trimmed.isEmpty) return;
    state = state.copyWith(
      name: trimmed.length > maxName ? trimmed.substring(0, maxName) : trimmed,
    );
  }

  /// Replaces him (restoring a backup).
  void replace(PipLife pip) => state = pip;
}

final pipLifeProvider = StateNotifierProvider<PipLifeNotifier, PipLife>(
  (ref) => PipLifeNotifier(ref.watch(appStorageProvider)),
);
