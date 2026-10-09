import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:the_app/core/crypto.dart';
import 'package:the_app/data/app_storage.dart';

/// Rules for choosing a master password.
abstract final class MasterPasswordRules {
  static const minLength = 8;

  /// An error message for an unacceptable new password, or null if it's OK.
  static String? validate(String password) {
    if (password.length < minLength) {
      return 'Use at least $minLength characters';
    }
    if (password.trim().isEmpty) return 'The password can\'t be only spaces';
    return null;
  }
}

/// Thrown when the current master password given is wrong.
class WrongPasswordException implements Exception {
  const WrongPasswordException();
}

/// The master password (L1–L3). State: its verifier (which also holds the
/// wrapped data key), or null if none is set. The password itself is never kept — not even in memory after an
/// operation finishes.
class SecurityNotifier extends StateNotifier<PasswordVerifier?> {
  final AppStorage _storage;

  SecurityNotifier(this._storage) : super(_storage.initialMasterPassword) {
    addListener(_storage.saveMasterPassword, fireImmediately: false);
  }

  bool get hasMasterPassword => state != null;

  /// Sets the master password. Only when none is set yet. Returns its key,
  /// so the caller can unlock without deriving it again.
  Future<PasswordKey> setPassword(String password) async {
    _checkNew(password);
    if (state != null) throw StateError('A master password is already set');
    final (verifier, key, _) = await PasswordVerifier.create(password);
    state = verifier;
    return key;
  }

  /// Replaces the master password. Throws [WrongPasswordException] if
  /// [current] is wrong (and changes nothing).
  ///
  /// The data key stays the same — it's only re-wrapped with the new
  /// password — so everything it protects stays readable, and the change is
  /// a single write of the security file.
  Future<void> changePassword(String current, String newPassword) async {
    _checkNew(newPassword);
    final key = await _unlock(current);
    final dataKey = await state!.unwrapDataKey(key);
    final (verifier, _, _) = await PasswordVerifier.create(
      newPassword,
      dataKey: dataKey,
    );
    state = verifier;
  }

  /// Stores [verifier] if it's the current master password with a data key
  /// added (see [PasswordVerifier.withDataKey]); used to upgrade records
  /// from before data keys existed.
  void addDataKey(PasswordVerifier verifier) {
    final current = state;
    if (current != null &&
        identical(verifier.params, current.params) &&
        !current.hasDataKey &&
        verifier.hasDataKey) {
      state = verifier;
    }
  }

  /// Removes the master password. Throws [WrongPasswordException] if
  /// [current] is wrong (and changes nothing).
  Future<void> removePassword(String current) async {
    await _unlock(current);
    state = null;
  }

  /// The key for [password]; throws [WrongPasswordException] if it's wrong.
  Future<PasswordKey> _unlock(String password) async {
    final verifier = state;
    if (verifier == null) throw StateError('No master password is set');
    final key = await verifier.unlock(password);
    if (key == null) throw const WrongPasswordException();
    return key;
  }

  void _checkNew(String password) {
    final error = MasterPasswordRules.validate(password);
    if (error != null) throw ArgumentError(error);
  }
}

final securityProvider =
    StateNotifierProvider<SecurityNotifier, PasswordVerifier?>((ref) {
  return SecurityNotifier(ref.watch(appStorageProvider));
});
