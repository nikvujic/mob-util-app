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

  group('restoring on a phone without a master password', () {
    test("takes over the backup's password; the notes open with it", () async {
      final backup = await exported(await oldPhone());
      final target = await phone();

      final undo = await target.read(backupImporterProvider).restore(backup);

      expect(undo!.adoptedMasterPassword, isTrue);
      final keys =
          await target.read(sessionProvider.notifier).unlock(oldPhonePassword);
      expect(keys, isNotNull);
      expect(
        await NotesNotifier.openContent(noteOf(target, 'Bank'), keys!.dataKey),
        'PIN 4711',
      );
    });

    test('undo also takes the password away again', () async {
      final backup = await exported(await oldPhone());
      final target = await phone();
      target.read(notesProvider.notifier).addNote(title: 'Before');
      final importer = target.read(backupImporterProvider);

      await importer.undo((await importer.restore(backup))!);

      expect(target.read(securityProvider), isNull);
      expect(target.read(notesProvider).single.title, 'Before');
    });
  });

  group('restoring on a phone with a master password', () {
    test('a backup from the same phone needs no other password', () async {
      final old = await oldPhone();
      final backup = await exported(old);
      old.read(notesProvider.notifier).replaceAll(const []);

      await old.read(backupImporterProvider).restore(
            backup,
            backupKey: answering(oldPhonePassword),
          );

      expect(backupPrompts, 0);
      expect(
        await NotesNotifier.openContent(noteOf(old, 'Bank'), keyOf(old)),
        'PIN 4711',
      );
    });

    test('asks to unlock this phone first if it is locked', () async {
      final old = await oldPhone();
      final backup = await exported(old);
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
      expect(noteOf(old, 'Bank').isLocked, isTrue);
    });

    test("another phone's notes are re-locked under this phone's key",
        () async {
      final backup = await exported(await oldPhone());
      final target = await phone(password: newPhonePassword);

      final undo = await target.read(backupImporterProvider).restore(
            backup,
            backupKey: answering(oldPhonePassword),
          );

      expect(backupPrompts, 1);
      expect(undo!.adoptedMasterPassword, isFalse);
      final bank = noteOf(target, 'Bank');
      expect(bank.isLocked, isTrue);
      expect(
        await NotesNotifier.openContent(bank, keyOf(target)),
        'PIN 4711',
      );
      expect(noteOf(target, 'Plain').content, 'plain text');
      // This phone's password stays.
      expect(
        await target.read(securityProvider)!.unlock(newPhonePassword),
        isNotNull,
      );
    });

    test("an encrypted backup's password is used, not asked again", () async {
      final backup = await exported(await oldPhone(), encrypted: true);
      final target = await phone(password: newPhonePassword);

      await target.read(backupImporterProvider).restore(
            backup,
            backupKey: answering(oldPhonePassword),
          );

      expect(backupPrompts, 0);
      expect(
        await NotesNotifier.openContent(
          noteOf(target, 'Bank'),
          keyOf(target),
        ),
        'PIN 4711',
      );
    });

    test('cancelling a prompt changes nothing', () async {
      final backup = await exported(await oldPhone());
      final target = await phone(password: newPhonePassword);
      target.read(notesProvider.notifier).addNote(title: 'Mine');
      final before = target.read(notesProvider);

      final undo = await target.read(backupImporterProvider).restore(
            backup,
            backupKey: (_) async => null,
          );

      expect(undo, isNull);
      expect(identical(target.read(notesProvider), before), isTrue);
    });
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
