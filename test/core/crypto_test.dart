import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:the_app/core/crypto.dart';

void main() {
  const password = 'correct horse battery staple ć';
  const context = 'test';

  /// Fixed parameters (the defaults, with a known salt).
  final fixedParams = KdfParams(
    memoryKiB: KdfParams.defaultMemoryKiB,
    iterations: KdfParams.defaultIterations,
    parallelism: KdfParams.defaultParallelism,
    salt: List.generate(16, (i) => i),
  );

  /// Cheap parameters for tests that only need *a* key.
  KdfParams fastParams() => KdfParams(
        memoryKiB: 64,
        iterations: 1,
        parallelism: 1,
        salt: KdfParams.generate().salt,
      );

  Future<PasswordKey> fastKey([String pw = password]) =>
      PasswordKey.derive(pw, fastParams());

  group('known answers from an independent implementation (OpenSSL)', () {
    // Generated with Python `cryptography` (OpenSSL), not this library, so
    // they prove the algorithms and parameters are the standard ones —
    // and that keys derived today will be derived the same way forever.
    test('Argon2id with the default parameters', () async {
      final key = await PasswordKey.derive(password, fixedParams);
      final box = await seal([1, 2, 3], key, context: context);
      // Same key bytes => opens with a key built from the OpenSSL output.
      final expected = PasswordKey.fromBytes(
        fixedParams,
        _hex(
            '0fc401f739888f68cf7e126aa48d4c6ff7b6a1a470f7922e6b384ad296cca9f8'),
      );
      expect(await open(box, expected, context: context), [1, 2, 3]);
    });

    test('AES-256-GCM opens data sealed by OpenSSL', () async {
      final key = PasswordKey.fromBytes(
        fixedParams,
        List.generate(32, (i) => i),
      );
      final box = SealedBox(
        nonce: List.generate(12, (i) => 100 + i),
        cipherText: base64Decode('AH6yChbFdvxfATSdqkWIYdE='),
        mac: base64Decode('yAT9/YfcnESG9DRR3KOZSA=='),
      );
      expect(
        utf8.decode(await open(box, key, context: 'the-app')),
        'Hello, backup ✓',
      );
    });
  });

  group('PasswordKey.derive', () {
    test('is deterministic for the same password and parameters', () async {
      final params = fastParams();
      final a = await PasswordKey.derive(password, params);
      final b = await PasswordKey.derive(password, params);
      final box = await seal([42], a, context: context);
      expect(await open(box, b, context: context), [42]);
    });

    test('gives a different key for a different salt', () async {
      final a = await fastKey();
      final b = await fastKey(); // fresh salt
      final box = await seal([42], a, context: context);
      expect(
        open(box, b, context: context),
        throwsA(isA<DecryptionException>()),
      );
    });

    test('fresh parameters get fresh salts', () {
      expect(KdfParams.generate().salt, isNot(KdfParams.generate().salt));
      expect(KdfParams.generate().salt, hasLength(KdfParams.saltLength));
    });
  });

  group('seal / open', () {
    test('round-trips empty, text and large data', () async {
      final key = await fastKey();
      for (final data in [
        <int>[],
        utf8.encode('Beleška: čćšđž 🔒'),
        List.generate(1 << 20, (i) => i % 251),
      ]) {
        final box = await seal(data, key, context: context);
        expect(await open(box, key, context: context), data);
      }
    });

    test('never reuses a nonce', () async {
      final key = await fastKey();
      final a = await seal([1], key, context: context);
      final b = await seal([1], key, context: context);
      expect(a.nonce, isNot(b.nonce));
      expect(a.cipherText, isNot(b.cipherText));
    });

    test('does not contain the plaintext', () async {
      final key = await fastKey();
      final secret = utf8.encode('my secret note');
      final box = await seal(secret, key, context: context);
      expect(utf8.decode(box.cipherText, allowMalformed: true),
          isNot(contains('secret')));
    });

    test('fails on a wrong password', () async {
      final params = fastParams();
      final right = await PasswordKey.derive(password, params);
      final wrong = await PasswordKey.derive('wrong', params);
      final box = await seal([1, 2, 3], right, context: context);
      expect(
        open(box, wrong, context: context),
        throwsA(isA<DecryptionException>()),
      );
    });

    test('fails on any change to the sealed data or context', () async {
      final key = await fastKey();
      final box = await seal([1, 2, 3, 4], key, context: context);
      List<int> flip(List<int> b) => [b.first ^ 1, ...b.skip(1)];

      for (final tampered in [
        SealedBox(
            nonce: flip(box.nonce), cipherText: box.cipherText, mac: box.mac),
        SealedBox(
            nonce: box.nonce, cipherText: flip(box.cipherText), mac: box.mac),
        SealedBox(
            nonce: box.nonce, cipherText: box.cipherText, mac: flip(box.mac)),
        SealedBox(nonce: [1, 2], cipherText: box.cipherText, mac: box.mac),
      ]) {
        expect(
          open(tampered, key, context: context),
          throwsA(isA<DecryptionException>()),
        );
      }
      expect(
        open(box, key, context: 'other'),
        throwsA(isA<DecryptionException>()),
      );
    });
  });

  group('JSON', () {
    test('KdfParams round-trip', () {
      final params = KdfParams.generate();
      final back = KdfParams.fromJson(
        jsonDecode(jsonEncode(params.toJson())) as Map<String, dynamic>,
      );
      expect(back.toJson(), params.toJson());
      expect(params.toJson()['algorithm'], 'argon2id');
    });

    test('KdfParams rejects unknown or dangerous values', () {
      Map<String, dynamic> valid() => KdfParams.generate().toJson();
      for (final bad in [
        valid()..['algorithm'] = 'md5',
        valid()..['memoryKiB'] = 1 << 30, // 1 TiB
        valid()..['iterations'] = 1000000,
        valid()..['iterations'] = 0,
        valid()..['parallelism'] = 64,
        valid()..['salt'] = base64Encode([1, 2]),
        valid()..remove('salt'),
      ]) {
        expect(() => KdfParams.fromJson(bad), throwsFormatException,
            reason: '$bad');
      }
    });

    test('SealedBox round-trip and validation', () async {
      final box = await seal([7, 8, 9], await fastKey(), context: context);
      final back = SealedBox.fromJson(
        jsonDecode(jsonEncode(box.toJson())) as Map<String, dynamic>,
      );
      expect(back.toJson(), box.toJson());
      expect(
        () => SealedBox.fromJson({'cipher': 'rot13'}),
        throwsFormatException,
      );
    });
  });
}

List<int> _hex(String hex) => [
      for (var i = 0; i < hex.length; i += 2)
        int.parse(hex.substring(i, i + 2), radix: 16),
    ];
