import 'dart:convert';
import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:the_app/data/app_storage.dart';
import 'package:the_app/models/app_section.dart';
import 'package:the_app/providers/section_locks_provider.dart';
import 'package:the_app/providers/security_provider.dart';
import 'package:the_app/providers/session_provider.dart';

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

  SectionLocksNotifier locks() => container.read(sectionLocksProvider.notifier);
  bool closed(AppSection s) => container.read(sectionClosedProvider(s));

  Future<void> withPassword({bool unlocked = true}) async {
    await container.read(securityProvider.notifier).setPassword(password);
    if (unlocked) {
      await container.read(sessionProvider.notifier).unlock(password);
    } else {
      container.read(sessionProvider.notifier).lock();
    }
  }

  test('locking needs a master password', () {
    expect(() => locks().lock(AppSection.shop), throwsStateError);
    expect(container.read(sectionLocksProvider), isEmpty);
  });

  test('a locked section is closed only while the app is locked', () async {
    await withPassword();
    locks().lock(AppSection.shop);

    expect(closed(AppSection.shop), isFalse, reason: 'unlocked');
    container.read(sessionProvider.notifier).lock();
    expect(closed(AppSection.shop), isTrue);
    expect(closed(AppSection.notes), isFalse, reason: 'not locked');
    expect(container.read(anySectionClosedProvider), isTrue);

    await container.read(sessionProvider.notifier).unlock(password);
    expect(closed(AppSection.shop), isFalse);
    expect(container.read(anySectionClosedProvider), isFalse);
  });

  test('a lock can only be turned off while unlocked', () async {
    await withPassword();
    locks().lock(AppSection.shop);
    container.read(sessionProvider.notifier).lock();

    expect(
      () => locks().unlock(AppSection.shop),
      throwsA(isA<AppLockedException>()),
    );
    expect(container.read(sectionLocksProvider), {AppSection.shop});

    await container.read(sessionProvider.notifier).unlock(password);
    locks().unlock(AppSection.shop);
    expect(container.read(sectionLocksProvider), isEmpty);
  });

  test('removing the master password removes all section locks', () async {
    await withPassword();
    locks()
      ..lock(AppSection.shop)
      ..lock(AppSection.notes);

    await container.read(securityProvider.notifier).removePassword(password);

    expect(container.read(sectionLocksProvider), isEmpty);
  });

  test('locks are saved and survive a restart', () async {
    final dir = Directory.systemTemp.createTempSync('section_locks');
    addTearDown(() => dir.deleteSync(recursive: true));
    final storage = await AppStorage.open(directory: dir);
    container = containerWith(storage);
    await withPassword();
    locks()
      ..lock(AppSection.planner)
      ..lock(AppSection.shop);
    await storage.flush();

    final reopened = await AppStorage.open(directory: dir);
    expect(reopened.initialSectionLocks, {AppSection.shop, AppSection.planner});
  });

  test('unknown sections in the file are skipped', () async {
    final dir = Directory.systemTemp.createTempSync('section_locks');
    addTearDown(() => dir.deleteSync(recursive: true));
    File('${dir.path}/settings.json').writeAsStringSync(
      jsonEncode({
        'version': 2,
        'sectionLocks': ['shop', 'from-a-newer-app'],
      }),
    );

    final storage = await AppStorage.open(directory: dir);
    expect(storage.initialSectionLocks, {AppSection.shop});
  });
}
