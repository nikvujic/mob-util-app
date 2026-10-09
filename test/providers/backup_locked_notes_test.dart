import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:the_app/core/app_info.dart';
import 'package:the_app/core/crypto.dart';
import 'package:the_app/data/app_storage.dart';
import 'package:the_app/data/backup_files.dart';
import 'package:the_app/models/note.dart';
import 'package:the_app/providers/backup_provider.dart';
import 'package:the_app/providers/notes_provider.dart';
import 'package:the_app/providers/security_provider.dart';
import 'package:the_app/providers/session_provider.dart';

import '../helpers.dart';

/// Backups with locked notes (D3, 12e): the notes stay encrypted in the
/// file, and after restoring they open with a master password the user
/// knows.
void main() {
  const oldPhonePassword = 'old phone password';
  const newPhonePassword = 'new phone password';

  late FakeBackupFiles files;

  setUp(() => files = FakeBackupFiles());

  /// A "phone": the app's state, with [password] set and unlocked if given.
  Future<ProviderContainer> phone({String? password}) async {
    final container = ProviderContainer(
      overrides: [
        appStorageProvider.overrideWithValue(AppStorage.inMemory()),
        appVersionProvider.overrideWithValue('1'),
        backupFilesProvider.overrideWithValue(files),
      ],
    );
    addTearDown(container.dispose);
    if (password != null) {
      await container.read(securityProvider.notifier).setPassword(password);
      await container.read(sessionProvider.notifier).unlock(password);
    }
    return container;
  }

  DataKey keyOf(ProviderContainer phone) =>
      phone.read(sessionProvider)!.dataKey;
  Note noteOf(ProviderContainer phone, String title) =>
      phone.read(notesProvider).singleWhere((n) => n.title == title);

  /// The old phone, with a plain note and a locked "Bank" note.
  Future<ProviderContainer> oldPhone() async {
    final old = await phone(password: oldPhonePassword);
    final notes = old.read(notesProvider.notifier);
    notes.addNote(title: 'Plain', content: 'plain text');
    final bank = notes.addNote(title: 'Bank', content: 'PIN 4711');
    await notes.lockNote(bank, keyOf(old));
    return old;
  }

  Future<RestorableBackup> exported(
    ProviderContainer from, {
    bool encrypted = false,
  }) async {
    final exporter = from.read(backupExporterProvider);
    if (encrypted) {
      await exporter.exportEncrypted(from.read(sessionProvider)!.passwordKey);
    } else {
      await exporter.export();
    }
    final bytes = Uint8List.fromList(files.saved.last.bytes);
    final importer = from.read(backupImporterProvider);
    return switch (importer.read(bytes)) {
      PlainPick(:final backup) => backup,
      final EncryptedPick pick => (await pick.unlock(oldPhonePassword))!,
    };
  }

  /// A prompt for the backup's password that answers [password] and
  /// counts how often it's asked.
  var backupPrompts = 0;
  AskBackupKey answering(String password) => (record) async {
        backupPrompts++;
        final key = await record.unlock(password);
        return key == null ? null : record.unwrapDataKey(key);
      };
  setUp(() => backupPrompts = 0);

  group('export', () {
    test('keeps locked notes encrypted and carries their key', () async {
      final old = await oldPhone();
      await old.read(backupExporterProvider).export();
      final file = utf8.decode(files.saved.single.bytes);

      expect(file, isNot(contains('PIN 4711')));
      expect(file, contains('"lockedContent"'));
      expect(file, contains('"masterPassword"'));
      expect(file, contains('"dataKey"'));
    });

    test('carries no key when nothing is locked', () async {
      final container = await phone(password: oldPhonePassword);
      container.read(notesProvider.notifier).addNote(title: 'Plain');
      await container.read(backupExporterProvider).export();

      expect(
        utf8.decode(files.saved.single.bytes),
        isNot(contains('masterPassword')),
      );
    });
  });

  /// Sets [password] on [phone] after removing [current], if any.
  Future<void> newPassword(
    ProviderContainer phone,
    String password, {
    String? current,
  }) async {
    final security = phone.read(securityProvider.notifier);
    if (current != null) await security.removePassword(current);
    await security.setPassword(password);
    await phone.read(sessionProvider.notifier).unlock(password);
  }

  /// Whether [password] opens [phone]'s locked "Bank" note.
  Future<bool> opensBank(ProviderContainer phone, String password) async {
    final record = phone.read(securityProvider);
    final key = await record?.unlock(password);
    if (key == null) return false;
    final dataKey = (await record!.unwrapDataKey(key))!;
    return await NotesNotifier.openContent(noteOf(phone, 'Bank'), dataKey) ==
        'PIN 4711';
  }

  // Every case for both kinds of backup: locked notes travel the same way
  // in each; an encrypted one only needs a password to open the file, and
  // that password is then reused instead of asked again.
  for (final encrypted in [false, true]) {
    final kind = encrypted ? 'encrypted' : 'plain';

    /// How often restoring asks for the backup's password when its locked
    /// notes don't fit this phone.
    final expectedPrompts = encrypted ? 0 : 1;

    Future<RestorableBackup> backupOf(ProviderContainer from) =>
        exported(from, encrypted: encrypted);

    group('$kind backup, on a phone without a master password', () {
      test("takes over the backup's password; the notes open with it",
          () async {
        final backup = await backupOf(await oldPhone());
        final target = await phone();

        final undo = await target.read(backupImporterProvider).restore(
              backup,
              backupKey: answering(oldPhonePassword),
            );

        expect(undo!.adoptedMasterPassword, isTrue);
        expect(backupPrompts, 0);
        expect(await opensBank(target, oldPhonePassword), isTrue);
        expect(noteOf(target, 'Plain').content, 'plain text');
      });

      test('changing that password afterwards keeps the notes readable',
          () async {
        final backup = await backupOf(await oldPhone());
        final target = await phone();
        await target.read(backupImporterProvider).restore(backup);

        await target
            .read(securityProvider.notifier)
            .changePassword(oldPhonePassword, newPhonePassword);

        expect(await opensBank(target, newPhonePassword), isTrue);
        expect(await opensBank(target, oldPhonePassword), isFalse);
      });

      test('undo also takes the password away again', () async {
        final backup = await backupOf(await oldPhone());
        final target = await phone();
        target.read(notesProvider.notifier).addNote(title: 'Before');
        final importer = target.read(backupImporterProvider);

        await importer.undo((await importer.restore(backup))!);

        expect(target.read(securityProvider), isNull);
        expect(target.read(notesProvider).single.title, 'Before');
      });
    });

    group('$kind backup, on the phone it was made on', () {
      test('with the same password: asks nothing', () async {
        final old = await oldPhone();
        final backup = await backupOf(old);
        old.read(notesProvider.notifier).replaceAll(const []);

        await old.read(backupImporterProvider).restore(
              backup,
              backupKey: answering(oldPhonePassword),
            );

        expect(backupPrompts, 0);
        expect(await opensBank(old, oldPhonePassword), isTrue);
      });

      test('after changing the password: asks nothing, opens with the new',
          () async {
        final old = await oldPhone();
        final backup = await backupOf(old);
        await old
            .read(securityProvider.notifier)
            .changePassword(oldPhonePassword, newPhonePassword);
        await old.read(sessionProvider.notifier).unlock(newPhonePassword);

        await old.read(backupImporterProvider).restore(
              backup,
              backupKey: answering(oldPhonePassword),
            );

        expect(backupPrompts, 0, reason: 'a change keeps the note key');
        expect(await opensBank(old, newPhonePassword), isTrue);
      });

      test('after removing it and setting a new one: opens with the new',
          () async {
        final old = await oldPhone();
        final backup = await backupOf(old);
        await newPassword(old, newPhonePassword, current: oldPhonePassword);

        await old.read(backupImporterProvider).restore(
              backup,
              backupKey: answering(oldPhonePassword),
            );

        expect(backupPrompts, expectedPrompts, reason: 'a new note key');
        expect(noteOf(old, 'Bank').isLocked, isTrue);
        expect(await opensBank(old, newPhonePassword), isTrue);
      });

      test('while locked: asks to unlock this phone first', () async {
        final old = await oldPhone();
        final backup = await backupOf(old);
        old.read(sessionProvider.notifier).lock();
        var asked = 0;

        await old.read(backupImporterProvider).restore(
          backup,
          thisAppKey: () async {
            asked++;
            return (await old
                    .read(sessionProvider.notifier)
                    .unlock(oldPhonePassword))
                ?.dataKey;
          },
        );

        expect(asked, 1);
        expect(await opensBank(old, oldPhonePassword), isTrue);
      });
    });

    group('$kind backup, on another phone with its own password', () {
      test("re-locks the notes under this phone's password", () async {
        final backup = await backupOf(await oldPhone());
        final target = await phone(password: newPhonePassword);

        final undo = await target.read(backupImporterProvider).restore(
              backup,
              backupKey: answering(oldPhonePassword),
            );

        expect(backupPrompts, expectedPrompts);
        expect(undo!.adoptedMasterPassword, isFalse);
        expect(await opensBank(target, newPhonePassword), isTrue);
        expect(noteOf(target, 'Plain').content, 'plain text');
      });
    });
  }

  test("a forgotten backup password changes nothing (plain backup)", () async {
    final backup = await exported(await oldPhone());
    final target = await phone(password: newPhonePassword);
    target.read(notesProvider.notifier).addNote(title: 'Mine');
    final before = target.read(notesProvider);

    // The prompt keeps saying "Wrong password" until the user cancels.
    final undo = await target.read(backupImporterProvider).restore(
          backup,
          backupKey: answering('not the password'),
        );

    expect(undo, isNull);
    expect(identical(target.read(notesProvider), before), isTrue);
  });

  test('locked notes without their key are refused, not restored', () async {
    final old = await oldPhone();
    final backup = await exported(old);
    // The same backup with its key removed, as a damaged file might be.
    final json = jsonDecode(utf8.decode(files.saved.single.bytes))
        as Map<String, dynamic>;
    (json['data'] as Map<String, dynamic>).remove('masterPassword');
    final keyless = (old
                .read(backupImporterProvider)
                .read(Uint8List.fromList(utf8.encode(jsonEncode(json))))
            as PlainPick)
        .backup;
    expect(backup.lockedNoteCount, keyless.lockedNoteCount);

    final target = await phone();
    await expectLater(
      target.read(backupImporterProvider).restore(keyless),
      throwsA(isA<ImportException>()),
    );
    expect(target.read(notesProvider), isEmpty);
    expect(target.read(securityProvider), isNull);
  });
}
