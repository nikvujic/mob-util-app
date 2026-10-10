import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:the_app/data/app_storage.dart';
import 'package:the_app/models/app_section.dart';
import 'package:the_app/providers/counters_provider.dart';
import 'package:the_app/providers/notes_provider.dart';
import 'package:the_app/providers/password_reset_provider.dart';
import 'package:the_app/providers/planner_provider.dart';
import 'package:the_app/providers/section_locks_provider.dart';
import 'package:the_app/providers/security_provider.dart';
import 'package:the_app/providers/session_provider.dart';
import 'package:the_app/providers/shop_provider.dart';

/// Resetting a forgotten master password (L7) deletes what it protects —
/// locked notes and locked sections' content — and keeps everything else.
void main() {
  const password = 'master password';

  late Directory dir;
  late ProviderContainer container;

  setUp(() async {
    dir = Directory.systemTemp.createTempSync('reset');
    addTearDown(() => dir.deleteSync(recursive: true));
    final storage = await AppStorage.open(directory: dir);
    container = ProviderContainer(
      overrides: [appStorageProvider.overrideWithValue(storage)],
    );
    addTearDown(container.dispose);
    addTearDown(storage.flush);
  });

  PasswordReset reset() => container.read(passwordResetProvider);
  List<String> noteTitles() =>
      container.read(notesProvider).map((n) => n.title).toList();
  String file(String name) => File('${dir.path}/$name').readAsStringSync();

  /// A master password; notes "Plain" and "Bank" (locked); a shop item,
  /// a planner task and a counter; then [locked] sections locked and the
  /// app locked again (the password is forgotten).
  Future<void> seed({Set<AppSection> locked = const {}}) async {
    await container.read(securityProvider.notifier).setPassword(password);
    final keys =
        (await container.read(sessionProvider.notifier).unlock(password))!;
    final notes = container.read(notesProvider.notifier);
    notes.addNote(title: 'Plain', content: 'plain text');
    await notes.lockNote(
      notes.addNote(title: 'Bank', content: 'PIN 4711'),
      keys.dataKey,
    );
    container.read(shopProvider.notifier).addItem('Milk');
    container
        .read(plannerProvider.notifier)
        .addTask(DateTime(2026, 10, 12), 'Gym', start: 480, end: 540);
    container.read(countersProvider.notifier).add('Push-ups');
    for (final section in locked) {
      container.read(sectionLocksProvider.notifier).lock(section);
    }
    container.read(sessionProvider.notifier).lock();
  }

  test('deletes only locked notes; everything else stays', () async {
    await seed();
    expect(reset().plan().lockedNotes, 1);
    expect(reset().plan().sections, isEmpty);

    await reset().run();

    expect(container.read(securityProvider), isNull);
    expect(noteTitles(), ['Plain']);
    expect(container.read(shopProvider), hasLength(1));
    expect(container.read(plannerProvider), hasLength(1));
    expect(container.read(countersProvider), hasLength(1));

    await container.read(appStorageProvider).flush();
    expect(file('notes.json'), isNot(contains('Bank')));
    expect(file('notes.json'), contains('plain text'));
    expect(file('security.json'), contains('"masterPassword":null'));
  });

  test('deletes the content of locked sections, so locks can\'t be bypassed',
      () async {
    await seed(locked: {AppSection.shop, AppSection.other});
    final plan = reset().plan();
    expect(plan.sections, {AppSection.shop: 1, AppSection.other: 1});
    expect(plan.lockedNotes, 1);

    await reset().run();

    expect(container.read(shopProvider), isEmpty);
    expect(container.read(countersProvider), isEmpty);
    expect(container.read(plannerProvider), hasLength(1), reason: 'unlocked');
    expect(noteTitles(), ['Plain']);
    expect(container.read(sectionLocksProvider), isEmpty);
  });

  test('a locked Notes section loses all its notes, locked or not', () async {
    await seed(locked: {AppSection.notes});
    expect(reset().plan().sections, {AppSection.notes: 2});
    expect(reset().plan().lockedNotes, 0, reason: 'counted in the section');

    await reset().run();

    expect(container.read(notesProvider), isEmpty);
    expect(container.read(shopProvider), hasLength(1));
  });

  test('the data is gone on disk before the password is', () async {
    await seed(locked: {AppSection.shop});
    String? notesOnDisk, shopOnDisk;
    container.listen(securityProvider, (_, next) {
      if (next == null) {
        notesOnDisk = file('notes.json');
        shopOnDisk = file('shop.json');
      }
    });

    await reset().run();

    expect(notesOnDisk, isNot(contains('Bank')));
    expect(shopOnDisk, isNot(contains('Milk')));
  });

  test('with nothing locked, the plan deletes nothing', () async {
    await container.read(securityProvider.notifier).setPassword(password);
    container.read(notesProvider.notifier).addNote(title: 'Plain');
    expect(reset().plan().deletesAnything, isFalse);

    await reset().run();
    expect(container.read(securityProvider), isNull);
    expect(noteTitles(), ['Plain']);
  });
}
