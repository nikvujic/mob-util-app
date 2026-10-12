import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:the_app/core/changelog.dart';
import 'package:the_app/data/app_storage.dart';
import 'package:the_app/models/preferences.dart';
import 'package:the_app/providers/notes_provider.dart';
import 'package:the_app/providers/preferences_provider.dart';

import '../helpers.dart';

/// The Introduction note (N16).
void main() {
  late ProviderContainer container;
  final tile = find.byKey(const Key('introductionTile'));
  final isNew = find.byKey(const Key('introductionNew'));

  Preferences preferences() => container.read(preferencesProvider);

  /// The app started with [saved] preferences (a fresh install by default).
  Future<void> start(WidgetTester tester, [Preferences? saved]) async {
    container = await pumpApp(
      tester,
      introduction: true,
      overrides: [
        appStorageProvider.overrideWithValue(
          AppStorage.inMemory(initialPreferences: saved ?? const Preferences()),
        ),
      ],
    );
    await tester.pumpAndSettle();
  }

  Future<void> open(WidgetTester tester) async {
    await tester.tap(tile);
    await tester.pumpAndSettle();
  }

  testWidgets('a fresh install: at the top of Notes, new', (tester) async {
    await start(tester);
    expect(tile, findsOneWidget);
    expect(isNew, findsOneWidget);
    expect(find.text('No notes'), findsNothing);
    expect(preferences().introVersion, testAppVersion);
  });

  testWidgets('opens read only: the guide, then what\'s new', (tester) async {
    await start(tester);
    await open(tester);
    expect(appBarTitle('Introduction'), findsOneWidget);
    final text = find.byKey(const Key('introductionText'));
    expect(text, findsOneWidget);
    final shown = tester.widget<Text>(text).textSpan!.toPlainText();
    expect(shown, contains('Welcome to The App'));
    expect(shown, contains("What's new in 1.2.3"));
    // Markdown is drawn: the title as a heading, its "# " hidden.
    final spans = <TextSpan>[];
    tester.widget<Text>(text).textSpan!.visitChildren((span) {
      if (span is TextSpan) spans.add(span);
      return true;
    });
    final title = spans.firstWhere((s) => s.text == 'Welcome to The App');
    expect(title.style!.fontSize, greaterThan(16));
    expect(find.byType(TextField), findsNothing, reason: "can't be edited");

    await tester.pageBack();
    await tester.pumpAndSettle();
    expect(isNew, findsNothing, reason: 'read');
  });

  testWidgets('deleted after asking, with undo; the menu brings it back',
      (tester) async {
    await start(tester);
    await open(tester);
    await tester.tap(find.byTooltip('Delete introduction'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Delete'));
    await tester.pumpAndSettle();
    expect(tile, findsNothing);
    expect(preferences().introDeleted, isTrue);

    await tester.tap(find.text('Undo'));
    await tester.pumpAndSettle();
    expect(tile, findsOneWidget);

    // Deleted again, then from the menu.
    container.read(preferencesProvider.notifier).setIntroDeleted(true);
    await tester.pumpAndSettle();
    expect(tile, findsNothing);
    await openMenu(tester);
    await tester.tap(find.text('Introduction'));
    await tester.pumpAndSettle();
    expect(appBarTitle('Introduction'), findsOneWidget);
    expect(preferences().introDeleted, isFalse);
  });

  testWidgets('an update brings it back, new', (tester) async {
    await start(
      tester,
      const Preferences(introVersion: '1.0.0 (1)', introDeleted: true),
    );
    expect(tile, findsOneWidget);
    expect(isNew, findsOneWidget);
  });

  testWidgets('not after updates when that is off', (tester) async {
    await start(
      tester,
      const Preferences(
        introVersion: '1.0.0 (1)',
        introDeleted: true,
        introOnUpdates: false,
      ),
    );
    expect(tile, findsNothing);
    expect(find.text('No notes'), findsOneWidget);
  });

  testWidgets('the same version again: stays deleted', (tester) async {
    await start(
      tester,
      const Preferences(introVersion: testAppVersion, introDeleted: true),
    );
    expect(tile, findsNothing);
  });

  testWidgets('Settings switches it off for updates', (tester) async {
    await start(tester);
    await openMenu(tester);
    await tester.tap(find.text('Settings'));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('introOnUpdates')));
    await tester.pumpAndSettle();
    expect(preferences().introOnUpdates, isFalse);
  });

  testWidgets('in selection mode it is left alone', (tester) async {
    await start(tester);
    container.read(notesProvider.notifier).addNote(title: 'Diary');
    await tester.pumpAndSettle();
    await tester.longPress(find.text('Diary'));
    await tester.pumpAndSettle();
    await tester.tap(tile);
    await tester.pumpAndSettle();
    expect(appBarTitle('Introduction'), findsNothing, reason: 'not opened');
    expect(find.text('1 selected'), findsOneWidget);
  });

  group('changes for a version', () {
    const changelog = '''
# Changelog

## [0.2.0] - unreleased

### Added
- Two

## [0.1.0] - 2026-01-01

### Fixed
- One
''';

    test('its own section, without the heading', () {
      expect(changesFor(changelog, '0.1.0'), '### Fixed\n- One');
      expect(changesFor(changelog, '0.2.0'), '### Added\n- Two');
    });

    test('the newest when the version has none', () {
      expect(changesFor(changelog, '9.9.9'), '### Added\n- Two');
      expect(changesFor('# Nothing', '0.1.0'), isNull);
    });

    test('the number of a shown version', () {
      expect(versionNumber('0.24.0 (25)'), '0.24.0');
    });
  });
}
