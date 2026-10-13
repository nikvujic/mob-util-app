import 'package:flutter_test/flutter_test.dart';
import 'package:the_app/core/pixel_font.dart';

/// The app's pixel letters (Round 34).
void main() {
  test('every letter and digit, each 3 x 5', () {
    for (final c
        in 'ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789 .,!?-\':/%+'.split('')) {
      final g = PixelFont.glyphs[c];
      expect(g, isNotNull, reason: c);
      expect(g, hasLength(PixelFont.height), reason: c);
      for (final row in g!) {
        expect(row, matches(RegExp(r'^[#.]{3}$')), reason: c);
      }
    }
  });

  test('no two letters look the same', () {
    final seen = <String, String>{};
    PixelFont.glyphs.forEach((c, g) {
      final key = g.join();
      expect(seen[key], isNull, reason: '$c looks like ${seen[key]}');
      seen[key] = c;
    });
  });

  test('small letters as capitals; anything else as ?', () {
    expect(PixelFont.glyphOf('p'), PixelFont.glyphs['P']);
    expect(PixelFont.glyphOf('č'), PixelFont.glyphs['?']);
    expect(PixelFont.widthOf('PIP'), 11);
    expect(PixelFont.widthOf(''), 0);
  });
}
