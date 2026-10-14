import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:the_app/models/preferences.dart';
import 'package:the_app/providers/preferences_provider.dart';

import '../helpers.dart';

/// Automatic backup on the Backup page (Round 39).
void main() {
  final now = DateTime(2026, 10, 14, 9, 5);

  Future<void> openBackup(WidgetTester tester) async {
    await openMenu(tester);
    await tester.tap(find.text('Backup'));
    await tester.pumpAndSettle();
  }

  String text(WidgetTester tester) =>
      tester.widget<Text>(find.byKey(const Key('autoBackupText'))).data!;

  testWidgets('switched on: a folder is picked and backed up into at once',
      (tester) async {
    final folder =
        FakeBackupFolder(picks: (uri: 'content://tree/x', name: 'Backups'));
    final container =
        await pumpApp(tester, clock: () => now, backupFolder: folder);
    await openBackup(tester);
    expect(text(tester), contains('a folder you pick'));
    await tester.tap(find.byKey(const Key('autoBackup')));
    await tester.pumpAndSettle();
    expect(folder.written, hasLength(1));
    expect(find.text('Backed up into the folder'), findsOneWidget);
    expect(text(tester), contains('Backups'));
    expect(find.byKey(const Key('autoBackupFolder')), findsOneWidget);
    expect(container.read(preferencesProvider).autoBackupFolder,
        'content://tree/x');

    // Off again.
    await tester.tap(find.byKey(const Key('autoBackup')));
    await tester.pumpAndSettle();
    expect(container.read(preferencesProvider).autoBackupFolder, isNull);
    expect(find.byKey(const Key('autoBackupFolder')), findsNothing);
  });

  testWidgets('the folder gone: says so, in red', (tester) async {
    await pumpApp(tester,
        clock: () => now,
        preferences: const Preferences(
          autoBackupFolder: 'content://tree/x',
          autoBackupFolderName: 'Backups',
          autoBackupFailed: true,
        ),
        backupFolder: FakeBackupFolder(works: false));
    await openBackup(tester);
    expect(text(tester), "Couldn't write to Backups: pick it again");
  });

  testWidgets('when the app opens, a day\'s backup if due', (tester) async {
    final folder = FakeBackupFolder();
    await pumpApp(tester,
        clock: () => now,
        preferences: Preferences(
          autoBackupFolder: 'content://tree/x',
          autoBackupFolderName: 'Backups',
          lastAutoBackupAt: now.subtract(const Duration(days: 2)),
        ),
        backupFolder: folder);
    await tester.pumpAndSettle();
    expect(folder.written, hasLength(1));
  });

  testWidgets('not due: none', (tester) async {
    final folder = FakeBackupFolder();
    await pumpApp(tester,
        clock: () => now,
        preferences: Preferences(
          autoBackupFolder: 'content://tree/x',
          lastAutoBackupAt: now.subtract(const Duration(hours: 3)),
        ),
        backupFolder: folder);
    await tester.pumpAndSettle();
    expect(folder.written, isEmpty);
  });
}
