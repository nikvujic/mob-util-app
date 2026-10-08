// Design checks: Android accessibility guidelines on every screen, and the
// size relationships the requirements ask for. See docs/ARCHITECTURE.md.
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:the_app/providers/notes_provider.dart';
import 'package:the_app/providers/shop_provider.dart';
import 'package:the_app/widgets/selection.dart';

import 'helpers.dart';

/// Seeds a few notes and shop items (in both sections).
void seed(ProviderContainer container) {
  container.read(notesProvider.notifier)
    ..addNote(title: 'Groceries', content: 'milk')
    ..addNote(title: 'Trip plan');
  final shop = container.read(shopProvider.notifier)
    ..addItem('Milk')
    ..addItem('Bread')
    ..addItem('Eggs');
  shop.toggle(container.read(shopProvider).last.id);
}

/// Checks the visible screen against Android's accessibility guidelines.
Future<void> expectAccessible(WidgetTester tester) async {
  await expectLater(tester, meetsGuideline(androidTapTargetGuideline));
  await expectLater(tester, meetsGuideline(labeledTapTargetGuideline));
  await expectLater(tester, meetsGuideline(textContrastGuideline));
}

void main() {
  group('accessibility guidelines', () {
    // Each case opens one screen of the seeded app.
    final screens = <String, Future<void> Function(WidgetTester)>{
      'notes list': (_) async {},
      'notes selection mode': (t) async {
        await t.longPress(find.text('Groceries'));
        await t.pumpAndSettle();
      },
      'note editor': (t) async {
        await t.tap(find.text('Groceries'));
        await t.pumpAndSettle();
      },
      'shop': (t) => openTab(t, 'Shop'),
      'shop selection mode': (t) async {
        await openTab(t, 'Shop');
        await t.longPress(find.text('Milk'));
        await t.pumpAndSettle();
      },
      'planner': (t) => openTab(t, 'Planner'),
      'other': (t) => openTab(t, 'Other'),
      'menu': openMenu,
      'backup': (t) async {
        await openMenu(t);
        await t.tap(find.text('Backup'));
        await t.pumpAndSettle();
      },
      'security': (t) async {
        await openMenu(t);
        await t.tap(find.text('Security'));
        await t.pumpAndSettle();
      },
      'set master password form': (t) async {
        await openMenu(t);
        await t.tap(find.text('Security'));
        await t.pumpAndSettle();
        await t.tap(find.text('Set master password'));
        await t.pumpAndSettle();
      },
    };

    for (final MapEntry(key: name, value: open) in screens.entries) {
      testWidgets(name, (tester) async {
        final semantics = tester.ensureSemantics();
        seed(await pumpApp(tester));
        await tester.pump();
        await open(tester);
        await expectAccessible(tester);
        semantics.dispose();
      });
    }
  });

  group('compact shop rows (S4)', () {
    /// The card of the list row showing [text].
    Finder rowOf(String text) => find.ancestor(
          of: find.text(text),
          matching: find.byType(SelectableCard),
        );

    Future<void> pumpSeeded(WidgetTester tester) async {
      seed(await pumpApp(tester));
      await tester.pump();
    }

    testWidgets('are exactly one touch target high', (tester) async {
      await pumpSeeded(tester);
      await openTab(tester, 'Shop');

      for (final name in ['Milk', 'Bread', 'Eggs']) {
        expect(
          tester.getSize(rowOf(name)).height,
          kMinInteractiveDimension,
          reason: name,
        );
      }
    });

    testWidgets('are at least 20% smaller than note rows, with tighter gaps',
        (tester) async {
      await pumpSeeded(tester);
      final noteRow = tester.getSize(rowOf('Groceries')).height;
      final noteGap = tester.getTopLeft(rowOf('Groceries')).dy -
          tester.getBottomLeft(rowOf('Trip plan')).dy;

      await openTab(tester, 'Shop');
      final shopRow = tester.getSize(rowOf('Eggs')).height;
      // Eggs and Bread are adjacent in "To buy".
      final shopGap = tester.getTopLeft(rowOf('Bread')).dy -
          tester.getBottomLeft(rowOf('Eggs')).dy;

      expect(shopRow, lessThanOrEqualTo(noteRow * 0.8));
      expect(shopGap, lessThan(noteGap));
    });

    testWidgets('announce the checkbox together with the item name',
        (tester) async {
      final semantics = tester.ensureSemantics();
      await pumpSeeded(tester);
      await openTab(tester, 'Shop');

      expect(
        tester.getSemantics(find.text('Bread')),
        containsSemantics(
          label: 'Bread',
          hasCheckedState: true,
          isChecked: false,
          hasTapAction: true,
        ),
      );
      expect(
        tester.getSemantics(find.text('Milk')),
        containsSemantics(label: 'Milk', isChecked: true),
      );
      semantics.dispose();
    });
  });

  testWidgets('selection is announced to screen readers', (tester) async {
    final semantics = tester.ensureSemantics();
    seed(await pumpApp(tester));
    await tester.pump();

    await tester.longPress(find.text('Groceries'));
    await tester.pump();
    expect(
      tester.getSemantics(find.text('Groceries')),
      containsSemantics(isSelected: true),
    );

    await openTab(tester, 'Shop');
    await tester.longPress(find.text('Bread'));
    await tester.pump();
    expect(
      tester.getSemantics(find.text('Bread')),
      containsSemantics(label: 'Bread', isSelected: true),
    );
    semantics.dispose();
  });

  testWidgets('lists cope with a very large system font', (tester) async {
    tester.platformDispatcher.textScaleFactorTestValue = 2.0;
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
    seed(await pumpApp(tester));
    await tester.pump();
    await openTab(tester, 'Shop');
    await openTab(tester, 'Notes');
    // Layout overflow would have been reported as an exception.
    expect(tester.takeException(), isNull);
  });
}
