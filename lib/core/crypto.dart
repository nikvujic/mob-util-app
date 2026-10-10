import 'dart:convert';
import 'dart:isolate';

import 'package:cryptography/cryptography.dart';
import 'package:flutter/foundation.dart';

/// Password-based encryption used for locked data and encrypted backups.
///
/// - A key is derived from the password with **Argon2id** and a random salt
///   ([KdfParams]). The parameters travel with the encrypted data, so they
///   can be strengthened later without breaking anything already saved.
/// - Data is encrypted with **AES-256-GCM** ([seal] / [open]), which also
///   detects any change to the encrypted bytes: a wrong password and
///   tampering both fail with [DecryptionException], never with garbage.
///
/// The password itself is never stored anywhere.

/// Opening sealed data failed: wrong password, or the data was changed.
class DecryptionException implements Exception {
  const DecryptionException();

  @override
  String toString() => 'DecryptionException: wrong password or damaged data';
}

/// How a key is derived from a password. Stored next to encrypted data.
class KdfParams {
  static const algorithm = 'argon2id';

  /// OWASP's recommended Argon2id setting (19 MiB, 2 passes, 1 lane):
  /// about 1 s on a phone, which is fine for occasional unlocks.
  static const defaultMemoryKiB = 19456;
  static const defaultIterations = 2;
  static const defaultParallelism = 1;
  static const saltLength = 16;

  /// Upper bounds accepted when reading parameters from a file, so a
  /// crafted file can't make the app allocate gigabytes or spin forever.
  static const maxMemoryKiB = 256 * 1024;
  static const maxIterations = 10;
  static const maxParallelism = 4;

  final int memoryKiB;
  final int iterations;
  final int parallelism;
  final List<int> salt;

  const KdfParams({
    required this.memoryKiB,
    required this.iterations,
    required this.parallelism,
    required this.salt,
  });

  /// Default parameters with a fresh random salt.
  factory KdfParams.generate() => KdfParams(
        memoryKiB: defaultMemoryKiB,
        iterations: defaultIterations,
        parallelism: defaultParallelism,
        salt: SecretKeyData.random(length: saltLength).bytes,
      );

  Map<String, dynamic> toJson() => {
        'algorithm': algorithm,
        'memoryKiB': memoryKiB,
        'iterations': iterations,
        'parallelism': parallelism,
        'salt': base64Encode(salt),
      };

  /// Throws [FormatException] for unknown algorithms or out-of-range values.
  factory KdfParams.fromJson(Map<String, dynamic> json) {
    if (json['algorithm'] != algorithm) {
      throw const FormatException('Unsupported key derivation');
    }
    final memory = json['memoryKiB'], iterations = json['iterations'];
    final parallelism = json['parallelism'], salt = json['salt'];
    if (memory is! int ||
        iterations is! int ||
        parallelism is! int ||
        salt is! String ||
        memory < 8 * parallelism ||
        memory > maxMemoryKiB ||
        iterations < 1 ||
        iterations > maxIterations ||
        parallelism < 1 ||
        parallelism > maxParallelism) {
      throw const FormatException('Invalid key derivation parameters');
    }
    final saltBytes = base64Decode(salt);
    if (saltBytes.length < 8) {
      throw const FormatException('Invalid key derivation parameters');
    }
    return KdfParams(
      memoryKiB: memory,
      iterations: iterations,
      parallelism: parallelism,
      salt: saltBytes,
    );
  }
}

/// A 256-bit key for [seal] and [open]: either a [PasswordKey] or a
/// [DataKey].
sealed class CipherKey {
  final SecretKey _key;

  CipherKey._(this._key);
}

/// A key derived from a password, together with the parameters used, so
/// data sealed with it records how to derive it again.
class PasswordKey extends CipherKey {
  final KdfParams params;

  PasswordKey._(this.params, SecretKey key) : super._(key);

  /// A key from raw bytes, for known-answer tests only.
  @visibleForTesting
  PasswordKey.fromBytes(this.params, List<int> bytes)
      : super._(SecretKey(bytes));

  /// A key kept in the phone's fingerprint-protected keystore (L6), put
  /// back together with the current password's [params]. Whether it's
  /// really that password's key is checked by unwrapping the data key.
  PasswordKey.restore(this.params, List<int> bytes) : super._(SecretKey(bytes));

  /// The raw key, only for keeping it in the phone's fingerprint-protected
  /// keystore (L6). Never write it anywhere else.
  Future<List<int>> exportForKeystore() => _key.extractBytes();

  /// Derives the key for [password]. Runs in a background isolate because
  /// Argon2id is deliberately slow; the UI stays responsive meanwhile.
  static Future<PasswordKey> derive(String password, KdfParams params) async {
    final bytes = await Isolate.run(() => _deriveBytes(password, params));
    return PasswordKey._(params, SecretKey(bytes));
  }

  static Future<List<int>> _deriveBytes(
    String password,
    KdfParams params,
  ) async {
    final kdf = Argon2id(
      memory: params.memoryKiB,
      iterations: params.iterations,
      parallelism: params.parallelism,
      hashLength: 32,
    );
    final key = await kdf.deriveKeyFromPassword(
      password: password,
      nonce: params.salt,
    );
    return key.extractBytes();
  }
}

/// Encrypted bytes plus what's needed to decrypt and verify them.
class SealedBox {
  final List<int> nonce;
  final List<int> cipherText;
  final List<int> mac;

  const SealedBox({
    required this.nonce,
    required this.cipherText,
    required this.mac,
  });

  Map<String, dynamic> toJson() => {
        'cipher': 'aes-256-gcm',
        'nonce': base64Encode(nonce),
        'cipherText': base64Encode(cipherText),
        'mac': base64Encode(mac),
      };

  /// Throws [FormatException] if the JSON isn't a sealed box.
  factory SealedBox.fromJson(Map<String, dynamic> json) {
    final nonce = json['nonce'], cipherText = json['cipherText'];
    final mac = json['mac'];
    if (json['cipher'] != 'aes-256-gcm' ||
        nonce is! String ||
        cipherText is! String ||
        mac is! String) {
      throw const FormatException('Not an encrypted box');
    }
    return SealedBox(
      nonce: base64Decode(nonce),
      cipherText: base64Decode(cipherText),
      mac: base64Decode(mac),
    );
  }
}

/// A random key that encrypts data (e.g. locked notes). It's never stored
/// in the clear: it's stored *wrapped* (sealed) with a [PasswordKey], so
/// changing the password only re-wraps this key instead of re-encrypting
/// everything it protects ("envelope encryption").
class DataKey extends CipherKey {
  static const _wrapContext = 'the-app/data-key';

  DataKey._(super.key) : super._();

  /// A new random key.
  factory DataKey.generate() => DataKey._(SecretKeyData.random(length: 32));

  /// A key from raw bytes, for tests only.
  @visibleForTesting
  DataKey.fromBytes(List<int> bytes) : super._(SecretKey(bytes));

  /// This key sealed with [passwordKey], for storing.
  Future<SealedBox> wrap(PasswordKey passwordKey) async => seal(
        await _key.extractBytes(),
        passwordKey,
        context: _wrapContext,
      );

  /// The key in [wrapped], or null if [passwordKey] can't open it.
  static Future<DataKey?> unwrap(
    SealedBox wrapped,
    PasswordKey passwordKey,
  ) async {
    try {
      final bytes = await open(wrapped, passwordKey, context: _wrapContext);
      return bytes.length == 32 ? DataKey._(SecretKey(bytes)) : null;
    } on DecryptionException {
      return null;
    }
  }
}

final _aes = AesGcm.with256bits();

/// Encrypts [plaintext] with [key] and a fresh random nonce. [context] is
/// authenticated but not encrypted: opening with a different context fails,
/// so data sealed for one purpose can't be passed off as another.
Future<SealedBox> seal(
  List<int> plaintext,
  CipherKey key, {
  required String context,
}) async {
  final box = await _aes.encrypt(
    plaintext,
    secretKey: key._key,
    aad: utf8.encode(context),
  );
  return SealedBox(
    nonce: box.nonce,
    cipherText: box.cipherText,
    mac: box.mac.bytes,
  );
}

/// Decrypts [box]. Throws [DecryptionException] if [key] is wrong, the data
/// was changed, or [context] differs from the one used to seal it.
Future<List<int>> open(
  SealedBox box,
  CipherKey key, {
  required String context,
}) async {
  try {
    return await _aes.decrypt(
      SecretBox(box.cipherText, nonce: box.nonce, mac: Mac(box.mac)),
      secretKey: key._key,
      aad: utf8.encode(context),
    );
  } on SecretBoxAuthenticationError {
    throw const DecryptionException();
  } on ArgumentError {
    // e.g. a nonce of the wrong length in a damaged file.
    throw const DecryptionException();
  }
}

/// The stored form of the master password: checks a password without
/// storing it, and holds the [DataKey] wrapped with the password's key.
///
/// Records from before data keys existed have none; [unwrapDataKey] then
/// returns null and the caller adds one with [withDataKey].
class PasswordVerifier {
  static const _context = 'the-app/password-check';

  final KdfParams params;
  final SealedBox _check;
  final SealedBox? _wrappedDataKey;

  PasswordVerifier._(this.params, this._check, this._wrappedDataKey);

  /// Makes a verifier for [password] (fresh salt) protecting [dataKey], or
  /// a new data key if none is given (a password change passes the current
  /// one, so everything it protects stays readable). Also returns the
  /// derived password key and the data key, so callers needn't derive or
  /// unwrap them again.
  static Future<(PasswordVerifier, PasswordKey, DataKey)> create(
    String password, {
    DataKey? dataKey,
  }) async {
    final key = await PasswordKey.derive(password, KdfParams.generate());
    final check = await seal(
      SecretKeyData.random(length: 16).bytes,
      key,
      context: _context,
    );
    final data = dataKey ?? DataKey.generate();
    return (
      PasswordVerifier._(key.params, check, await data.wrap(key)),
      key,
      data,
    );
  }

  /// The key for [password], or null if it's the wrong password.
  Future<PasswordKey?> unlock(String password) async {
    final key = await PasswordKey.derive(password, params);
    try {
      await open(_check, key, context: _context);
      return key;
    } on DecryptionException {
      return null;
    }
  }

  bool get hasDataKey => _wrappedDataKey != null;

  /// The data key, using [passwordKey] from [unlock]. Null if this record
  /// has no data key yet (or the key doesn't fit).
  Future<DataKey?> unwrapDataKey(PasswordKey passwordKey) async {
    final wrapped = _wrappedDataKey;
    return wrapped == null ? null : DataKey.unwrap(wrapped, passwordKey);
  }

  /// This verifier with [dataKey] added, wrapped with [passwordKey] (which
  /// must come from [unlock]). Keeps the same [params], so it's the same
  /// password.
  Future<PasswordVerifier> withDataKey(
    DataKey dataKey,
    PasswordKey passwordKey,
  ) async =>
      PasswordVerifier._(params, _check, await dataKey.wrap(passwordKey));

  Map<String, dynamic> toJson() => {
        'kdf': params.toJson(),
        'check': _check.toJson(),
        if (_wrappedDataKey != null) 'dataKey': _wrappedDataKey.toJson(),
      };

  /// Throws [FormatException] if the JSON isn't a verifier.
  factory PasswordVerifier.fromJson(Map<String, dynamic> json) {
    final kdf = json['kdf'], check = json['check'];
    final dataKey = json['dataKey'];
    if (kdf is! Map<String, dynamic> ||
        check is! Map<String, dynamic> ||
        (dataKey != null && dataKey is! Map<String, dynamic>)) {
      throw const FormatException('Not a password verifier');
    }
    return PasswordVerifier._(
      KdfParams.fromJson(kdf),
      SealedBox.fromJson(check),
      dataKey == null
          ? null
          : SealedBox.fromJson(dataKey as Map<String, dynamic>),
    );
  }
}
