import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:the_app/data/backup.dart';
import 'package:the_app/models/app_section.dart';
import 'package:the_app/providers/notes_provider.dart';
import 'package:the_app/providers/section_locks_provider.dart';
import 'package:the_app/providers/security_provider.dart';
import 'package:the_app/providers/session_provider.dart';

import '../helpers.dart';

void main() {
  const password = 'master password';

  late ProviderContainer container;
  late DateTime now;
  late FakeBackupFiles files;

  bool unlocked() => container.read(sessionProvider) != null;

  /// The app with a master password set, unlocked unless [locked].
  Future<void> start(WidgetTester tester, {bool locked = false}) async {
    now = DateTime(2026, 10, 8, 12);
    files = FakeBackupFiles();
    container = await pumpApp(tester, backupFiles: files, clock: () => now);
    await tester.runAsync(() async {
      await container.read(securityProvider.notifier).setPassword(password);
      if (!locked) {
        await container.read(sessionProvider.notifier).unlock(password);
      }
    });
    await tester.pump();
  }

  /// Sends the app to the background for [away], then brings it back.
  Future<void> goAway(WidgetTester tester, Duration away) async {
    for (final state in [
      AppLifecycleState.inactive,
      AppLifecycleState.hidden,
      AppLifecycleState.paused,
    ]) {
      tester.binding.handleAppLifecycleStateChanged(state);
    }
    now = now.add(away);
    for (final state in [
      AppLifecycleState.hidden,
      AppLifecycleState.inactive,
      AppLifecycleState.resumed,
    ]) {
      tester.binding.handleAppLifecycleStateChanged(state);
    }
    await tester.pump();
  }

  group('auto-lock', () {
    testWidgets('a short trip away keeps it unlocked', (tester) async {
      await start(tester);
      await goAway(tester, const Duration(minutes: 2));
      expect(unlocked(), isTrue);
    });

    testWidgets('5 minutes away locks', (tester) async {
      await start(tester);
      await goAway(tester, const Duration(minutes: 5));
      expect(unlocked(), isFalse);
    });
  });

  group('menu', () {
    testWidgets(
        'offers Lock now only while unlocked; locks quietly, the menu '
        'staying open (Round 24)', (tester) async {
      await start(tester);
      container.read(sectionLocksProvider.notifier).lock(AppSection.notes);
      await openMenu(tester);
      await tester.tap(find.byTooltip('Lock now'));
      await tester.pumpAndSettle();

      expect(unlocked(), isFalse);
      expect(find.byType(Drawer), findsOneWidget, reason: 'still open');
      expect(find.byTooltip('Lock now'), findsNothing);
      expect(find.byType(SnackBar), findsNothing);
    });

    testWidgets('the header: Pip, and the same height locked or not (Round 25)',
        (tester) async {
      await start(tester);
      await openMenu(tester);
      expect(find.byKey(const Key('menuPip')), findsOneWidget);
      // The title a little below Pip's middle (Round 27).
      final pip = tester.getCenter(find.byKey(const Key('menuPip'))).dy;
      final title = tester.getCenter(find.byKey(const Key('menuTitle'))).dy;
      expect(title - pip, inInclusiveRange(1, 5));
      final unlocked = tester.getSize(find.byKey(const Key('menuHeader')));
      final items = tester.getTopLeft(find.text('Security')).dy;
      await tester.tap(find.byTooltip('Lock now'));
      await tester.pumpAndSettle();
      expect(tester.getSize(find.byKey(const Key('menuHeader'))), unlocked);
      expect(tester.getTopLeft(find.text('Security')).dy, items,
          reason: "the menu doesn't shift");
    });

    testWidgets(
        "locking from Security while on a locked section: Security stays "
        '(Round 24)', (tester) async {
      await start(tester);
      container.read(sectionLocksProvider.notifier).lock(AppSection.notes);
      await openMenu(tester);
      await tester.tap(find.text('Security'));
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(TextButton, 'Lock now'));
      await tester.pumpAndSettle();
      expect(unlocked(), isFalse);
      expect(appBarTitle('Security'), findsOneWidget);
    });
  });

  testWidgets(
      'locking while "Save changes?" is open saves and keeps the app '
      '(Notes locked)', (tester) async {
    await start(tester);
    container.read(sectionLocksProvider.notifier).lock(AppSection.notes);
    final id = container
        .read(notesProvider.notifier)
        .addNote(title: 'Shopping', content: 'milk');
    await tester.pump();
    await tester.tap(find.text('Shopping'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const Key('noteContentField')), 'eggs');
    await tester.pump();
    await tester.pageBack();
    await tester.pumpAndSettle();
    expect(find.text('Save changes?'), findsOneWidget);

    container.read(sessionProvider.notifier).lock();
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    expect(find.byType(BottomNavigationBar), findsOneWidget,
        reason: 'the home screen stays');
    final note = container.read(notesProvider).firstWhere((n) => n.id == id);
    expect(note.content, 'eggs');
  });

  testWidgets('Lock now sits top right of the menu and doesn\'t scroll',
      (tester) async {
    await start(tester);
    await openMenu(tester);
    final drawer = tester.getRect(find.byType(Drawer));
    final lock = tester.getRect(find.byTooltip('Lock now'));
    expect(lock.center.dx, greaterThan(drawer.center.dx), reason: 'right');
    expect(lock.top, lessThan(drawer.top + 80), reason: 'top');

    // Pulling the list down (reach mode) doesn't move it.
    await tester.drag(find.text('Security'), const Offset(0, 200));
    await tester.pumpAndSettle();
    expect(tester.getRect(find.byTooltip('Lock now')), lock);

    // Themes now comes before Backup.
    expect(tester.getTopLeft(find.text('Themes')).dy,
        lessThan(tester.getTopLeft(find.text('Backup')).dy));
  });

  group('Security page', () {
    Future<void> openSecurity(WidgetTester tester) async {
      await openMenu(tester);
      await tester.tap(find.text('Security'));
      await tester.pumpAndSettle();
    }

    testWidgets('shows the state and unlocks with the password',
        (tester) async {
      await start(tester, locked: true);
      await openSecurity(tester);
      expect(find.text('Locked'), findsOneWidget);

      await tester.tap(find.widgetWithText(TextButton, 'Unlock'));
      await tester.pumpAndSettle();
      await tester.enterText(
        find.descendant(
          of: find.byKey(const Key('promptPassword')),
          matching: find.byType(TextField),
        ),
        password,
      );
      await tester.tap(find.widgetWithText(FilledButton, 'Unlock'));
      await tester.pump();
      await settleBusy(tester);

      expect(unlocked(), isTrue);
      expect(find.text('Unlocked'), findsOneWidget);

      await tester.tap(find.widgetWithText(TextButton, 'Lock now'));
      await tester.pump();
      expect(unlocked(), isFalse);
      expect(find.text('Locked'), findsOneWidget);
    });
  });

  group('encrypted export', () {
    Future<void> exportEncrypted(WidgetTester tester) async {
      await openMenu(tester);
      await tester.tap(find.text('Backup'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Export all data'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Encrypted file'));
      await tester.pump();
      await settleBusy(tester);
    }

    testWidgets('needs no password while unlocked', (tester) async {
      await start(tester);
      await exportEncrypted(tester);

      expect(find.byType(AlertDialog), findsNothing, reason: 'no prompt');
      expect(find.text('Encrypted backup saved'), findsOneWidget);
      final file = BackupFile.parse(utf8.decode(files.saved.single.bytes));
      expect(file, isA<EncryptedBackupFile>());
    });

    testWidgets('asks when locked, and that unlocks the session',
        (tester) async {
      await start(tester, locked: true);
      await exportEncrypted(tester);
      expect(find.text('Encrypt backup'), findsOneWidget);

      await tester.enterText(
        find.descendant(
          of: find.byKey(const Key('promptPassword')),
          matching: find.byType(TextField),
        ),
        password,
      );
      await tester.tap(find.text('Encrypt'));
      await tester.pump();
      await settleBusy(tester);

      expect(find.text('Encrypted backup saved'), findsOneWidget);
      expect(unlocked(), isTrue);
    });
  });
}
