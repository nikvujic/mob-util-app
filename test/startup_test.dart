import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:the_app/providers/storage_status_provider.dart';

import 'helpers.dart';

/// Data that couldn't be read at startup is set aside, and the app says so.
void main() {
  testWidgets('says which data couldn\'t be read', (tester) async {
    await pumpApp(
      tester,
      overrides: [
        unreadableFilesProvider.overrideWithValue(['notes.json']),
      ],
    );
    await tester.pumpAndSettle();

    expect(find.text("Some data couldn't be read"), findsOneWidget);
    expect(find.textContaining('notes.json could not be read'), findsOneWidget);
    await tester.tap(find.text('OK'));
    await tester.pumpAndSettle();
    expect(find.text("Some data couldn't be read"), findsNothing);
  });

  testWidgets('says nothing when all is well', (tester) async {
    await pumpApp(tester);
    await tester.pumpAndSettle();
    expect(find.byType(Dialog), findsNothing);
  });
}
