// Design checks: Android accessibility guidelines on every screen, and the
// size relationships the requirements ask for. See docs/ARCHITECTURE.md.
import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:the_app/core/crypto.dart';
import 'package:the_app/core/theme.dart';
import 'package:the_app/data/backup.dart';
import 'package:the_app/models/app_section.dart';
import 'package:the_app/models/shop_item.dart';
import 'package:the_app/providers/counters_provider.dart';
import 'package:the_app/providers/notes_provider.dart';
import 'package:the_app/providers/planner_provider.dart';
import 'package:the_app/providers/section_locks_provider.dart';
import 'package:the_app/providers/security_provider.dart';
import 'package:the_app/providers/session_provider.dart';
import 'package:the_app/providers/shop_provider.dart';
import 'package:the_app/widgets/selection.dart';

import 'helpers.dart';

/// Seeds a few notes (one locked) and shop items (in both sections).
Future<void> seed(ProviderContainer container) async {
  final notes = container.read(notesProvider.notifier)
    ..addNote(title: 'Bank', content: 'PIN')
    ..addNote(title: 'Groceries', content: 'milk')
    ..addNote(title: 'Trip plan');
  final bank = container.read(notesProvider).last.id;
  await notes.lockNote(bank, DataKey.fromBytes(List.filled(32, 1)));
  final shop = container.read(shopProvider.notifier)
    ..addItem('Milk')
    ..addItem('Bread')
    ..addItem('Eggs');
  shop.toggle(
    container.read(shopProvider).firstWhere((i) => i.name == 'Milk').id,
  );
  final today = DateTime.now();
  final planner = container.read(plannerProvider.notifier)
    ..addTask(today, 'Gym')
    ..addTask(today, 'Call the bank');
  planner.toggleDone(container.read(plannerProvider).first.id);
  container.read(countersProvider.notifier)
    ..add('Push-ups')
    ..add('Glasses of water');
}

/// A fake file picker that returns a small backup when importing.
FakeBackupFiles pickingBackup() => FakeBackupFiles()
  ..toPick = Uint8List.fromList(
    utf8.encode(
      Backup(
        createdAt: DateTime(2026, 10, 8),
        appVersion: '1',
        notes: const [],
        shopItems: const [ShopItem(id: 'i', name: 'Tea')],
      ).encode(),
    ),
  );

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
      'note editor menu': (t) async {
        await t.tap(find.text('Groceries'));
        await t.pumpAndSettle();
        await t.tap(find.byTooltip('More'));
        await t.pumpAndSettle();
      },
      'lock needs a master password dialog': (t) async {
        await t.tap(find.text('Groceries'));
        await t.pumpAndSettle();
        await t.tap(find.byTooltip('More'));
        await t.pumpAndSettle();
        await t.tap(find.text('Lock note'));
        await t.pumpAndSettle();
        expect(find.text('Set a master password?'), findsOneWidget);
      },
      'save changes dialog': (t) async {
        await t.tap(find.text('Groceries'));
        await t.pumpAndSettle();
        await t.enterText(find.byKey(const Key('noteContentField')), 'eggs');
        await t.pump();
        await t.pageBack();
        await t.pumpAndSettle();
        expect(find.text('Save changes?'), findsOneWidget);
      },
      'shop': (t) => openTab(t, 'Shop'),
      'shop selection mode': (t) async {
        await openTab(t, 'Shop');
        await t.longPress(find.text('Milk'));
        await t.pumpAndSettle();
      },
      'planner': (t) => openTab(t, 'Planner'),
      'planner selection mode': (t) async {
        await openTab(t, 'Planner');
        await t.longPress(find.text('Gym'));
        await t.pumpAndSettle();
      },
      'other': (t) => openTab(t, 'Other'),
      'counters': (t) async {
        await openTab(t, 'Other');
        await t.tap(find.text('Counters'));
        await t.pumpAndSettle();
      },
      'counters selection mode': (t) async {
        await openTab(t, 'Other');
        await t.tap(find.text('Counters'));
        await t.pumpAndSettle();
        await t.longPress(find.text('Push-ups'));
        await t.pumpAndSettle();
      },
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
      'export choice': (t) async {
        await openMenu(t);
        await t.tap(find.text('Backup'));
        await t.pumpAndSettle();
        await t.tap(find.text('Export all data'));
        await t.pumpAndSettle();
      },
      'import preview': (t) async {
        await openMenu(t);
        await t.tap(find.text('Backup'));
        await t.pumpAndSettle();
        await t.tap(find.text('Import from file')); // picks [backupFile]
        await t.pumpAndSettle();
        expect(find.text('Restore this backup?'), findsOneWidget);
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
        await seed(await pumpApp(tester, backupFiles: pickingBackup()));
        await tester.pump();
        await open(tester);
        await expectAccessible(tester);
        semantics.dispose();
      });
    }
  });

  for (final unlock in [false, true]) {
    testWidgets(
        'accessibility guidelines: security with a master password, '
        '${unlock ? 'unlocked' : 'locked'}', (tester) async {
      final semantics = tester.ensureSemantics();
      final container = await pumpApp(tester);
      await tester.runAsync(() async {
        await container
            .read(securityProvider.notifier)
            .setPassword('master password');
        if (unlock) {
          await container
              .read(sessionProvider.notifier)
              .unlock('master password');
        }
      });
      await openMenu(tester);
      await tester.tap(find.text('Security'));
      await tester.pumpAndSettle();
      await expectAccessible(tester);
      semantics.dispose();
    });
  }

  testWidgets('accessibility guidelines: a locked section', (tester) async {
    final semantics = tester.ensureSemantics();
    final container = await pumpApp(tester);
    await tester.runAsync(() async {
      await container
          .read(securityProvider.notifier)
          .setPassword('master password');
      await container.read(sessionProvider.notifier).unlock('master password');
    });
    container.read(sectionLocksProvider.notifier).lock(AppSection.notes);
    container.read(sessionProvider.notifier).lock();
    await tester.pumpAndSettle();

    expect(find.text('Notes is locked'), findsOneWidget);
    await expectAccessible(tester);
    semantics.dispose();
  });

  group('compact shop rows (S4)', () {
    /// The card of the list row showing [text].
    Finder rowOf(String text) => find.ancestor(
          of: find.text(text),
          matching: find.byType(SelectableCard),
        );

    Future<void> pumpSeeded(WidgetTester tester) async {
      await seed(await pumpApp(tester));
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
      // Bread and Eggs are adjacent in "To buy", in that order.
      final shopGap = tester.getTopLeft(rowOf('Eggs')).dy -
          tester.getBottomLeft(rowOf('Bread')).dy;

      expect(shopRow, lessThanOrEqualTo(noteRow * 0.8));
      expect(shopGap, greaterThanOrEqualTo(0), reason: 'rows in this order');
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

  testWidgets('drag handles fill the row height and are easy to grab',
      (tester) async {
    await seed(await pumpApp(tester));
    await tester.pump();

    Future<void> check(String text) async {
      final row = find.ancestor(
        of: find.text(text),
        matching: find.byType(SelectableCard),
      );
      final handle = find.descendant(
        of: row,
        matching: find.byType(ReorderableDragStartListener),
      );
      expect(tester.getSize(handle).height, tester.getSize(row).height,
          reason: text);
      expect(
        tester.getSize(handle).width,
        greaterThanOrEqualTo(ReorderOrSelectIndicator.width),
        reason: text,
      );
      // The icon stays near the right edge; the extra area is to its left.
      final icon = find.descendant(
        of: row,
        matching: find.byIcon(Icons.drag_handle),
      );
      expect(
        tester.getRect(icon).right,
        tester.getRect(handle).right - ReorderOrSelectIndicator.iconInset,
        reason: text,
      );
    }

    await check('Groceries');
    await openTab(tester, 'Shop');
    await check('Milk');
  });

  testWidgets('selection actions sit in the lower right, in thumb reach',
      (tester) async {
    await seed(await pumpApp(tester));
    await tester.pump();
    final screen = tester.getSize(find.byType(MaterialApp));

    for (final (tab, item) in [('Notes', 'Groceries'), ('Shop', 'Milk')]) {
      await openTab(tester, tab);
      await tester.longPress(find.text(item));
      await tester.pumpAndSettle();

      for (final tooltip in ['Select all', 'Delete']) {
        final button = tester.getCenter(find.byTooltip(tooltip));
        expect(button.dx, greaterThan(screen.width / 2), reason: tooltip);
        expect(button.dy, greaterThan(screen.height * 0.75), reason: tooltip);
        expect(
          find.descendant(
            of: find.byType(AppBar),
            matching: find.byTooltip(tooltip),
          ),
          findsNothing,
          reason: '$tooltip is not at the top any more',
        );
      }
      // Delete is the rightmost.
      expect(
        tester.getCenter(find.byTooltip('Delete')).dx,
        greaterThan(tester.getCenter(find.byTooltip('Select all')).dx),
      );

      await tester.tap(find.byTooltip('Cancel selection'));
      await tester.pumpAndSettle();
    }
  });

  group('touch feedback', () {
    /// Presses (without releasing) on [target] inside the row showing
    /// [text], and returns the layer the row's ripple is drawn on.
    Future<Object> pressRow(
      WidgetTester tester,
      String text, {
      Finder? target,
    }) async {
      final row = find.ancestor(
        of: find.text(text),
        matching: find.byType(SelectableCard),
      );
      await tester.startGesture(tester.getCenter(target ?? row));
      await tester.pump(const Duration(milliseconds: 100));
      return Material.of(
        tester.element(
          find.descendant(of: row, matching: find.byType(InkWell)),
        ),
      );
    }

    testWidgets('rows ripple in the app ripple colour', (tester) async {
      await seed(await pumpApp(tester));
      await tester.pump();
      final material = await pressRow(tester, 'Groceries');
      expect(material, paints..circle());

      final theme = Theme.of(tester.element(find.text('Groceries')));
      expect(theme.splashColor, AppColors.ripple);
      expect(theme.splashFactory, InkRipple.splashFactory);
    });

    testWidgets("a shop row's checkbox gives the row's ripple", (tester) async {
      await seed(await pumpApp(tester));
      await openTab(tester, 'Shop');
      final checkbox = find.descendant(
        of: find.ancestor(
          of: find.text('Milk'),
          matching: find.byType(SelectableCard),
        ),
        matching: find.byType(Checkbox),
      );
      final material = await pressRow(tester, 'Milk', target: checkbox);
      expect(material, paints..circle());
      // The checkbox takes no touches itself, so the ripple is the row's.
      expect(
        tester
            .widget<IgnorePointer>(
              find
                  .ancestor(of: checkbox, matching: find.byType(IgnorePointer))
                  .first,
            )
            .ignoring,
        isTrue,
      );
    });
  });

  testWidgets('a locked note row: same height, lock announced', (tester) async {
    final semantics = tester.ensureSemantics();
    await seed(await pumpApp(tester));
    await tester.pump();
    Finder rowOf(String text) => find.ancestor(
          of: find.text(text),
          matching: find.byType(SelectableCard),
        );

    expect(
      tester.getSize(rowOf('Bank')).height,
      tester.getSize(rowOf('Groceries')).height,
    );
    // One element for screen readers, saying it's locked before the title.
    expect(
      tester.getSemantics(find.text('Bank')).label,
      matches(RegExp(r'^Locked\nBank\n')),
    );
    semantics.dispose();
  });

  testWidgets('selection is announced to screen readers', (tester) async {
    final semantics = tester.ensureSemantics();
    await seed(await pumpApp(tester));
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
    await seed(await pumpApp(tester));
    await tester.pump();
    await openTab(tester, 'Shop');
    await openTab(tester, 'Planner');
    await openTab(tester, 'Other');
    await tester.tap(find.text('Counters'));
    await tester.pumpAndSettle();
    await tester.pageBack();
    await tester.pumpAndSettle();
    await openTab(tester, 'Notes');
    // Layout overflow would have been reported as an exception.
    expect(tester.takeException(), isNull);
  });
}
