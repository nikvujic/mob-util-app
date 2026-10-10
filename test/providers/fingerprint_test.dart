import 'dart:convert';
import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:the_app/core/crypto.dart';
import 'package:the_app/data/app_storage.dart';
import 'package:the_app/data/fingerprint_vault.dart';
import 'package:the_app/providers/fingerprint_provider.dart';
import 'package:the_app/providers/password_reset_provider.dart';
import 'package:the_app/providers/preferences_provider.dart';
import 'package:the_app/providers/security_provider.dart';
import 'package:the_app/providers/session_provider.dart';

import '../helpers.dart';

/// Unlocking with a fingerprint (L6).
void main() {
  const password = 'master password';

  late ProviderContainer container;
  late FakeFingerprintVault vault;
  late AppStorage storage;

  ProviderContainer start() {
    final c = ProviderContainer(
      overrides: [
        appStorageProvider.overrideWithValue(storage),
        fingerprintVaultProvider.overrideWithValue(vault),
      ],
    );
    addTearDown(c.dispose);
    c.listen(fingerprintProvider, (_, __) {}); // kept running, like the app
    return c;
  }

  setUp(() {
    vault = FakeFingerprintVault();
    storage = AppStorage.inMemory();
    container = start();
  });

  FingerprintNotifier fingerprint() =>
      container.read(fingerprintProvider.notifier);
  SessionNotifier session() => container.read(sessionProvider.notifier);
  bool on() => container.read(fingerprintProvider);

  /// A master password, unlocked, with fingerprint unlock on, then locked.
  Future<UnlockedKeys> setUpFingerprint() async {
    await container.read(securityProvider.notifier).setPassword(password);
    final keys = (await session().unlock(password))!;
    expect(await fingerprint().turnOn(), isTrue);
    session().lock();
    return keys;
  }

  test('off at first; turning it on needs the app unlocked', () async {
    expect(on(), isFalse);
    await container.read(securityProvider.notifier).setPassword(password);
    expect(fingerprint().turnOn, throwsStateError);
    expect(vault.stored, isNull);
  });

  test('a fingerprint unlocks the app, with the same keys', () async {
    final keys = await setUpFingerprint();
    expect(on(), isTrue);
    expect(container.read(sessionProvider), isNull);

    final unlocked = await fingerprint().unlock();

    expect(unlocked, isNotNull);
    expect(container.read(sessionProvider), same(unlocked));
    // The password's own key: it opens the data key, the same one.
    final verifier = container.read(securityProvider)!;
    final dataKey = await verifier.unwrapDataKey(unlocked!.passwordKey);
    expect(dataKey, isNotNull);
    final sealed = await dataKey!.wrap(keys.passwordKey);
    expect(await DataKey.unwrap(sealed, keys.passwordKey), isNotNull);
  });

  test('stores the key, never the password', () async {
    await setUpFingerprint();
    final stored = jsonDecode(vault.stored!) as Map<String, dynamic>;
    expect(stored.keys, unorderedEquals(['version', 'salt', 'key']));
    expect(vault.stored, isNot(contains(password)));
    expect(
      container.read(preferencesProvider).fingerprintFor,
      stored['salt'],
      reason: 'notes which password it belongs to',
    );
  });

  test('cancelling unlocks nothing and keeps it on', () async {
    await setUpFingerprint();
    vault.nextFinger = false;
    expect(await fingerprint().unlock(), isNull);
    expect(container.read(sessionProvider), isNull);
    expect(on(), isTrue);
    expect(vault.stored, isNotNull);
  });

  test('a voided key (new fingerprint enrolled) turns it off', () async {
    await setUpFingerprint();
    vault.nextFinger = null;
    expect(await fingerprint().unlock(), isNull);
    expect(on(), isFalse);
    expect(vault.stored, isNull);
    expect(container.read(preferencesProvider).fingerprintFor, isNull);
  });

  test('a stored key that doesn\'t open the data key turns it off', () async {
    await setUpFingerprint();
    final stored = jsonDecode(vault.stored!) as Map<String, dynamic>;
    vault.stored = jsonEncode({
      ...stored,
      'key': base64Encode(List.filled(32, 7)),
    });
    expect(await fingerprint().unlock(), isNull);
    expect(container.read(sessionProvider), isNull);
    expect(on(), isFalse);
  });

  group('turns off when the master password', () {
    test('changes', () async {
      await setUpFingerprint();
      await container
          .read(securityProvider.notifier)
          .changePassword(password, 'another password');
      expect(on(), isFalse);
      expect(vault.stored, isNull);
    });

    test('is removed', () async {
      await setUpFingerprint();
      await container.read(securityProvider.notifier).removePassword(password);
      expect(on(), isFalse);
      expect(vault.stored, isNull);
    });

    test('is reset', () async {
      await setUpFingerprint();
      await container.read(passwordResetProvider).run();
      expect(on(), isFalse);
      expect(vault.stored, isNull);
    });
  });

  test('stays on across a restart; off if stored for another password',
      () async {
    final dir = Directory.systemTemp.createTempSync('fingerprint');
    addTearDown(() => dir.deleteSync(recursive: true));
    Future<void> restart() async {
      await storage.flush();
      storage = await AppStorage.open(directory: dir);
      container = start(); // same files and keystore
    }

    storage = await AppStorage.open(directory: dir);
    container = start();
    await setUpFingerprint();
    await restart();
    expect(on(), isTrue);
    expect(await fingerprint().unlock(), isNotNull);

    // Saved for some other password (e.g. the files were swapped).
    container.read(preferencesProvider.notifier).setFingerprintFor('other');
    await restart();
    expect(on(), isFalse);
    await Future<void>.delayed(Duration.zero);
    expect(vault.stored, isNull, reason: 'cleared');
  });

  test('turning it off clears the key', () async {
    await setUpFingerprint();
    await fingerprint().turnOff();
    expect(on(), isFalse);
    expect(vault.stored, isNull);
    expect(await fingerprint().unlock(), isNull);
    expect(vault.asked, 1, reason: 'not asked for a fingerprint when off');
  });
}
