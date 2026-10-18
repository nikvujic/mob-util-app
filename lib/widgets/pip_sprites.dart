import 'dart:math' as math;

import 'package:the_app/core/pip_brain.dart';
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
    // Round 61: a blink shuts the eyes of the face he has (tired, very
    // tired), keeping its mouth: before, every blink was the smiling one.
    if (kind.startsWith('blink-')) {
      final face = _face(kind.substring(6), look);
      bool eye((int, int) p) =>
          p.$2 <= 4 && eyes.any((e) => p.$1 == e || p.$1 == e + 1);
      final shut = face.where(eye).map((p) => p.$2).fold(3, math.max);
      return {
        ...face.where((p) => !eye(p)),
        for (final e in eyes) ...[(e, shut), (e + 1, shut)],
      };
    }
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
      case 'yawn':
        // Round 57: eyes shut, mouth wide open.
        return {
          for (final e in eyes) ...[(e, 3), (e + 1, 3)],
          (mouth + 2, 4), (mouth + 3, 4), //
          (mouth + 1, 5), (mouth + 4, 5),
          (mouth + 1, 6), (mouth + 4, 6),
          (mouth + 1, 7), (mouth + 4, 7),
          (mouth + 2, 8), (mouth + 3, 8),
        };
      case 'angry':
        // Round 52: brows down to the middle, a frown.
        return {
          (eyes[0] - 1, 1), (eyes[0], 1), (eyes[0] + 1, 2), //
          (eyes[1] + 2, 1), (eyes[1] + 1, 1), (eyes[1], 2),
          for (final e in eyes) ...[(e, 3), (e + 1, 3)],
          (mouth + 1, 6), (mouth + 2, 5), (mouth + 3, 5), (mouth + 4, 6),
        };
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
      PipFace.angry => 'angry',
      PipFace.asleep => 'asleep',
      PipFace.off => 'off',
      PipFace.yawn => 'yawn',
      PipFace.tired when frame == PipFrame.blink => 'blink-tired',
      PipFace.veryTired when frame == PipFrame.blink => 'blink-very',
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

  /// His old battery (Round 54), thrown away: dark inside, a red bit
  /// left at the bottom.
  static const batteryEmpty = [
    '.hh.',
    'gXXg',
    'gXXg',
    'gXXg',
    'gXXg',
    'gRRg',
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

  /// The station's drone (Round 58), 10 x 5, its rotors two ways (they
  /// spin), in [stationColours].
  static const drone = [
    [
      'GGGG..GGGG',
      '....HH....',
      '.HHggggHH.',
      '..HggggH..',
      '...HqqH...',
    ],
    [
      '.GG....GG.',
      '....HH....',
      '.HHggggHH.',
      '..HggggH..',
      '...HqqH...',
    ],
  ];

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

  // Round 52: his screen showing things, and what's in his field.

  /// His standing frame with [screen] on his screen, [t] seconds in.
  static List<String> screenFrame(PipScreen screen, double t) {
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

    /// A small picture, '#' its pixels (in [c]), its top left at [x], [y].
    void draw(List<String> art, int x, int y, [String c = 'K']) {
      for (var j = 0; j < art.length; j++) {
        for (var i = 0; i < art[j].length; i++) {
          if (art[j][i] == '#') k(x + i, y + j, c);
        }
      }
    }

    final blink = (t * 3).floor().isEven;
    switch (screen) {
      case PipScreen.envelope:
        // An envelope, its flap a V; it nudges up and down.
        final up = (t * 4).floor() % 2;
        draw(const [
          '##########',
          '##......##',
          '#.#....#.#',
          '#..#..#..#',
          '#...##...#',
          '##########',
        ], 2, 1 + up);
      case PipScreen.bell:
        // A bell, swinging.
        final swing = const [0, 1, 0, -1][(t * 6).floor() % 4];
        draw(const [
          '...##...',
          '..####..',
          '.######.',
          '.######.',
          '########',
          '...##...',
        ], 3 + swing, 1, 'Y');
        if (swing != 0) {
          k(swing > 0 ? 1 : 12, 2, 'K');
          k(swing > 0 ? 1 : 12, 4, 'K');
        }
      case PipScreen.alert:
        // A red "!", blinking.
        if (blink) {
          draw(const ['##', '##', '##', '##', '..', '##'], 6, 1, 'R');
        }
      case PipScreen.pill:
        // A capsule, half red, half white, hopping: medicine time.
        final hop = (t * 3).floor().isEven ? 0 : 1;
        draw(const [
          '.########.',
          '#........#',
          '#........#',
          '.########.',
        ], 2, 2 - hop);
        draw(const ['####', '####'], 3, 3 - hop, 'R');
      case PipScreen.music:
        // Two notes, bobbing in turn.
        final a = (t * 3).floor().isEven ? 0 : 1;
        draw(const ['.##', '.#.', '.#.', '##.', '##.'], 3, 1 + a);
        draw(const ['.##', '.#.', '.#.', '##.', '##.'], 8, 2 - a);
      case PipScreen.happy:
        // ^ ^ and a big smile: proud, or glad.
        for (final e in const [3, 10]) {
          k(e, 3);
          k(e + 1, 2);
          k(e + 2, 3);
        }
        for (final (x, y) in const [
          (4, 5),
          (9, 5),
          (5, 6),
          (6, 6),
          (7, 6),
          (8, 6),
        ]) {
          k(x, y);
        }
    }
    return [for (final r in rows) r.join()];
  }

  /// A computer bug (Round 52; Round 53 bigger), 8 x 6, its legs one
  /// way or the other: green with darker stripes and belly, a red eye
  /// and two feelers at the front (its left: it's mirrored going right).
  static const bugUp = [
    'K..K....',
    '.KK.bbb.',
    '.rbbBbBb',
    'bbbbBbBb',
    '.BBBBBB.',
    '.K..K..K',
  ];
  static const bugDown = [
    'K..K....',
    '.KK.bbb.',
    '.rbbBbBb',
    'bbbbBbBb',
    '.BBBBBB.',
    'K..K..K.',
  ];

  /// His sword (Round 53 redrawn), 5 x 13, pointing up: a blade with a
  /// shine down it, a gold guard with a red gem, the grip, a pommel.
  static const sword = [
    '..h..',
    '.hse.',
    '.hse.',
    '.hse.',
    '.hse.',
    '.hse.',
    '.hse.',
    '.hse.',
    'ggrgg',
    '..t..',
    '..t..',
    '..t..',
    '.ggg.',
  ];

  /// The sword's grip row the hand holds (the middle of the grip).
  static const swordGrip = 10;

  /// A flower, 5 x 7: petals, its heart, a stem with a leaf.
  static const flower = [
    '.pp..',
    'pfpP.',
    '.pP..',
    '..v..',
    '.vv..',
    '..v..',
    '..v..',
  ];

  /// A butterfly, 7 x 4, its wings up or down.
  static const butterflyUp = [
    'ww...ww',
    'wWw.wWw',
    '.wwkww.',
    '...k...',
  ];
  static const butterflyDown = [
    '.......',
    '...k...',
    'wwwkwww',
    '.wW.Ww.',
  ];

  /// A ball, 4 x 4, its stripe turned four ways as it rolls.
  static const ballFrames = [
    ['.oo.', 'oiio', 'oooo', '.oo.'],
    ['.oo.', 'oioo', 'oioo', '.oo.'],
    ['.oo.', 'oooo', 'oiio', '.oo.'],
    ['.oo.', 'ooio', 'ooio', '.oo.'],
  ];

  /// [frame] with what's on his screen turned left to right (Round 53):
  /// drawn mirrored when he faces left, his screen then reads right.
  static List<String> screenTurned(List<String> frame) => [
        for (final (y, row) in frame.indexed)
          y < _screenY || y >= _screenY + screenRows
              ? row
              : row.substring(0, _screenX) +
                  row
                      .substring(_screenX, _screenX + screenWidth)
                      .split('')
                      .reversed
                      .join() +
                  row.substring(_screenX + screenWidth),
      ];

  /// His cross words over his head (#!), two ways, 7 x 5.
  static const crossWords = [
    ['.#.#..#', '#####.#', '.#.#..#', '#####..', '.#.#..#'],
    ['#.#...#', '#####.#', '#.#...#', '#####..', '#.#...#'],
  ];

  /// His plate (Round 53), 10 x 2.
  static const plate = ['QqqqqqqqqQ', '.QQQQQQQQ.'];

  /// What's on his plate with [left] bites left (3 to 0), 10 wide: a
  /// heap with a green leaf on top, smaller each bite.
  static List<String> meal(int left) => switch (left) {
        >= 3 => const ['...uumm...', '..mmmmMm..', '.mMmmmmmm.'],
        2 => const ['....um....', '...mmMm...'],
        1 => const ['....mM....'],
        _ => const <String>[],
      };

  /// His hats (Round 57), drawn on his head (mirrored with him), their
  /// bottom row just above his casing ([hatBottom]). Round 58: centred
  /// on his head, over his antenna (it's under the hat), each an even
  /// width so it sits in the middle ([hatLeftOf]); the party hat bigger,
  /// striped, with a pompom.
  static const hats = {
    PipHat.party: [
      '....oo....',
      '...oooo...',
      '....yp....',
      '...yppy...',
      '...ppyy...',
      '..ppyypp..',
      '..pyyppy..',
      '.pyyppyyp.',
      'oooooooooo',
    ],
    PipHat.crown: [
      'g..gg..g',
      'gg.gg.gg',
      'gggggggg',
      'grgbbgrg',
    ],
    PipHat.topHat: [
      '..kkkkkk..',
      '..kkkkkk..',
      '..kkkkkk..',
      '..kkkkkk..',
      '..rrrrrr..',
      'kkkkkkkkkk',
    ],
    PipHat.wizard: [
      '......u...',
      '.....uu...',
      '....uuu...',
      '....uyu...',
      '...uuuuu..',
      '...uuuyu..',
      '..uyuuuuu.',
      'uuuuuuuuuu',
    ],
    PipHat.cap: [
      '...cccc...',
      '..cccccc..',
      '..cccccccc',
    ],
    PipHat.beanie: [
      '....ww....',
      '..bbbbbb..',
      '.bbbbbbbb.',
      '.bbbbbbbb.',
      'wbwbwbwbwb',
    ],
    // Round 61: a day of the year's.
    PipHat.santa: [
      '.......oo.',
      '......rroo',
      '.....rrr..',
      '....rrrrr.',
      '...rrrrrr.',
      '.rrrrrrrr.',
      'oooooooooo',
    ],
    PipHat.witch: [
      '.......k..',
      '......kk..',
      '.....kkk..',
      '....kkkk..',
      '....kkkkk.',
      '...uuuuuu.',
      'kkkkkkkkkk',
    ],
    PipHat.bunny: [
      '.ww..ww.',
      '.wp..pw.',
      '.wp..pw.',
      '.wwwwww.',
      'wwwwwwww',
    ],
    PipHat.heart: [
      '.rr..rr.',
      'rrrrrrrr',
      '.rrrrrr.',
      '..rrrr..',
      '...rr...',
      'pppppppp',
    ],
  };

  /// The middle of his head on his frame: between columns 9 and 10.
  static const hatCentre = 10;

  /// The row a hat's bottom is on.
  static const hatBottom = 1;

  /// Where [art] (a hat) starts on his frame, so it's centred.
  static int hatLeftOf(List<String> art) => hatCentre - art.first.length ~/ 2;

  static const hatColours = {
    'o': PipColours.hatWhite,
    'p': PipColours.hatPink,
    'y': PipColours.hatYellow,
    'g': PipColours.hatGold,
    'r': PipColours.hatRuby,
    'b': PipColours.hatSapphire,
    'k': PipColours.hatBlack,
    'u': PipColours.hatPurple,
    'c': PipColours.hatGreen,
    'w': PipColours.hatWhite,
  };

  static const fieldColours = {
    'q': PipColours.plate,
    'Q': PipColours.plateShade,
    'm': PipColours.meal,
    'M': PipColours.mealDark,
    'u': PipColours.stem,
    'K': PipColours.face,
    'b': PipColours.bug,
    'B': PipColours.bugDark,
    'r': PipColours.bugEye,
    'h': PipColours.bladeShine,
    's': PipColours.blade,
    'e': PipColours.bladeEdge,
    'g': PipColours.guard,
    't': PipColours.hilt,
    'p': PipColours.petal,
    'P': PipColours.petalDark,
    'f': PipColours.flowerHeart,
    'w': PipColours.wing,
    'W': PipColours.wingDark,
    'k': PipColours.face,
    'o': PipColours.ball,
    'i': PipColours.ballStripe,
    '#': PipColours.cross,
    'v': PipColours.stem,
  };

  /// Round 64: the tavern on his day out, 33 x 26: a roof and chimney,
  /// wooden walls, a door, a sign with a mug, and a lit window with a
  /// counter (the plate flies out of it).
  static const tavern = [
    '........................CCC......',
    '........................ccc......',
    '.............rRRrRRr....ccc......',
    '...........RrRRrRRrRRr..ccc......',
    '.........RRrRRrRRrRRrRRr.........',
    '.......rRRrRRrRRrRRrRRrRRr.......',
    '.....RrRRrRRrRRrRRrRRrRRrRRr.....',
    '...RRrRRrRRrRRrRRrRRrRRrRRrRRr...',
    '.rRRrRRrRRrRRrRRrRRrRRrRRrRRrRRr.',
    'rrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrr',
    '..wWWWWWWWWWWWWWWWWWWWWWWWWWWWw..',
    '..wWssssssssWWWWWWWWWWWWWWWWWWw..',
    '..wWsSSyySSsWWWWWllllllllllllWw..',
    '..wwsssssssswwwwwlLLLLLLLLLLlww..',
    '..wWWWWWWWWWWWWWWlLLLLLLLLLLlWw..',
    '..wWWddddddWWWWWWlLLLLLLLLLLlWw..',
    '..wWWdDDDDdWWWWWWlLLLLLLLLLLlWw..',
    '..wwwdDDDDdwwwwwwlLLLLLLLLLLlww..',
    '..wWWdDDDDdWWWWWWlLLLLLLLLLLlWw..',
    '..wWWdDDDDdWWWWWWllllllllllllWw..',
    '..wWWdDDDkdWWWWWllllllllllllllw..',
    '..wwwdDDDDdwwwwwwwwwwwwwwwwwwww..',
    '..wWWdDDDDdWWWWWWWWWWWWWWWWWWWw..',
    '..wWWdDDDDdWWWWWWWWWWWWWWWWWWWw..',
    '..wWWdDDDDdWWWWWWWWWWWWWWWWWWWw..',
    '..wwwdDDDDdwwwwwwwwwwwwwwwwwwww..',
  ];

  /// Its table (10 wide, 6 tall) and his stool (8 x 3), outside.
  static const table = [
    'wwwwwwwwww',
    '.wWWWWWWw.',
    '..w....w..',
    '..w....w..',
    '..w....w..',
    '..w....w..',
  ];
  static const stool = ['wwwwwwww', '.w....w.', '.w....w.'];

  static const tavernColours = {
    'R': PipColours.roof,
    'r': PipColours.roofDark,
    'W': PipColours.wood,
    'w': PipColours.woodDark,
    'D': PipColours.door,
    'd': PipColours.doorDark,
    'k': PipColours.windowGlow,
    'L': PipColours.windowGlow,
    'l': PipColours.windowFrame,
    'c': PipColours.chimney,
    'C': PipColours.chimneyTop,
    's': PipColours.windowFrame,
    'S': PipColours.sign,
    'y': PipColours.mug,
  };

  /// Round 63: LEVEL UP, in little 3 x 5 letters, 31 x 5.
  static const levelUp = [
    'x...xxx.x.x.xxx.x.......x.x.xx.',
    'x...x...x.x.x...x.......x.x.x.x',
    'x...xx..x.x.xx..x.......x.x.xx.',
    'x...x...x.x.x...x.......x.x.x..',
    'xxx.xxx..x..xxx.xxx.....xxx.x..',
  ];

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
    // Round 52: his screen's pictures.
    'R': PipColours.heart,
  };

  /// How many rows a frame has.
  static int get height => _head.length + 3;
}
