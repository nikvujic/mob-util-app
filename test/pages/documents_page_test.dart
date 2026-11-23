import 'package:the_app/core/theme.dart';
import 'package:the_app/providers/preferences_provider.dart';
import 'package:the_app/core/picture_crop.dart';
import 'package:barcode/barcode.dart' as bc;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:the_app/data/reminder_scheduler.dart';
import 'package:the_app/models/document_item.dart';
import 'package:the_app/models/hub_tool.dart';
import 'package:the_app/pages/hub/documents.dart';
import 'package:the_app/providers/documents_provider.dart';
import 'package:the_app/providers/section_locks_provider.dart';
import 'package:the_app/providers/security_provider.dart';
import 'package:the_app/providers/session_provider.dart';
import 'package:the_app/providers/section_data_provider.dart';

import '../helpers.dart';

/// The Documents page (spec `docs/DOCUMENTS_SPEC.md`): its kinds, the
/// camera first for some, the form's editing rules, pictures (camera,
/// gallery, rotate, move, download, delete with Undo), the list's search,
/// filter and order, Clear data.
void main() {
  late ProviderContainer container;
  late FakeDocumentCamera camera;
  late FakePhotoGallery gallery;
  late FakeReminderScheduler scheduler;

  Future<void> start(WidgetTester tester,
      {List<DocItem> items = const []}) async {
    camera = FakeDocumentCamera();
    gallery = FakePhotoGallery();
    scheduler = FakeReminderScheduler();
    container = await pumpApp(tester,
        clock: () => DateTime(2026, 11, 23, 12),
        camera: camera,
        gallery: gallery,
        reminders: scheduler);
    for (final d in items.reversed) {
      container.read(documentsProvider.notifier).save(d);
    }
    await openTab(tester, 'Hub');
    await tester.tap(find.byTooltip('Documents'));
    await tester.pumpAndSettle();
  }

  DocumentBook book() => container.read(documentsProvider);

  Future<void> add(WidgetTester tester, DocKind kind) async {
    await tester.tap(find.byTooltip('Add a document'));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(Key('choice-${kind.name}')));
    await tester.pumpAndSettle();
  }

  testWidgets('empty at first; a document opens the form, no camera',
      (tester) async {
    await start(tester);
    expect(find.text('No documents'), findsOneWidget);
    await add(tester, DocKind.document);
    expect(camera.opened, 0);
    expect(appBarTitle('New document'), findsOneWidget);
    await tester.enterText(find.byKey(const Key('documentName')), 'Passport');
    await tester.pump();
    expect(book().items.single.name, 'Passport', reason: 'saved as typed');
    await leaveSaved(tester);
    expect(find.text('Passport'), findsOneWidget);
    expect(
        find.descendant(
            of: find.byKey(Key('document-${book().items.single.id}')),
            matching: find.text('Document')),
        findsOneWidget,
        reason: 'its kind');
  });

  testWidgets(
      'a receipt opens the camera first: its photo the first picture; '
      'shop and price', (tester) async {
    await start(tester);
    camera.photos.add(testPng(shade: 10));
    await add(tester, DocKind.receipt);
    expect(camera.opened, 1);
    final saved = book().items.single;
    expect(saved.kind, DocKind.receipt);
    expect(saved.pictures, hasLength(1));
    expect(
        await container
            .read(documentsProvider.notifier)
            .readPicture(saved.pictures.single.id),
        testPng(shade: 10));
    await tester.enterText(find.byKey(const Key('documentShop')), 'Tehnika');
    await tester.enterText(find.byKey(const Key('documentPrice')), '449 €');
    await tester.pump();
    expect((book().items.single.shop, book().items.single.price),
        ('Tehnika', '449 €'));
  });

  testWidgets(
      'the camera closed without a photo: the form stays, empty, its kind '
      'kept; left empty, nothing is kept', (tester) async {
    await start(tester);
    await add(tester, DocKind.ticket);
    expect(camera.opened, 1);
    expect(appBarTitle('New ticket'), findsOneWidget);
    expect(book().items, isEmpty);
    await pressBack(tester);
    expect(find.byType(AlertDialog), findsNothing, reason: 'nothing to ask');
    expect(book().items, isEmpty);
    expect(find.text('No documents'), findsOneWidget);
  });

  testWidgets("the camera can't open: says so; the gallery still adds",
      (tester) async {
    await start(tester);
    camera.unavailable = true;
    await add(tester, DocKind.barcode);
    expect(find.textContaining("The camera didn't open"), findsOneWidget);
    camera.picks = [testPng(shade: 1), testPng(shade: 2)];
    await tester.tap(find.byKey(const Key('documentGallery')));
    await tester.pumpAndSettle();
    expect(book().items.single.pictures, hasLength(2));
    // Cancelled: nothing more.
    camera.picks = [];
    await tester.tap(find.byKey(const Key('documentGallery')));
    await tester.pumpAndSettle();
    expect(book().items.single.pictures, hasLength(2));
  });

  testWidgets(
      'a picture held: rotate, move, download, delete with Undo; a tap '
      'opens it full screen', (tester) async {
    final a = testPng(shade: 1), b = testPng(shade: 2);
    await start(tester);
    final notifier = container.read(documentsProvider.notifier);
    final ida = await tester.runAsync(() => notifier.addPicture(a));
    final idb = await tester.runAsync(() => notifier.addPicture(b));
    notifier.save(DocItem(
      id: 'd',
      kind: DocKind.document,
      name: 'ID',
      pictures: [DocPicture(ida!), DocPicture(idb!)],
      createdAt: DateTime(2026, 11, 23),
    ));
    await tester.pumpAndSettle();
    await tester.tap(find.text('ID'));
    await tester.pumpAndSettle();

    Future<void> menu(int i, String choice) async {
      await tester.longPress(find.byKey(Key('documentPicture-$i')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(Key('choice-$choice')));
      await tester.pumpAndSettle();
    }

    await menu(0, 'rotate');
    expect(book().items.single.pictures.first.turns, 1);
    await menu(0, 'later');
    expect(book().items.single.pictures.map((p) => p.id), [idb, ida]);
    await menu(1, 'download');
    expect(gallery.saved.keys, ['ID 2']);
    expect(gallery.saved['ID 2'], a);
    expect(find.text('Saved to the gallery'), findsOneWidget);

    await menu(0, 'delete');
    expect(book().items.single.pictures.map((p) => p.id), [ida]);
    await tester.tap(find.text('Undo'));
    await tester.pumpAndSettle();
    expect(book().items.single.pictures.map((p) => p.id), [idb, ida]);

    await tester.tap(find.byKey(const Key('documentPicture-1')));
    await tester.pumpAndSettle();
    expect(find.text('2 of 2'), findsOneWidget);
    // A finger's swipe, a bit at a time (the page takes it before the
    // picture's pinch).
    final swipe =
        await tester.startGesture(tester.getCenter(find.byType(PageView)));
    for (var i = 0; i < 30; i++) {
      await swipe.moveBy(const Offset(20, 0));
      await tester.pump(const Duration(milliseconds: 16));
    }
    await swipe.up();
    await tester.pumpAndSettle();
    expect(find.text('1 of 2'), findsOneWidget);
  });

  testWidgets(
      'back after changes asks Save or Discard; Discard puts it back as '
      'it was', (tester) async {
    await start(tester, items: [
      DocItem(
          id: 'p',
          kind: DocKind.document,
          name: 'Passport',
          createdAt: DateTime(2026, 11, 1)),
    ]);
    await tester.tap(find.text('Passport'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const Key('documentName')), 'Pasoš');
    await tester.pump();
    expect(book().items.single.name, 'Pasoš');
    await pressBack(tester);
    expect(find.text('Save changes?'), findsOneWidget);
    await tester.tap(find.text('Discard'));
    await tester.pumpAndSettle();
    expect(book().items.single.name, 'Passport');
  });

  testWidgets('deleted, asked first, with Undo', (tester) async {
    await start(tester, items: [
      DocItem(
          id: 'p',
          kind: DocKind.document,
          name: 'Passport',
          createdAt: DateTime(2026, 11, 1)),
    ]);
    await tester.tap(find.text('Passport'));
    await tester.pumpAndSettle();
    await reveal(tester, find.byKey(const Key('deleteDocument')));
    await tester.tap(find.byKey(const Key('deleteDocument')));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilledButton, 'Delete'));
    await tester.pumpAndSettle();
    expect(book().items, isEmpty);
    await tester.tap(find.text('Undo'));
    await tester.pumpAndSettle();
    expect(book().items.single.name, 'Passport');
  });

  testWidgets(
      'search by name, shop and note; filter by kind; narrowed, no '
      'handles', (tester) async {
    DocItem item(String id, DocKind kind, String name,
            {String shop = '', String note = ''}) =>
        DocItem(
            id: id,
            kind: kind,
            name: name,
            shop: shop,
            note: note,
            createdAt: DateTime(2026, 11, 1));
    await start(tester, items: [
      item('a', DocKind.document, 'Passport', note: 'renew in March'),
      item('b', DocKind.receipt, 'Washing machine', shop: 'Tehnika'),
      item('c', DocKind.barcode, 'Library card'),
    ]);
    expect(find.byIcon(Icons.drag_handle), findsNWidgets(3));
    await tester.enterText(find.byKey(const Key('documentsSearch')), 'tehn');
    await tester.pumpAndSettle();
    expect(find.text('Washing machine'), findsOneWidget);
    expect(find.text('Passport'), findsNothing);
    expect(find.byIcon(Icons.drag_handle), findsNothing);
    await tester.enterText(find.byKey(const Key('documentsSearch')), 'MARCH');
    await tester.pumpAndSettle();
    expect(find.text('Passport'), findsOneWidget);
    await tester.enterText(find.byKey(const Key('documentsSearch')), '');
    await tester.tap(find.byKey(const Key('documentsFilter-barcode')));
    await tester.pumpAndSettle();
    expect(find.text('Library card'), findsOneWidget);
    expect(find.text('Passport'), findsNothing);
    await tester.tap(find.byKey(const Key('documentsFilter-barcode')));
    await tester.pumpAndSettle();
    expect(find.text('Passport'), findsOneWidget);
  });

  testWidgets('Clear data empties it, its pictures too', (tester) async {
    await start(tester);
    final notifier = container.read(documentsProvider.notifier);
    final id = await tester.runAsync(() => notifier.addPicture([1, 2]));
    notifier.save(DocItem(
        id: 'p',
        kind: DocKind.document,
        name: 'Passport',
        pictures: [DocPicture(id!)],
        createdAt: DateTime(2026, 11, 1)));
    final data = container.read(sectionDataProvider);
    expect(data.countOf(HubTool.documents), 1);
    expect(HubTool.documents.lockable, isTrue);
    expect(HubTool.documents.clearable, isTrue);
    data.clearOf(HubTool.documents);
    await tester.runAsync(() => Future<void>.delayed(Duration.zero));
    expect(book().items, isEmpty);
    expect(await tester.runAsync(() => notifier.files.ids()), isEmpty);
  });

  group('barcode', () {
    /// A wide picture: a black band (the barcode) across a white card.
    final card = testPng(pixels: [
      for (var y = 0; y < 10; y++)
        [for (var x = 0; x < 20; x++) y >= 4 && y < 6 ? 0 : 0xFFFFFF],
    ]);

    /// Lets the crop step read and cut the picture (real work).
    Future<void> settle(WidgetTester tester) => settleBusy(tester);

    testWidgets(
        'a new card: the camera, then the crop step; its crop the barcode, '
        'shown full screen at full brightness, given back on closing',
        (tester) async {
      final calls = <String>[];
      tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
          const MethodChannel('the_app/screen'), (call) async {
        calls.add('${call.method} ${call.arguments}');
        return null;
      });
      await start(tester);
      camera.photos.add(card);
      await add(tester, DocKind.barcode);
      await settle(tester);
      expect(find.text('Frame the barcode'), findsOneWidget);
      await tester.tap(find.byKey(const Key('barcodeCropUse')));
      await settle(tester);
      expect(find.text('Frame the barcode'), findsNothing);

      final saved = book().items.single;
      expect(saved.pictures, hasLength(1));
      expect(saved.barcode, isNotNull);
      expect(saved.fileIds, hasLength(2), reason: 'the crop is its own');
      final crop = await tester.runAsync(() => container
          .read(documentsProvider.notifier)
          .readPicture(saved.barcode!));
      expect(crop!.sublist(1, 4), 'PNG'.codeUnits);

      await tester.tap(find.byKey(const Key('documentShowBarcode')));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('shownBarcode')), findsOneWidget);
      expect(calls, ['keepOn true', 'brightness 0.75']);
      await tester.pageBack();
      await tester.pumpAndSettle();
      expect(calls, [
        'keepOn true',
        'brightness 0.75',
        'brightness null',
        'keepOn false'
      ]);
    });

    testWidgets(
        'the crop cancelled: the picture stays, no barcode; Set barcode '
        'later crops it, Remove takes it off', (tester) async {
      await start(tester);
      camera.photos.add(card);
      await add(tester, DocKind.ticket);
      await settle(tester);
      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();
      expect(book().items.single.pictures, hasLength(1));
      expect(book().items.single.barcode, isNull);
      expect(find.byKey(const Key('documentShowBarcode')), findsNothing);

      await tester.tap(find.byKey(const Key('documentSetBarcode')));
      await settle(tester);
      // The frame dragged down a little: still a crop.
      await tester.drag(
          find.byKey(const Key('barcodeCropArea')), const Offset(0, 20));
      await tester.tap(find.byKey(const Key('barcodeCropUse')));
      await settle(tester);
      expect(book().items.single.barcode, isNotNull);

      await tester.tap(find.byKey(const Key('documentRemoveBarcode')));
      await tester.pumpAndSettle();
      expect(book().items.single.barcode, isNull);
    });

    testWidgets('a document and a receipt have no barcode', (tester) async {
      await start(tester);
      await add(tester, DocKind.document);
      expect(find.byKey(const Key('documentSetBarcode')), findsNothing);
    });
  });

  group('dates and reminders', () {
    List<String> ours() => [
          for (final r in scheduler.scheduled)
            if (r.kind == ReminderKind.documents)
              '${r.at.month}/${r.at.day} ${r.title}: ${r.body}',
        ];

    testWidgets(
        "a receipt's warranty: from today, until a year or two on by the "
        'quick buttons; a reminder before it ends', (tester) async {
      await start(tester);
      await add(tester, DocKind.receipt);
      await tester.enterText(find.byKey(const Key('documentName')), 'Washer');
      await tester.pump();
      await reveal(tester, find.byKey(const Key('documentWarranty')));
      await tester.tap(find.byKey(const Key('documentWarranty')));
      await tester.pumpAndSettle();
      expect(find.text('From today'), findsOneWidget);
      await reveal(tester, find.byKey(const Key('documentWarrantyYears-2')));
      await tester.tap(find.byKey(const Key('documentWarrantyYears-2')));
      await tester.pumpAndSettle();
      final saved = book().items.single;
      expect((saved.warranty, saved.warrantyFrom, saved.warrantyTo),
          (true, DateTime(2026, 11, 23), DateTime(2028, 11, 23)));
      await tester.tap(find.byKey(const Key('documentWarrantyYears-1')));
      await tester.pumpAndSettle();
      expect(book().items.single.warrantyTo, DateTime(2027, 11, 23));

      await reveal(tester, find.byKey(const Key('documentRemind-month')));
      await tester.tap(find.byKey(const Key('documentRemind-month')));
      await tester.pumpAndSettle();
      expect(book().items.single.remind, DocRemind.month);
      await leaveSaved(tester);
      expect(find.text('Warranty until 23 Nov 2027'), findsOneWidget);
    });

    testWidgets(
        "an expiry's reminder comes before it, at 09:00; private or the "
        'page locked, without its name', (tester) async {
      await start(tester, items: [
        DocItem(
          id: 'p',
          kind: DocKind.document,
          name: 'Passport',
          expires: DateTime(2026, 12, 1),
          remind: DocRemind.week,
          createdAt: DateTime(2026, 11, 1),
        ),
      ]);
      await tester.pumpAndSettle();
      expect(ours(), ['11/24 Passport: Expires in 7 days · 1 Dec 2026']);
      expect(tester.widget<Text>(find.byKey(const Key('documentDate-p'))).data,
          'Expires 1 Dec 2026');

      await tester.runAsync(() => container
          .read(securityProvider.notifier)
          .setPassword('master password'));
      container.read(pageLocksProvider.notifier).lock(HubTool.documents);
      await tester.pumpAndSettle();
      expect(ours(), ['11/24 Documents: A document expires in 7 days']);
    });

    testWidgets("a ticket's day: reminded on it unless turned off",
        (tester) async {
      await start(tester);
      await add(tester, DocKind.ticket);
      await reveal(tester, find.byKey(const Key('documentDate')));
      await tester.tap(find.byKey(const Key('documentDate')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('28'));
      await tester.tap(find.text('OK'));
      await tester.pumpAndSettle();
      expect(book().items.single.date, DateTime(2026, 11, 28));
      expect(book().items.single.remind, DocRemind.onTheDay);
      await tester.pumpAndSettle();
      expect(ours(), ['11/28 Ticket: Your ticket is for today']);
      await reveal(tester, find.byKey(const Key('documentTicketRemind')));
      await tester.tap(find.byKey(const Key('documentTicketRemind')));
      await tester.pumpAndSettle();
      expect(ours(), isEmpty);
    });

    testWidgets('its own settings on the Notifications page', (tester) async {
      await start(tester, items: [
        DocItem(
          id: 'p',
          kind: DocKind.document,
          name: 'Passport',
          expires: DateTime(2026, 12, 1),
          remind: DocRemind.week,
          createdAt: DateTime(2026, 11, 1),
        ),
      ]);
      await pressBack(tester);
      await openMenu(tester);
      await tester.tap(find.text('Notifications'));
      await tester.pumpAndSettle();
      final private = find.byKey(const Key('notifyPrivate-documents'));
      await reveal(tester, private);
      await tester.tap(private);
      await tester.pumpAndSettle();
      expect(ours(), ['11/24 Documents: A document expires in 7 days']);
      final on = find.byKey(const Key('notifyOn-documents'));
      await reveal(tester, on);
      await tester.tap(on);
      await tester.pumpAndSettle();
      expect(ours(), isEmpty);
    });
  });

  test('the date line: its words and colour on a day', () {
    final today = DateTime(2026, 11, 23);
    DocItem d(DocKind kind,
            {DateTime? expires,
            DateTime? to,
            DateTime? date,
            DocRemind remind = DocRemind.none}) =>
        DocItem(
            id: 'x',
            kind: kind,
            expires: expires,
            warranty: to != null,
            warrantyTo: to,
            date: date,
            remind: remind,
            createdAt: today);
    String line(DocItem item) {
      final l = documentDateLine(item, today);
      return l == null ? '-' : '${l.text} (${l.tone.name})';
    }

    expect(line(d(DocKind.document, expires: DateTime(2031, 3, 3))),
        'Expires 3 Mar 2031 (plain)');
    // Within its reminder (or a month, with none): orange.
    expect(
        line(d(DocKind.document,
            expires: DateTime(2026, 12, 1), remind: DocRemind.week)),
        'Expires 1 Dec 2026 (plain)');
    expect(
        line(d(DocKind.document,
            expires: DateTime(2026, 11, 30), remind: DocRemind.week)),
        'Expires 30 Nov 2026 (soon)');
    expect(line(d(DocKind.document, expires: DateTime(2026, 12, 20))),
        'Expires 20 Dec 2026 (soon)');
    expect(line(d(DocKind.document, expires: DateTime(2026, 11, 1))),
        'Expired 1 Nov 2026 (gone)');
    expect(line(d(DocKind.receipt, to: DateTime(2028, 11, 12))),
        'Warranty until 12 Nov 2028 (plain)');
    expect(line(d(DocKind.receipt, to: DateTime(2026, 1, 1))),
        'Warranty ended (past)');
    expect(line(d(DocKind.ticket, date: DateTime(2026, 11, 24))),
        'Tomorrow (soon)');
    expect(
        line(d(DocKind.ticket, date: DateTime(2026, 11, 23))), 'Today (soon)');
    expect(line(d(DocKind.ticket, date: DateTime(2026, 11, 2))),
        '2 Nov 2026 (past)');
    expect(line(d(DocKind.barcode)), '-');
    expect(line(d(DocKind.document)), '-');
  });

  testWidgets(
      "the Documents lock on Security: on, it's encrypted; off, opened "
      'again', (tester) async {
    await start(tester, items: [
      DocItem(
          id: 'p',
          kind: DocKind.document,
          name: 'Passport',
          createdAt: DateTime(2026, 11, 1)),
    ]);
    await tester.runAsync(() async {
      await container
          .read(securityProvider.notifier)
          .setPassword('master password');
      await container.read(sessionProvider.notifier).unlock('master password');
    });
    await pressBack(tester);
    await openMenu(tester);
    await tester.tap(find.text('Security'));
    await tester.pumpAndSettle();
    final lock = find.byKey(const Key('pageLock-documents'));
    await reveal(tester, lock);
    await tester.tap(lock);
    await settleBusy(tester);
    await tester
        .runAsync(() => container.read(documentsProvider.notifier).reconcile());
    await tester.pumpAndSettle();
    final docs = container.read(documentsProvider.notifier);
    expect(container.read(pageLocksProvider), contains(HubTool.documents));
    expect(docs.encrypted, isTrue);
    expect(book().items.single.name, 'Passport', reason: 'open while unlocked');

    await tester.tap(lock);
    await settleBusy(tester);
    await tester.runAsync(() => docs.reconcile());
    await tester.pumpAndSettle();
    expect(docs.encrypted, isFalse);
    expect(book().items.single.name, 'Passport');
  });

  testWidgets(
      "a card with a barcode: its card's button shows it at once; the "
      'others have none', (tester) async {
    await start(tester);
    final notifier = container.read(documentsProvider.notifier);
    final code = await tester.runAsync(() => notifier.addPicture(testPng()));
    notifier.save(DocItem(
        id: 'c',
        kind: DocKind.barcode,
        name: 'Library',
        barcode: code,
        createdAt: DateTime(2026, 11, 1)));
    notifier.save(DocItem(
        id: 'p',
        kind: DocKind.document,
        name: 'Passport',
        createdAt: DateTime(2026, 11, 1)));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('documentQuickBarcode-p')), findsNothing);
    await tester.tap(find.byKey(const Key('documentQuickBarcode-c')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('shownBarcode')), findsOneWidget);
  });

  testWidgets(
      'the kind chips: a row apart as much as side by side; the search '
      "icon on its text's line", (tester) async {
    tester.view.physicalSize = const Size(700, 1600);
    tester.view.devicePixelRatio = 2;
    addTearDown(tester.view.reset);
    await start(tester, items: [
      DocItem(
          id: 'p',
          kind: DocKind.document,
          name: 'Passport',
          createdAt: DateTime(2026, 11, 1)),
    ]);
    final chips = [
      for (final k in DocKind.values)
        tester.getRect(find.byKey(Key('documentsFilter-${k.name}'))),
    ];
    final rows = <double>{for (final c in chips) c.top}.toList()..sort();
    expect(rows.length, greaterThan(1), reason: 'narrow: two rows');
    final first = chips.where((c) => c.top == rows[0]).toList()
      ..sort((a, b) => a.left.compareTo(b.left));
    final across = first[1].left - first[0].right;
    final down = rows[1] - first[0].bottom;
    expect(down, moreOrLessEquals(across, epsilon: 0.5));

    final icon = tester.getCenter(find.byIcon(Icons.search));
    final field = tester.getCenter(find.byKey(const Key('documentsSearch')));
    expect(icon.dy, moreOrLessEquals(field.dy, epsilon: 1));
  });

  group('scanning and the barcode shown', () {
    final ean = codePng(bc.Barcode.ean13(), '4006381333931');

    /// A card with [photo] as its picture and its crop, on the list.
    Future<DocItem> card(WidgetTester tester, Uint8List photo,
        {DocCode? scanned, DocKind kind = DocKind.barcode}) async {
      final notifier = container.read(documentsProvider.notifier);
      final id = await tester.runAsync(() => notifier.addPicture(photo));
      final item = DocItem(
        id: 'c',
        kind: kind,
        name: 'Library',
        pictures: [DocPicture(id!)],
        barcode: id,
        scanned: scanned,
        createdAt: DateTime(2026, 11, 1),
      );
      notifier.save(item);
      await tester.pumpAndSettle();
      return item;
    }

    DocItem saved() => book().items.single;

    testWidgets(
        'Scan this: read (from the whole picture, the frame being off it), '
        'the code drawn from it, its number under it', (tester) async {
      await start(tester);
      camera.photos.add(ean);
      await add(tester, DocKind.barcode);
      await settleBusy(tester);
      // The frame dragged off the code: read from the whole picture.
      await tester.tap(find.byKey(const Key('barcodeCropScan')));
      await settleBusy(tester);
      expect(find.text('Frame the barcode'), findsNothing);
      expect(saved().scanned, const DocCode('4006381333931', 'ean13'));
      expect(find.byKey(const Key('drawnCode-ean13')), findsOneWidget);
      expect(find.text('4006381333931'), findsOneWidget);
    });

    testWidgets('no code in the picture: says so, the crop step stays',
        (tester) async {
      await start(tester);
      camera.photos.add(ean); // a shop barcode…
      await add(tester, DocKind.qr);
      await settleBusy(tester);
      expect(find.text('Frame the QR code'), findsOneWidget);
      // …but a QR code is asked for.
      await tester.tap(find.byKey(const Key('barcodeCropScan')));
      await settleBusy(tester);
      expect(find.textContaining('No code found'), findsOneWidget);
      expect(find.text('Frame the QR code'), findsOneWidget);
      await tester.tap(find.byKey(const Key('barcodeCropUse')));
      await settleBusy(tester);
      expect(saved().barcode, isNotNull);
      expect(saved().scanned, isNull, reason: 'its photo, as it is');
    });

    testWidgets("a QR code: framed square, read as QR", (tester) async {
      final qr =
          codePng(bc.Barcode.qrCode(), 'https://example.com/pass/9', module: 6);
      await start(tester);
      camera.photos.add(qr);
      await add(tester, DocKind.qr);
      await settleBusy(tester);
      await tester.tap(find.byKey(const Key('barcodeCropScan')));
      await settleBusy(tester);
      expect(saved().kind, DocKind.qr);
      expect(
          saved().scanned, const DocCode('https://example.com/pass/9', 'qr'));
      // The crop is square.
      final crop = await tester.runAsync(() => container
          .read(documentsProvider.notifier)
          .readPicture(saved().barcode!));
      final size = await tester.runAsync(() => pictureSize(crop!));
      expect(size!.width, moreOrLessEquals(size.height, epsilon: 2));
    });

    testWidgets(
        'shown: a drag moves it up and down anywhere, not sideways '
        'unless zoomed past the sides; tap twice and drag zooms; where '
        "it's left is kept; reset", (tester) async {
      await start(tester);
      await card(tester, ean, scanned: const DocCode('4006381333931', 'ean13'));
      await tester.tap(find.byKey(const Key('documentQuickBarcode-c')));
      await tester.pumpAndSettle();
      final area = find.byKey(const Key('shownBarcode'));
      Offset centre() =>
          tester.getCenter(find.byKey(const Key('shownBarcodeCode')));
      final start0 = centre();

      // Up, from near the edge (not on the code).
      final edge = tester.getTopLeft(area) + const Offset(20, 300);
      await tester.dragFrom(edge, const Offset(60, -150));
      await tester.pumpAndSettle();
      expect(centre().dy, moreOrLessEquals(start0.dy - 150, epsilon: 2));
      expect(centre().dx, moreOrLessEquals(start0.dx, epsilon: 1),
          reason: 'not sideways: it fits');
      expect(saved().codeView.dy, moreOrLessEquals(-150, epsilon: 2));

      // Tap, then tap and drag down: zoomed in.
      final at = tester.getCenter(area);
      await tester.tapAt(at);
      await tester.pump(const Duration(milliseconds: 100));
      final zoom = await tester.startGesture(at);
      for (var k = 0; k < 10; k++) {
        await zoom.moveBy(const Offset(0, 15));
        await tester.pump(const Duration(milliseconds: 16));
      }
      await zoom.up();
      await tester.pumpAndSettle();
      expect(saved().codeView.scale, greaterThan(2));
      // Zoomed past the sides: sideways now too.
      await tester.dragFrom(at, const Offset(80, 0));
      await tester.pumpAndSettle();
      expect(saved().codeView.dx, greaterThan(40));

      // Shown again: as it was left.
      final kept = saved().codeView;
      await tester.pageBack();
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('documentQuickBarcode-c')));
      await tester.pumpAndSettle();
      expect(saved().codeView, kept);
      await tester.tap(find.byKey(const Key('barcodeReset')));
      await tester.pumpAndSettle();
      expect(saved().codeView, CodeView.centred);
      expect(centre(), start0);
    });

    testWidgets(
        'the brightness slider: the screen follows, and the last one set '
        'comes back next time', (tester) async {
      final calls = <String>[];
      tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
          const MethodChannel('the_app/screen'), (call) async {
        if (call.method == 'brightness') calls.add('${call.arguments}');
        return null;
      });
      await start(tester);
      await card(tester, ean);
      await tester.tap(find.byKey(const Key('documentQuickBarcode-c')));
      await tester.pumpAndSettle();
      final slider = find.byKey(const Key('barcodeBrightness'));
      await tester.tapAt(tester.getTopRight(slider) - const Offset(30, -20));
      await tester.pumpAndSettle();
      final set = container.read(preferencesProvider).barcodeBrightness;
      expect(set, greaterThan(0.9));
      expect(double.parse(calls.last), closeTo(set, 0.001));
      await tester.pageBack();
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('documentQuickBarcode-c')));
      await tester.pumpAndSettle();
      expect(double.parse(calls.last), closeTo(set, 0.001));
    });

    testWidgets(
        'the toggle: drawn or its photo; one never read is read first '
        '(or says so)', (tester) async {
      await start(tester);
      await card(tester, ean);
      await tester.tap(find.byKey(const Key('documentQuickBarcode-c')));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('drawnCode-ean13')), findsNothing);
      await tester.tap(find.byKey(const Key('barcodeToggle')));
      await settleBusy(tester);
      expect(saved().scanned, const DocCode('4006381333931', 'ean13'));
      expect(find.byKey(const Key('drawnCode-ean13')), findsOneWidget);
      expect(find.byKey(const Key('drawnCodeText')), findsOneWidget);
      await tester.tap(find.byKey(const Key('barcodeToggle')));
      await tester.pump();
      // Its photo while it's read: white, as the page (not the theme's
      // background, which flashed black in the dark theme).
      for (final box in tester.widgetList<ColoredBox>(
          find.byKey(const Key('docThumbPlaceholder')))) {
        expect(box.color, ViewerColours.paper);
      }
      await tester.pumpAndSettle();
      expect(saved().showPhoto, isTrue);
      expect(find.byKey(const Key('drawnCode-ean13')), findsNothing);
    });

    testWidgets('a photo with no code: the toggle says so', (tester) async {
      await start(tester);
      await card(tester, testPng(shade: 180));
      await tester.tap(find.byKey(const Key('documentQuickBarcode-c')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('barcodeToggle')));
      await settleBusy(tester);
      expect(find.textContaining('No code found in it'), findsOneWidget);
      expect(saved().scanned, isNull);
    });

    testWidgets('QR code sits between Barcode and Ticket', (tester) async {
      await start(tester, items: [
        DocItem(
            id: 'p',
            kind: DocKind.document,
            name: 'Passport',
            createdAt: DateTime(2026, 11, 1)),
      ]);
      double x(DocKind k) =>
          tester.getTopLeft(find.byKey(Key('documentsFilter-${k.name}'))).dx;
      double y(DocKind k) =>
          tester.getTopLeft(find.byKey(Key('documentsFilter-${k.name}'))).dy;
      expect(DocKind.values.indexOf(DocKind.qr),
          DocKind.values.indexOf(DocKind.barcode) + 1);
      expect(DocKind.values.last, DocKind.ticket);
      expect(
          y(DocKind.qr) > y(DocKind.barcode) ||
              x(DocKind.qr) > x(DocKind.barcode),
          isTrue);
      await tester.tap(find.byTooltip('Add a document'));
      await tester.pumpAndSettle();
      final top = [
        for (final k in DocKind.values)
          tester.getTopLeft(find.byKey(Key('choice-${k.name}'))).dy,
      ];
      expect([...top]..sort(), top, reason: 'in that order');
    });
  });
}
