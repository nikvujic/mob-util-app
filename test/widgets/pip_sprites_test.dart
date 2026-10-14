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
      // The colours his standing frame uses (not the egg's, Round 34).
      final used = PipSprites.frames[PipFrame.idle]!.join().split('').toSet();
      for (final MapEntry(:key, :value) in PipSprites.colours.entries) {
        if (!used.contains(key)) continue;
        final rgb = [value.r, value.g, value.b]
            .map((c) => '0x${hex((c * 255).round()).toUpperCase()}')
            .join(', ');
        expect(tool, contains("'$key': ($rgb)"), reason: key);
      }
      expect(PipSprites.colours['A'], PipColours.light);
    });
  });

  group('his charging station (Round 44)', () {
    test('the station: 14 x 27, every pixel in its colours', () {
      expect(PipSprites.station, hasLength(PipBrain.stationHeight));
      for (final row in [...PipSprites.station, ...PipSprites.stationLampOff]) {
        expect(row.length, PipBrain.stationWidth);
        for (final c in row.split('')) {
          if (c == '.') continue;
          expect(PipSprites.stationColours, contains(c), reason: c);
        }
      }
      // Its socket on its left, where his port's height is.
      final socketRow = PipBrain.stationHeight - 1 - PipBrain.socketUp.toInt();
      expect(PipSprites.station[socketRow][0], 'c');
      // The lamp blinks: lit in one, off in the other.
      expect(PipSprites.station.join(), contains('q'));
      expect(PipSprites.stationLampOff.join(), isNot(contains('q')));
    });

    test('mitts, plug and notes in his colours', () {
      for (final row in [
        ...PipSprites.mitt,
        ...PipSprites.plug,
        ...PipSprites.note,
      ]) {
        for (final c in row.split('')) {
          if (c != '.') expect(PipSprites.colours, contains(c), reason: c);
        }
      }
    });

    test('every charging screen: his frame, his colours', () {
      final idle = PipSprites.frames[PipFrame.idle]!;
      for (final screen in ChargeScreen.values) {
        for (final t in [0.0, 0.7, 1.6, 5.0]) {
          final frame = PipSprites.chargingFrame(screen, t, lamp: t < 1);
          expect(frame, hasLength(idle.length), reason: screen.name);
          for (var y = 0; y < frame.length; y++) {
            expect(frame[y].length, idle[y].length);
            for (final c in frame[y].split('')) {
              if (c != '.') {
                expect(PipSprites.colours, contains(c), reason: screen.name);
              }
            }
          }
        }
      }
    });

    test(
        'the screens move: the battery fills, the '
        'static changes, his eyes follow the lamp', () {
      String screen(ChargeScreen s, double t, {bool lamp = true}) =>
          PipSprites.chargingFrame(s, t, lamp: lamp).join('\n');
      expect(screen(ChargeScreen.battery, 0), isNot(contains('B')));
      expect(screen(ChargeScreen.battery, 1.6), contains('B'));
      expect(screen(ChargeScreen.static, 0.05),
          isNot(screen(ChargeScreen.static, 0.25)));
      expect(screen(ChargeScreen.blinking, 0, lamp: true),
          isNot(screen(ChargeScreen.blinking, 0, lamp: false)));
      expect(screen(ChargeScreen.bolt, 0), contains('Y'));
    });
  });
}
