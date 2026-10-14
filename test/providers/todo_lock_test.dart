import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:the_app/data/app_storage.dart';
import 'package:the_app/models/preferences.dart';
import 'package:the_app/providers/preferences_provider.dart';
import 'package:the_app/providers/section_locks_provider.dart';
import 'package:the_app/providers/security_provider.dart';
import 'package:the_app/providers/session_provider.dart';

/// The to-do note's lock (Round 45): just a password, as a Hub page's.
void main() {
  const password = 'master password';

  late ProviderContainer container;

  ProviderContainer containerWith(AppStorage storage) {
    final c = ProviderContainer(
      overrides: [appStorageProvider.overrideWithValue(storage)],
    );
    addTearDown(c.dispose);
    return c;
  }

  setUp(() => container = containerWith(AppStorage.inMemory()));

  TodoLockNotifier lock() => container.read(todoLockProvider.notifier);
  bool closed() => container.read(todoClosedProvider);

  Future<void> withPassword() async {
    await container.read(securityProvider.notifier).setPassword(password);
    await container.read(sessionProvider.notifier).unlock(password);
  }

  test('locking needs a master password', () {
    expect(() => lock().lock(), throwsStateError);
    expect(container.read(todoLockProvider), isFalse);
  });

  test('closed only while the app is locked; backups then ask', () async {
    await withPassword();
    lock().lock();
    expect(closed(), isFalse, reason: 'unlocked');
    container.read(sessionProvider.notifier).lock();
    expect(closed(), isTrue);
    expect(container.read(anySectionClosedProvider), isTrue);
    await container.read(sessionProvider.notifier).unlock(password);
    expect(closed(), isFalse);
    expect(container.read(anySectionClosedProvider), isFalse);
  });

  test('turned off only while unlocked', () async {
    await withPassword();
    lock().lock();
    container.read(sessionProvider.notifier).lock();
    expect(() => lock().unlock(), throwsA(isA<AppLockedException>()));
    expect(container.read(todoLockProvider), isTrue);
    await container.read(sessionProvider.notifier).unlock(password);
    lock().unlock();
    expect(container.read(todoLockProvider), isFalse);
  });

  test('removing the master password removes the lock', () async {
    await withPassword();
    lock().lock();
    await container.read(securityProvider.notifier).removePassword(password);
    expect(container.read(todoLockProvider), isFalse);
  });

  test('the to-do switch in Settings leaves it (and Waiting) as they are',
      () async {
    await withPassword();
    lock().lock();
    container.read(preferencesProvider.notifier).setTodoWaiting(true);
    container.read(preferencesProvider.notifier).setTodoNote(false);
    expect(container.read(todoLockProvider), isTrue);
    expect(container.read(preferencesProvider).todoWaiting, isTrue);
  });

  test('saved in settings.json with the other locks, and loaded back',
      () async {
    final dir = Directory.systemTemp.createTempSync('todo_lock');
    addTearDown(() => dir.deleteSync(recursive: true));
    final storage = await AppStorage.open(directory: dir);
    container = containerWith(storage);
    await withPassword();
    lock().lock();
    await storage.flush();
    expect(File('${dir.path}/settings.json').readAsStringSync(),
        contains('"todoLocked":true'));
    final again = await AppStorage.open(directory: dir);
    expect(again.initialTodoLocked, isTrue);
  });

  test('the Waiting list switch: kept in preferences.json only when on', () {
    expect(const Preferences().toJson().containsKey('todoWaiting'), isFalse);
    final on = const Preferences(todoWaiting: true).toJson();
    expect(on['todoWaiting'], isTrue);
    expect(Preferences.fromJson(on).todoWaiting, isTrue);
    expect(Preferences.fromJson(const {}).todoWaiting, isFalse);
  });
}
