import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:the_app/core/clock.dart';
import 'package:the_app/core/crypto.dart';
import 'package:the_app/data/app_storage.dart';
import 'package:the_app/providers/security_provider.dart';
import 'package:the_app/providers/session_provider.dart';

void main() {
  const password = 'master password';

  late ProviderContainer container;
  late DateTime now;

  setUp(() async {
    now = DateTime(2026, 10, 8, 12);
    container = ProviderContainer(
      overrides: [
        appStorageProvider.overrideWithValue(AppStorage.inMemory()),
        clockProvider.overrideWithValue(() => now),
      ],
    );
    addTearDown(container.dispose);
  });

  SessionNotifier session() => container.read(sessionProvider.notifier);
  SecurityNotifier security() => container.read(securityProvider.notifier);
  bool unlocked() => container.read(sessionProvider) != null;

  Future<void> setUpUnlocked() async {
    await security().setPassword(password);
    expect(await session().unlock(password), isNotNull);
  }

  test('starts locked', () {
    expect(unlocked(), isFalse);
  });

  test('cannot unlock without a master password', () async {
    expect(await session().unlock(password), isNull);
    expect(unlocked(), isFalse);
  });

  test('unlocks with the right password only', () async {
    await security().setPassword(password);
    expect(await session().unlock('wrong password'), isNull);
    expect(unlocked(), isFalse);

    expect(await session().unlock(password), isNotNull);
    expect(unlocked(), isTrue);
  });

  test('lock() locks', () async {
    await setUpUnlocked();
    session().lock();
    expect(unlocked(), isFalse);
  });

  group('in the background', () {
    test('stays unlocked for a short trip', () async {
      await setUpUnlocked();
      session().appHidden();
      now = now.add(const Duration(minutes: 4, seconds: 59));
      session().appShown();
      expect(unlocked(), isTrue);
    });

    test('locks after 5 minutes away', () async {
      await setUpUnlocked();
      session().appHidden();
      now = now.add(SessionNotifier.autoLockAfter);
      session().appShown();
      expect(unlocked(), isFalse);
    });

    test('measures from when it first left', () async {
      await setUpUnlocked();
      session().appHidden();
      now = now.add(const Duration(minutes: 3));
      session().appHidden(); // e.g. hidden reported twice
      now = now.add(const Duration(minutes: 2));
      session().appShown();
      expect(unlocked(), isFalse);
    });

    test('each trip is timed on its own', () async {
      await setUpUnlocked();
      for (var i = 0; i < 3; i++) {
        session().appHidden();
        now = now.add(const Duration(minutes: 4));
        session().appShown();
        now = now.add(const Duration(minutes: 10)); // in use, visible
      }
      expect(unlocked(), isTrue);
    });
  });

  test('locks when the master password changes or is removed', () async {
    await setUpUnlocked();
    await security().changePassword(password, 'new password!');
    expect(unlocked(), isFalse);

    expect(await session().unlock('new password!'), isNotNull);
    await security().removePassword('new password!');
    expect(unlocked(), isFalse);
  });

  test('unlockWith accepts only a key of the current password', () async {
    await security().setPassword(password);
    final key = await container.read(securityProvider)!.unlock(password);
    expect(await session().unlockWith(key!), isTrue);
    expect(unlocked(), isTrue);

    session().lock();
    await security().changePassword(password, 'new password!');
    expect(await session().unlockWith(key), isFalse); // old password's key
    expect(unlocked(), isFalse);
  });

  test('unlocking makes the data key available', () async {
    await setUpUnlocked();
    final keys = container.read(sessionProvider)!;
    final box = await seal([1], keys.dataKey, context: 'test');
    expect(await open(box, keys.dataKey, context: 'test'), [1]);
  });

  test('changing the password keeps the same data key', () async {
    await setUpUnlocked();
    final box = await seal(
      [7],
      container.read(sessionProvider)!.dataKey,
      context: 'test',
    );

    await security().changePassword(password, 'new password!');
    expect(await session().unlock('new password!'), isNotNull);

    final dataKey = container.read(sessionProvider)!.dataKey;
    expect(await open(box, dataKey, context: 'test'), [7]);
  });

  test('a master password without a data key gets one on first unlock',
      () async {
    // A record as written before data keys existed.
    final (full, _, _) = await PasswordVerifier.create(password);
    final json = full.toJson()..remove('dataKey');
    final old = PasswordVerifier.fromJson(
      jsonDecode(jsonEncode(json)) as Map<String, dynamic>,
    );
    container = ProviderContainer(
      overrides: [
        appStorageProvider.overrideWithValue(
          AppStorage.inMemory(initialMasterPassword: old),
        ),
        clockProvider.overrideWithValue(() => now),
      ],
    );
    addTearDown(container.dispose);

    expect(await session().unlock(password), isNotNull);
    expect(unlocked(), isTrue, reason: 'adding the key must not lock');
    expect(container.read(securityProvider)!.hasDataKey, isTrue);

    // The same data key comes back next time.
    final box = await seal(
      [3],
      container.read(sessionProvider)!.dataKey,
      context: 'test',
    );
    session().lock();
    expect(await session().unlock(password), isNotNull);
    final again = container.read(sessionProvider)!.dataKey;
    expect(await open(box, again, context: 'test'), [3]);
  });
}
