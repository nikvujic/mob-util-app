import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:the_app/models/app_section.dart';
import 'package:the_app/providers/section_locks_provider.dart';
import 'package:the_app/providers/security_provider.dart';
import 'package:the_app/providers/session_provider.dart';
import 'package:the_app/providers/shop_provider.dart';

import '../helpers.dart';

/// Leaving the app while it's unlocked covers it, so coming back after
/// the auto-lock never shows a protected page for a moment (L4).
void main() {
  const password = 'master password';

  late ProviderContainer container;
  late DateTime now;

  final curtain = find.byKey(const Key('privacyCurtain'));

  /// Shop locked and open, with "Milk" in it; unlocked unless [locked].
  Future<void> start(WidgetTester tester, {bool locked = false}) async {
    now = DateTime(2026, 10, 8, 12);
    container = await pumpApp(tester, clock: () => now);
    container.read(shopProvider.notifier).addItem('Milk');
    await tester.runAsync(() async {
      await container.read(securityProvider.notifier).setPassword(password);
      container.read(sectionLocksProvider.notifier).lock(AppSection.shop);
      if (!locked) {
        await container.read(sessionProvider.notifier).unlock(password);
      }
    });
    await openTab(tester, 'Shop');
  }

  void send(WidgetTester tester, List<AppLifecycleState> states) {
    for (final state in states) {
      tester.binding.handleAppLifecycleStateChanged(state);
    }
  }

  Future<void> leave(WidgetTester tester) async {
    send(tester, [AppLifecycleState.inactive]);
    // The frame Android keeps is drawn as the app starts leaving.
    await tester.pump();
    send(tester, [AppLifecycleState.hidden, AppLifecycleState.paused]);
    await tester.pump();
  }

  /// Back in front; the first frame is what's checked.
  Future<void> comeBack(WidgetTester tester, Duration away) async {
    now = now.add(away);
    send(tester, [
      AppLifecycleState.hidden,
      AppLifecycleState.inactive,
      AppLifecycleState.resumed,
    ]);
    await tester.pump();
  }

  testWidgets('leaving while unlocked covers the page at once', (tester) async {
    await start(tester);
    expect(find.text('Milk'), findsOneWidget);
    await leave(tester);
    expect(curtain, findsOneWidget);
    expect(find.text('Milk').hitTestable(), findsNothing);
  });

  testWidgets('back after the auto-lock: locked, never the page',
      (tester) async {
    await start(tester);
    await leave(tester);
    await comeBack(tester, SessionNotifier.autoLockAfter);
    expect(container.read(sessionProvider), isNull);
    expect(find.text('Milk'), findsNothing);
    expect(curtain, findsNothing);
  });

  testWidgets('back soon: the page again, uncovered', (tester) async {
    await start(tester);
    await leave(tester);
    await comeBack(tester, const Duration(minutes: 1));
    expect(curtain, findsNothing);
    expect(find.text('Milk').hitTestable(), findsOneWidget);
  });

  testWidgets('locked already: nothing to cover', (tester) async {
    await start(tester, locked: true);
    await leave(tester);
    expect(curtain, findsNothing);
  });
}
