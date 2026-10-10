import 'package:biometric_storage/biometric_storage.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// How asking for the fingerprint went.
sealed class VaultRead {
  const VaultRead();
}

/// The fingerprint matched: here's what was stored.
class VaultOpened extends VaultRead {
  final String secret;
  const VaultOpened(this.secret);
}

/// The user cancelled (or it timed out, or was locked out for a while):
/// nothing is wrong with what's stored.
class VaultCancelled extends VaultRead {
  const VaultCancelled();
}

/// What's stored can't be read any more (e.g. a new fingerprint was
/// enrolled, which voids the key), or nothing is stored.
class VaultBroken extends VaultRead {
  const VaultBroken();
}

/// A secret kept on this phone that only a fingerprint opens (L6).
abstract class FingerprintVault {
  /// Whether the phone can use it: strong biometrics, at least one
  /// fingerprint enrolled.
  Future<bool> isAvailable();

  /// Stores [secret], asking for a fingerprint. False if that didn't
  /// happen (cancelled or failed).
  Future<bool> store(String secret);

  /// Asks for a fingerprint and returns what's stored.
  Future<VaultRead> read();

  /// Removes what's stored (no fingerprint needed).
  Future<void> clear();
}

/// [FingerprintVault] in Android's keystore, via biometric_storage: the
/// secret is encrypted with a keystore key that needs a fingerprint for
/// every use and is voided when a new fingerprint is enrolled.
class KeystoreFingerprintVault implements FingerprintVault {
  static const _name = 'master-password-key';

  static final _options = StorageFileInitOptions(
    authenticationRequired: true,
    // Every use needs a fingerprint; no grace period.
    authenticationValidityDurationSeconds: -1,
    androidBiometricOnly: true,
  );

  static const _prompt = PromptInfo(
    androidPromptInfo: AndroidPromptInfo(
      title: 'Unlock with fingerprint',
      negativeButton: 'Use password',
    ),
  );

  Future<BiometricStorageFile> _file() => BiometricStorage().getStorage(
        _name,
        options: _options,
        promptInfo: _prompt,
      );

  @override
  Future<bool> isAvailable() async {
    try {
      return await BiometricStorage().canAuthenticate() ==
          CanAuthenticateResponse.success;
    } on MissingPluginException {
      return false; // not on a phone (e.g. tests)
    } on PlatformException {
      return false;
    }
  }

  @override
  Future<bool> store(String secret) async {
    try {
      await (await _file()).write(secret);
      return true;
    } on AuthException {
      return false;
    } on BiometricStorageException {
      return false;
    } on PlatformException {
      return false;
    }
  }

  @override
  Future<VaultRead> read() async {
    try {
      final secret = await (await _file()).read();
      return secret == null ? const VaultBroken() : VaultOpened(secret);
    } on AuthException {
      return const VaultCancelled();
    } on BiometricStorageException {
      return const VaultBroken();
    } on PlatformException {
      return const VaultBroken();
    }
  }

  @override
  Future<void> clear() async {
    try {
      await (await _file()).delete();
    } on Exception {
      // Nothing stored, or the keystore key is already gone: either way
      // there's nothing left to read.
    }
  }
}

final fingerprintVaultProvider =
    Provider<FingerprintVault>((ref) => KeystoreFingerprintVault());
