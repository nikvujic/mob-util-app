import 'dart:math' as math;

import 'package:the_app/core/pip_brain.dart';
import 'package:the_app/core/pixel_font.dart';
import 'package:the_app/core/theme.dart';

/// Pip's frames on a 20-wide grid (Round 26), one letter a pixel ('.'
/// empty): his head with a 14 x 9 screen (Round 27: one row taller than
/// at first, less flat), his face on it, and legs that can step. The room
/// draws them all; the menu header and the launcher icon
/// (`tool/make_icon.py`) draw [PipFrame.idle].
abstract final class PipSprites {
  /// His screen's size, in pixels.
  static const screenWidth = 14;
  static const screenRows = 9;

  static final _head = [
    '.........A..........',
    '.........L..........',
    '...LLLLLLLLLLLLLL...',
    '..LLLLLLLLLLLLLLLL..',
    for (var i = 0; i < screenRows; i++) '..LWWWWWWWWWWWWWWL..',
    '..LLLLLLLLLLLLLLLL..',
    '...OOOOOOOOOOOOOO...',
    '...SSSSSSSSSSSSSS...',
  ];

  /// Where the screen's top left pixel is.
  static const _screenX = 3, _screenY = 4;

  static const _legs = {
    'stand': [
      '.....OO......OO.....',
      '.....OO......OO.....',
      '.....SS......SS.....',
    ],
    'stepL': [
      '.....OO......OO.....',
      '.....SS......OO.....',
      '.............SS.....',
    ],
    'stepR': [
      '.....OO......OO.....',
      '.....OO......SS.....',
      '.....SS.............',
    ],
    'tuck': [
      '.....SS......SS.....',
      '....................',
      '....................',
    ],
  };

  /// The face's dark pixels, on the screen (from its top left), looking
  /// [look] pixels to the right. Even looking ahead his face sits a pixel
  /// right of the middle: a little goofy, and liked that way.
  static Set<(int, int)> _face(String kind, int look) {
    final eyes = [3 + look, 10 + look];
    final mouth = 4 + look;
    // Round 37: tired, eyes half shut and a flat mouth; very tired, eyes
    // low and a wobbly mouth; asleep, eyes shut and a small mouth.
    switch (kind) {
      case 'tired':
        return {
          for (final e in eyes) ...[(e, 3), (e + 1, 3)],
          for (var i = 1; i <= 4; i++) (mouth + i, 6),
        };
      case 'very':
        return {
          for (final e in eyes) ...[(e, 4), (e + 1, 4)],
          (mouth + 1, 6),
          (mouth + 2, 5),
          (mouth + 3, 6),
          (mouth + 4, 5),
        };
      case 'asleep':
        return {
          for (final e in eyes) ...[(e, 3), (e + 1, 3)],
          (mouth + 2, 6),
          (mouth + 3, 6),
        };
      case 'off':
        return const {};
    }
    return {
      for (final e in eyes)
        ...switch (kind) {
          'blink' => [(e, 3), (e + 1, 3)],
          _ => [(e, 2), (e + 1, 2), (e, 3), (e + 1, 3)],
        },
      ...switch (kind) {
        // Surprised: a small round mouth.
        'oh' => [
            (mouth + 2, 5),
            (mouth + 3, 5),
            (mouth + 1, 6),
            (mouth + 4, 6),
            (mouth + 2, 7),
            (mouth + 3, 7),
          ],
        _ => [
            (mouth, 5),
            (mouth + 5, 5),
            for (var i = 1; i <= 4; i++) (mouth + i, 6),
          ],
      },
    };
  }

  static List<String> _frame(String face, String legs, {int look = 0}) {
    final rows = [for (final r in _head) r.split('')];
    // Asleep his screen dims; off it's dark, with a glint (Round 37).
    final screen = switch (face) { 'asleep' => 'D', 'off' => 'X', _ => null };
    if (screen != null) {
      for (var y = 0; y < screenRows; y++) {
        for (var x = 0; x < screenWidth; x++) {
          rows[_screenY + y][_screenX + x] = screen;
        }
      }
    }
    if (face == 'off') {
      for (final (x, y) in const [(1, 1), (2, 1), (1, 2)]) {
        rows[_screenY + y][_screenX + x] = 'x';
      }
    }
    for (final (x, y) in _face(face, look)) {
      rows[_screenY + y][_screenX + x] = 'K';
    }
    return [
      for (final r in rows) r.join(),
      ..._legs[legs]!,
    ];
  }

  /// Each frame's rows.
  static final Map<PipFrame, List<String>> frames = {
    PipFrame.idle: _frame('smile', 'stand'),
    PipFrame.blink: _frame('blink', 'stand'),
    // Walking: looking ahead (to the right; mirrored going left).
    PipFrame.step1: _frame('smile', 'stepL', look: 1),
    PipFrame.step2: _frame('smile', 'stand', look: 1),
    PipFrame.step3: _frame('smile', 'stepR', look: 1),
    PipFrame.step4: _frame('smile', 'stand', look: 1),
    PipFrame.oh: _frame('oh', 'stand'),
    PipFrame.tuck: _frame('oh', 'tuck'),
  };

  /// [frame] with [face] (Round 37): tired faces by his energy, asleep
  /// (screen dimmed), off (screen dark). Blinks and surprise keep their
  /// own faces while he's awake.
  static List<String> frameOf(PipFrame frame, PipFace face) =>
      face == PipFace.normal ? frames[frame]! : _faced[(frame, face)]!;

  static final Map<(PipFrame, PipFace), List<String>> _faced = {
    for (final frame in PipFrame.values)
      for (final face in PipFace.values)
        if (face != PipFace.normal) (frame, face): _withFace(frame, face),
  };

  static List<String> _withFace(PipFrame frame, PipFace face) {
    final kind = switch (face) {
      PipFace.asleep => 'asleep',
      PipFace.off => 'off',
      _ when frame == PipFrame.blink => 'blink',
      _ when frame == PipFrame.oh || frame == PipFrame.tuck => 'oh',
      PipFace.tired => 'tired',
      _ => 'very',
    };
    final (legs, look) = switch (frame) {
      PipFrame.step1 => ('stepL', 1),
      PipFrame.step2 || PipFrame.step4 => ('stand', 1),
      PipFrame.step3 => ('stepR', 1),
      PipFrame.tuck => ('tuck', 0),
      _ => ('stand', 0),
    };
    return _frame(kind, legs, look: look);
  }

  /// A battery (Round 37), 4 x 7: its cap, a grey case, blue inside
  /// (Round 42).
  static const battery = [
    '.hh.',
    'gGGg',
    'gGGg',
    'gGGg',
    'gGGg',
    'gGGg',
    'gggg',
  ];

  // Round 44: his charging station, his hands, his charging screens.

  /// The power station (Round 44: drafts v2), 14 x 27, its socket and
  /// hook on its left (mirrored when it stands on his left): a lamp on
  /// top, a roof, a screen with a bolt, a little panel of lights, vents,
  /// a hazard band, a base with bolts. Its own colours ([stationColours]).
  static const station = [
    '......ee......',
    '.....eqqe.....',
    '...HHHHHHHH...',
    '..HGGGGGGGGH..',
    '.HHHHHHHHHHHH.',
    '.HggggggggggH.',
    '.HgkkkkkkkkgH.',
    '.HgkkkkyykkgH.',
    '.HgkkkyykkkgH.',
    '.HgkkyyyykkgH.',
    '.HgkkkyykkkgH.',
    '.HgkkyykkkkgH.',
    '.HgkkkkkkkkgH.',
    '.HggggggggggH.',
    '.HgGGGGGGGGgH.',
    '.HgGhrGGeGGgH.',
    '.HgGGGGGGGGgH.',
    'hHggggggggggH.',
    'cHghhhhhhhhgH.',
    'hHggggggggggH.',
    '.HghhhhhhhhgH.',
    '.HggggggggggH.',
    '.HyKyKyKyKyKH.',
    '.HKyKyKyKyKyH.',
    '.HHHHHHHHHHHH.',
    'hhhhhhhhhhhhhh',
    'hKhhhhhhhhhhKh',
  ];

  static const stationColours = {
    'H': PipColours.stationEdge,
    'g': PipColours.stationBody,
    'G': PipColours.stationLight,
    'h': PipColours.stationDark,
    'k': PipColours.stationPanel,
    'y': PipColours.stationBolt,
    'K': PipColours.face,
    'r': PipColours.energyLow,
    'e': PipColours.lampOff,
    'q': PipColours.lampOn,
    'c': PipColours.cable,
  };

  /// [station] with its lamp off (it blinks).
  static final stationLampOff = [
    for (final row in station) row.replaceAll('q', 'e'),
  ];

  /// A floating hand (Round 44: no arms, they pop in when needed), 2 x 3.
  static const mitt = ['LL', 'LL', 'SS'];

  /// The plug, 2 x 2: grey, its darker end.
  static const plug = ['gg', 'hh'];

  /// A note floating up while he hums, 3 x 3.
  static const note = ['.KK', '.K.', 'KK.'];

  /// His standing frame with [screen] showing while he charges, [t]
  /// seconds into it; [lamp]: the station's lamp on (he blinks with it).
  static List<String> chargingFrame(ChargeScreen screen, double t,
      {bool lamp = true}) {
    final rows = [for (final r in frames[PipFrame.idle]!) r.split('')];
    for (var y = 0; y < screenRows; y++) {
      for (var x = 0; x < screenWidth; x++) {
        rows[_screenY + y][_screenX + x] = 'W';
      }
    }
    void k(int x, int y, [String c = 'K']) {
      if (x >= 0 && x < screenWidth && y >= 0 && y < screenRows) {
        rows[_screenY + y][_screenX + x] = c;
      }
    }

    const smile = [(4, 5), (9, 5), (5, 6), (6, 6), (7, 6), (8, 6)];
    void eyes(List<(int, int)> eye) {
      for (final e in const [3, 10]) {
        for (final (x, y) in eye) {
          k(e + x, y);
        }
      }
    }

    switch (screen) {
      case ChargeScreen.happy || ChargeScreen.sparks:
        // ^ ^ eyes.
        eyes(const [(0, 3), (1, 2), (2, 3)]);
        for (final (x, y) in smile) {
          k(x, y);
        }
      case ChargeScreen.battery:
        // A battery outline filling up, a bar at a time.
        for (var x = 3; x < 11; x++) {
          k(x, 2);
          k(x, 6);
        }
        for (var y = 2; y < 7; y++) {
          k(3, y);
          k(10, y);
        }
        for (final y in const [3, 4, 5]) {
          k(11, y);
        }
        final bars = (t / 0.5).floor() % 4;
        for (var i = 0; i < bars; i++) {
          for (var y = 3; y < 6; y++) {
            for (var x = 4 + 2 * i; x < 6 + 2 * i; x++) {
              k(x, y, 'B');
            }
          }
        }
      case ChargeScreen.static:
        // Snow: new every tenth of a second.
        final r = math.Random((t * 10).floor());
        for (var y = 0; y < screenRows; y++) {
          for (var x = 0; x < screenWidth; x++) {
            k(x, y, const ['W', 'W', 'n', 'n', 'd', 'K'][r.nextInt(6)]);
          }
        }
      case ChargeScreen.bolt:
        const bolt = ['...yy', '..yy.', '.yyyy', '..yy.', '.yy..', 'yy...'];
        for (var y = 0; y < bolt.length; y++) {
          for (var x = 0; x < bolt[y].length; x++) {
            if (bolt[y][x] == 'y') k(4 + x, 1 + y, 'Y');
          }
        }
      case ChargeScreen.content || ChargeScreen.humming:
        // Eyes shut, a small smile.
        eyes(const [(0, 3), (1, 3)]);
        k(6, 6);
        k(7, 6);
      case ChargeScreen.percent:
        // Counting up to 100%, then staying there.
        final p = math.min(100, (t * 30).floor());
        final text = '$p%';
        var x = (screenWidth - text.length * 4 + 1) ~/ 2;
        for (final ch in text.split('')) {
          final glyph = PixelFont.glyphOf(ch);
          for (var y = 0; y < glyph.length; y++) {
            for (var gx = 0; gx < glyph[y].length; gx++) {
              if (glyph[y][gx] == '#') k(x + gx, 2 + y);
            }
          }
          x += 4;
        }
      case ChargeScreen.blinking:
        // His eyes close when the station's lamp goes off.
        eyes(lamp
            ? const [(0, 2), (1, 2), (0, 3), (1, 3)]
            : const [(0, 3), (1, 3)]);
        for (final (x, y) in smile) {
          k(x, y);
        }
    }
    return [for (final r in rows) r.join()];
  }

  /// A little z rising while he sleeps, 3 x 4.
  static const z = ['zzz', '..z', '.z.', 'zzz'];

  /// His egg (Round 34, Nikola's pick: spotted), 16 x 19: the shell, a
  /// shade down its right and bottom edges, spots in his casing colour.
  static const egg = [
    '......WWWW......',
    '.....WWWWWW.....',
    '....WWWWWWWw....',
    '...WWWWWWWWWw...',
    '..WWWLLWWWWWWw..',
    '..WWWWWWWWWWWw..',
    '.WWWWWWWWWWWWWw.',
    '.WWWWWWWWWWLLWw.',
    '.WWWWWWWWWWWLWw.',
    'WWWWWWWWWWWWWWWw',
    'WWWWWWWWWWWWWWWw',
    'WWWLLWWWWWWWWWWw',
    'WWWWWWWWWWWWWWWw',
    'WWWWWWWWWWWWLWWw',
    '.WWWWWWWWWLWWWw.',
    '.WWWWWWWWWWWWWw.',
    '..WWWWWWWWWWWw..',
    '...wwwwwwwwww...',
    '.....wwwwww.....',
  ];

  /// The crack across his egg: a zigzag through its middle, longer at each
  /// stage (1 to 3), as (x, y) on [egg].
  static const crackZigzag = [
    (8, 8), (7, 9), (9, 9), // a first nick
    (6, 8), (10, 8), (5, 9), (11, 9), // longer
    (4, 8), (12, 8), (3, 9), (13, 9), (2, 8), (14, 8), (1, 9), // across
  ];
  static const crackLength = [0, 3, 7, 14];

  /// [egg] cracked to [stage] (0 to 3).
  static List<String> crackedEgg(int stage) {
    final rows = [for (final r in egg) r.split('')];
    for (final (x, y) in crackZigzag.take(crackLength[stage.clamp(0, 3)])) {
      if (rows[y][x] != '.') rows[y][x] = 'K';
    }
    return [for (final r in rows) r.join()];
  }

  /// The egg's two halves once he's out: the bottom (rows 9 on, its top
  /// edge broken) and the top (rows 0 to 8).
  static final eggBottom = [
    [
      for (final (i, c) in egg[9].split('').indexed) i % 3 == 1 ? '.' : c,
    ].join(),
    ...egg.skip(10),
  ];
  static final eggTop = egg.take(9).toList();

  static const colours = {
    'w': PipColours.eggShade,
    'L': PipColours.casing,
    'O': PipColours.body,
    'S': PipColours.shade,
    'W': PipColours.screen,
    'K': PipColours.face,
    'A': PipColours.light,
    // Round 37.
    'D': PipColours.screenAsleep,
    'X': PipColours.screenOff,
    'x': PipColours.screenGlint,
    'g': PipColours.batteryCase,
    'G': PipColours.batteryCharge,
    'h': PipColours.batteryCap,
    'z': PipColours.star,
    // Round 44: his charging screens.
    'B': PipColours.batteryCharge,
    'Y': PipColours.stationBolt,
    'n': PipColours.staticLight,
    'd': PipColours.staticDark,
  };

  /// How many rows a frame has.
  static int get height => _head.length + 3;
}
