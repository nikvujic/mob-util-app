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

/// A key derived from a password, together with the parameters used, so
/// data sealed with it records how to derive it again.
class PasswordKey {
  final KdfParams params;
  final SecretKey _key;

  PasswordKey._(this.params, this._key);

  /// A key from raw bytes, for known-answer tests only.
  @visibleForTesting
  PasswordKey.fromBytes(this.params, List<int> bytes) : _key = SecretKey(bytes);

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

final _aes = AesGcm.with256bits();

/// Encrypts [plaintext] with [key] and a fresh random nonce. [context] is
/// authenticated but not encrypted: opening with a different context fails,
/// so data sealed for one purpose can't be passed off as another.
Future<SealedBox> seal(
  List<int> plaintext,
  PasswordKey key, {
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
  PasswordKey key, {
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
