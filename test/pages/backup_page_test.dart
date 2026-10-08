import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:the_app/data/backup.dart';
import 'package:the_app/models/note.dart';
import 'package:the_app/models/shop_item.dart';
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

  group('import', () {
    Backup sample() => Backup(
          createdAt: DateTime(2026, 10, 8, 9, 30),
          appVersion: '0.9.0 (10)',
          notes: [
            Note(
              id: 'b1',
              title: 'Restored note',
              content: '',
              createdAt: DateTime(2026, 10, 1),
              modifiedAt: DateTime(2026, 10, 1),
            ),
            Note(
              id: 'b2',
              title: 'Second restored',
              content: '',
              createdAt: DateTime(2026, 10, 1),
              modifiedAt: DateTime(2026, 10, 1),
            ),
          ],
          shopItems: const [ShopItem(id: 'i1', name: 'Coffee')],
        );

    List<String> titles() =>
        container.read(notesProvider).map((n) => n.title).toList();

    Future<void> tapImport(WidgetTester tester) async {
      await tester.tap(find.text('Import from file'));
      await tester.pumpAndSettle();
    }

    testWidgets('shows what the backup holds, restores it, and can undo',
        (tester) async {
      await openBackup(tester);
      files.toPick = Uint8List.fromList(utf8.encode(sample().encode()));
      await tapImport(tester);

      expect(find.text('Restore this backup?'), findsOneWidget);
      expect(find.textContaining('2 notes · 1 shop item'), findsOneWidget);
      expect(find.textContaining('2026-10-08'), findsOneWidget);
      expect(titles(), ['Groceries'], reason: 'nothing changed yet');

      await tester.tap(find.text('Restore'));
      await tester.pump();
      await settleBusy(tester);
      expect(titles(), ['Restored note', 'Second restored']);
      expect(find.text('Backup restored'), findsOneWidget);

      await tester.tap(find.text('Undo'));
      await tester.pumpAndSettle();
      expect(titles(), ['Groceries']);
    });

    testWidgets('cancelling the confirmation changes nothing', (tester) async {
      await openBackup(tester);
      files.toPick = Uint8List.fromList(utf8.encode(sample().encode()));
      await tapImport(tester);
      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();

      expect(titles(), ['Groceries']);
      expect(find.byType(SnackBar), findsNothing);
    });

    testWidgets('cancelling the file picker does nothing', (tester) async {
      await openBackup(tester);
      await tapImport(tester);

      expect(find.byType(AlertDialog), findsNothing);
      expect(find.byType(SnackBar), findsNothing);
    });

    testWidgets('a file that is not a backup is refused', (tester) async {
      await openBackup(tester);
      files.toPick = Uint8List.fromList(utf8.encode('shopping: milk, eggs'));
      await tapImport(tester);

      expect(find.text('This file is not a backup.'), findsOneWidget);
      expect(find.byType(AlertDialog), findsNothing);
      expect(titles(), ['Groceries']);
    });

    testWidgets('an encrypted backup asks for its password first',
        (tester) async {
      await openBackup(tester, withPassword: true);
      final key = await tester.runAsync(
        () => container.read(securityProvider)!.unlock(password),
      );
      final encrypted = await tester.runAsync(
        () => sample().encodeEncrypted(key!),
      );
      files.toPick = Uint8List.fromList(utf8.encode(encrypted!));
      await tapImport(tester);
      expect(find.text('Encrypted backup'), findsOneWidget);

      Future<void> tryPassword(String pw) async {
        await tester.enterText(
          find.descendant(
            of: find.byKey(const Key('promptPassword')),
            matching: find.byType(TextField),
          ),
          pw,
        );
        await tester.tap(find.text('Open'));
        await tester.pump();
        await settleBusy(tester);
      }

      await tryPassword('wrong password');
      expect(find.text('Wrong password'), findsOneWidget);

      await tryPassword(password);
      expect(find.text('Restore this backup?'), findsOneWidget);
      await tester.tap(find.text('Restore'));
      await tester.pump();
      await settleBusy(tester);
      expect(titles(), ['Restored note', 'Second restored']);
    });
  });
}
