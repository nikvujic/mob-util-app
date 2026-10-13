import 'package:flutter_test/flutter_test.dart';
import 'package:the_app/data/app_storage.dart';

import '../helpers.dart';

/// When saving fails (D6, Round 23), e.g. a full phone: the app says so
/// once, and says when it's saved again.
void main() {
  testWidgets('failing: a dialog; saved again: a short note', (tester) async {
    final storage = AppStorage.inMemory();
    await pumpApp(
      tester,
      overrides: [appStorageProvider.overrideWithValue(storage)],
    );
    await tester.pumpAndSettle();

    storage.saveFailing.value = true;
    await tester.pumpAndSettle();
    expect(find.text("Changes can't be saved"), findsOneWidget);
    await tester.tap(find.text('OK'));
    await tester.pumpAndSettle();

    storage.saveFailing.value = false;
    await tester.pump();
    expect(find.text('Saved again'), findsOneWidget);
  });
}
