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
    expect(names, ['Clay', 'Green', 'Black', 'Mono']);
    for (final name in names) {
      await tester.scrollUntilVisible(find.text(name), 50,
          scrollable: find.byType(Scrollable).last);
      expect(find.text(name), findsOneWidget);
    }

    await tester.tap(find.text('Mono'));
    await tester.pumpAndSettle();

    expect(paletteOf(tester), AppPalette.mono);
    expect(container.read(preferencesProvider).theme, 'mono');
  });

  testWidgets('a new theme shows at once, with no frame of the old one',
      (tester) async {
    final container = await pumpApp(tester);
    await openMenu(tester);
    await tester.tap(find.text('Security'));
    await tester.pumpAndSettle();

    container.read(preferencesProvider.notifier).setTheme('black');
    await tester.pump(); // one frame

    expect(paletteOf(tester), AppPalette.black);
    // Also on the page underneath, when going back to it.
    await tester.pageBack();
    await tester.pump();
    expect(paletteOf(tester), AppPalette.black);
  });

  testWidgets(
      "a theme since removed: the nearest one kept, shown picked on Themes",
      (tester) async {
    expect(AppThemeChoice.fromId('ocean'), AppThemeChoice.mono);
    expect(AppThemeChoice.fromId('frost'), AppThemeChoice.mono);
    expect(AppThemeChoice.fromId('grape'), AppThemeChoice.clay);
    expect(AppThemeChoice.fromId('rose'), AppThemeChoice.clay);
    expect(AppThemeChoice.fromId('from-a-newer-app'), AppThemeChoice.clay);

    await pumpApp(tester, preferences: const Preferences(theme: 'ocean'));
    expect(paletteOf(tester), AppPalette.mono);
    await openMenu(tester);
    await tester.tap(find.text('Themes'));
    await tester.pumpAndSettle();
    final mono = tester.widget<ListTile>(
        find.ancestor(of: find.text('Mono'), matching: find.byType(ListTile)));
    expect(mono.selected, isTrue);
  });

  test('Mono is black and white', () {
    const mono = AppPalette.mono;
    expect(mono.background, const Color(0xFF000000));
    expect(mono.accent, const Color(0xFFFFFFFF));
    expect(mono.textPrimary, const Color(0xFFFFFFFF));
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
