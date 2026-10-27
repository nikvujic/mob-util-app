import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:the_app/providers/preferences_provider.dart';
import 'package:the_app/providers/security_provider.dart';
import 'package:the_app/providers/session_provider.dart';

import '../helpers.dart';

/// Settings → Hide People notes (Round 109): on freely; off again only
/// with the password, when there is one.
void main() {
  const password = 'master password';

  Future<void> openSettings(WidgetTester tester) async {
    await openMenu(tester);
    await scrollMenuTo(tester, 'Settings');
    await tester.tap(find.text('Settings'));
    await tester.pumpAndSettle();
  }

  Future<void> toggle(WidgetTester tester) async {
    await tester.scrollUntilVisible(
        find.byKey(const Key('hidePeopleNotes')), 80,
        scrollable: find.byType(Scrollable).first);
    await tester.tap(find.byKey(const Key('hidePeopleNotes')));
    await tester.pumpAndSettle();
  }

  testWidgets('no password: on and off, nothing asked', (tester) async {
    final container = await pumpApp(tester);
    bool hidden() => container.read(preferencesProvider).hidePeopleNotes;
    await openSettings(tester);
    await toggle(tester);
    expect(hidden(), isTrue);
    await toggle(tester);
    expect(hidden(), isFalse);
  });

  testWidgets('with a password: shown again only once it is given',
      (tester) async {
    final container = await pumpApp(tester);
    await tester.runAsync(() async {
      await container.read(securityProvider.notifier).setPassword(password);
      await container.read(sessionProvider.notifier).unlock(password);
    });
    bool hidden() => container.read(preferencesProvider).hidePeopleNotes;
    await openSettings(tester);
    await toggle(tester);
    expect(hidden(), isTrue);

    await toggle(tester);
    expect(find.text('Show People notes'), findsOneWidget);
    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();
    expect(hidden(), isTrue, reason: 'not given');

    await toggle(tester);
    await tester.enterText(find.byType(TextField).last, password);
    await tester.tap(find.text('Show'));
    await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 1500)));
    await tester.pumpAndSettle();
    expect(hidden(), isFalse);
  });
}
