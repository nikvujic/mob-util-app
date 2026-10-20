import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:the_app/models/subscription.dart';

import '../helpers.dart';

/// Round 88 (Nikola): a tap on nothing lets the field being typed in go
/// (the keyboard goes), on every page; a tap in a field, or on a button,
/// is as ever.
void main() {
  testWidgets(
      'a subscription\'s page: typing its name, a tap on nothing lets it '
      'go; on another field, that one is typed in', (tester) async {
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 2.625;
    addTearDown(tester.view.reset);
    await pumpApp(tester,
        clock: () => DateTime(2026, 10, 20, 12),
        subscriptions: SubscriptionBook([
          Subscription(
              id: 'c', name: 'Claude', price: 20, date: DateTime(2026, 11, 3)),
        ]));
    await openTab(tester, 'Hub');
    await tester.tap(find.byTooltip('Subscriptions'));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('c')));
    await tester.pumpAndSettle();

    bool typing() => tester.testTextInput.isVisible;
    await tester.tap(find.byKey(const Key('subscriptionName')));
    await tester.pumpAndSettle();
    expect(typing(), isTrue);

    // Another field: typed in, the keyboard stays.
    await tester.tap(find.byKey(const Key('subscriptionPrice')));
    await tester.pumpAndSettle();
    expect(typing(), isTrue);
    expect(
        tester
            .widget<EditableText>(find.descendant(
                of: find.byKey(const Key('subscriptionPrice')),
                matching: find.byType(EditableText)))
            .focusNode
            .hasFocus,
        isTrue);

    // Nothing there: the page's title.
    await tester.tap(find.text('Subscription'));
    await tester.pumpAndSettle();
    expect(typing(), isFalse);
    expect(FocusManager.instance.primaryFocus?.context?.widget,
        isNot(isA<EditableText>()));
  });

  testWidgets('a note: typing, a tap on its title bar lets it go',
      (tester) async {
    await pumpApp(tester);
    await tester.tap(find.byTooltip('New note'));
    await tester.pumpAndSettle();
    bool typing() => tester.testTextInput.isVisible;
    if (!typing()) {
      await tester.tap(find.byType(EditableText).last);
      await tester.pumpAndSettle();
    }
    expect(typing(), isTrue);
    await tester.tapAt(const Offset(200, 30));
    await tester.pumpAndSettle();
    expect(typing(), isFalse);
  });
}
