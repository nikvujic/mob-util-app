import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:the_app/models/app_section.dart';
import 'package:the_app/providers/section_locks_provider.dart';
import 'package:the_app/providers/security_provider.dart';
import 'package:the_app/providers/shop_provider.dart';

import '../helpers.dart';

void main() {
  const password = 'first password';
  const newPassword = 'second password';

  late ProviderContainer container;

  SecurityNotifier security() => container.read(securityProvider.notifier);

  Future<void> openSecurity(WidgetTester tester,
      {bool withPassword = false}) async {
    container = await pumpApp(tester);
    if (withPassword) {
      await tester.runAsync(() => security().setPassword(password));
    }
    await openMenu(tester);
    await tester.tap(find.text('Security'));
    await tester.pumpAndSettle();
  }

  Future<void> fill(WidgetTester tester, String key, String text) =>
      tester.enterText(find.byKey(Key(key)), text);

  Future<void> submit(WidgetTester tester, String action) async {
    await tester.tap(find.widgetWithText(FilledButton, action));
    await tester.pump();
    await settleBusy(tester);
  }

  /// Whether [pw] unlocks the current master password (real crypto).
  Future<bool> unlocks(WidgetTester tester, String pw) async =>
      await tester.runAsync(() => security().state!.unlock(pw)) != null;

  String? errorOf(WidgetTester tester, String key) => tester
      .widget<TextField>(
        find.descendant(
            of: find.byKey(Key(key)), matching: find.byType(TextField)),
      )
      .decoration!
      .errorText;

  group('without a master password', () {
    testWidgets('offers only "Set"', (tester) async {
      await openSecurity(tester);
      expect(find.text('Set master password'), findsOneWidget);
      expect(find.text('Change master password'), findsNothing);
      expect(find.text('Remove master password'), findsNothing);
    });

    testWidgets('set: validates, then sets and confirms', (tester) async {
      await openSecurity(tester);
      await tester.tap(find.text('Set master password'));
      await tester.pumpAndSettle();
      expect(find.textContaining("can't be recovered"), findsOneWidget);

      await fill(tester, 'newPassword', 'short');
      await submit(tester, 'Set password');
      expect(errorOf(tester, 'newPassword'), 'Use at least 8 characters');

      await fill(tester, 'newPassword', password);
      await fill(tester, 'repeatPassword', 'something else');
      await submit(tester, 'Set password');
      expect(errorOf(tester, 'repeatPassword'), "Passwords don't match");
      expect(security().hasMasterPassword, isFalse);

      await fill(tester, 'repeatPassword', password);
      await submit(tester, 'Set password');

      expect(security().hasMasterPassword, isTrue);
      expect(await unlocks(tester, password), isTrue);
      expect(appBarTitle('Security'), findsOneWidget);
      expect(find.text('Master password set'), findsOneWidget);
      expect(find.text('On'), findsOneWidget);
    });
  });

  group('with a master password', () {
    testWidgets('offers Change and Remove', (tester) async {
      await openSecurity(tester, withPassword: true);
      expect(find.text('Set master password'), findsNothing);
      expect(find.text('Change master password'), findsOneWidget);
      expect(find.text('Remove master password'), findsOneWidget);
    });

    testWidgets('change: wrong current password changes nothing',
        (tester) async {
      await openSecurity(tester, withPassword: true);
      await tester.tap(find.text('Change master password'));
      await tester.pumpAndSettle();

      await fill(tester, 'currentPassword', 'not it at all');
      await fill(tester, 'newPassword', newPassword);
      await fill(tester, 'repeatPassword', newPassword);
      await submit(tester, 'Change password');

      expect(errorOf(tester, 'currentPassword'), 'Wrong password');
      expect(await unlocks(tester, password), isTrue);

      await fill(tester, 'currentPassword', password);
      await submit(tester, 'Change password');

      expect(find.text('Master password changed'), findsOneWidget);
      expect(await unlocks(tester, newPassword), isTrue);
      expect(await unlocks(tester, password), isFalse);
    });

    testWidgets('remove: needs the current password', (tester) async {
      await openSecurity(tester, withPassword: true);
      await tester.tap(find.text('Remove master password'));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('newPassword')), findsNothing);

      await submit(tester, 'Remove password');
      expect(errorOf(tester, 'currentPassword'), 'Enter your current password');

      await fill(tester, 'currentPassword', 'wrong password');
      await submit(tester, 'Remove password');
      expect(errorOf(tester, 'currentPassword'), 'Wrong password');
      expect(security().hasMasterPassword, isTrue);

      await fill(tester, 'currentPassword', password);
      await submit(tester, 'Remove password');

      expect(security().hasMasterPassword, isFalse);
      expect(find.text('Master password removed'), findsOneWidget);
      expect(find.text('Set master password'), findsOneWidget);
    });
  });

  testWidgets('password fields are hidden until shown', (tester) async {
    await openSecurity(tester);
    await tester.tap(find.text('Set master password'));
    await tester.pumpAndSettle();

    TextField field() => tester.widget<TextField>(
          find.descendant(
            of: find.byKey(const Key('newPassword')),
            matching: find.byType(TextField),
          ),
        );
    expect(field().obscureText, isTrue);
    expect(field().enableSuggestions, isFalse);
    expect(field().autocorrect, isFalse);

    await tester.tap(find.byTooltip('Show password').first);
    await tester.pump();
    expect(field().obscureText, isFalse);
  });

  testWidgets('shows progress and blocks input while working', (tester) async {
    await openSecurity(tester);
    await tester.tap(find.text('Set master password'));
    await tester.pumpAndSettle();
    await fill(tester, 'newPassword', password);
    await fill(tester, 'repeatPassword', password);

    await tester.tap(find.widgetWithText(FilledButton, 'Set password'));
    await tester.pump();
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    expect(
      tester.widget<FilledButton>(find.byType(FilledButton)).onPressed,
      isNull,
    );
    // System back (not pressBack: the spinner never "settles").
    await tester.binding.handlePopRoute();
    await tester.pump();
    expect(appBarTitle('Set master password'), findsOneWidget,
        reason: "can't leave halfway");

    await settleBusy(tester);
    expect(security().hasMasterPassword, isTrue);
  });

  testWidgets('back from the form returns to Security unchanged',
      (tester) async {
    await openSecurity(tester);
    await tester.tap(find.text('Set master password'));
    await tester.pumpAndSettle();
    await fill(tester, 'newPassword', password);

    await pressBack(tester);

    expect(appBarTitle('Security'), findsOneWidget);
    expect(security().hasMasterPassword, isFalse);
  });

  group('forgot master password (L7)', () {
    Future<void> openForgot(WidgetTester tester) async {
      final tile = find.text('Forgot master password?');
      await tester.ensureVisible(tile);
      await tester.tap(tile);
      await tester.pumpAndSettle();
    }

    Finder resetButton() => find.widgetWithText(FilledButton, 'Reset');
    bool resetEnabled(WidgetTester tester) =>
        tester.widget<FilledButton>(resetButton()).onPressed != null;

    testWidgets('lists what goes and needs RESET typed; Cancel keeps all',
        (tester) async {
      container = await pumpApp(tester);
      await tester.runAsync(() => security().setPassword(password));
      container.read(shopProvider.notifier)
        ..addItem('Milk')
        ..addItem('Bread');
      container.read(sectionLocksProvider.notifier).lock(AppSection.shop);
      await openMenu(tester);
      await tester.tap(find.text('Security'));
      await tester.pumpAndSettle();

      await openForgot(tester);
      expect(find.textContaining('Shop (locked section): 2 items'),
          findsOneWidget);
      expect(resetEnabled(tester), isFalse);
      await tester.enterText(find.byKey(const Key('resetConfirm')), 'reset');
      await tester.pump();
      expect(resetEnabled(tester), isTrue);

      await tester.tap(find.widgetWithText(OutlinedButton, 'Cancel'));
      await tester.pumpAndSettle();
      expect(security().hasMasterPassword, isTrue);
      expect(container.read(shopProvider), hasLength(2));

      await openForgot(tester);
      await tester.enterText(find.byKey(const Key('resetConfirm')), 'RESET');
      await tester.pump();
      await tester.tap(resetButton());
      await tester.pumpAndSettle();

      expect(security().hasMasterPassword, isFalse);
      expect(container.read(shopProvider), isEmpty);
      expect(find.text('Master password reset'), findsOneWidget);
      expect(find.text('Set master password'), findsOneWidget);
    });

    testWidgets('with nothing locked, says so and resets at once',
        (tester) async {
      await openSecurity(tester, withPassword: true);
      await openForgot(tester);
      expect(find.textContaining('nothing will be deleted'), findsOneWidget);
      expect(find.byKey(const Key('resetConfirm')), findsNothing);

      await tester.tap(resetButton());
      await tester.pumpAndSettle();
      expect(security().hasMasterPassword, isFalse);
    });
  });
}
