import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:the_app/core/app_info.dart';
import 'package:the_app/core/clock.dart';
import 'package:the_app/data/app_storage.dart';
import 'package:the_app/data/backup.dart';
import 'package:the_app/data/backup_folder.dart';
import 'package:the_app/models/app_section.dart';
import 'package:the_app/models/preferences.dart';
import 'package:the_app/providers/auto_backup_provider.dart';
import 'package:the_app/providers/notes_provider.dart';
import 'package:the_app/providers/preferences_provider.dart';
import 'package:the_app/providers/section_locks_provider.dart';
import 'package:the_app/providers/security_provider.dart';
import 'package:the_app/providers/session_provider.dart';

import '../helpers.dart';

/// Automatic backup (Round 39): once a day into a folder picked once.
void main() {
  late ProviderContainer container;
  late FakeBackupFolder folder;
  late DateTime now;

  setUp(() {
    now = DateTime(2026, 10, 14, 9, 5);
    folder = FakeBackupFolder(
        picks: (uri: 'content://tree/Backups', name: 'Backups'));
    container = ProviderContainer(overrides: [
      appStorageProvider.overrideWithValue(AppStorage.inMemory()),
      appVersionProvider.overrideWithValue('1.7.0 (42)'),
      clockProvider.overrideWithValue(() => now),
      backupFolderProvider.overrideWithValue(folder),
    ]);
    addTearDown(container.dispose);
  });

  AutoBackup auto() => container.read(autoBackupProvider);
  Preferences preferences() => container.read(preferencesProvider);

  test('off until a folder is picked', () async {
    expect(await auto().run(), AutoBackupResult.off);
    expect(folder.written, isEmpty);
  });

  test('picked: backs up into it straight away, as Export writes it', () async {
    container.read(notesProvider.notifier).addNote(title: 'Kept');
    expect(await auto().pickFolder(), AutoBackupResult.written);
    expect(preferences().autoBackupFolderName, 'Backups');
    final file = folder.written.single;
    expect(file.folder, 'content://tree/Backups');
    expect(file.name, 'the-app-auto-2026-10-14-0905.json');
    expect(file.prefix, AutoBackup.prefix);
    expect(file.keep, 7);
    final backup = (BackupFile.parse(file.text) as PlainBackupFile).backup;
    expect(backup.notes.single.title, 'Kept');
    expect(preferences().lastAutoBackupAt, now);
    expect(preferences().lastBackupAt, now, reason: 'the reminder counts it');
  });

  test('once a day', () async {
    await auto().pickFolder();
    now = now.add(const Duration(hours: 20));
    expect(await auto().run(), AutoBackupResult.notDue);
    now = now.add(const Duration(hours: 5));
    expect(await auto().run(), AutoBackupResult.written);
    expect(folder.written, hasLength(2));
  });

  test('cancelled picking: stays off', () async {
    folder.picks = null;
    expect(await auto().pickFolder(), isNull);
    expect(preferences().autoBackupFolder, isNull);
  });

  test('the folder gone: says so; the next one that works clears it', () async {
    await auto().pickFolder();
    folder.works = false;
    now = now.add(const Duration(days: 1));
    expect(await auto().run(), AutoBackupResult.failed);
    expect(preferences().autoBackupFailed, isTrue);
    folder.works = true;
    expect(await auto().run(), AutoBackupResult.written);
    expect(preferences().autoBackupFailed, isFalse);
  });

  test('while a section is locked: waits for the app to be unlocked', () async {
    await auto().pickFolder();
    await container
        .read(securityProvider.notifier)
        .setPassword('master password');
    await container.read(sessionProvider.notifier).unlock('master password');
    container.read(sectionLocksProvider.notifier).lock(AppSection.notes);
    container.read(sessionProvider.notifier).lock();
    now = now.add(const Duration(days: 1));
    expect(await auto().run(), AutoBackupResult.locked);
    expect(folder.written, hasLength(1));
  });

  test('turned off: nothing more', () async {
    await auto().pickFolder();
    auto().turnOff();
    now = now.add(const Duration(days: 2));
    expect(await auto().run(), AutoBackupResult.off);
    expect(preferences().autoBackupFolder, isNull);
  });

  test('kept on this phone', () {
    final on = Preferences(
      autoBackupFolder: 'content://x',
      autoBackupFolderName: 'Drive',
      lastAutoBackupAt: DateTime(2026, 10, 14, 9),
      autoBackupFailed: true,
    );
    final back = Preferences.fromJson(on.toJson());
    expect(back.autoBackupFolder, 'content://x');
    expect(back.autoBackupFolderName, 'Drive');
    expect(back.lastAutoBackupAt, DateTime(2026, 10, 14, 9));
    expect(back.autoBackupFailed, isTrue);
    expect(Preferences.fromJson(const {}).autoBackupFolder, isNull);
  });
}
