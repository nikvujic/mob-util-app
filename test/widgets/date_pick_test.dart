import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:the_app/core/theme.dart';
import 'package:the_app/models/subscription.dart';
import 'package:the_app/widgets/date_pick.dart';
import 'package:the_app/widgets/month_picker.dart';

import '../helpers.dart';

/// Round 87 (Nikola): every calendar opens on today's month, never where
/// an earlier one (or the thing's own day) was.
void main() {
  final today = DateTime(2026, 10, 20, 12);

  Future<Future<DateTime?>> open(
    WidgetTester tester, {
    DateTime? value,
    DateTime? first,
    DateTime? last,
    SelectableDayPredicate? selectable,
  }) async {
    late Future<DateTime?> picked;
    await tester.pumpWidget(MaterialApp(
      theme: AppTheme.dark,
      home: Builder(
        builder: (context) => Scaffold(
          body: TextButton(
            onPressed: () => picked = pickDate(context,
                today: today,
                value: value,
                first: first ?? DateTime(2020),
                last: last ?? DateTime(2030),
                selectable: selectable),
            child: const Text('go'),
          ),
        ),
      ),
    ));
    await tester.tap(find.text('go'));
    await tester.pumpAndSettle();
    return picked;
  }

  /// The month shown, and the day picked in it (null: none).
  (String, String?) shown(WidgetTester tester) {
    final month = find.textContaining(RegExp(r'^\w+ 20\d\d$'));
    final picker = find.byType(CalendarDatePicker);
    return (
      tester.widget<Text>(month.first).data!,
      tester.widget<CalendarDatePicker>(picker).initialDate?.day.toString(),
    );
  }

  testWidgets('a day set in another month: opens on today\'s, none picked',
      (tester) async {
    await open(tester, value: DateTime(2027, 3, 31));
    expect(shown(tester), ('October 2026', null));
  });

  testWidgets('nothing set: today\'s month', (tester) async {
    await open(tester);
    expect(shown(tester), ('October 2026', null));
  });

  testWidgets('a day set this month: picked there', (tester) async {
    final picked = await open(tester, value: DateTime(2026, 10, 3));
    expect(shown(tester), ('October 2026', '3'));
    await tester.tap(find.text('OK'));
    await tester.pumpAndSettle();
    expect(await picked, DateTime(2026, 10, 3));
  });

  testWidgets('today out of reach: the nearest month allowed', (tester) async {
    await open(tester, first: DateTime(2026, 12, 5));
    expect(shown(tester), ('December 2026', '5'));
  });

  testWidgets(
      'in the app: a subscription renewing next month opens on this month; '
      'its card expiry on this year, though set for another', (tester) async {
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 2.625;
    addTearDown(tester.view.reset);
    await pumpApp(tester,
        clock: () => today,
        subscriptions: SubscriptionBook([
          Subscription(
              id: 'c',
              name: 'Claude',
              price: 20,
              date: DateTime(2026, 11, 3),
              cardExpires: DateTime(2028, 2)),
        ]));
    await openTab(tester, 'Hub');
    await tester.tap(find.byTooltip('Subscriptions'));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('c')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('subscriptionDate')));
    await tester.pumpAndSettle();
    expect(shown(tester), ('October 2026', null));
    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();

    final expires = find.byKey(const Key('subscriptionCardExpires'));
    await tester.scrollUntilVisible(expires, 200,
        scrollable: find.byType(Scrollable).last);
    await tester.tap(expires);
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('monthPickerYear')), findsOneWidget);
    expect(tester.widget<Text>(find.byKey(const Key('monthPickerYear'))).data,
        '2026');
    await tester.tap(find.byTooltip('Year after'));
    await tester.tap(find.byTooltip('Year after'));
    await tester.pumpAndSettle();
    expect(find.text('2028'), findsOneWidget);
    // Its month marked in its own year.
    final feb = tester.widget<Material>(find
        .ancestor(
            of: find.byKey(const Key('month-2')),
            matching: find.byType(Material))
        .first);
    final mar = tester.widget<Material>(find
        .ancestor(
            of: find.byKey(const Key('month-3')),
            matching: find.byType(Material))
        .first);
    expect(feb.color, isNot(mar.color));
  });

  testWidgets('the month picker, nothing set: this year, none marked',
      (tester) async {
    await tester.pumpWidget(MaterialApp(
      theme: AppTheme.dark,
      home: Builder(
        builder: (context) => Scaffold(
          body: TextButton(
            onPressed: () => showMonthPicker(context,
                title: 'Card expires',
                today: today,
                firstYear: 2021,
                lastYear: 2041),
            child: const Text('go'),
          ),
        ),
      ),
    ));
    await tester.tap(find.text('go'));
    await tester.pumpAndSettle();
    expect(find.text('2026'), findsOneWidget);
    final colours = {
      for (var m = 1; m <= 12; m++)
        tester
            .widget<Material>(find
                .ancestor(
                    of: find.byKey(Key('month-$m')),
                    matching: find.byType(Material))
                .first)
            .color,
    };
    expect(colours, hasLength(1), reason: 'none marked');
  });
}
