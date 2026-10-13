import 'dart:ui' show Color;

import 'package:the_app/core/theme.dart';

/// Where Pip is shown (Round 35): the menu's strip, or Pip Home's tall
/// scene. Each has its own version of a background.
enum PipPlace { room, home }

/// The part of the day his sky follows.
enum DayPart { night, dawn, day, dusk }

/// [now]'s part of the day: dawn 5:30–7, day to 18:30, dusk to 20:00,
/// night otherwise. (Later: with the seasons.)
DayPart dayPartAt(DateTime now) {
  final m = now.hour * 60 + now.minute;
  if (m < 5 * 60 + 30) return DayPart.night;
  if (m < 7 * 60) return DayPart.dawn;
  if (m < 18 * 60 + 30) return DayPart.day;
  if (m < 20 * 60) return DayPart.dusk;
  return DayPart.night;
}

/// A background for his field (Round 35): a sky for each part of the day.
/// One for now ("Field"); more can come, each saying how it looks.
enum PipBackground {
  field('Field');

  final String label;

  const PipBackground(this.label);

  /// The sky's top and bottom colours at [part].
  (Color, Color) skyAt(DayPart part) => switch (part) {
        DayPart.night => (PipColours.nightTop, PipColours.nightBottom),
        DayPart.dawn => (PipColours.dawnTop, PipColours.dawnBottom),
        DayPart.day => (PipColours.dayTop, PipColours.dayBottom),
        DayPart.dusk => (PipColours.duskTop, PipColours.duskBottom),
      };
}

/// Things drawn in his sky (Round 35). Each says where it may show: in
/// which places, at which parts of the day, on which backgrounds. Later
/// ones (snow, a Santa hat in the last week of the year...) say the same,
/// so nothing turns up where it doesn't belong.
enum PipProp {
  stars(
    places: {PipPlace.room, PipPlace.home},
    parts: {DayPart.night},
    backgrounds: {PipBackground.field},
  ),
  moon(
    places: {PipPlace.room, PipPlace.home},
    parts: {DayPart.night, DayPart.dusk},
    backgrounds: {PipBackground.field},
  ),
  sun(
    places: {PipPlace.room, PipPlace.home},
    parts: {DayPart.day, DayPart.dawn},
    backgrounds: {PipBackground.field},
  ),
  // The menu's strip is too low for clouds.
  clouds(
    places: {PipPlace.home},
    parts: {DayPart.day, DayPart.dawn, DayPart.dusk},
    backgrounds: {PipBackground.field},
  );

  final Set<PipPlace> places;
  final Set<DayPart> parts;
  final Set<PipBackground> backgrounds;

  const PipProp({
    required this.places,
    required this.parts,
    required this.backgrounds,
  });

  bool showsIn(PipPlace place, DayPart part, PipBackground background) =>
      places.contains(place) &&
      parts.contains(part) &&
      backgrounds.contains(background);
}

/// What's showing in one place at one moment: the one place that works it
/// out (Round 35), so the menu and Pip Home can't disagree.
class PipScene {
  final PipPlace place;

  /// Null: no background (turned off): his field on the page's own colour.
  final PipBackground? background;
  final DayPart part;
  final Set<PipProp> props;

  const PipScene._(this.place, this.background, this.part, this.props);

  factory PipScene.at(
    PipPlace place,
    DateTime now, {
    PipBackground? background = PipBackground.field,
  }) {
    final part = dayPartAt(now);
    return PipScene._(place, background, part, {
      if (background != null)
        for (final prop in PipProp.values)
          if (prop.showsIn(place, part, background)) prop,
    });
  }

  /// The sky's top and bottom colours, or null without a background.
  (Color, Color)? get sky => background?.skyAt(part);
}
