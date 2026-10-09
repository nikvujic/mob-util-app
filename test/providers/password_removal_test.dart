import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:the_app/core/crypto.dart';
import 'package:the_app/data/app_storage.dart';
import 'package:the_app/providers/notes_provider.dart';
import 'package:the_app/providers/security_provider.dart';
import 'package:the_app/providers/session_provider.dart';

/// Removing the master password (L1, 12d) unlocks every locked note first,
/// so nothing is left encrypted without a password.
void main() {
  const password = 'master password';

  late Directory dir;
  late ProviderContainer container;

  setUp(() async {
    dir = Directory.systemTemp.createTempSync('removal');
    addTearDown(() => dir.deleteSync(recursive: true));
    final storage = await AppStorage.open(directory: dir);
    container = ProviderContainer(
      overrides: [appStorageProvider.overrideWithValue(storage)],
    );
    addTearDown(container.dispose);
    // Runs first (tear-downs run in reverse): let saves finish before the
    // folder is deleted.
    addTearDown(storage.flush);
  });

  NotesNotifier notes() => container.read(notesProvider.notifier);
  SecurityNotifier security() => container.read(securityProvider.notifier);

  /// A master password and notes "Bank" (locked) and "Plain".
  Future<void> seed() async {
    await security().setPassword(password);
    final keys = (await container.read(sessionProvider.notifier).unlock(
          password,
        ))!;
    notes().addNote(title: 'Plain', content: 'plain text');
    final bank = notes().addNote(title: 'Bank', content: 'PIN 4711');
    await notes().lockNote(bank, keys.dataKey);
  }

  String file(String name) => File('${dir.path}/$name').readAsStringSync();

  test('unlocks every locked note, on disk, then removes the password',
      () async {
    await seed();

    await security().removePassword(password);

    expect(security().hasMasterPassword, isFalse);
    final bank = container.read(notesProvider).firstWhere(
          (n) => n.title == 'Bank',
        );
    expect(bank.isLocked, isFalse);
    expect(bank.content, 'PIN 4711');

    await container.read(appStorageProvider).flush();
    expect(file('notes.json'), isNot(contains('lockedContent')));
    expect(file('notes.json'), contains('PIN 4711'));
    expect(file('security.json'), contains('"masterPassword":null'));
  });

  test('notes are unlocked on disk before the password is gone', () async {
    await seed();
    var notesOnDiskUnlocked = false;
    container.listen(securityProvider, (_, next) {
      if (next == null) {
        notesOnDiskUnlocked = !file('notes.json').contains('lockedContent');
      }
    });

    await security().removePassword(password);

    expect(notesOnDiskUnlocked, isTrue);
  });

  test("keeps everything if a locked note doesn't open with it", () async {
    await seed();
    final foreign = notes().addNote(title: 'Foreign', content: 'x');
    await notes().lockNote(foreign, DataKey.fromBytes(List.filled(32, 9)));
    final before = container.read(notesProvider);

    await expectLater(
      security().removePassword(password),
      throwsA(isA<LockedDataException>()),
    );

    expect(security().hasMasterPassword, isTrue);
    expect(identical(container.read(notesProvider), before), isTrue);
  });

  test('a wrong password changes nothing', () async {
    await seed();
    final before = container.read(notesProvider);

    await expectLater(
      security().removePassword('wrong password'),
      throwsA(isA<WrongPasswordException>()),
    );

    expect(security().hasMasterPassword, isTrue);
    expect(identical(container.read(notesProvider), before), isTrue);
  });
}
