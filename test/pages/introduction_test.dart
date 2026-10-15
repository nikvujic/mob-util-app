import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:the_app/core/changelog.dart';
import 'package:the_app/core/markdown.dart';
import 'package:the_app/data/app_storage.dart';
import 'package:the_app/models/preferences.dart';
import 'package:the_app/providers/notes_provider.dart';
import 'package:the_app/providers/preferences_provider.dart';
import 'package:the_app/widgets/pull_down_list.dart';

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

  testWidgets(
      "scrolled to the end, Delete covers no text, above the phone's "
      'own bar too (Round 17)', (tester) async {
    // A 48 dp navigation bar (the view's padding is in physical pixels).
    tester.view.padding =
        FakeViewPadding(bottom: 48 * tester.view.devicePixelRatio);
    addTearDown(tester.view.resetPadding);
    await start(tester);
    await open(tester);
    final list = find.byType(CustomScrollView);
    for (var i = 0; i < 10; i++) {
      await tester.drag(list, const Offset(0, -3000));
      await tester.pumpAndSettle();
    }
    final textBottom =
        tester.getBottomLeft(find.byKey(const Key('introductionText'))).dy;
    // On a phone the button floats above the bar: its height, its margin
    // and the bar must all fit under the text.
    final button = tester.getSize(find.byTooltip('Delete introduction'));
    final screen = tester.getSize(find.byType(MaterialApp)).height;
    expect(screen - textBottom, greaterThanOrEqualTo(button.height + 16 + 48));
  });

  testWidgets('deleted after asking, no toast (Round 27); Settings restores it',
      (tester) async {
    await start(tester);
    await open(tester);
    await tester.tap(find.byTooltip('Delete introduction'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Delete'));
    await tester.pumpAndSettle();
    expect(tile, findsNothing);
    expect(preferences().introDeleted, isTrue);
    expect(find.byType(SnackBar), findsNothing);

    // Settings offers to restore it; the menu has no entry.
    await openMenu(tester);
    expect(find.text('Introduction'), findsNothing);
    await tester.tap(find.text('Settings'));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('restoreIntro')));
    await tester.pumpAndSettle();
    expect(preferences().introDeleted, isFalse);
    expect(find.byKey(const Key('restoreIntro')), findsNothing,
        reason: 'only offered while deleted');
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
        todoNote: false, // nothing else at the top of Notes
      ),
    );
    expect(tile, findsNothing);
    expect(find.text('No notes'), findsOneWidget);
  });

  group('opens where it was left (Round 29)', () {
    final text = find.byKey(const Key('introductionText'));
    double scrolled(WidgetTester tester) =>
        PullDownList.scrolledOf(tester.element(text));

    testWidgets('closed and opened again: the same place', (tester) async {
      await start(tester);
      await open(tester);
      await tester.dragFrom(const Offset(400, 400), const Offset(0, -500));
      await tester.pumpAndSettle();
      final left = scrolled(tester);
      expect(left, greaterThan(100));
      expect(preferences().introScroll, left);

      await tester.pageBack();
      await tester.pumpAndSettle();
      await open(tester);
      expect(scrolled(tester), closeTo(left, 0.5));
    });

    testWidgets('new (an update) or restored: from the top', (tester) async {
      await start(
        tester,
        const Preferences(introVersion: '1.0.0 (1)', introScroll: 900),
      );
      expect(preferences().introScroll, 0, reason: 'an update brings it up');
      await open(tester);
      expect(scrolled(tester), 0);

      container.read(preferencesProvider.notifier)
        ..setIntroScroll(700)
        ..setIntroDeleted(true);
      expect(preferences().introScroll, 700, reason: 'kept while deleted');
      container.read(preferencesProvider.notifier).setIntroDeleted(false);
      expect(preferences().introScroll, 0);
    });
  });

  testWidgets('the same version again: stays deleted', (tester) async {
    await start(
      tester,
      const Preferences(introVersion: testAppVersion, introDeleted: true),
    );
    expect(tile, findsNothing);
  });

  testWidgets('Settings: line numbers first (Round 20)', (tester) async {
    await start(tester);
    await openMenu(tester);
    await tester.tap(find.text('Settings'));
    await tester.pumpAndSettle();
    final tiles = tester
        .widgetList<SwitchListTile>(find.byType(SwitchListTile))
        .map((t) => (t.title! as Text).data)
        .toList();
    expect(tiles.first, 'Line numbers in notes');
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

    test(
        "a patch shows its whole minor version's changes, newest first "
        '(Round 48)', () {
      const patched = '''
## [0.3.1] - unreleased

### Fixed
- Three

## [0.3.0] - 2026-01-03

### Added
- Big

## [0.2.0] - 2026-01-02

### Added
- Two
''';
      expect(changesFor(patched, '0.3.1'),
          '## 0.3.1\n\n### Fixed\n- Three\n\n## 0.3.0\n\n### Added\n- Big');
      expect(changesFor(patched, '0.3.0'), '### Added\n- Big',
          reason: 'not the patch after it');
      expect(changesFor(patched, '0.2.0'), '### Added\n- Two');
    });

    test('the number of a shown version', () {
      expect(versionNumber('0.24.0 (25)'), '0.24.0');
    });
  });

  test(
      'every version\'s "What\'s new" reads as text, no stray code block '
      '(Round 29: 1.2.0\'s turned mostly into code)', () {
    final changelog = File('CHANGELOG.md').readAsStringSync();
    final versions = RegExp(r'^## \[(\d+\.\d+\.\d+)\]', multiLine: true)
        .allMatches(changelog)
        .map((m) => m[1]!);
    for (final version in versions) {
      final changes = changesFor(changelog, version)!;
      expect(markdownRuns(changes).where((r) => r.block), isEmpty,
          reason: version);
    }
  });
}
