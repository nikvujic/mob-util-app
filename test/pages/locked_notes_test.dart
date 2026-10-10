import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:the_app/core/app_info.dart';
import 'package:the_app/data/app_storage.dart';
import 'package:the_app/data/backup_files.dart';
import 'package:the_app/providers/backup_provider.dart';
import 'package:the_app/models/note.dart';
import 'package:the_app/providers/notes_provider.dart';
import 'package:the_app/providers/security_provider.dart';
import 'package:the_app/providers/session_provider.dart';

import '../helpers.dart';

/// Locked notes in the UI (N6, N7): locking, opening, editing, removing
/// the lock, and the setup route when there's no master password yet.
void main() {
  const password = 'master password';

  late ProviderContainer container;
  late DateTime now;

  NotesNotifier notes() => container.read(notesProvider.notifier);
  Note note(String title) =>
      container.read(notesProvider).singleWhere((n) => n.title == title);
  bool unlocked() => container.read(sessionProvider) != null;

  /// The app with notes [titles] (content "<title> text"); with a master
  /// password unless [withPassword] is false, unlocked unless [locked].
  Future<void> start(
    WidgetTester tester, {
    List<String> titles = const ['Bank'],
    bool withPassword = true,
    bool locked = false,
    FakeBackupFiles? files,
  }) async {
    now = DateTime(2026, 10, 8, 12);
    container = await pumpApp(tester, clock: () => now, backupFiles: files);
    for (final title in titles.reversed) {
      notes().addNote(title: title, content: '$title text');
    }
    if (withPassword) {
      await tester.runAsync(() async {
        await container.read(securityProvider.notifier).setPassword(password);
        if (!locked) {
          await container.read(sessionProvider.notifier).unlock(password);
        }
      });
    }
    await tester.pumpAndSettle();
  }

  /// Locks [title] directly (unlocking briefly if needed). Only deriving
  /// the key needs real async; encryption runs on the test's clock, like
  /// everything the UI does with notes.
  Future<void> seedLocked(WidgetTester tester, String title) async {
    final session = container.read(sessionProvider.notifier);
    final wasLocked = !session.isUnlocked;
    if (wasLocked) await tester.runAsync(() => session.unlock(password));
    final key = container.read(sessionProvider)!.dataKey;
    await notes().lockNote(note(title).id, key);
    if (wasLocked) session.lock();
    await tester.pumpAndSettle();
  }

  Future<String> readLocked(String title) => notes()
      .readContent(note(title), container.read(sessionProvider)!.dataKey);

  Future<void> editorAction(WidgetTester tester, String label) async {
    await tester.tap(find.byTooltip(label));
    await tester.pumpAndSettle();
  }

  Future<void> enterPassword(WidgetTester tester, String value) async {
    await tester.enterText(find.byKey(const Key('promptPassword')), value);
    await tester.tap(find.text('Unlock').last);
    await settleBusy(tester);
  }

  Finder lockIcon() => find.byIcon(Icons.lock_outline);

  testWidgets('lock from the editor: title stays, content is encrypted',
      (tester) async {
    await start(tester);
    await tester.tap(find.text('Bank'));
    await tester.pumpAndSettle();
    expect(appBarTitle('Note'), findsOneWidget);

    await editorAction(tester, 'Lock note');

    expect(appBarTitle('Locked note'), findsOneWidget);
    expect(note('Bank').isLocked, isTrue);
    expect(note('Bank').content, isEmpty);
    expect(await readLocked('Bank'), 'Bank text');

    // Locking counts as saving: leaving doesn't ask.
    await leaveNote(tester);
    expect(find.text('Bank'), findsOneWidget);
    expect(lockIcon(), findsOneWidget);
    expect(find.bySemanticsLabel(RegExp('Locked')), findsOneWidget);
  });

  testWidgets('edits to a locked note are saved encrypted', (tester) async {
    await start(tester);
    await seedLocked(tester, 'Bank');

    await tester.tap(find.text('Bank'));
    await tester.pumpAndSettle();
    expect(find.text('Bank text'), findsOneWidget, reason: 'decrypted');

    await tester.enterText(
      find.byKey(const Key('noteContentField')),
      'PIN 4711',
    );
    await leaveNote(tester, save: true);

    expect(note('Bank').content, isEmpty);
    expect(await readLocked('Bank'), 'PIN 4711');
  });

  testWidgets('Discard on a locked note puts back the encrypted original',
      (tester) async {
    await start(tester);
    await seedLocked(tester, 'Bank');
    final original = note('Bank');

    await tester.tap(find.text('Bank'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const Key('noteContentField')), 'oops');
    // Let the autosave run, so there is something to put back.
    await tester.pump(const Duration(seconds: 1));
    await leaveNote(tester, save: false);

    expect(identical(note('Bank'), original), isTrue);
  });

  group('opening a locked note while the app is locked', () {
    testWidgets('asks for the master password first', (tester) async {
      await start(tester, locked: true);
      await seedLocked(tester, 'Bank');

      await tester.tap(find.text('Bank'));
      await tester.pumpAndSettle();
      expect(find.text('Enter the master password to open this note.'),
          findsOneWidget);

      await enterPassword(tester, 'wrong password');
      expect(find.text('Wrong password'), findsOneWidget);

      await enterPassword(tester, password);
      expect(appBarTitle('Locked note'), findsOneWidget);
      expect(find.text('Bank text'), findsOneWidget);
      expect(unlocked(), isTrue, reason: 'unlocks the app too');
    });

    testWidgets('cancelling stays on the list', (tester) async {
      await start(tester, locked: true);
      await seedLocked(tester, 'Bank');

      await tester.tap(find.text('Bank'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();

      expect(appBarTitle('Notes'), findsOneWidget);
      expect(unlocked(), isFalse);
    });
  });

  testWidgets('auto-lock saves and closes an open locked note', (tester) async {
    await start(tester);
    await seedLocked(tester, 'Bank');
    await tester.tap(find.text('Bank'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const Key('noteContentField')), 'new');
    await tester.pump();

    // Gone long enough to lock (see SessionNotifier.autoLockAfter).
    for (final state in [
      AppLifecycleState.inactive,
      AppLifecycleState.hidden,
      AppLifecycleState.paused,
    ]) {
      tester.binding.handleAppLifecycleStateChanged(state);
    }
    now = now.add(const Duration(minutes: 6));
    for (final state in [
      AppLifecycleState.hidden,
      AppLifecycleState.inactive,
      AppLifecycleState.resumed,
    ]) {
      tester.binding.handleAppLifecycleStateChanged(state);
    }
    await tester.pumpAndSettle();

    expect(appBarTitle('Notes'), findsOneWidget);
    expect(find.text('new'), findsNothing);
    expect(unlocked(), isFalse);
    await tester.runAsync(
      () => container.read(sessionProvider.notifier).unlock(password),
    );
    expect(await readLocked('Bank'), 'new');
  });

  testWidgets('an unlocked note stays open when the app locks', (tester) async {
    await start(tester);
    await tester.tap(find.text('Bank'));
    await tester.pumpAndSettle();

    container.read(sessionProvider.notifier).lock();
    await tester.pumpAndSettle();

    expect(appBarTitle('Note'), findsOneWidget);
  });

  testWidgets('Remove lock stores the content in the clear again',
      (tester) async {
    await start(tester);
    await seedLocked(tester, 'Bank');
    await tester.tap(find.text('Bank'));
    await tester.pumpAndSettle();

    await editorAction(tester, 'Remove lock');
    expect(find.text('Remove lock?'), findsOneWidget);
    await tester.tap(find.widgetWithText(FilledButton, 'Remove lock'));
    await tester.pumpAndSettle();

    expect(appBarTitle('Note'), findsOneWidget);
    expect(note('Bank').isLocked, isFalse);
    expect(note('Bank').content, 'Bank text');
  });

  group('without a master password', () {
    testWidgets('locking explains, sets one up, then locks', (tester) async {
      await start(tester, withPassword: false);
      await tester.tap(find.text('Bank'));
      await tester.pumpAndSettle();

      await editorAction(tester, 'Lock note');
      expect(find.text('Set a master password?'), findsOneWidget);
      await tester.tap(find.text('Set password'));
      await tester.pumpAndSettle();

      expect(appBarTitle('Set master password'), findsOneWidget);
      await tester.enterText(find.byKey(const Key('newPassword')), password);
      await tester.enterText(
        find.byKey(const Key('repeatPassword')),
        password,
      );
      await tester.tap(find.widgetWithText(FilledButton, 'Set password'));
      await settleBusy(tester);

      // Back in the note, now locked, without asking for the password again.
      expect(find.byKey(const Key('promptPassword')), findsNothing);
      expect(appBarTitle('Locked note'), findsOneWidget);
      expect(find.text('Master password set'), findsOneWidget);
      expect(unlocked(), isTrue);
      expect(note('Bank').isLocked, isTrue);
    });

    testWidgets('backing out locks nothing', (tester) async {
      await start(tester, withPassword: false);
      await tester.tap(find.text('Bank'));
      await tester.pumpAndSettle();

      await editorAction(tester, 'Lock note');
      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();
      expect(appBarTitle('Note'), findsOneWidget);

      await editorAction(tester, 'Lock note');
      await tester.tap(find.text('Set password'));
      await tester.pumpAndSettle();
      await tester.pageBack();
      await tester.pumpAndSettle();

      expect(appBarTitle('Note'), findsOneWidget);
      expect(note('Bank').isLocked, isFalse);
      expect(container.read(securityProvider), isNull);
    });
  });

  group('selection mode', () {
    testWidgets('locks the selected notes', (tester) async {
      await start(tester, titles: ['Bank', 'Mail', 'Groceries']);
      await tester.longPress(find.text('Bank'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Mail'));
      await tester.pumpAndSettle();

      await tester.tap(find.byTooltip('Lock'));
      await tester.pumpAndSettle();

      expect(find.text('2 notes locked'), findsOneWidget);
      expect(note('Bank').isLocked, isTrue);
      expect(note('Mail').isLocked, isTrue);
      expect(note('Groceries').isLocked, isFalse);
      expect(find.text('2 selected'), findsNothing, reason: 'selection ends');
    });

    testWidgets('offers Remove lock when all selected are locked',
        (tester) async {
      await start(tester, titles: ['Bank', 'Mail']);
      await seedLocked(tester, 'Bank');

      await tester.longPress(find.text('Bank'));
      await tester.pumpAndSettle();
      expect(find.byTooltip('Remove lock'), findsOneWidget);

      await tester.tap(find.text('Mail'));
      await tester.pumpAndSettle();
      expect(find.byTooltip('Remove lock'), findsNothing);
      expect(find.byTooltip('Lock'), findsOneWidget);

      await tester.tap(find.text('Mail'));
      await tester.pumpAndSettle();
      await tester.tap(find.byTooltip('Remove lock'));
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(FilledButton, 'Remove lock'));
      await tester.pumpAndSettle();

      expect(note('Bank').isLocked, isFalse);
      expect(note('Bank').content, 'Bank text');
    });
  });

  testWidgets('removing the master password says it unlocks locked notes',
      (tester) async {
    await start(tester, titles: ['Bank', 'Mail']);
    await seedLocked(tester, 'Bank');

    await openMenu(tester);
    await tester.tap(find.text('Security'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Remove master password'));
    await tester.pumpAndSettle();
    expect(
      find.text('1 locked note will be unlocked and stored unencrypted.'),
      findsOneWidget,
    );

    await tester.enterText(find.byKey(const Key('currentPassword')), password);
    await tester.tap(find.widgetWithText(FilledButton, 'Remove password'));
    await settleBusy(tester);

    expect(find.text('Master password removed'), findsOneWidget);
    expect(note('Bank').isLocked, isFalse);
    expect(note('Bank').content, 'Bank text');
  });

  testWidgets("restoring another phone's locked notes asks for its password",
      (tester) async {
    const oldPassword = 'old phone password';
    // A backup from another phone, with a locked note.
    final oldFiles = FakeBackupFiles();
    final old = ProviderContainer(
      overrides: [
        appStorageProvider.overrideWithValue(AppStorage.inMemory()),
        appVersionProvider.overrideWithValue('1'),
        backupFilesProvider.overrideWithValue(oldFiles),
      ],
    );
    addTearDown(old.dispose);
    await tester.runAsync(() async {
      await old.read(securityProvider.notifier).setPassword(oldPassword);
      final keys = await old.read(sessionProvider.notifier).unlock(oldPassword);
      final id = old
          .read(notesProvider.notifier)
          .addNote(title: 'Old bank', content: 'old PIN');
      await old.read(notesProvider.notifier).lockNote(id, keys!.dataKey);
      await old.read(backupExporterProvider).export();
    });

    await start(
      tester,
      files: FakeBackupFiles()..toPick = oldFiles.saved.single.bytes,
    );
    await openMenu(tester);
    await tester.tap(find.text('Backup'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Import from file'));
    await tester.pumpAndSettle();
    expect(find.textContaining('1 note (1 locked)'), findsOneWidget);
    await tester.tap(find.widgetWithText(FilledButton, 'Restore'));
    await tester.pumpAndSettle();

    expect(find.text('Locked notes'), findsOneWidget);
    await tester.enterText(find.byKey(const Key('promptPassword')), password);
    await tester.tap(find.text('OK'));
    await settleBusy(tester);
    expect(find.text('Wrong password'), findsOneWidget);

    await tester.enterText(
      find.byKey(const Key('promptPassword')),
      oldPassword,
    );
    await tester.tap(find.text('OK'));
    await settleBusy(tester);

    expect(find.text('Backup restored'), findsOneWidget);
    expect(note('Old bank').isLocked, isTrue);
    expect(await readLocked('Old bank'), 'old PIN', reason: 'our key');
  });
}
