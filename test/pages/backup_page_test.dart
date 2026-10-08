import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:the_app/data/backup.dart';
import 'package:the_app/providers/notes_provider.dart';

import '../helpers.dart';

void main() {
  late FakeBackupFiles files;

  Future<void> openBackup(WidgetTester tester) async {
    files = FakeBackupFiles();
    final container = await pumpApp(tester, backupFiles: files);
    container.read(notesProvider.notifier).addNote(title: 'Groceries');
    await openMenu(tester);
    await tester.tap(find.text('Backup'));
    await tester.pumpAndSettle();
  }

  Future<void> tapExport(WidgetTester tester) async {
    await tester.tap(find.text('Export all data'));
    await tester.pumpAndSettle();
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

  testWidgets('import is shown as coming soon', (tester) async {
    await openBackup(tester);
    final tile = tester.widget<ListTile>(
      find.widgetWithText(ListTile, 'Import from file'),
    );
    expect(tile.enabled, isFalse);
  });
}
