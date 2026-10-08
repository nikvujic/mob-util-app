import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:the_app/widgets/password_prompt.dart';

void main() {
  const right = 'right password';

  /// Opens the prompt; [attempt] defaults to "right password => 'key'".
  Future<Future<String?>> open(
    WidgetTester tester, {
    Future<String?> Function(String)? attempt,
  }) async {
    late Future<String?> result;
    await tester.pumpWidget(MaterialApp(
      home: Builder(
        builder: (context) => TextButton(
          onPressed: () => result = showPasswordPrompt<String>(
            context,
            title: 'Unlock',
            message: 'Enter your master password',
            attempt: attempt ?? (pw) async => pw == right ? 'key' : null,
          ),
          child: const Text('open'),
        ),
      ),
    ));
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
    return result;
  }

  Future<void> enter(WidgetTester tester, String text) => tester.enterText(
        find.descendant(
          of: find.byKey(const Key('promptPassword')),
          matching: find.byType(TextField),
        ),
        text,
      );

  String? error(WidgetTester tester) =>
      tester.widget<TextField>(find.byType(TextField)).decoration!.errorText;

  testWidgets('returns the result for the right password', (tester) async {
    final result = await open(tester);
    expect(find.text('Enter your master password'), findsOneWidget);

    await enter(tester, right);
    await tester.tap(find.text('OK'));
    await tester.pumpAndSettle();

    expect(await result, 'key');
    expect(find.byType(AlertDialog), findsNothing);
  });

  testWidgets('stays open on a wrong password', (tester) async {
    final result = await open(tester);

    await enter(tester, 'nope');
    await tester.tap(find.text('OK'));
    await tester.pumpAndSettle();
    expect(error(tester), 'Wrong password');
    expect(find.byType(AlertDialog), findsOneWidget);

    await enter(tester, right);
    await tester.testTextInput.receiveAction(TextInputAction.done);
    await tester.pumpAndSettle();
    expect(await result, 'key');
  });

  testWidgets('asks for a password instead of trying an empty one',
      (tester) async {
    var attempts = 0;
    await open(tester, attempt: (_) async {
      attempts++;
      return null;
    });
    await tester.tap(find.text('OK'));
    await tester.pumpAndSettle();

    expect(error(tester), 'Enter the password');
    expect(attempts, 0);
  });

  testWidgets('cancel resolves to null', (tester) async {
    final result = await open(tester);
    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();
    expect(await result, isNull);
  });

  testWidgets('shows progress and blocks input while checking', (tester) async {
    final check = Completer<String?>();
    final result = await open(tester, attempt: (_) => check.future);

    await enter(tester, right);
    await tester.tap(find.text('OK'));
    await tester.pump();
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    final cancel = tester.widget<OutlinedButton>(
      find.widgetWithText(OutlinedButton, 'Cancel'),
    );
    expect(cancel.onPressed, isNull);

    // Back can't close it either.
    await tester.binding.handlePopRoute();
    await tester.pump();
    expect(find.byType(AlertDialog), findsOneWidget);

    check.complete('key');
    await tester.pumpAndSettle();
    expect(await result, 'key');
  });
}
