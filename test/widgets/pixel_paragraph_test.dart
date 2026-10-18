import 'package:flutter_test/flutter_test.dart';
import 'package:the_app/widgets/pixel_text.dart';

/// Pixel words wrapped onto lines (Round 66).
void main() {
  test('broken between words, each line within the width', () {
    expect(PixelParagraph.linesOf('COME BACK BETWEEN 13:00 AND 17:00', 17), [
      'COME BACK BETWEEN',
      '13:00 AND 17:00',
    ]);
    expect(PixelParagraph.linesOf('NOT AN ADVENTURER YET', 14),
        ['NOT AN', 'ADVENTURER YET']);
    expect(PixelParagraph.linesOf('SHORT', 40), ['SHORT']);
  });

  test('a word longer than a line goes on its own', () {
    expect(
        PixelParagraph.linesOf('A ADVENTURER B', 5), ['A', 'ADVENTURER', 'B']);
  });
}
