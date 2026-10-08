import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:the_app/core/clock.dart';
import 'package:the_app/core/crypto.dart';
import 'package:the_app/providers/security_provider.dart';

/// The unlocked session (L4): after entering the master password once,
/// everything protected by it is available without asking again.
///
/// State: the key derived from the master password, or null when locked.
/// It lives in memory only, so closing the app (or Android ending it)
/// always locks. It also locks after [autoLockAfter] in the background,
/// on [lock], and whenever the master password changes or is removed.
class SessionNotifier extends StateNotifier<PasswordKey?> {
  static const autoLockAfter = Duration(minutes: 5);

  final Ref _ref;

  /// When the app went to the background, while it is there.
  DateTime? _hiddenAt;

  SessionNotifier(this._ref) : super(null) {
    // A key from an old password must never outlive it.
    _ref.listen(securityProvider, (previous, next) {
      if (!identical(previous, next)) lock();
    });
  }

  bool get isUnlocked => state != null;

  /// Unlocks with the master password. False if it's wrong or none is set.
  Future<bool> unlock(String password) async {
    final verifier = _ref.read(securityProvider);
    if (verifier == null) return false;
    final key = await verifier.unlock(password);
    if (key == null || verifier != _ref.read(securityProvider)) return false;
    state = key;
    return true;
  }

  /// Unlocks with a key the caller already derived from the master
  /// password (e.g. via a password prompt), so it isn't derived twice.
  void unlockWith(PasswordKey key) {
    final verifier = _ref.read(securityProvider);
    if (verifier != null && identical(key.params, verifier.params)) {
      state = key;
    }
  }

  void lock() {
    state = null;
    _hiddenAt = null;
  }

  /// The app went to the background (another app, home, screen off).
  void appHidden() {
    _hiddenAt ??= _ref.read(clockProvider)();
  }

  /// The app is visible again: lock if it was away too long.
  void appShown() {
    final hiddenAt = _hiddenAt;
    _hiddenAt = null;
    if (hiddenAt == null) return;
    final away = _ref.read(clockProvider)().difference(hiddenAt);
    if (away >= autoLockAfter) lock();
  }
}

final sessionProvider =
    StateNotifierProvider<SessionNotifier, PasswordKey?>(SessionNotifier.new);
