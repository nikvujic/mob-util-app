import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:the_app/core/theme.dart';
import 'package:the_app/data/app_storage.dart';
import 'package:the_app/models/preferences.dart';
import 'package:the_app/providers/preferences_provider.dart';

import '../helpers.dart';

/// Menu → Themes (G12).
void main() {
  AppPalette paletteOf(WidgetTester tester) =>
      Theme.of(tester.element(find.byType(Scaffold).first))
          .extension<AppPalette>()!;

  testWidgets('starts green; picking a theme applies it at once and keeps it',
      (tester) async {
    final container = await pumpApp(tester);
    expect(paletteOf(tester), AppPalette.green);

    await openMenu(tester);
    await tester.tap(find.text('Themes'));
    await tester.pumpAndSettle();
    for (final theme in ['Green', 'Black', 'Clay']) {
      expect(find.text(theme), findsOneWidget);
    }

    await tester.tap(find.text('Clay'));
    await tester.pumpAndSettle();

    expect(paletteOf(tester), AppPalette.clay);
    expect(container.read(preferencesProvider).theme, 'clay');
  });

  testWidgets('a new theme shows at once, with no frame of the old one',
      (tester) async {
    final container = await pumpApp(tester);
    await openMenu(tester);
    await tester.tap(find.text('Security'));
    await tester.pumpAndSettle();

    container.read(preferencesProvider.notifier).setTheme('clay');
    await tester.pump(); // one frame

    expect(paletteOf(tester), AppPalette.clay);
    // Also on the page underneath, when going back to it.
    await tester.pageBack();
    await tester.pump();
    expect(paletteOf(tester), AppPalette.clay);
  });

  group('preferences', () {
    test('default to green with counter feedback on', () {
      const p = Preferences();
      expect(p.theme, 'green');
      expect(p.counterFeedback, isTrue);
    });

    test('are saved and survive a restart', () async {
      final dir = Directory.systemTemp.createTempSync('prefs');
      addTearDown(() => dir.deleteSync(recursive: true));
      final storage = await AppStorage.open(directory: dir);
      final container = ProviderContainer(
        overrides: [appStorageProvider.overrideWithValue(storage)],
      );
      addTearDown(container.dispose);
      container.read(preferencesProvider.notifier)
        ..setTheme('black')
        ..setCounterFeedback(false);
      await storage.flush();

      final reopened =
          (await AppStorage.open(directory: dir)).initialPreferences;
      expect(reopened.theme, 'black');
      expect(reopened.counterFeedback, isFalse);
    });

    test('an unknown theme (e.g. from a newer app) shows the default', () {
      expect(AppThemeChoice.fromId('neon'), AppThemeChoice.green);
      expect(
        Preferences.fromJson({'counterFeedback': false}).theme,
        'green',
        reason: 'missing values take their defaults',
      );
    });
  });
}
