import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:the_app/data/reminder_scheduler.dart';
import 'package:the_app/models/date_entry.dart';
import 'package:the_app/models/hub_tool.dart';
import 'package:the_app/models/notification_target.dart';
import 'package:the_app/models/notify_settings.dart';
import 'package:the_app/providers/dates_provider.dart';
import 'package:the_app/providers/medicine_provider.dart';
import 'package:the_app/providers/preferences_provider.dart';
import 'package:the_app/providers/section_locks_provider.dart';
import 'package:the_app/providers/security_provider.dart';

import '../helpers.dart';

/// Birthdays & dates in the app (Round 57): their reminders, the
/// Notifications page, a reminder tapped, and the green dot.
void main() {
  late ProviderContainer container;
  late FakeReminderScheduler scheduler;
  // Thursday 15 October 2026, 13:20.
  var now = DateTime(2026, 10, 15, 13, 20);

  final ana = DateEntry(
    id: 'd1',
    title: 'Ana',
    type: DateType.birthday,
    day: 24,
    month: 10,
    year: 1995,
  );

  Future<void> start(WidgetTester tester, {List<DateEntry>? dates}) async {
    now = DateTime(2026, 10, 15, 13, 20);
    scheduler = FakeReminderScheduler();
    container = await pumpApp(tester, clock: () => now, reminders: scheduler);
    if (dates != null) {
      container.read(datesProvider.notifier).replaceAll(DateBook(dates));
    }
    await tester.pumpAndSettle();
  }

  List<String> dateReminders() => [
        for (final r in scheduler.scheduled)
          if (r.kind == ReminderKind.dates)
            '${r.at.day} ${r.at.hour}:${r.at.minute} ${r.title}: ${r.body}',
      ];

  testWidgets(
      'a date reminds as set, planned again as dates change; its page on '
      'the Notifications page turns them off', (tester) async {
    await start(tester, dates: [ana]);
    expect(dateReminders(), ['23 9:0 Ana: Birthday tomorrow · turns 31']);
    container.read(datesProvider.notifier).save(ana.copyWith(reminders: const [
          DateReminder(daysBefore: 0, minutes: 8 * 60),
        ]));
    await tester.pumpAndSettle();
    expect(dateReminders(), ['24 8:0 Ana: Birthday today · turns 31']);

    await openMenu(tester);
    await tester.tap(find.text('Notifications'));
    await tester.pumpAndSettle();
    final on = find.byKey(const Key('notifyOn-dates'));
    await reveal(tester, on);
    await tester.tap(on);
    await tester.pumpAndSettle();
    expect(container.read(preferencesProvider).datesReminders, isFalse);
    expect(dateReminders(), isEmpty);
  });

  testWidgets('private: no names; Round 82: locked, names still',
      (tester) async {
    await start(tester, dates: [ana]);
    final prefs = container.read(preferencesProvider.notifier);
    prefs.setNotifyStyle(
      NotifyPage.dates,
      container
          .read(preferencesProvider)
          .styleOf(NotifyPage.dates)
          .copyWith(private: true),
    );
    await tester.pumpAndSettle();
    expect(dateReminders(), ['23 9:0 Dates: A birthday tomorrow']);
    prefs.setNotifyStyle(
      NotifyPage.dates,
      container
          .read(preferencesProvider)
          .styleOf(NotifyPage.dates)
          .copyWith(private: false),
    );
    await tester.runAsync(() => container
        .read(securityProvider.notifier)
        .setPassword('master password'));
    container.read(pageLocksProvider.notifier).lock(HubTool.dates);
    await tester.pumpAndSettle();
    expect(dateReminders(), ['23 9:0 Ana: Birthday tomorrow · turns 31']);
  });

  testWidgets('a date\'s reminder tapped: the Dates page', (tester) async {
    await start(tester, dates: [ana]);
    scheduler.taps.add(const DatesTarget().payload);
    await tester.pumpAndSettle();
    expect(appBarTitle('Dates'), findsOneWidget);
  });

  testWidgets(
      'the green dot: a birthday today, on the tile and the Hub tab, gone '
      'once Dates is opened; a red dot comes first on the tab', (tester) async {
    await start(tester, dates: [ana.copyWith(day: 15)]);
    expect(find.byKey(const Key('hubNews')), findsOneWidget);
    await openTab(tester, 'Hub');
    expect(find.byKey(const Key('toolNews')), findsOneWidget);
    await tester.tap(find.byTooltip('Dates'));
    await tester.pumpAndSettle();
    await pressBack(tester);
    expect(find.byKey(const Key('toolNews')), findsNothing);
    expect(find.byKey(const Key('hubNews')), findsNothing);
    // The next day, another birthday: back.
    container.read(datesProvider.notifier).save(ana.copyWith(day: 16));
    now = DateTime(2026, 10, 16, 9);
    await tester.pump(const Duration(seconds: 30));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('toolNews')), findsOneWidget);
    // A dose due: red on the tab, not green.
    container.read(medicineProvider.notifier).add('Pills',
        times: [8 * 60], from: DateTime(2026, 10, 16), important: true);
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('hubDot')), findsOneWidget);
    expect(find.byKey(const Key('hubNews')), findsNothing);
    // Not a birthday (an anniversary): no dot.
    container.read(datesProvider.notifier)
      ..replaceAll(DateBook.empty)
      ..save(ana.copyWith(day: 16, type: DateType.anniversary));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('toolNews')), findsNothing);
  });
}
