import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:the_app/core/clock.dart';
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
    expect(await session().unlock(password), isTrue);
  }

  test('starts locked', () {
    expect(unlocked(), isFalse);
  });

  test('cannot unlock without a master password', () async {
    expect(await session().unlock(password), isFalse);
    expect(unlocked(), isFalse);
  });

  test('unlocks with the right password only', () async {
    await security().setPassword(password);
    expect(await session().unlock('wrong password'), isFalse);
    expect(unlocked(), isFalse);

    expect(await session().unlock(password), isTrue);
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

    expect(await session().unlock('new password!'), isTrue);
    await security().removePassword('new password!');
    expect(unlocked(), isFalse);
  });

  test('unlockWith accepts only a key of the current password', () async {
    await security().setPassword(password);
    final key = await container.read(securityProvider)!.unlock(password);
    session().unlockWith(key!);
    expect(unlocked(), isTrue);

    session().lock();
    await security().changePassword(password, 'new password!');
    session().unlockWith(key); // key of the old password
    expect(unlocked(), isFalse);
  });
}
