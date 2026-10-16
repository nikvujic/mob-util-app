import 'package:flutter_test/flutter_test.dart';
import 'package:the_app/core/pip_brain.dart';
import 'package:the_app/widgets/pip_sprites.dart';

/// Round 61: a blink keeps his mouth (tired, he doesn't smile for it).
void main() {
  /// His screen's rows below the eyes: his mouth.
  List<String> mouth(PipFrame frame, PipFace face) =>
      PipSprites.frameOf(frame, face).sublist(4 + 5, 4 + 9);

  test('a blink keeps the mouth of the face he has', () {
    for (final face in [PipFace.normal, PipFace.tired, PipFace.veryTired]) {
      expect(mouth(PipFrame.blink, face), mouth(PipFrame.idle, face),
          reason: face.name);
    }
    expect(mouth(PipFrame.blink, PipFace.tired),
        isNot(mouth(PipFrame.idle, PipFace.normal)),
        reason: 'not the smile');
  });

  test('a blink shuts the eyes: none above the lowest eye row', () {
    for (final face in [PipFace.normal, PipFace.tired, PipFace.veryTired]) {
      final rows = PipSprites.frameOf(PipFrame.blink, face);
      // The screen's rows 0-2 hold no face pixels (eyes shut at 3 or 4).
      for (var y = 4; y < 4 + 3; y++) {
        expect(rows[y].contains('K'), isFalse, reason: '${face.name} row $y');
      }
    }
  });
}
