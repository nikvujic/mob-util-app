import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:the_app/models/app_section.dart';
import 'package:the_app/providers/fingerprint_provider.dart';
import 'package:the_app/providers/section_locks_provider.dart';
import 'package:the_app/providers/security_provider.dart';
import 'package:the_app/providers/session_provider.dart';

import '../helpers.dart';

/// Fingerprint unlock (L6) in the app.
void main() {
  const password = 'master password';

  late ProviderContainer container;
  late FakeFingerprintVault vault;

  Future<void> start(WidgetTester tester, {bool available = true}) async {
    vault = FakeFingerprintVault(available: available);
    container = await pumpApp(tester, fingerprint: vault);
    await tester.runAsync(
      () => container.read(securityProvider.notifier).setPassword(password),
    );
  }

  Future<void> openSecurity(WidgetTester tester) async {
    await openMenu(tester);
    await tester.tap(find.text('Security'));
    await tester.pumpAndSettle();
  }

  bool unlocked() => container.read(sessionProvider) != null;
  final toggle = find.widgetWithText(SwitchListTile, 'Unlock with fingerprint');

  /// Fingerprint unlock on (with real crypto), app locked.
  Future<void> turnOn(WidgetTester tester) async {
    await tester.runAsync(() async {
      await container.read(sessionProvider.notifier).unlock(password);
      await container.read(fingerprintProvider.notifier).turnOn();
    });
    container.read(sessionProvider.notifier).lock();
    await tester.pump();
  }

  /// Opens the locked Shop's unlock prompt.
  Future<void> openShopPrompt(WidgetTester tester) async {
    container.read(sectionLocksProvider.notifier).lock(AppSection.shop);
    await openTab(tester, 'Shop');
    await tester.runAsync(() async {
      await tester.tap(find.text('Unlock'));
      // The fingerprint is tried as the prompt opens (real crypto).
      for (var i = 0; i < 20; i++) {
        await tester.pump();
        await Future<void>.delayed(const Duration(milliseconds: 50));
      }
    });
    await tester.pumpAndSettle();
  }

  testWidgets('the switch only shows if the phone can do it', (tester) async {
    await start(tester, available: false);
    await openSecurity(tester);
    expect(toggle, findsNothing);
  });

  testWidgets('turning it on while locked asks for the password first',
      (tester) async {
    await start(tester);
    await openSecurity(tester);
    expect(tester.widget<SwitchListTile>(toggle).value, isFalse);

    await tester.tap(toggle);
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const Key('promptPassword')), password);
    await tester.tap(find.text('Unlock').last);
    await settleBusy(tester);
    await tester.runAsync(() => Future<void>.delayed(Duration.zero));
    await tester.pumpAndSettle();

    expect(tester.widget<SwitchListTile>(toggle).value, isTrue);
    expect(vault.stored, isNotNull);
    expect(find.text('Fingerprint unlock is on'), findsOneWidget);
  });

  testWidgets('unlocking goes straight to the fingerprint', (tester) async {
    await start(tester);
    await turnOn(tester);

    await openShopPrompt(tester);

    expect(unlocked(), isTrue);
    expect(find.text('Shop is locked'), findsNothing);
    expect(find.byKey(const Key('promptPassword')), findsNothing);
  });

  testWidgets('cancelling it leaves the password, and a button to retry',
      (tester) async {
    await start(tester);
    await turnOn(tester);
    vault.nextFinger = false;

    await openShopPrompt(tester);
    expect(unlocked(), isFalse);
    expect(find.byKey(const Key('promptPassword')), findsOneWidget);
    final retry = find.text('Use fingerprint');
    expect(retry, findsOneWidget);
    final semantics = tester.ensureSemantics();
    await expectLater(tester, meetsGuideline(androidTapTargetGuideline));
    await expectLater(tester, meetsGuideline(labeledTapTargetGuideline));
    await expectLater(tester, meetsGuideline(textContrastGuideline));
    semantics.dispose();

    vault.nextFinger = true;
    await tester.runAsync(() async {
      await tester.tap(retry);
      for (var i = 0; i < 20; i++) {
        await tester.pump();
        await Future<void>.delayed(const Duration(milliseconds: 50));
      }
    });
    await tester.pumpAndSettle();
    expect(unlocked(), isTrue);
  });

  testWidgets('when off, the prompt is just the password', (tester) async {
    await start(tester);
    await openShopPrompt(tester);
    expect(vault.asked, 0);
    expect(find.byKey(const Key('promptPassword')), findsOneWidget);
    expect(find.text('Use fingerprint'), findsNothing);
  });
}
