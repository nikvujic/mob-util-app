import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:the_app/core/pip_brain.dart';
import 'package:the_app/core/theme.dart';
import 'package:the_app/widgets/pip_sprites.dart';

/// Pip's frames (Round 26), his screen a row taller (Round 27), and the
/// launcher icon drawn from the same idle frame.
void main() {
  test('every frame is his size, the brain\'s', () {
    for (final MapEntry(:key, :value) in PipSprites.frames.entries) {
      expect(value, hasLength(PipBrain.height), reason: key.name);
      expect(PipSprites.height, PipBrain.height);
      for (final row in value) {
        expect(row, hasLength(PipBrain.width), reason: key.name);
      }
    }
    expect(PipFrame.values.toSet(), PipSprites.frames.keys.toSet());
  });

  test('his screen is 14 x 9, the face on it, a pixel right of the middle', () {
    final idle = PipSprites.frames[PipFrame.idle]!;
    final screen = [
      for (final row in idle)
        if (row.contains('W')) row.substring(3, 17),
    ];
    expect(screen, hasLength(9));
    for (final row in screen) {
      expect(row, isNot(contains('L')), reason: '14 wide, inside the casing');
    }
    // Eyes two rows tall; left of them 3 pixels, right of them 2.
    expect(screen[2], 'WWWKKWWWWWKKWW');
    expect(screen[3], 'WWWKKWWWWWKKWW');
    expect(screen[5], 'WWWWKWWWWKWWWW');
    expect(screen[6], 'WWWWWKKKKWWWWW');
  });

  test('every letter has a colour', () {
    for (final frame in PipSprites.frames.values) {
      for (final c in frame.join().split('').toSet()..remove('.')) {
        expect(PipSprites.colours, contains(c));
      }
    }
  });

  group('the launcher icon (tool/make_icon.py)', () {
    final tool = File('tool/make_icon.py').readAsStringSync();

    test('is his idle frame', () {
      final sprite = tool
          .split('SPRITE = [')[1]
          .split(']')[0]
          .split('\n')
          .map((l) => l.trim())
          .where((l) => l.startsWith("'"))
          .map((l) => l.substring(1, l.lastIndexOf("'")))
          .toList();
      expect(sprite, PipSprites.frames[PipFrame.idle]);
    });

    test('in his colours', () {
      String hex(int v) => v.toRadixString(16).padLeft(2, '0');
      for (final MapEntry(:key, :value) in PipSprites.colours.entries) {
        final rgb = [value.r, value.g, value.b]
            .map((c) => '0x${hex((c * 255).round()).toUpperCase()}')
            .join(', ');
        expect(tool, contains("'$key': ($rgb)"), reason: key);
      }
      expect(PipSprites.colours['A'], PipColours.light);
    });
  });
}
