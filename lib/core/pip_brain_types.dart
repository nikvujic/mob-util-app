part of 'pip_brain.dart';

// Pip's brain's types (Round 138: out of `pip_brain.dart`): what he's
// doing, what may start during what (the one table), his hats, screens,
// faces, frames and the animations Pip Home's list plays.

/// What Pip is doing (Round 26).
enum PipActivity {
  /// Not hatched yet (Round 34): an egg in the middle of the room, cracked
  /// a little more by taps.
  egg,

  /// Out of the egg: its top pops off, he jumps out and lands, the shell
  /// fades.
  hatching,

  /// The first time the menu opens: the ground cracks, he comes up out
  /// of it, hops and lands.
  spawning,

  /// Standing about (blinking now and then).
  standing,

  /// Walking to a spot.
  walking,

  /// Round 37: eyes closing, he settles down to sleep.
  fallingAsleep,

  /// Asleep, settled down, little z's rising.
  asleep,

  /// Round 77: woken by taps, still lying there: one eye opens and looks
  /// about a moment, shuts, then he wakes ([wakingUp]).
  stirring,

  /// Waking: eyes open, he gets up with a little hop.
  wakingUp,

  /// Out of energy: his screen flickers out and he falls over.
  poweringOff,

  /// Lying there, his screen dark.
  off,

  /// A battery flies to him (if one was given), his screen comes back on
  /// and he gets up.
  poweringOn,

  /// A battery dropped in his room: he walks over and picks it up.
  fetching,

  /// Round 44: the phone plugged in, he hurries to his charging station.
  toStation,

  /// At the station: his hands pop in, he takes the plug off its hook,
  /// plugs it into his side, and the hands pop away.
  plugging,

  /// Plugged in, his antenna lit, his screen changing now and then.
  charging,

  /// Unplugging: the same as plugging in, backwards.
  unplugging,

  // Round 52: more ways in, and things happening in his field.

  /// Dropping in from the sky: he falls, lands with a squash and dust.
  falling,

  /// Thrown in from the side (the menu's swing): tumbling through the
  /// air, landing with a thump.
  thrown,

  /// After being thrown in: a scowl, a fist shaken, cross words.
  angry,

  /// Bugs crawl in; he pops out a sword and fights them off.
  bugHunt,

  /// Something on his screen for a while (a notification, or his medicine).
  showing,

  /// A flower comes up; he walks over, picks it, holds it a while.
  flower,

  /// A butterfly flutters by; he watches it.
  butterfly,

  /// A ball rolls in; he walks up and kicks it away.
  ball,

  /// At dusk or night: a shooting star streaks over; he looks up at it.
  stargazing,

  /// A little dance: hops, turning to the beat, music on his screen.
  dancing,

  /// Round 53: eating from a plate in his hands, a few bites, crumbs.
  eating,

  /// Round 63: out on his adventure (12:00 to 18:00): running, the
  /// ground moving under him, striking bugs ([PipRun]).
  adventuring,

  /// Round 67: on his ski trip's bus ([PipBus]).
  riding,

  /// Round 75: in his tent in a storm, awake (`core/pip_weather.dart`):
  /// keeping still till it's over.
  sheltering,

  /// One of the weather's events ([PipWeatherEvent]).
  weatherEvent,

  /// The weather's changed: he stops and looks up.
  lookingUp,

  /// Round 127: at his quest's work (`core/pip_quest_scene.dart`): in his
  /// house area, out gathering, or walking between.
  questing,
}

/// A hat on his head (Round 57): the party hat on a birthday, or one
/// tried on in Pip Home's Hats.
enum PipHat {
  party('Party hat'),
  crown('Crown'),
  topHat('Top hat'),
  wizard('Wizard hat'),
  cap('Cap'),
  beanie('Beanie'),

  /// Round 61: for days of the year (see `pip_hats.dart`).
  santa('Santa hat', everyday: false),
  witch('Witch hat', everyday: false),
  bunny('Bunny ears', everyday: false),
  heart('Heart band', everyday: false),

  /// Round 67: all his ski days.
  skiBeanie('Ski beanie', everyday: false),

  /// Round 128: at his quest's work in rain, snow or a storm.
  rainHat('Rain hat', everyday: false);

  final String label;

  /// Worn on a random day (Round 61); the others are for their days.
  final bool everyday;

  const PipHat(this.label, {this.everyday = true});
}

/// A buzz of the phone, how strong (Round 53).
enum PipBuzz { light, medium, heavy }

/// How he comes into his field (Round 52): out of the ground, from the
/// sky, or thrown in from the side (only in the menu, by its swing).
enum PipEntrance { ground, sky, side }

/// What his screen can show for a while (Round 52): notifications (when
/// one comes), and with some events (Round 53: not for fun on its own).
enum PipScreen {
  envelope(notification: true),
  bell(notification: true),
  alert(notification: true),

  /// Round 53: a pill, reminding of a medicine (the medicine red dot).
  pill,

  /// Dancing.
  music,

  /// Proud (after the bugs) or glad (holding a flower).
  happy;

  /// Shown when a notification comes (Round 53: no more pictures for fun:
  /// the others go with an event).
  final bool notification;

  /// Shown with a hop: a notification, or his medicine reminder.
  bool get hops => notification || this == PipScreen.pill;

  const PipScreen({this.notification = false});
}

/// What his screen shows while he charges (Round 44), now and then
/// another, at random.
enum ChargeScreen {
  happy,
  battery,
  static,
  bolt,
  content,
  sparks,
  humming,
  blinking,
}

/// How his face looks (Round 37): by his energy, asleep, or off.
enum PipFace {
  normal,
  tired,
  veryTired,
  asleep,
  off,

  /// Round 52: thrown in, and cross about it.
  angry,

  /// Round 57: waking up, a big yawn (eyes shut, mouth wide).
  yawn,

  /// Round 77: woken at night, one eye open (the other shut).
  peek,
}

/// His animations that can be played on request (Round 35: Pip Home's
/// Animations): each one he has, by name.
enum PipAnimation {
  spawn('Out of the ground'),
  hatch('Out of his egg'),
  walk('A walk'),
  blink('A blink'),
  turn('A look round'),
  // Round 37: in the list they come back on their own (asleep, then up
  // again; off, then on again).
  fallAsleep('Falling asleep'),
  powerOff('Running out'),
  wakeUp('Waking up', listed: false),
  // Round 77: three taps at night; in the list, he falls asleep first.
  nightWake('Woken at night'),
  powerOn('Back on', listed: false),
  // Round 54: in the list too, as a preview (no battery used).
  fetch('Changing his battery'),
  // Round 44: the station rises, he plugs in, charges a while, unplugs.
  charge('Charging'),
  // Round 52: more entrances, and things that happen now and then.
  fromSky('Falling from the sky'),
  fromSide('Thrown in from the side'),
  bugs('Fighting bugs'),
  notified('A notification'),
  flower('Picking a flower'),
  butterfly('Watching a butterfly'),
  ball('Kicking a ball'),
  shootingStar('A shooting star'),
  dance('A little dance'),
  // Round 53: a medicine due (the red dot), and after a recipe.
  medicine('A medicine reminder'),
  eat('Eating'),
  // Round 75: the weather's (Pip Home's list tries the weather on too).
  puddle('Jumping in a puddle'),
  twirl('A twirl under his umbrella'),
  handOut('A hand out in the drizzle'),
  flakes('Snowflakes on his tongue'),
  snowman('Building a snowman'),
  snowball('A snowball at you'),
  lost('Lost in the fog');

  final String label;

  /// In Pip Home's Animations list (the others only happen for real).
  final bool listed;

  const PipAnimation(this.label, {this.listed = true});
}

/// What may start while he's doing something (Round 35): the one table
/// that keeps things from clashing. Mid-entrance (out of the ground or
/// his egg) nothing interrupts; an egg only hatches by its taps. New
/// activities and events (batteries, bugs...) get their row and column
/// here, and the table is tested whole.
///
/// Round 37: in the middle of falling asleep, waking, turning off or on,
/// or picking up a battery, nothing starts either. Asleep, he can only
/// wake (or run out); off, only come back on (a battery). Up and about,
/// anything but waking or coming back on.
///
/// Round 44: hurrying to his station, plugging in or out, or charging,
/// nothing starts (asleep at night, he first unplugs: [PipBrain.show]).
///
/// Round 52: an entrance (from the sky, thrown in, angry after) or an
/// event (bugs, his screen, a flower, a butterfly, a ball) runs its
/// course; they start only while he's up and about.
bool mayStart(PipActivity doing, PipAnimation next) => switch (doing) {
      PipActivity.egg ||
      PipActivity.hatching ||
      PipActivity.spawning ||
      PipActivity.fallingAsleep ||
      PipActivity.stirring ||
      PipActivity.wakingUp ||
      PipActivity.poweringOff ||
      PipActivity.poweringOn ||
      PipActivity.fetching ||
      PipActivity.toStation ||
      PipActivity.plugging ||
      PipActivity.charging ||
      PipActivity.unplugging ||
      // Round 52: an entrance, or an event, runs its course.
      PipActivity.falling ||
      PipActivity.thrown ||
      PipActivity.angry ||
      PipActivity.bugHunt ||
      PipActivity.flower ||
      PipActivity.butterfly ||
      PipActivity.ball ||
      PipActivity.stargazing ||
      PipActivity.dancing ||
      PipActivity.eating ||
      // Round 75: the weather's events, and looking up at it, too.
      PipActivity.weatherEvent ||
      PipActivity.lookingUp ||
      // Round 63: out, nothing else happens till he's back; Round 67: on
      // the bus, nor then.
      PipActivity.adventuring ||
      PipActivity.riding =>
        false,
      // Round 55: something on his screen (his medicine reminder, which
      // keeps on) gives way to bedtime, or running out.
      PipActivity.showing =>
        next == PipAnimation.fallAsleep || next == PipAnimation.powerOff,
      PipActivity.asleep => next == PipAnimation.wakeUp ||
          next == PipAnimation.nightWake ||
          next == PipAnimation.powerOff,
      // Round 75: in his tent in a storm, he keeps still: nothing starts
      // but sleep, or running out (a battery flies into it). Round 127: at
      // his quest's work, the same (spec 8: only a power down stops it).
      PipActivity.sheltering ||
      PipActivity.questing =>
        next == PipAnimation.fallAsleep || next == PipAnimation.powerOff,
      PipActivity.off => next == PipAnimation.powerOn,
      PipActivity.standing ||
      PipActivity.walking =>
        next != PipAnimation.wakeUp && next != PipAnimation.powerOn,
    };

/// The station's drone's trip (Round 58).
enum DronePhase { rising, out, beaming, back, sinking }

/// Pip's frames, by name; drawn by `widgets/pip_room.dart`.
enum PipFrame {
  idle,
  blink,
  step1,
  step2,
  step3,
  step4,
  oh,
  tuck,

  /// Round 74: sitting (legs tucked, as he looks), and chewing so.
  sit,
  chew,
}
