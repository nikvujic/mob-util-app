import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:the_app/models/app_section.dart';
import 'package:the_app/providers/notes_provider.dart';
import 'package:the_app/providers/section_locks_provider.dart';
import 'package:the_app/providers/security_provider.dart';
import 'package:the_app/providers/session_provider.dart';
import 'package:the_app/providers/shop_provider.dart';

import '../helpers.dart';

/// Section locks (L5): switches on Security; a locked section shows a lock
/// screen while the app is locked.
void main() {
  const password = 'master password';

  late ProviderContainer container;
  late FakeBackupFiles files;

  Set<AppSection> locks() => container.read(sectionLocksProvider);

  /// The app with a note and a shop item; with a master password unless
  /// [withPassword] is false (unlocked), and [locked] sections.
  Future<void> start(
    WidgetTester tester, {
    bool withPassword = true,
    Set<AppSection> locked = const {},
  }) async {
    files = FakeBackupFiles();
    container = await pumpApp(tester, backupFiles: files);
    container.read(notesProvider.notifier).addNote(
          title: 'Diary',
          content: 'secret thoughts',
        );
    container.read(shopProvider.notifier).addItem('Milk');
    if (withPassword) {
      await tester.runAsync(() async {
        await container.read(securityProvider.notifier).setPassword(password);
        await container.read(sessionProvider.notifier).unlock(password);
      });
      for (final section in locked) {
        container.read(sectionLocksProvider.notifier).lock(section);
      }
    }
    await tester.pumpAndSettle();
  }

  void lockApp() => container.read(sessionProvider.notifier).lock();

  /// Taps the Shop section lock, scrolling to it first.
  Future<void> tapShopSwitch(WidgetTester tester) async {
    final shop = find.widgetWithText(SwitchListTile, 'Shop');
    await tester.ensureVisible(shop);
    await tester.pumpAndSettle();
    await tester.tap(shop);
  }

  Future<void> openSecurity(WidgetTester tester) async {
    await openMenu(tester);
    await tester.tap(find.text('Security'));
    await tester.pumpAndSettle();
  }

  Future<void> enterPassword(WidgetTester tester, String value) async {
    await tester.enterText(find.byKey(const Key('promptPassword')), value);
    await tester.tap(find.text('Unlock').last);
    await settleBusy(tester);
  }

  testWidgets('without a master password there are no switches',
      (tester) async {
    await start(tester, withPassword: false);
    await openSecurity(tester);

    expect(find.text('Set a master password first'), findsOneWidget);
    expect(find.byType(SwitchListTile), findsNothing);
  });

  testWidgets(
      'a switch locks the section; it shows a lock screen once the '
      'app locks', (tester) async {
    await start(tester);
    await openSecurity(tester);

    await tapShopSwitch(tester);
    await tester.pumpAndSettle();
    expect(locks(), {AppSection.shop});

    lockApp();
    await tester.pageBack();
    await tester.pumpAndSettle();
    await openTab(tester, 'Shop');

    expect(find.text('Shop is locked'), findsOneWidget);
    expect(find.text('Milk'), findsNothing);

    await openTab(tester, 'Notes');
    expect(find.text('Diary'), findsOneWidget, reason: 'Notes is not locked');
  });

  testWidgets('the lock screen unlocks with the master password',
      (tester) async {
    await start(tester, locked: {AppSection.shop});
    lockApp();
    await openTab(tester, 'Shop');

    await tester.tap(find.text('Unlock'));
    await tester.pumpAndSettle();
    await enterPassword(tester, 'wrong password');
    expect(find.text('Wrong password'), findsOneWidget);

    await enterPassword(tester, password);
    expect(find.text('Shop is locked'), findsNothing);
    expect(find.text('Milk'), findsOneWidget);
  });

  testWidgets('turning a lock off needs the password while locked',
      (tester) async {
    await start(tester, locked: {AppSection.shop});
    lockApp();
    await openSecurity(tester);

    await tapShopSwitch(tester);
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('promptPassword')), findsOneWidget);
    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();
    expect(locks(), {AppSection.shop}, reason: 'cancelled');

    await tapShopSwitch(tester);
    await tester.pumpAndSettle();
    await enterPassword(tester, password);
    expect(locks(), isEmpty);
  });

  testWidgets(
      'locking the app closes an open note of a locked section, '
      'saving it', (tester) async {
    await start(tester, locked: {AppSection.notes});
    await tester.tap(find.text('Diary'));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const Key('noteContentField')),
      'more thoughts',
    );
    await tester.pump();

    lockApp();
    await tester.pumpAndSettle();

    expect(find.text('Notes is locked'), findsOneWidget);
    expect(find.byKey(const Key('noteContentField')), findsNothing);
    expect(
      container.read(notesProvider).single.content,
      'more thoughts',
    );
  });

  testWidgets('backups need unlocking while a section is locked',
      (tester) async {
    await start(tester, locked: {AppSection.shop});
    lockApp();
    await openMenu(tester);
    await tester.tap(find.text('Backup'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Export all data'));
    await tester.pumpAndSettle();
    expect(
      find.text('Some sections are locked. Enter the master password to '
          'back up or restore.'),
      findsOneWidget,
    );
    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();
    expect(find.text('Export as'), findsNothing);
    expect(files.saved, isEmpty);

    await tester.tap(find.text('Export all data'));
    await tester.pumpAndSettle();
    await enterPassword(tester, password);
    expect(find.text('Export as'), findsOneWidget, reason: 'unlocked: goes on');
  });

  testWidgets('removing the master password removes the locks', (tester) async {
    await start(tester, locked: {AppSection.shop, AppSection.notes});
    await openSecurity(tester);
    await tester.tap(find.text('Remove master password'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const Key('currentPassword')), password);
    await tester.tap(find.widgetWithText(FilledButton, 'Remove password'));
    await settleBusy(tester);

    expect(locks(), isEmpty);
    expect(find.text('Set a master password first'), findsOneWidget);
  });
}
