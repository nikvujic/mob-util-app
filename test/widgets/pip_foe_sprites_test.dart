import 'package:flutter_test/flutter_test.dart';
import 'package:the_app/core/pip_run.dart';
import 'package:the_app/widgets/pip_sprites.dart';

/// Round 73: what he fights, drawn.
void main() {
  test('each foe as wide as it is, its legs stepping, every colour drawn', () {
    for (final foe in PipFoe.values) {
      final up = PipSprites.foeArt(foe, true);
      final down = PipSprites.foeArt(foe, false);
      expect(up.first.length, foe.width, reason: foe.name);
      for (final art in [up, down]) {
        expect(art.every((r) => r.length == foe.width), isTrue,
            reason: foe.name);
        for (final c in art.join().split('')) {
          if (c != '.') {
            expect(PipSprites.foeColours.containsKey(c), isTrue,
                reason: '${foe.name} $c');
          }
        }
      }
      expect(up, isNot(down), reason: '${foe.name}: its legs step');
      expect(up.join().contains('r'), isTrue, reason: '${foe.name}: eyes');
    }
    // Bigger ones bigger; the boss biggest, in a crown.
    final heights = [
      for (final f in PipFoe.values) PipSprites.foeArt(f, true).length
    ];
    expect(heights, orderedEquals([...heights]..sort()));
    expect(PipSprites.bossUp.first.contains('y'), isTrue);
    expect(PipSprites.foeFlashColours.keys, PipSprites.foeColours.keys);
  });

  test('the XP he gains in little letters', () {
    final text = PipSprites.tinyText('+12 XP');
    expect(text.length, 5);
    // Five letters three wide, a space one wide, a column between each.
    expect(text.every((r) => r.length == 5 * 3 + 1 + 5), isTrue);
    expect(PipSprites.tinyText('0123456789').first.length, 10 * 3 + 9);
  });
}
