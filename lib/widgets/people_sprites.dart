import 'dart:ui' show Color;

import 'package:the_app/core/theme.dart';

/// People's faces (Round 108): 16 x 16, one letter a pixel ('.' empty),
/// as drafted (`docs/people_avatar_drafts.png`): an age group's face for
/// each gender, its hair's colours named.
abstract final class PeopleSprites {
  static const size = 16;

  /// The ages, youngest first (as the app's age groups).
  static const ages = 7;

  /// A face: [age] 0 (baby) to 6 (old); [female] or not.
  static List<String> face(int age, {required bool female}) =>
      (female ? _female : _male)[age.clamp(0, ages - 1)].$2;

  /// Its colours: letter to colour.
  static Map<String, Color> palette(int age, {required bool female}) => {
        ..._base,
        ..._hair[(female ? _female : _male)[age.clamp(0, ages - 1)].$1] ??
            const {},
        'T': female ? PeopleColours.femaleShirt : PeopleColours.maleShirt,
      };

  static const _base = {
    'K': PeopleColours.outline,
    'S': PeopleColours.skin,
    's': PeopleColours.skinShade,
    'E': PeopleColours.eye,
    'M': PeopleColours.mouth,
    'P': PeopleColours.cheek,
    'F': PeopleColours.freckle,
    'L': PeopleColours.glasses,
    'B': PeopleColours.beard,
    'C': PeopleColours.pacifier,
    'R': PeopleColours.ribbon,
    'G': PeopleColours.grey,
    'g': PeopleColours.greyDark,
    'W': PeopleColours.white,
    'w': PeopleColours.whiteShade,
    'Y': PeopleColours.blonde,
    'y': PeopleColours.blondeShade,
  };

  static const _hair = {
    'brown': {'H': PeopleColours.brown, 'h': PeopleColours.brownLight},
    'dark': {'H': PeopleColours.dark, 'h': PeopleColours.darkLight},
    'auburn': {'H': PeopleColours.auburn, 'h': PeopleColours.auburnLight},
  };

  static const _male = <(String, List<String>)>[
    // Baby.
    (
      'brown',
      [
        '................',
        '......HHH.......',
        '.......H........',
        '....KKKKKKKK....',
        '...KSSSSSSSSK...',
        '..KSSSSSSSSSSK..',
        '..KSSSSSSSSSSK..',
        '.KSSSEESSEESSSK.',
        '.KSSSEESSEESSSK.',
        '.KSPPSSSSSSPPSK.',
        '.KSSSSSCCSSSSSK.',
        '..KSSSSCCSSSSK..',
        '..KSSSSSSSSSSK..',
        '...KKSSSSSSKK...',
        '.....KKKKKK.....',
        '................',
      ]
    ),
    // Kid.
    (
      'brown',
      [
        '................',
        '....HHHHHHHH....',
        '...HHhHHHHHHH...',
        '...HHHHHHHHHH...',
        '...KHSSSSSSHK...',
        '...KSSSSSSSSK...',
        '...KSEESSEESK...',
        '...KSEESSEESK...',
        '..KsSFSSSSFSsK..',
        '...KSSSMMSSSK...',
        '....KSSSSSSK....',
        '.....KKSSKK.....',
        '....TTKSSKTT....',
        '...TTTTTTTTTT...',
        '..TTTTTTTTTTTT..',
        '..TTTTTTTTTTTT..',
      ]
    ),
    // Teen.
    (
      'dark',
      [
        '....H.H..H.H....',
        '...HHHHHHHHHH...',
        '..HHHhHHHHhHHH..',
        '...HHHHHHHHHH...',
        '...KHHSSSSHHK...',
        '...KSSSSSSSSK...',
        '...KSEESSEESK...',
        '...KSSSSSSSSK...',
        '..KsSSSSSSSSsK..',
        '...KSSSSSSSSK...',
        '...KSSMMMMSSK...',
        '....KSSSSSSK....',
        '.....KKSSKK.....',
        '...TTTKSSKTTT...',
        '..TTTTTTTTTTTT..',
        '..TTTTTTTTTTTT..',
      ]
    ),
    // Adult.
    (
      'brown',
      [
        '................',
        '....HHHHHHHH....',
        '...HHHHHHHhHH...',
        '...HHHHHHHHHH...',
        '...KHSSSSSSSK...',
        '...KSSSSSSSSK...',
        '...KSEESSEESK...',
        '...KSSSSSSSSK...',
        '..KsSSSSSSSSsK..',
        '...KSSSSSSSSK...',
        '...KSSMMMMSSK...',
        '....KSSSSSSK....',
        '.....KKSSKK.....',
        '...TTTKSSKTTT...',
        '..TTTTTTTTTTTT..',
        '..TTTTTTTTTTTT..',
      ]
    ),
    // Older adult.
    (
      'brown',
      [
        '................',
        '................',
        '.....HHgHHH.....',
        '...HHSSSSSSHH...',
        '...KHSSSSSSHK...',
        '...KSSSSSSSSK...',
        '...KSEESSEESK...',
        '...KSSSSSSSSK...',
        '..KsSSSSSSSSsK..',
        '...KBSSSSSSBK...',
        '...KBBMMMMBBK...',
        '....KBBBBBBK....',
        '.....KKBBKK.....',
        '...TTTKSSKTTT...',
        '..TTTTTTTTTTTT..',
        '..TTTTTTTTTTTT..',
      ]
    ),
    // Older.
    (
      '',
      [
        '................',
        '................',
        '.....GGGGGG.....',
        '...GGSSSSSSGG...',
        '...KGSSSSSSGK...',
        '...KLLLSSLLLK...',
        '...KLELLLLELK...',
        '...KLLLSSLLLK...',
        '..KsSSSSSSSSsK..',
        '...KSsSSSSsSK...',
        '...KSSMMMMSSK...',
        '....KSSSSSSK....',
        '.....KKSSKK.....',
        '...TTTKSSKTTT...',
        '..TTTTTTTTTTTT..',
        '..TTTTTTTTTTTT..',
      ]
    ),
    // Old.
    (
      '',
      [
        '................',
        '................',
        '.....KKKKKK.....',
        '....KSSSSSSK....',
        '...KSSsSSsSSK...',
        '..WKLLLSSLLLKW..',
        '..WKLELLLLELKW..',
        '..WKLLLSSLLLKW..',
        '..KsSSSSSSSSsK..',
        '...KSWWWWWWSK...',
        '...KSsSMMSsSK...',
        '....KSSSSSSK....',
        '.....KKSSKK.....',
        '...TTTKSSKTTT...',
        '..TTTTTTTTTTTT..',
        '..TTTTTTTTTTTT..',
      ]
    ),
  ];

  static const _female = <(String, List<String>)>[
    // Baby.
    (
      'brown',
      [
        '................',
        '......R..R......',
        '......RRRR......',
        '....KKKKKKKK....',
        '...KSSSSSSSSK...',
        '..KSSSSSSSSSSK..',
        '..KSSSSSSSSSSK..',
        '.KSSSEESSEESSSK.',
        '.KSSSEESSEESSSK.',
        '.KSPPSSSSSSPPSK.',
        '.KSSSSSCCSSSSSK.',
        '..KSSSSCCSSSSK..',
        '..KSSSSSSSSSSK..',
        '...KKSSSSSSKK...',
        '.....KKKKKK.....',
        '................',
      ]
    ),
    // Kid.
    (
      '',
      [
        '................',
        '....YYYYYYYY....',
        '...YYyYYYYYYY...',
        '.RYYYYYYYYYYYYR.',
        '.YYKYSSSSSSYKYY.',
        '..YKSSSSSSSSKY..',
        '...KSEESSEESK...',
        '...KSEESSEESK...',
        '..KsSPSSSSPSsK..',
        '...KSSSMMSSSK...',
        '....KSSSSSSK....',
        '.....KKSSKK.....',
        '....TTKSSKTT....',
        '...TTTTTTTTTT...',
        '..TTTTTTTTTTTT..',
        '..TTTTTTTTTTTT..',
      ]
    ),
    // Teen.
    (
      'brown',
      [
        '................',
        '....HHHHHHHH....',
        '...HHHHHHhHHH...',
        '..HHHHHHHHHRHH..',
        '..HKHHSSSSHHKH..',
        '..HKSSSSSSSSKH..',
        '..HKSEESSEESKH..',
        '..HKSSSSSSSSKH..',
        '..HKSPSSSSPSKH..',
        '..HKSSSMMSSSKH..',
        '..HHKSSSSSSKHH..',
        '..HHHKKSSKKHHH..',
        '..HHTTKSSKTTHH..',
        '..HTTTTTTTTTTH..',
        '..TTTTTTTTTTTT..',
        '..TTTTTTTTTTTT..',
      ]
    ),
    // Adult.
    (
      'auburn',
      [
        '................',
        '....HHHHHHHH....',
        '...HHHHHHhHHH...',
        '..HHHHHHHHHHHH..',
        '..HKHHSSSSHHKH..',
        '..HKSSSSSSSSKH..',
        '..HKSEESSEESKH..',
        '..HKSSSSSSSSKH..',
        '..HKSSSSSSSSKH..',
        '..HKSSMMMMSSKH..',
        '..HHKSSSSSSKHH..',
        '..HHHKKSSKKHHH..',
        '..HHTTKSSKTTHH..',
        '..HTTTTTTTTTTH..',
        '..TTTTTTTTTTTT..',
        '..TTTTTTTTTTTT..',
      ]
    ),
    // Older adult.
    (
      'dark',
      [
        '................',
        '....HHHHHHHH....',
        '...HHHHgHHHHH...',
        '..HHHHHHHHHHHH..',
        '..HKHHHHSSSSKH..',
        '..HKSSSSSSSSKH..',
        '..HKSEESSEESKH..',
        '..HKSSSSSSSSKH..',
        '..HKSSSSSSSSKH..',
        '..HHKSMMMMSKHH..',
        '...HKSSSSSSKH...',
        '....HKKSSKKH....',
        '......KSSK......',
        '...TTTKSSKTTT...',
        '..TTTTTTTTTTTT..',
        '..TTTTTTTTTTTT..',
      ]
    ),
    // Older.
    (
      '',
      [
        '................',
        '....GGGGGGGG....',
        '...GGGGgGGGGG...',
        '..GGGGGGGGGGGG..',
        '..GKGGGGSSSSKG..',
        '..GKLLLSSLLLKG..',
        '..GKLELLLLELKG..',
        '..GKLLLSSLLLKG..',
        '..GKSsSSSSsSKG..',
        '..GGKSMMMMSKGG..',
        '...GKSSSSSSKG...',
        '....GKKSSKKG....',
        '......KSSK......',
        '...TTTKSSKTTT...',
        '..TTTTTTTTTTTT..',
        '..TTTTTTTTTTTT..',
      ]
    ),
    // Old.
    (
      '',
      [
        '......WWWW......',
        '.....WWwWWW.....',
        '....WWWWWWWW....',
        '...WWWWWWWWWW...',
        '..WWKSsSSsSKWW..',
        '..WKLLLSSLLLKW..',
        '..WKLELLLLELKW..',
        '..WKLLLSSLLLKW..',
        '..WKSSSSSSSSKW..',
        '...KSsSSSSsSK...',
        '...KSSSMMSSSK...',
        '....KSSSSSSK....',
        '.....KKSSKK.....',
        '...TTTKSSKTTT...',
        '..TTTTTTTTTTTT..',
        '..TTTTTTTTTTTT..',
      ]
    ),
  ];
}
