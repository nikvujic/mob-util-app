import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:the_app/core/app_info.dart';
import 'package:the_app/data/app_storage.dart';
import 'package:the_app/data/backup.dart';
import 'package:the_app/data/backup_files.dart';
import 'package:the_app/models/hub_tool.dart';
import 'package:the_app/models/packing.dart';
import 'package:the_app/providers/backup_provider.dart';
import 'package:the_app/providers/packing_provider.dart';

import '../helpers.dart';

/// Round 94: packing lists, things under sections, a count,
/// ticks. Round 95: each list has its own sections (at least one; Other
/// is like any other), the defaults are what a new one starts with.
void main() {
  const documents = PackingSection(id: 'documents', name: 'Documents');
  const clothes = PackingSection(id: 'clothes', name: 'Clothes');
  const gear = PackingSection(id: 'gear', name: 'Ski gear');
  const sections = [documents, clothes, gear];

  PackingItem item(String id, String section,
          {int count = 1, bool packed = false}) =>
      PackingItem(
          id: id, name: id, sectionId: section, count: count, packed: packed);

  final trip =
      PackingList(id: 'l1', name: 'Ski trip', sections: sections, items: [
    item('passport', 'documents', packed: true),
    item('socks', 'clothes', count: 5),
    item('goggles', 'gear'),
    item('id', 'documents'),
    item('umbrella', 'gone'),
  ]);

  List<String> shown(PackingList list) => [
        for (final (s, items) in list.grouped())
          '${s.id}: ${items.map((i) => i.id).join(' ')}',
      ];

  group('PackingBook', () {
    test('the usual default sections at first, Other a normal one', () {
      expect(PackingBook.initial.sections.map((s) => s.name), [
        'Documents',
        'Clothes',
        'Toiletries',
        'Electronics',
        'Medicine',
        'Other',
      ]);
      expect(PackingBook.initial.lists, isEmpty);
      expect(PackingBook(sections: const []).sections, PackingBook.defaults,
          reason: 'never none');
    });

    test('written as read; sections missing: the usual ones', () {
      final book = PackingBook(sections: sections, lists: [trip]);
      final again = PackingBook.fromJson(book.toJson());
      expect(again.sections, book.sections);
      expect(again.byId('l1')!.sameAs(trip), isTrue);
      expect(item('a', 'clothes').toJson(),
          {'id': 'a', 'name': 'a', 'section': 'clothes'},
          reason: 'a count of 1, not packed: not written');
      expect(PackingBook.fromJson(const {}).sections, PackingBook.defaults);
      expect(PackingItem.fromJson(const {'id': 'x', 'count': 500}).count, 99);
    });

    test("Round 94's lists (no sections of their own) get the shared ones", () {
      final book = PackingBook.fromJson({
        'sections': [for (final s in sections) s.toJson()],
        'lists': [
          {
            'id': 'old',
            'name': 'Old',
            'items': [item('socks', 'clothes').toJson()],
          },
        ],
      });
      expect(book.byId('old')!.sections, sections);
    });
  });

  group('PackingList', () {
    test('every section shown, empty ones too; lost things in the last', () {
      expect(shown(trip), [
        'documents: passport id',
        'clothes: socks',
        'gear: goggles umbrella',
      ]);
      final empty = trip.copyWith(items: [trip.items.first]);
      expect(shown(empty), ['documents: passport', 'clothes: ', 'gear: '],
          reason: 'set up in edit mode, shown in view mode');
    });

    test('ticked, unticked in place; Reset unticks all', () {
      final ticked = trip.toggled('socks');
      expect(ticked.items.map((i) => i.id), trip.items.map((i) => i.id),
          reason: "they don't move");
      expect(ticked.packedCount, 2);
      expect(ticked.toggled('socks').packedCount, 1);
      expect(ticked.reset().packedCount, 0);
    });

    test('no two of a name in a section, nor two sections of a name', () {
      expect(trip.named(' SOCKS ', 'clothes')?.id, 'socks');
      expect(trip.named('socks', 'gear'), isNull);
      expect(trip.named('socks', 'clothes', except: 'socks'), isNull);
      expect(trip.sectionNamed('ski GEAR')?.id, 'gear');
      expect(trip.sectionNamed('ski gear', except: 'gear'), isNull);
    });

    test('a thing dragged in edit mode takes the section it lands in', () {
      // Rows: [Documents] passport id [Clothes] socks [Ski gear] goggles
      //       umbrella
      expect(shown(trip.moved(1, 5)), [
        'documents: id',
        'clothes: socks passport',
        'gear: goggles umbrella',
      ]);
      // Above every heading: into the first.
      expect(
          trip.moved(6, 0).items.firstWhere((i) => i.id == 'goggles').sectionId,
          'documents');
      // A heading doesn't move this way.
      expect(trip.moved(0, 3).sameAs(trip), isTrue);
    });

    test('a section moved to another place, its things with it', () {
      final moved = trip.sectionMovedTo('gear', 0);
      expect(moved.sections.map((s) => s.id), ['gear', 'documents', 'clothes']);
      expect(shown(moved).first, 'gear: goggles');
      expect(trip.sectionMovedTo('documents', 2).sections.map((s) => s.id),
          ['clothes', 'gear', 'documents']);
      expect(shown(trip.sectionMovedTo('documents', 2)).last,
          'documents: passport id umbrella',
          reason: 'a lost thing stays under the last');
      expect(trip.sectionMovedTo('gear', 3).sameAs(trip), isTrue);
      expect(trip.sectionMovedTo('gear', -1).sameAs(trip), isTrue);
    });

    test('a section deleted with its things; the last one stays', () {
      final noClothes = trip.withoutSection('clothes');
      expect(shown(noClothes), [
        'documents: passport id',
        'gear: goggles umbrella',
      ]);
      // The last one's lost things go with it too.
      expect(trip.withoutSection('gear').items.map((i) => i.id),
          ['passport', 'socks', 'id']);
      final one = trip.copyWith(sections: [documents]);
      expect(one.withoutSection('documents').sections, [documents]);
    });

    test('changed or not, for Save or Discard: its sections count', () {
      expect(trip.sameAs(trip.copyWith()), isTrue);
      expect(
          trip.sameAs(trip.copyWith(sections: [documents, clothes])), isFalse);
      expect(trip.sameAs(trip.copyWith(name: 'Other')), isFalse);
      expect(trip.sameAs(trip.toggled('id')), isFalse);
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

    test('a new list: the default sections, kept on top once saved', () {
      final draft = notifier.draft();
      expect(draft.sections, sections);
      expect(book().lists, hasLength(1), reason: 'not kept yet');
      notifier.save(draft.copyWith(name: 'Beach'));
      expect(book().lists.map((l) => l.name), ['Beach', 'Ski trip']);
    });

    test(
        'copy: a new name, only the sections picked and their things, '
        'nothing ticked', () {
      final id = notifier.copy('l1', 'Ski trip 2027', {'documents', 'gear'})!;
      expect(book().lists.map((l) => l.name), ['Ski trip', 'Ski trip 2027']);
      final copy = book().byId(id)!;
      expect(copy.sections, [documents, gear]);
      expect(copy.items.map((i) => i.name),
          ['passport', 'id', 'goggles', 'umbrella']);
      expect(copy.packedCount, 0);
      expect(copy.items.map((i) => i.id), isNot(contains('passport')),
          reason: 'its own things');
      expect(copy.items.last.sectionId, 'gear', reason: 'lost one placed');
      expect(book().byId('l1')!.packedCount, 1, reason: 'the original stays');
      final bare = notifier.copy('l1', 'Bare', <String>{})!;
      expect(book().byId(bare)!.sections, [documents],
          reason: 'a list has at least one section');
    });

    test('reset', () {
      notifier.reset('l1');
      expect(book().byId('l1')!.packedCount, 0);
    });

    test(
        'default sections: added, reordered, deleted (Undo; one stays); '
        'the lists keep theirs', () {
      notifier.addSection('Beach');
      expect(book().sections.map((s) => s.name),
          ['Documents', 'Clothes', 'Ski gear', 'Beach']);
      notifier.reorderSections(3, 0);
      expect(book().sections.first.name, 'Beach');
      final before = notifier.removeSection('documents')!;
      expect(book().sections.map((s) => s.id), isNot(contains('documents')));
      expect(book().byId('l1')!.sections, sections, reason: 'untouched');
      notifier.restoreSections(before);
      expect(book().sections.map((s) => s.id), contains('documents'));
      for (final s in [...book().sections].skip(1)) {
        notifier.removeSection(s.id);
      }
      expect(book().sections, hasLength(1));
      expect(notifier.removeSection(book().sections.single.id), isNull);
    });

    test('removed and put back where it was', () {
      notifier.save(notifier.draft().copyWith(name: 'New'));
      final removed = notifier.remove({'l1'});
      expect(book().lists.map((l) => l.name), ['New']);
      notifier.undoRemove(removed);
      expect(book().lists.map((l) => l.name), ['New', 'Ski trip']);
    });
  });

  test('a page of its own: locked and cleared like the others', () {
    expect(HubTool.packing.label, 'Packing');
    expect(HubTool.packing.lockable, isTrue);
    expect(HubTool.packing.clearable, isTrue);
  });

  test('in backups (version 31), the usual sections when missing', () {
    expect(Backup.version, greaterThanOrEqualTo(31));
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
    expect(
        Backup.decode(jsonEncode(json)).packing.sections, PackingBook.defaults);
  });

  group('a backup restored', () {
    late ProviderContainer container;
    PackingBook book() => container.read(packingProvider);

    setUp(() {
      container = ProviderContainer(overrides: [
        appStorageProvider.overrideWithValue(AppStorage.inMemory(
          initialPacking: PackingBook(
            sections: PackingBook.defaults,
            lists: [
              PackingList(
                  id: 'l1', name: 'Here', sections: PackingBook.defaults),
            ],
          ),
        )),
        appVersionProvider.overrideWithValue('1.40.1 (97)'),
        backupFilesProvider.overrideWithValue(FakeBackupFiles()),
      ]);
      addTearDown(container.dispose);
    });

    PlainPick read() => container.read(backupImporterProvider).read(
          Uint8List.fromList(utf8.encode(Backup(
            createdAt: DateTime(2026, 10, 21),
            appVersion: '1.40.1 (97)',
            notes: const [],
            shopItems: const [],
            packing: PackingBook(
              sections: sections,
              lists: [
                trip,
                PackingList(id: 'l2', name: 'Beach', sections: sections),
              ],
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

    test('in part: the lists picked with their sections, a copy of one here',
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
      expect(book().lists.last.sections, sections);
      expect(book().sections, PackingBook.defaults,
          reason: 'the defaults here stay');
    });
  });
}
