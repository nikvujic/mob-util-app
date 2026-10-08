import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:the_app/data/backup.dart';
import 'package:the_app/providers/notes_provider.dart';
import 'package:the_app/providers/security_provider.dart';

import '../helpers.dart';

void main() {
  const password = 'master password';
  late FakeBackupFiles files;
  late ProviderContainer container;

  Future<void> openBackup(
    WidgetTester tester, {
    bool withPassword = false,
  }) async {
    files = FakeBackupFiles();
    container = await pumpApp(tester, backupFiles: files);
    container.read(notesProvider.notifier).addNote(title: 'Groceries');
    if (withPassword) {
      await tester.runAsync(
        () => container.read(securityProvider.notifier).setPassword(password),
      );
    }
    await openMenu(tester);
    await tester.tap(find.text('Backup'));
    await tester.pumpAndSettle();
  }

  /// Export all data → Plain file.
  Future<void> tapExport(WidgetTester tester) async {
    await tester.tap(find.text('Export all data'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Plain file'));
    await tester.pumpAndSettle();
  }

  Future<void> chooseEncrypted(WidgetTester tester) async {
    await tester.tap(find.text('Export all data'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Encrypted file'));
    await tester.pumpAndSettle();
  }

  Future<void> enterPassword(WidgetTester tester, String pw) async {
    await tester.enterText(
      find.descendant(
        of: find.byKey(const Key('promptPassword')),
        matching: find.byType(TextField),
      ),
      pw,
    );
    await tester.tap(find.text('Encrypt'));
    await tester.pump();
    await settleBusy(tester);
  }

  testWidgets('export saves a backup and confirms it', (tester) async {
    await openBackup(tester);
    await tapExport(tester);

    expect(find.text('Backup saved'), findsOneWidget);
    final backup = Backup.decode(utf8.decode(files.saved.single.bytes));
    expect(backup.notes.single.title, 'Groceries');
  });

  testWidgets('cancelling the save dialog shows nothing', (tester) async {
    await openBackup(tester);
    files.cancel = true;
    await tapExport(tester);

    expect(find.byType(SnackBar), findsNothing);
  });

  testWidgets('a failed save is reported', (tester) async {
    await openBackup(tester);
    files.error = Exception('disk full');
    await tapExport(tester);

    expect(
      find.text("Couldn't save the backup. Please try again."),
      findsOneWidget,
    );
  });

  testWidgets('export is disabled while it runs', (tester) async {
    await openBackup(tester);
    files.pending = Completer<bool>();

    await tester.tap(find.text('Export all data'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Plain file'));
    await tester.pump();
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    final tile = tester.widget<ListTile>(
      find.widgetWithText(ListTile, 'Export all data'),
    );
    expect(tile.onTap, isNull);

    files.pending!.complete(true);
    await tester.pumpAndSettle();
    expect(find.byType(CircularProgressIndicator), findsNothing);
  });

  testWidgets('closing the choice dialog exports nothing', (tester) async {
    await openBackup(tester);
    await tester.tap(find.text('Export all data'));
    await tester.pumpAndSettle();
    await tester.tapAt(const Offset(5, 5));
    await tester.pumpAndSettle();

    expect(files.saved, isEmpty);
    expect(find.byType(SnackBar), findsNothing);
  });

  group('encrypted', () {
    testWidgets('needs a master password', (tester) async {
      await openBackup(tester);
      await tester.tap(find.text('Export all data'));
      await tester.pumpAndSettle();

      expect(
          find.text('Set a master password in Security first'), findsOneWidget);
      final tile = tester.widget<ListTile>(
        find.widgetWithText(ListTile, 'Encrypted file'),
      );
      expect(tile.enabled, isFalse);
    });

    testWidgets('asks for the master password, then saves an encrypted file',
        (tester) async {
      await openBackup(tester, withPassword: true);
      await chooseEncrypted(tester);

      await enterPassword(tester, 'not my password');
      expect(find.text('Wrong password'), findsOneWidget);
      expect(files.saved, isEmpty);

      await enterPassword(tester, password);
      expect(find.text('Encrypted backup saved'), findsOneWidget);

      final file = files.saved.single;
      expect(file.fileName, endsWith('-encrypted.json'));
      final source = utf8.decode(file.bytes);
      expect(source, isNot(contains('Groceries')));

      final parsed = BackupFile.parse(source) as EncryptedBackupFile;
      final backup = await tester.runAsync(() => parsed.open(password));
      expect(backup!.notes.single.title, 'Groceries');
    });

    testWidgets('cancelling the password prompt exports nothing',
        (tester) async {
      await openBackup(tester, withPassword: true);
      await chooseEncrypted(tester);
      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();

      expect(files.saved, isEmpty);
      expect(find.byType(SnackBar), findsNothing);
    });
  });

  testWidgets('import is shown as coming soon', (tester) async {
    await openBackup(tester);
    final tile = tester.widget<ListTile>(
      find.widgetWithText(ListTile, 'Import from file'),
    );
    expect(tile.enabled, isFalse);
  });
}
