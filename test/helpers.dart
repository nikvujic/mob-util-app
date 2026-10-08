import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:the_app/core/app_info.dart';
import 'package:the_app/data/app_storage.dart';
import 'package:the_app/data/backup_files.dart';
import 'package:the_app/app/app.dart';

const testAppVersion = '1.2.3 (4)';

/// Opens the hamburger menu from the visible section.
Future<void> openMenu(WidgetTester tester) async {
  await tester.tap(find.byTooltip('Menu'));
  await tester.pumpAndSettle();
}

/// Starts the whole app with in-memory storage and returns its provider
/// container, so tests can seed and inspect state.
Future<ProviderContainer> pumpApp(
  WidgetTester tester, {
  BackupFiles? backupFiles,
}) async {
  final container = ProviderContainer(
    overrides: [
      appStorageProvider.overrideWithValue(AppStorage.inMemory()),
      appVersionProvider.overrideWithValue(testAppVersion),
      backupFilesProvider.overrideWithValue(backupFiles ?? FakeBackupFiles()),
    ],
  );
  addTearDown(container.dispose);
  await tester.pumpWidget(
    UncontrolledProviderScope(container: container, child: const MyApp()),
  );
  return container;
}

/// Switches to a main section via the bottom navigation bar.
Future<void> openTab(WidgetTester tester, String label) async {
  await tester.tap(
    find.descendant(
      of: find.byType(BottomNavigationBar),
      matching: find.text(label),
    ),
  );
  await tester.pumpAndSettle();
}

/// Finds [title] inside the app bar of the visible page.
Finder appBarTitle(String title) => find.descendant(
      of: find.byType(AppBar),
      matching: find.text(title),
    );

/// Records whether the app asked Android to close it
/// (`SystemNavigator.pop`), which is what system back does on the root page.
class ExitRecorder {
  int exits = 0;

  ExitRecorder(WidgetTester tester) {
    final messenger = tester.binding.defaultBinaryMessenger;
    messenger.setMockMethodCallHandler(SystemChannels.platform, (call) async {
      if (call.method == 'SystemNavigator.pop') exits++;
      return null;
    });
    addTearDown(
      () => messenger.setMockMethodCallHandler(SystemChannels.platform, null),
    );
  }
}

/// Simulates the Android system back button.
Future<void> pressBack(WidgetTester tester) async {
  await tester.binding.handlePopRoute();
  await tester.pumpAndSettle();
}

/// Leaves the note editor with back. If [save] is given, the "Save
/// changes?" dialog is expected and answered with Yes (true) or No (false).
Future<void> leaveNote(WidgetTester tester, {bool? save}) async {
  await tester.pump(); // let pending text changes settle
  await tester.pageBack();
  await tester.pumpAndSettle();
  if (save != null) {
    await tester.tap(find.text(save ? 'Yes' : 'No'));
    await tester.pumpAndSettle();
  }
}

/// Stands in for the system "save as" dialog. By default the user "saves";
/// set [cancel] to simulate closing the dialog, [error] to make saving fail,
/// or [pending] to keep the dialog open until the test completes it.
class FakeBackupFiles implements BackupFiles {
  bool cancel = false;
  Object? error;
  Completer<bool>? pending;

  final saved = <({String fileName, Uint8List bytes})>[];

  @override
  Future<bool> save({required String fileName, required Uint8List bytes}) {
    if (error != null) return Future.error(error!);
    if (pending != null) return pending!.future;
    if (cancel) return Future.value(false);
    saved.add((fileName: fileName, bytes: bytes));
    return Future.value(true);
  }
}
