import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:the_app/data/app_storage.dart';
import 'package:the_app/models/counter.dart';
import 'package:the_app/providers/counters_provider.dart';

void main() {
  late CountersNotifier counters;

  setUp(() => counters = CountersNotifier(AppStorage.inMemory()));

  String idOf(String name) =>
      counters.state.firstWhere((c) => c.name == name).id;
  Map<String, int> values() =>
      {for (final c in counters.state) c.name: c.value};

  test('adds trimmed counters at 0, at the end; ignores blanks', () {
    counters
      ..add('Push-ups')
      ..add('  Coffee ')
      ..add('  ');
    expect(values(), {'Push-ups': 0, 'Coffee': 0});
    expect(counters.state.map((c) => c.name), ['Push-ups', 'Coffee']);
  });

  test('counts up and down, also below zero', () {
    counters.add('Score');
    final id = idOf('Score');
    counters
      ..step(id, 1)
      ..step(id, 1)
      ..step(id, -1);
    expect(values()['Score'], 1);
    counters
      ..step(id, -1)
      ..step(id, -1);
    expect(values()['Score'], -1);
  });

  test('rename keeps the value; blank names are ignored', () {
    counters.add('Cofee');
    counters.step(idOf('Cofee'), 3);
    counters.rename(idOf('Cofee'), ' Coffee ');
    counters.rename(idOf('Coffee'), '   ');
    expect(values(), {'Coffee': 3});
  });

  test('reset and remove act on the given counters only', () {
    counters
      ..add('A')
      ..add('B')
      ..add('C');
    for (final name in ['A', 'B', 'C']) {
      counters.step(idOf(name), 5);
    }
    counters.reset({idOf('A'), idOf('B')});
    expect(values(), {'A': 0, 'B': 0, 'C': 5});

    counters.remove({idOf('B')});
    expect(values(), {'A': 0, 'C': 5});
  });

  test('reorder follows ReorderableListView index semantics', () {
    counters
      ..add('A')
      ..add('B')
      ..add('C');
    counters.reorder(0, 3);
    expect(counters.state.map((c) => c.name), ['B', 'C', 'A']);
  });

  test('counters are saved and survive a restart', () async {
    final dir = Directory.systemTemp.createTempSync('counters');
    addTearDown(() => dir.deleteSync(recursive: true));
    final storage = await AppStorage.open(directory: dir);
    counters = CountersNotifier(storage)
      ..add('Push-ups')
      ..add('Coffee');
    counters.step(idOf('Push-ups'), 20);
    await storage.flush();

    final reopened = (await AppStorage.open(directory: dir)).initialCounters;
    expect(
      reopened.map((c) => c.toJson()),
      counters.state.map((c) => c.toJson()),
    );
  });

  group('options (O5)', () {
    Counter counter(String name) =>
        counters.state.firstWhere((c) => c.name == name);
    CounterOptions options(
      String name, {
      int step = 1,
      String? color,
      int? min,
      int? max,
    }) =>
        (name: name, step: step, color: color, min: min, max: max);

    test('a step: each tap counts that much', () {
      counters.add('Water', options: options('Water', step: 250));
      counters
        ..step(idOf('Water'), 1)
        ..step(idOf('Water'), 1);
      expect(values()['Water'], 500);
      counters.step(idOf('Water'), -1);
      expect(values()['Water'], 250);
    });

    test('limits: never past min or max', () {
      counters.add('Pages',
          options: options('Pages', step: 3, min: 0, max: 10));
      final id = idOf('Pages');
      for (var i = 0; i < 5; i++) {
        counters.step(id, 1);
      }
      expect(values()['Pages'], 10, reason: 'stops at max, not 12 or 15');
      expect(counter('Pages').canGoUp, isFalse);
      for (var i = 0; i < 5; i++) {
        counters.step(id, -1);
      }
      expect(values()['Pages'], 0);
      expect(counter('Pages').canGoDown, isFalse);
    });

    test('starts, and resets, at 0 or the nearest limit', () {
      counters.add('Floor', options: options('Floor', min: 3, max: 9));
      expect(values()['Floor'], 3);
      counters
        ..step(idOf('Floor'), 1)
        ..reset({idOf('Floor')});
      expect(values()['Floor'], 3);
      counters.add('Debt', options: options('Debt', max: -5));
      expect(values()['Debt'], -5);
    });

    test('editing keeps the value, moved within new limits', () {
      counters.add('Push-ups');
      counters.step(idOf('Push-ups'), 20);
      counters.edit(
        idOf('Push-ups'),
        options('Push-ups', step: 5, color: 'teal', max: 12),
      );
      final c = counter('Push-ups');
      expect((c.value, c.step, c.color, c.max), (12, 5, 'teal', 12));
    });

    test('nonsense is made sensible: step ≥ 1, min ≤ max', () {
      counters.add('X', options: options('X', step: 0, min: 10, max: 2));
      final c = counter('X');
      expect((c.step, c.min, c.max), (1, 2, 10));
    });

    test('saved only where it differs from the defaults', () {
      const plain = Counter(id: 'a', name: 'A', value: 3);
      expect(plain.toJson().keys, ['id', 'name', 'value']);
      const full = Counter(
        id: 'b',
        name: 'B',
        value: 4,
        step: 5,
        color: 'pink',
        min: -10,
        max: 100,
      );
      final back = Counter.fromJson(full.toJson());
      expect(
          (back.step, back.color, back.min, back.max), (5, 'pink', -10, 100));
    });
  });
}
