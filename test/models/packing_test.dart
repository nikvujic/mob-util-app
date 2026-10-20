import 'dart:convert';

import 'dart:typed_data';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:the_app/data/app_storage.dart';
import 'package:the_app/core/app_info.dart';
import 'package:the_app/data/backup.dart';
import 'package:the_app/data/backup_files.dart';
import 'package:the_app/models/hub_tool.dart';
import 'package:the_app/models/packing.dart';
import 'package:the_app/providers/backup_provider.dart';
import 'package:the_app/providers/packing_provider.dart';

import '../helpers.dart';

/// Round 94 (Nikola): packing lists, items under sections every list
/// shares (Other always last), a count, ticks.
void main() {
  const documents = PackingSection(id: 'documents', name: 'Documents');
  const clothes = PackingSection(id: 'clothes', name: 'Clothes');
  const gear = PackingSection(id: 'gear', name: 'Ski gear');
  final sections = [documents, clothes, gear, PackingSection.other];

  PackingItem item(String id, String section,
          {int count = 1, bool packed = false}) =>
      PackingItem(
          id: id, name: id, sectionId: section, count: count, packed: packed);

  final trip = PackingList(id: 'l1', name: 'Ski trip', items: [
    item('passport', 'documents', packed: true),
    item('socks', 'clothes', count: 5),
    item('goggles', 'gear'),
    item('id', 'documents'),
    item('umbrella', 'gone'),
  ]);

  group('PackingBook', () {
    test('the usual sections at first, Other last; no lists', () {
      expect(PackingBook.initial.sections.map((s) => s.name), [
        'Documents',
        'Clothes',
        'Toiletries',
        'Electronics',
        'Medicine',
        'Other',
      ]);
      expect(PackingBook.initial.lists, isEmpty);
    });

    test('Other always there and last, wherever it was', () {
      expect(
        PackingBook(sections: [PackingSection.other, documents])
            .sections
            .map((s) => s.id),
        ['documents', 'other'],
      );
      expect(PackingBook(sections: [documents]).sections.last.isOther, isTrue);
    });

    test('a section deleted: its items, in every list, go to Other', () {
      final book = PackingBook(sections: sections, lists: [trip]);
      final after = book.withoutSection('gear');
      expect(
          after.sections.map((s) => s.id), ['documents', 'clothes', 'other']);
      expect(
          after
              .byId('l1')!
              .items
              .firstWhere((i) => i.id == 'goggles')
              .sectionId,
          'other');
      expect(book.withoutSection('other').sections, book.sections,
          reason: 'Other stays');
      expect(book.itemsIn('documents'), 2);
    });

    test('written as read; sections missing: the usual ones', () {
      final book = PackingBook(sections: sections, lists: [trip]);
      final again = PackingBook.fromJson(book.toJson());
      expect(again.sections, book.sections);
      expect(again.byId('l1')!.sameAs(trip), isTrue);
      expect(item('a', 'clothes').toJson(),
          {'id': 'a', 'name': 'a', 'section': 'clothes'},
          reason: 'a count of 1, not packed: not written');
      expect(PackingBook.fromJson(const {}).sections,
          PackingBook.initial.sections);
      expect(PackingItem.fromJson(const {'id': 'x', 'count': 500}).count, 99);
    });
  });

  group('PackingList', () {
    test('shown by section, in the sections\' order; lost ones in Other', () {
      expect(
        [
          for (final (s, items) in trip.grouped(sections))
            '${s.id}: ${items.map((i) => i.id).join(' ')}',
        ],
        [
          'documents: passport id',
          'clothes: socks',
          'gear: goggles',
          'other: umbrella',
        ],
      );
      final noGear = trip.copyWith(items: [trip.items.first]);
      expect(noGear.grouped(sections).map((g) => g.$1.id), ['documents'],
          reason: 'empty sections left out');
      expect(noGear.grouped(sections, keepEmpty: true).map((g) => g.$1.id),
          ['documents', 'clothes', 'gear', 'other']);
    });

    test('ticked, unticked in place; Reset unticks all', () {
      final ticked = trip.toggled('socks');
      expect(ticked.items.map((i) => i.id), trip.items.map((i) => i.id),
          reason: "they don't move");
      expect(ticked.packedCount, 2);
      expect(ticked.toggled('socks').packedCount, 1);
      expect(ticked.reset().packedCount, 0);
    });

    test('no two of a name in a section (any case)', () {
      expect(trip.named(' SOCKS ', 'clothes')?.id, 'socks');
      expect(trip.named('socks', 'gear'), isNull);
      expect(trip.named('socks', 'clothes', except: 'socks'), isNull);
    });

    test('an item dragged in edit mode takes the section it lands in', () {
      // Rows: [Documents] passport id [Clothes] socks [Ski gear] goggles
      //       [Other] umbrella
      final moved = trip.moved(sections, 1, 5); // passport under Clothes
      expect(
        [
          for (final (s, items) in moved.grouped(sections, keepEmpty: true))
            '${s.id}: ${items.map((i) => i.id).join(' ')}',
        ],
        [
          'documents: id',
          'clothes: socks passport',
          'gear: goggles',
          'other: umbrella',
        ],
      );
      // Above every heading: into the first.
      final top = trip.moved(sections, 6, 0);
      expect(top.items.firstWhere((i) => i.id == 'goggles').sectionId,
          'documents');
      // A heading doesn't move.
      expect(trip.moved(sections, 0, 3).sameAs(trip), isTrue);
    });
  });

  group('PackingNotifier', () {
    late ProviderContainer container;
    late PackingNotifier notifier;
    PackingBook book() => container.read(packingProvider);

    setUp(() {
      container = ProviderContainer(overrides: [
        appStorageProvider.overrideWithValue(AppStorage.inMemory(
          initialPacking: PackingBook(sections: sections, lists: [trip]),
        )),
      ]);
      notifier = container.read(packingProvider.notifier);
    });
    tearDown(() => container.dispose());

    test('copy: a new name, only the sections picked, nothing ticked', () {
      final id = notifier.copy('l1', 'Ski trip 2027', {'documents', 'other'})!;
      expect(book().lists.map((l) => l.name), ['Ski trip', 'Ski trip 2027']);
      final copy = book().byId(id)!;
      expect(copy.items.map((i) => i.name), ['passport', 'id', 'umbrella']);
      expect(copy.packedCount, 0);
      expect(copy.items.map((i) => i.id), isNot(contains('passport')),
          reason: 'its own items');
      expect(copy.items.last.sectionId, 'other');
      expect(book().byId('l1')!.packedCount, 1, reason: 'the original stays');
    });

    test('reset, with what it was for Undo', () {
      final before = notifier.reset('l1')!;
      expect(book().byId('l1')!.packedCount, 0);
      notifier.save(before);
      expect(book().byId('l1')!.packedCount, 1);
    });

    test('sections: added before Other, reordered with Other kept last', () {
      notifier.addSection('Beach');
      expect(book().sections.map((s) => s.name),
          ['Documents', 'Clothes', 'Ski gear', 'Beach', 'Other']);
      notifier.reorderSections(3, 0);
      expect(book().sections.map((s) => s.name).first, 'Beach');
      notifier.reorderSections(0, 10);
      expect(book().sections.map((s) => s.name),
          ['Documents', 'Clothes', 'Ski gear', 'Beach', 'Other']);
      final before = notifier.removeSection('documents');
      expect(book().byId('l1')!.items.first.sectionId, 'other');
      notifier.replaceAll(before);
      expect(book().sections.first.id, 'documents');
    });

    test('a new list on top; removed and put back where it was', () {
      final id = notifier.add();
      expect(book().lists.first.id, id);
      final removed = notifier.remove({'l1'});
      expect(book().lists.map((l) => l.id), [id]);
      notifier.undoRemove(removed);
      expect(book().lists.map((l) => l.id), [id, 'l1']);
    });
  });

  test('a page of its own: locked and cleared like the others', () {
    expect(HubTool.packing.label, 'Packing');
    expect(HubTool.packing.lockable, isTrue);
    expect(HubTool.packing.clearable, isTrue);
  });

  test('a part restored: its sections come too, by name if there', () {
    final now = PackingBook(sections: [
      const PackingSection(id: 'mine', name: 'Ski Gear'),
      documents,
    ]);
    final restored = withPackingLists(
      now,
      PackingBook(sections: sections, lists: [trip]),
      [trip],
    );
    expect(restored.sections.map((s) => s.id),
        ['mine', 'documents', 'clothes', 'other'],
        reason: 'Ski gear is "Ski Gear" here; Clothes is added');
    final items = restored.byId('l1')!.items;
    expect(items.firstWhere((i) => i.id == 'goggles').sectionId, 'mine');
    expect(items.firstWhere((i) => i.id == 'umbrella').sectionId, 'gone',
        reason: 'shown under Other');
  });

  test('in backups (version 30), the usual sections when missing', () {
    expect(Backup.version, 30);
    final backup = Backup(
      createdAt: DateTime.utc(2026, 10, 21),
      appVersion: 'test',
      notes: const [],
      shopItems: const [],
      packing: PackingBook(sections: sections, lists: [trip]),
    );
    final again = Backup.decode(backup.encode());
    expect(again.packing.byId('l1')!.sameAs(trip), isTrue);
    expect(again.packing.sections, sections);
    final json = backup.toJson();
    (json['data'] as Map<String, dynamic>).remove('packing');
    expect(Backup.decode(jsonEncode(json)).packing.sections,
        PackingBook.initial.sections);
  });

  group('a backup restored', () {
    late ProviderContainer container;
    PackingBook book() => container.read(packingProvider);

    setUp(() {
      container = ProviderContainer(overrides: [
        appStorageProvider.overrideWithValue(AppStorage.inMemory(
          initialPacking: PackingBook(
            sections: PackingBook.initial.sections,
            lists: [PackingList(id: 'l1', name: 'Here')],
          ),
        )),
        appVersionProvider.overrideWithValue('1.40.0 (96)'),
        backupFilesProvider.overrideWithValue(FakeBackupFiles()),
      ]);
      addTearDown(container.dispose);
    });

    PlainPick read() => container.read(backupImporterProvider).read(
          Uint8List.fromList(utf8.encode(Backup(
            createdAt: DateTime(2026, 10, 21),
            appVersion: '1.40.0 (96)',
            notes: const [],
            shopItems: const [],
            packing: PackingBook(
              sections: sections,
              lists: [trip, PackingList(id: 'l2', name: 'Beach')],
            ),
          ).encode())),
        ) as PlainPick;

    test('whole, and Undo', () async {
      final importer = container.read(backupImporterProvider);
      final undo = await importer.restore(read().backup);
      expect(book().lists.map((l) => l.name), ['Ski trip', 'Beach']);
      expect(book().sections, sections);
      await importer.undo(undo!);
      expect(book().lists.single.name, 'Here');
    });

    test('in part: the lists picked, a copy of one here, its sections',
        () async {
      final pick = read();
      expect(
          pick.backup.packingLists.map((l) => l.name), ['Ski trip', 'Beach']);
      final done = await container
          .read(backupImporterProvider)
          .restorePart(pick.backup, {
        BackupPart.packing: {'l1'},
      });
      expect((done!.added, done.copies), (1, 1));
      expect(book().lists.map((l) => l.name), ['Here', 'Ski trip (Copy)']);
      expect(book().section('gear')?.name, 'Ski gear',
          reason: 'its things need it');
      expect(book().sections.last.isOther, isTrue);
    });
  });
}
