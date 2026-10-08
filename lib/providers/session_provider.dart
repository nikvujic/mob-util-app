import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:the_app/core/clock.dart';
import 'package:the_app/core/crypto.dart';
import 'package:the_app/providers/security_provider.dart';

/// The keys available while unlocked: the key derived from the master
/// password (e.g. for encrypted backups) and the data key it protects (for
/// locked notes).
class UnlockedKeys {
  final PasswordKey passwordKey;
  final DataKey dataKey;

  const UnlockedKeys(this.passwordKey, this.dataKey);
}

/// The unlocked session (L4): after entering the master password once,
/// everything protected by it is available without asking again.
///
/// State: the unlocked keys, or null when locked.
/// It lives in memory only, so closing the app (or Android ending it)
/// always locks. It also locks after [autoLockAfter] in the background,
/// on [lock], and whenever the master password changes or is removed.
class SessionNotifier extends StateNotifier<UnlockedKeys?> {
  static const autoLockAfter = Duration(minutes: 5);

  final Ref _ref;

  /// When the app went to the background, while it is there.
  DateTime? _hiddenAt;

  SessionNotifier(this._ref) : super(null) {
    // Keys of an old password must never outlive it. (Adding a data key
    // to the same password keeps its parameters, so that doesn't lock.)
    _ref.listen(securityProvider, (previous, next) {
      if (!identical(previous?.params, next?.params)) lock();
    });
  }

  bool get isUnlocked => state != null;

  /// Unlocks with the master password. False if it's wrong or none is set.
  Future<bool> unlock(String password) async {
    final verifier = _ref.read(securityProvider);
    if (verifier == null) return false;
    final key = await verifier.unlock(password);
    if (key == null) return false;
    return unlockWith(key);
  }

  /// Unlocks with a key the caller already derived from the master
  /// password (e.g. via a password prompt), so it isn't derived twice.
  /// False if it isn't the current password's key.
  ///
  /// A master password from before data keys existed gets its data key
  /// here, the first time it's unlocked.
  Future<bool> unlockWith(PasswordKey key) async {
    final verifier = _ref.read(securityProvider);
    if (verifier == null || !identical(key.params, verifier.params)) {
      return false;
    }
    var dataKey = await verifier.unwrapDataKey(key);
    if (dataKey == null) {
      if (verifier.hasDataKey) return false; // doesn't fit: not this key
      dataKey = DataKey.generate();
      _ref
          .read(securityProvider.notifier)
          .addDataKey(await verifier.withDataKey(dataKey, key));
    }
    // The password may have changed while this was running.
    if (!identical(_ref.read(securityProvider)?.params, key.params)) {
      return false;
    }
    state = UnlockedKeys(key, dataKey);
    return true;
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
    StateNotifierProvider<SessionNotifier, UnlockedKeys?>(SessionNotifier.new);
