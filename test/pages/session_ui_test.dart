import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:the_app/data/backup.dart';
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
    testWidgets('offers Lock now only while unlocked', (tester) async {
      await start(tester);
      await openMenu(tester);
      await tester.tap(find.text('Lock now'));
      await tester.pumpAndSettle();

      expect(unlocked(), isFalse);
      expect(find.text('Locked'), findsOneWidget); // snackbar
      await openMenu(tester);
      expect(find.text('Lock now'), findsNothing);
    });
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
