import 'package:flutter_test/flutter_test.dart';
import 'package:the_app/data/reminder_scheduler.dart';
import 'package:the_app/models/document_item.dart';
import 'package:the_app/models/preferences.dart';
import 'package:the_app/providers/document_alerts_provider.dart';

/// The documents' reminders (spec: reminders): before an expiry or a
/// warranty's end as each is set, a ticket on its day, at 09:00; none
/// while off or paused; no names when private or locked.
void main() {
  final now = DateTime(2026, 11, 23, 12);
  DocItem item(String id, DocKind kind,
          {String name = '',
          DateTime? expires,
          DateTime? date,
          DateTime? warrantyTo,
          bool warranty = false,
          DocRemind remind = DocRemind.none}) =>
      DocItem(
        id: id,
        kind: kind,
        name: name,
        expires: expires,
        date: date,
        warranty: warranty,
        warrantyTo: warrantyTo,
        remind: remind,
        createdAt: now,
      );

  final book = DocumentBook([
    item('p', DocKind.document,
        name: 'Passport',
        expires: DateTime(2026, 12, 3),
        remind: DocRemind.week),
    item('w', DocKind.receipt,
        name: 'Washer',
        warranty: true,
        warrantyTo: DateTime(2026, 12, 24),
        remind: DocRemind.month),
    item('t', DocKind.ticket,
        name: 'Concert',
        date: DateTime(2026, 11, 28),
        remind: DocRemind.onTheDay),
    // Off, ended, or nothing to remind of.
    item('n', DocKind.document, name: 'ID', expires: DateTime(2026, 12, 1)),
    item('x', DocKind.receipt,
        name: 'Old',
        warranty: false,
        warrantyTo: DateTime(2026, 12, 24),
        remind: DocRemind.month),
    item('g', DocKind.ticket,
        name: 'Gone', date: DateTime(2026, 11, 20), remind: DocRemind.onTheDay),
    item('c', DocKind.barcode, name: 'Card', remind: DocRemind.week),
  ]);

  List<String> plan({
    Preferences preferences = const Preferences(),
    bool hideNames = false,
    DateTime? at,
  }) =>
      [
        for (final r in planDocumentReminders(
          now: at ?? now,
          book: book,
          preferences: preferences,
          days: 14,
          hideNames: hideNames,
        ))
          '${r.at.month}/${r.at.day} ${r.at.hour}h ${r.title}: ${r.body}',
      ];

  test('before each date as set, a ticket on its day, at 09:00', () {
    expect(plan(), [
      '11/24 9h Washer: Its warranty ends in 30 days · 24 Dec 2026',
      '11/26 9h Passport: Expires in 7 days · 3 Dec 2026',
      '11/28 9h Concert: Your ticket is for today',
    ]);
    final r = planDocumentReminders(
        now: now, book: book, preferences: const Preferences(), days: 14);
    expect(r.every((x) => x.kind == ReminderKind.documents), isTrue);
    expect(r.first.target, 'documents');
  });

  test('private (or the page locked): no names', () {
    expect(plan(hideNames: true), [
      '11/24 9h Documents: A warranty ends in 30 days',
      '11/26 9h Documents: A document expires in 7 days',
      '11/28 9h Documents: A ticket today',
    ]);
  });

  test('off: none; paused: none through that day', () {
    expect(plan(preferences: const Preferences(documentsReminders: false)),
        isEmpty);
    expect(
        plan(
            preferences:
                Preferences(documentsPausedUntil: DateTime(2026, 11, 26))),
        ['11/28 9h Concert: Your ticket is for today']);
  });

  test('only ahead, and within the days planned', () {
    expect(plan(at: DateTime(2026, 11, 24, 9, 30)), [
      '11/26 9h Passport: Expires in 7 days · 3 Dec 2026',
      '11/28 9h Concert: Your ticket is for today',
    ]);
    expect(plan(at: DateTime(2026, 11, 1)), isEmpty);
  });
}
