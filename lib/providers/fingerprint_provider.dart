import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:the_app/core/crypto.dart';
import 'package:the_app/data/fingerprint_vault.dart';
import 'package:the_app/providers/preferences_provider.dart';
import 'package:the_app/providers/security_provider.dart';
import 'package:the_app/providers/session_provider.dart';

/// Unlocking with a fingerprint instead of typing the master password (L6).
/// State: whether it's on for the current master password.
///
/// The key derived from the master password is kept in the phone's
/// keystore ([FingerprintVault]), which releases it only for a fingerprint;
/// the password itself is never stored. Which password the key belongs to
/// is noted (its salt, in the preferences), so a key of an earlier password
/// is never used: changing, removing or resetting the password turns
/// fingerprint unlock off and clears the stored key.
class FingerprintNotifier extends StateNotifier<bool> {
  final Ref _ref;

  FingerprintNotifier(this._ref) : super(false) {
    state = _storedFor(_ref.read(securityProvider));
    if (!state && _ref.read(preferencesProvider).fingerprintFor != null) {
      // Stored for an earlier password: clear it (just after this
      // provider is set up, which mustn't change others).
      Future.microtask(turnOff);
    }
    _ref.listen(securityProvider, (previous, next) {
      if (!identical(previous?.params, next?.params) && state) turnOff();
    });
  }

  FingerprintVault get _vault => _ref.read(fingerprintVaultProvider);

  static String _saltOf(PasswordVerifier verifier) =>
      base64Encode(verifier.params.salt);

  /// Whether the stored key belongs to [verifier]'s password.
  bool _storedFor(PasswordVerifier? verifier) {
    final storedFor = _ref.read(preferencesProvider).fingerprintFor;
    return verifier != null &&
        storedFor != null &&
        storedFor == _saltOf(verifier);
  }

  /// Whether this phone can do it (a fingerprint enrolled).
  Future<bool> isAvailable() => _vault.isAvailable();

  /// Turns it on: stores the key of the unlocked session, after a
  /// fingerprint. False if that was cancelled or failed. Needs the app
  /// unlocked.
  Future<bool> turnOn() async {
    final keys = _ref.read(sessionProvider);
    final verifier = _ref.read(securityProvider);
    if (keys == null || verifier == null) {
      throw StateError('Fingerprint unlock needs the app unlocked');
    }
    final secret = jsonEncode({
      'version': 1,
      'salt': _saltOf(verifier),
      'key': base64Encode(await keys.passwordKey.exportForKeystore()),
    });
    if (!await _vault.store(secret)) return false;
    // The password may have changed meanwhile: then the key is stale.
    if (!identical(_ref.read(securityProvider)?.params, verifier.params)) {
      await _vault.clear();
      return false;
    }
    _ref.read(preferencesProvider.notifier).setFingerprintFor(
          _saltOf(verifier),
        );
    state = true;
    return true;
  }

  /// Turns it off and clears the stored key.
  Future<void> turnOff() async {
    state = false;
    _ref.read(preferencesProvider.notifier).setFingerprintFor(null);
    await _vault.clear();
  }

  /// Asks for a fingerprint and unlocks the app with the stored key.
  /// Null if it's off, cancelled, or the stored key no longer works (then
  /// it's turned off: e.g. a new fingerprint was enrolled, which voids it).
  Future<UnlockedKeys?> unlock() async {
    if (!state) return null;
    final read = await _vault.read();
    switch (read) {
      case VaultCancelled():
        return null;
      case VaultBroken():
        await turnOff();
        return null;
      case VaultOpened(:final secret):
        final keys = await _unlockWith(secret);
        if (keys == null) await turnOff();
        return keys;
    }
  }

  Future<UnlockedKeys?> _unlockWith(String secret) async {
    final verifier = _ref.read(securityProvider);
    if (verifier == null) return null;
    try {
      final stored = jsonDecode(secret) as Map<String, dynamic>;
      if (stored['salt'] != _saltOf(verifier)) return null;
      final key = PasswordKey.restore(
        verifier.params,
        base64Decode(stored['key'] as String),
      );
      final session = _ref.read(sessionProvider.notifier);
      return await session.unlockWith(key) ? _ref.read(sessionProvider) : null;
    } on Object {
      return null; // not what was stored: unusable
    }
  }
}

final fingerprintProvider =
    StateNotifierProvider<FingerprintNotifier, bool>(FingerprintNotifier.new);
