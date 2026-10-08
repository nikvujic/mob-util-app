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

  group('PasswordVerifier', () {
    test('unlocks with the right password only', () async {
      final (verifier, key, _) = await PasswordVerifier.create(password);
      expect(await verifier.unlock('wrong password'), isNull);

      final unlocked = await verifier.unlock(password);
      expect(unlocked, isNotNull);
      // The unlocked key is the same key create() returned.
      final box = await seal([5], key, context: context);
      expect(await open(box, unlocked!, context: context), [5]);
    });

    test('uses the default (strong) parameters and a fresh salt', () async {
      final (a, _, _) = await PasswordVerifier.create(password);
      final (b, _, _) = await PasswordVerifier.create(password);
      expect(a.params.memoryKiB, KdfParams.defaultMemoryKiB);
      expect(a.params.iterations, KdfParams.defaultIterations);
      expect(a.params.salt, isNot(b.params.salt));
    });

    test('survives a JSON round trip and never contains the password',
        () async {
      final (verifier, _, _) = await PasswordVerifier.create(password);
      final json = jsonEncode(verifier.toJson());
      expect(json, isNot(contains('horse')));

      final back = PasswordVerifier.fromJson(
        jsonDecode(json) as Map<String, dynamic>,
      );
      expect(await back.unlock(password), isNotNull);
      expect(await back.unlock('nope'), isNull);
      expect(() => PasswordVerifier.fromJson({}), throwsFormatException);
    });
  });

  group('DataKey', () {
    test('seals and opens data like a password key', () async {
      final key = DataKey.generate();
      final box = await seal([1, 2, 3], key, context: context);
      expect(await open(box, key, context: context), [1, 2, 3]);
      expect(
        open(box, DataKey.generate(), context: context),
        throwsA(isA<DecryptionException>()),
      );
    });

    test('wraps and unwraps with the right password key only', () async {
      final dataKey = DataKey.generate();
      final params = fastParams();
      final right = await PasswordKey.derive(password, params);
      final wrong = await PasswordKey.derive('wrong', params);
      final wrapped = await dataKey.wrap(right);

      final unwrapped = await DataKey.unwrap(wrapped, right);
      final box = await seal([9], dataKey, context: context);
      expect(await open(box, unwrapped!, context: context), [9]);
      expect(await DataKey.unwrap(wrapped, wrong), isNull);
    });

    test('a wrapped key is not usable as other sealed data', () async {
      final key = await fastKey();
      final wrapped = await DataKey.generate().wrap(key);
      expect(
        open(wrapped, key, context: context),
        throwsA(isA<DecryptionException>()),
      );
    });
  });

  group('PasswordVerifier data key', () {
    test('create wraps a new data key, or the given one', () async {
      final (verifier, key, dataKey) = await PasswordVerifier.create(password);
      expect(verifier.hasDataKey, isTrue);
      final box = await seal([4], dataKey, context: context);
      final unwrapped = await verifier.unwrapDataKey(key);
      expect(await open(box, unwrapped!, context: context), [4]);

      final (other, otherKey, same) =
          await PasswordVerifier.create('another password', dataKey: dataKey);
      expect(identical(same, dataKey), isTrue);
      final again = await other.unwrapDataKey(otherKey);
      expect(await open(box, again!, context: context), [4]);
    });

    test('records without a data key still load, and can get one', () async {
      final (full, key, _) = await PasswordVerifier.create(password);
      final json = full.toJson()..remove('dataKey');
      final old = PasswordVerifier.fromJson(
        jsonDecode(jsonEncode(json)) as Map<String, dynamic>,
      );
      expect(old.hasDataKey, isFalse);
      expect(await old.unwrapDataKey(key), isNull);

      final unlocked = (await old.unlock(password))!;
      final dataKey = DataKey.generate();
      final upgraded = await old.withDataKey(dataKey, unlocked);
      expect(identical(upgraded.params, old.params), isTrue);
      expect(await upgraded.unwrapDataKey(unlocked), isNotNull);
    });

    test('the data key survives JSON', () async {
      final (verifier, key, dataKey) = await PasswordVerifier.create(password);
      final back = PasswordVerifier.fromJson(
        jsonDecode(jsonEncode(verifier.toJson())) as Map<String, dynamic>,
      );
      final box = await seal([5], dataKey, context: context);
      final unwrapped = await back.unwrapDataKey(key);
      expect(await open(box, unwrapped!, context: context), [5]);
    });
  });
}

List<int> _hex(String hex) => [
      for (var i = 0; i < hex.length; i += 2)
        int.parse(hex.substring(i, i + 2), radix: 16),
    ];
