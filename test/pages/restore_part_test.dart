import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:the_app/data/backup.dart';
import 'package:the_app/models/note.dart';
import 'package:the_app/models/shop_item.dart';
import 'package:the_app/providers/notes_provider.dart';
import 'package:the_app/providers/shop_provider.dart';

import '../helpers.dart';

/// Restoring part of a backup from the Backup page (Round 28).
void main() {
  late ProviderContainer container;

  Note note(String id, String title) => Note(
        id: id,
        title: title,
        content: '',
        createdAt: DateTime(2026, 1, 1),
        modifiedAt: DateTime(2026, 1, 2),
      );

  Future<void> openPicker(WidgetTester tester) async {
    final files = FakeBackupFiles()
      ..toPick = Uint8List.fromList(utf8.encode(Backup(
        createdAt: DateTime(2026, 10, 8),
        appVersion: '1',
        notes: [note('n1', 'Lost note'), note('n2', 'Other note')],
        shopItems: const [ShopItem(id: 's1', name: 'Tea')],
      ).encode()));
    container = await pumpApp(tester, backupFiles: files);
    container.read(notesProvider.notifier).addNote(title: 'Current note');
    await openMenu(tester);
    await tester.tap(find.text('Backup'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Restore part of a backup'));
    await tester.pumpAndSettle();
  }

  testWidgets('lists what the backup holds, nothing ticked', (tester) async {
    await openPicker(tester);
    expect(appBarTitle('Restore part'), findsOneWidget);
    expect(find.text('NOTES  ·  2'), findsOneWidget);
    expect(find.text('SHOP  ·  1'), findsOneWidget);
    expect(find.text('TO-DO  ·  0'), findsNothing,
        reason: 'empty kinds hidden');
    for (final title in ['Lost note', 'Other note', 'Tea']) {
      expect(find.text(title), findsOneWidget);
    }
    expect(find.byKey(const Key('restorePicked')), findsNothing);
  });

  testWidgets('one note back, the rest left as it is; Undo', (tester) async {
    await openPicker(tester);
    await tester.tap(find.text('Lost note'));
    await tester.pumpAndSettle();
    // A wide button, its label inside it (Round 30).
    final button = tester.getRect(find.byKey(const Key('restorePicked')));
    final label = tester.getRect(find.text('Restore 1'));
    expect(button.contains(label.topLeft) && button.contains(label.bottomRight),
        isTrue);
    expect(button.width, greaterThan(300));
    await tester.tap(find.text('Restore 1'));
    await tester.pumpAndSettle();

    expect(container.read(notesProvider).map((n) => n.title),
        ['Lost note', 'Current note']);
    expect(container.read(shopProvider), isEmpty);
    expect(find.text('1 thing restored'), findsOneWidget);

    await tester.tap(find.text('Undo'));
    await tester.pumpAndSettle();
    expect(container.read(notesProvider).map((n) => n.title), ['Current note']);
  });

  testWidgets('All picks a whole kind, and None unpicks it', (tester) async {
    await openPicker(tester);
    final all = find.descendant(
      of: find.byKey(const Key('part-notes')),
      matching: find.text('All'),
    );
    await tester.tap(all);
    await tester.pumpAndSettle();
    expect(find.text('Restore 2'), findsOneWidget);
    await tester.tap(find.descendant(
      of: find.byKey(const Key('part-notes')),
      matching: find.text('None'),
    ));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('restorePicked')), findsNothing);
  });

  testWidgets('one still in the app: marked, and comes back as a copy',
      (tester) async {
    await openPicker(tester);
    container.read(notesProvider.notifier).replaceAll([note('n1', 'Edited')]);
    await tester.pumpAndSettle();
    expect(find.textContaining('Also in the app'), findsOneWidget);
    await tester.tap(find.text('Lost note'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Restore 1'));
    await tester.pumpAndSettle();
    expect(container.read(notesProvider).map((n) => n.title),
        ['Lost note (Copy)', 'Edited']);
    expect(find.text('1 thing restored; 1 as a copy'), findsOneWidget);
  });

  testWidgets('back without restoring changes nothing', (tester) async {
    await openPicker(tester);
    await tester.tap(find.text('Lost note'));
    await tester.pumpAndSettle();
    await tester.pageBack();
    await tester.pumpAndSettle();
    expect(container.read(notesProvider).map((n) => n.title), ['Current note']);
  });
}
