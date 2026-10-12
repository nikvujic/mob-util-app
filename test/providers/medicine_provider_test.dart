import 'package:flutter_test/flutter_test.dart';
import 'package:the_app/data/app_storage.dart';
import 'package:the_app/models/medicine.dart';
import 'package:the_app/providers/medicine_provider.dart';

/// The medicine tracker's data (O6).
void main() {
  late MedicineNotifier medicine;
  late DateTime now;
  final today = DateTime(2026, 10, 12);

  setUp(() {
    now = DateTime(2026, 10, 12, 8, 3);
    medicine = MedicineNotifier(AppStorage.inMemory(), () => now);
  });

  Medicine only() => medicine.state.medicines.single;

  test('adds one with its times in order; blank names ignored', () {
    expect(medicine.add('  ', times: [480], from: today), isNull);
    medicine.add(' Vitamin D ', times: [1200, 480], from: today);
    expect((only().name, only().dosesADay), ('Vitamin D', 2));
    expect(only().times, [480, 1200]);
  });

  test('on its days only: from, until, or for good', () {
    medicine.add('Course',
        times: [480], from: today, until: DateTime(2026, 10, 14));
    expect(only().isOn(DateTime(2026, 10, 11)), isFalse);
    expect(only().isOn(today), isTrue);
    expect(only().isOn(DateTime(2026, 10, 14, 23)), isTrue);
    expect(only().isOn(DateTime(2026, 10, 15)), isFalse);
    medicine.add('Daily', times: [480], from: today);
    expect(medicine.state.medicines.last.isOn(DateTime(2030, 1, 1)), isTrue);
  });

  test('a dose is marked with the time it was tapped, and unmarked', () {
    final id = medicine.add('Pills', times: [480, 1200], from: today)!;
    medicine.toggleDose(id, today, 0);
    final mark = medicine.state.takenFor(id, today, 0)!;
    expect(mark.at, DateTime(2026, 10, 12, 8, 3));
    expect(medicine.state.takenFor(id, today, 1), isNull, reason: 'its own');
    expect(medicine.state.takenFor(id, DateTime(2026, 10, 13), 0), isNull,
        reason: 'per day');

    medicine.toggleDose(id, today, 0);
    expect(medicine.state.takenFor(id, today, 0), isNull);
  });

  test('editing keeps the history', () {
    final id = medicine.add('Pills', times: [480], from: today)!;
    medicine
      ..toggleDose(id, today, 0)
      ..update(id, name: 'Pills 💊', times: [540, 1260], from: today);
    expect(only().name, 'Pills 💊');
    expect(only().times, [540, 1260]);
    expect(medicine.state.takenFor(id, today, 0), isNotNull);
  });

  test('deleting takes its history too; undo brings both back', () {
    final id = medicine.add('Pills', times: [480], from: today)!;
    medicine.add('Other', times: [600], from: today);
    medicine.toggleDose(id, today, 0);
    final before = medicine.remove(id);
    expect(medicine.state.medicines.map((m) => m.name), ['Other']);
    expect(medicine.state.taken, isEmpty);
    medicine.replaceAll(before);
    expect(medicine.state.takenFor(id, today, 0), isNotNull);
  });

  test('round trip through JSON', () {
    final id = medicine.add('Pills',
        times: [480, 1200], from: today, until: DateTime(2026, 12, 31))!;
    medicine.toggleDose(id, today, 1);
    final back = MedicineBook.fromJson(medicine.state.toJson());
    final m = back.medicines.single;
    expect((m.name, m.from, m.until), ('Pills', today, DateTime(2026, 12, 31)));
    expect(m.times, [480, 1200]);
    expect(back.takenFor(id, today, 1)!.at, now);
  });
}
