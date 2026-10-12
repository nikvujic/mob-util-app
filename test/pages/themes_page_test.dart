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

  testWidgets('starts on Clay; picking a theme applies it at once',
      (tester) async {
    final container = await pumpApp(tester);
    expect(paletteOf(tester), AppPalette.clay);

    await openMenu(tester);
    await tester.tap(find.text('Themes'));
    await tester.pumpAndSettle();
    // Clay first, then the rest.
    final names = [for (final t in AppThemeChoice.values) t.label];
    expect(names.first, 'Clay');
    expect(names.length, greaterThanOrEqualTo(8));
    for (final name in names) {
      await tester.scrollUntilVisible(find.text(name), 50,
          scrollable: find.byType(Scrollable).last);
      expect(find.text(name), findsOneWidget);
    }

    await tester.tap(find.text('Ocean'));
    await tester.pumpAndSettle();

    expect(paletteOf(tester), AppPalette.ocean);
    expect(container.read(preferencesProvider).theme, 'ocean');
  });

  testWidgets('a new theme shows at once, with no frame of the old one',
      (tester) async {
    final container = await pumpApp(tester);
    await openMenu(tester);
    await tester.tap(find.text('Security'));
    await tester.pumpAndSettle();

    container.read(preferencesProvider.notifier).setTheme('grape');
    await tester.pump(); // one frame

    expect(paletteOf(tester), AppPalette.grape);
    // Also on the page underneath, when going back to it.
    await tester.pageBack();
    await tester.pump();
    expect(paletteOf(tester), AppPalette.grape);
  });

  group('preferences', () {
    test('default to Clay with counter feedback on', () {
      const p = Preferences();
      expect(p.theme, 'clay');
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
      expect(AppThemeChoice.fromId('neon'), AppThemeChoice.clay);
      expect(
        Preferences.fromJson({'counterFeedback': false}).theme,
        'clay',
        reason: 'missing values take their defaults',
      );
    });
  });
}
