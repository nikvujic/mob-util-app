import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:the_app/widgets/format_bar.dart';

/// The text's selection handles (Round 64): their touch area starts at
/// the handle and reaches down, not up into the line they mark (a tap on
/// the text there grabbed the left one).
void main() {
  final controls = FormatBarSelectionControls(ValueNotifier(false));

  test('each handle as tall as a touch area', () {
    final size = controls.getHandleSize(18);
    expect(size.height, kMinInteractiveDimension);
    expect(size.width, lessThan(kMinInteractiveDimension),
        reason: 'as wide as drawn');
  });

  testWidgets('drawn at the top of it, where it marks the text',
      (tester) async {
    for (final type in [
      TextSelectionHandleType.left,
      TextSelectionHandleType.right,
    ]) {
      await tester.pumpWidget(MaterialApp(
        home: Align(
          alignment: Alignment.topLeft,
          child: Builder(
            builder: (context) => controls.buildHandle(context, type, 18),
          ),
        ),
      ));
      final box = tester.getRect(find.byType(SizedBox).first);
      expect(box.height, kMinInteractiveDimension, reason: type.name);
      final drawn = tester.getRect(find.byType(CustomPaint).last);
      expect(drawn.top, box.top, reason: type.name);
      expect(drawn.height, lessThan(kMinInteractiveDimension));
    }
  });
}
