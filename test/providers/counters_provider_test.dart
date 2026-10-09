import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:the_app/data/app_storage.dart';
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
}
