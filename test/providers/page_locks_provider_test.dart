import 'dart:convert';
import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:the_app/data/app_storage.dart';
import 'package:the_app/models/app_section.dart';
import 'package:the_app/models/hub_tool.dart';
import 'package:the_app/providers/section_locks_provider.dart';
import 'package:the_app/providers/security_provider.dart';
import 'package:the_app/providers/session_provider.dart';

/// Locks for each of the Hub's pages (O7, Round 21).
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

  PageLocksNotifier pages() => container.read(pageLocksProvider.notifier);
  bool closed(HubTool t) => container.read(pageClosedProvider(t));
  bool hidden(HubTool t) => container.read(pageHiddenProvider(t));

  Future<void> withPassword() async {
    await container.read(securityProvider.notifier).setPassword(password);
    await container.read(sessionProvider.notifier).unlock(password);
  }

  test('locking needs a master password', () {
    expect(() => pages().lock(HubTool.medicine), throwsStateError);
    expect(container.read(pageLocksProvider), isEmpty);
  });

  test('a locked page is closed only while the app is locked', () async {
    await withPassword();
    pages().lock(HubTool.medicine);
    expect(closed(HubTool.medicine), isFalse, reason: 'unlocked');

    container.read(sessionProvider.notifier).lock();
    expect(closed(HubTool.medicine), isTrue);
    expect(closed(HubTool.counters), isFalse, reason: 'not locked');
    expect(container.read(anySectionClosedProvider), isTrue,
        reason: 'backups ask for the password');

    await container.read(sessionProvider.notifier).unlock(password);
    expect(closed(HubTool.medicine), isFalse);
    expect(container.read(anySectionClosedProvider), isFalse);
  });

  test('independent of the Hub: either hides a page', () async {
    await withPassword();
    container.read(sectionLocksProvider.notifier).lock(AppSection.hub);
    container.read(sessionProvider.notifier).lock();
    expect(closed(HubTool.counters), isFalse, reason: 'its own lock is off');
    expect(hidden(HubTool.counters), isTrue, reason: 'the Hub is locked');

    await container.read(sessionProvider.notifier).unlock(password);
    container.read(sectionLocksProvider.notifier).unlock(AppSection.hub);
    pages().lock(HubTool.placard);
    container.read(sessionProvider.notifier).lock();
    expect(container.read(sectionClosedProvider(AppSection.hub)), isFalse);
    expect(hidden(HubTool.placard), isTrue, reason: 'a free Hub, locked page');
    expect(hidden(HubTool.counters), isFalse);
  });

  test('a lock can only be turned off while unlocked', () async {
    await withPassword();
    pages().lock(HubTool.medicine);
    container.read(sessionProvider.notifier).lock();
    expect(
      () => pages().unlock(HubTool.medicine),
      throwsA(isA<AppLockedException>()),
    );
    expect(container.read(pageLocksProvider), {HubTool.medicine});

    await container.read(sessionProvider.notifier).unlock(password);
    pages().unlock(HubTool.medicine);
    expect(container.read(pageLocksProvider), isEmpty);
  });

  test('removing the master password removes them', () async {
    await withPassword();
    pages().lock(HubTool.medicine);
    await container.read(securityProvider.notifier).removePassword(password);
    expect(container.read(pageLocksProvider), isEmpty);
  });

  test('saved with the section locks; both survive a restart', () async {
    final dir = Directory.systemTemp.createTempSync('page_locks');
    addTearDown(() => dir.deleteSync(recursive: true));
    final storage = await AppStorage.open(directory: dir);
    container = containerWith(storage);
    await withPassword();
    container.read(sectionLocksProvider.notifier).lock(AppSection.shop);
    pages()
      ..lock(HubTool.medicine)
      ..lock(HubTool.counters);
    // A section change after the pages' doesn't drop them (one file).
    container.read(sectionLocksProvider.notifier).lock(AppSection.planner);
    await storage.flush();

    final reopened = await AppStorage.open(directory: dir);
    expect(reopened.initialSectionLocks, {AppSection.shop, AppSection.planner});
    expect(reopened.initialPageLocks, {HubTool.counters, HubTool.medicine});
  });

  test('unknown pages are skipped; files from before have none', () async {
    final dir = Directory.systemTemp.createTempSync('page_locks');
    addTearDown(() => dir.deleteSync(recursive: true));
    File('${dir.path}/settings.json').writeAsStringSync(
      jsonEncode({
        'version': 2,
        'sectionLocks': ['shop'],
        'pageLocks': ['medicine', 'from-a-newer-app'],
      }),
    );
    expect((await AppStorage.open(directory: dir)).initialPageLocks,
        {HubTool.medicine});

    File('${dir.path}/settings.json').writeAsStringSync(
      jsonEncode({
        'version': 2,
        'sectionLocks': ['shop'],
      }),
    );
    final before = await AppStorage.open(directory: dir);
    expect(before.initialPageLocks, isEmpty);
    expect(before.initialSectionLocks, {AppSection.shop});
  });
}
