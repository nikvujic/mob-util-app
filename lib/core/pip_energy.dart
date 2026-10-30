import 'dart:math' as math;

import 'package:the_app/core/pip_adventure.dart';
import 'package:the_app/core/pip_brain.dart';
import 'package:the_app/core/pip_quest.dart';

/// Pip's energy and sleep (Round 37): plain rules, worked out from the
/// clock, so nothing runs in the background. His energy is kept as a
/// level (0 to [full]) at a moment; at any later moment it's that level
/// less what he's used since: slowly while asleep, faster awake.
abstract final class PipEnergy {
  /// Full: three segments of his battery.
  static const full = 3.0;

  /// Energy used an hour awake, and asleep (much less, so he rarely runs
  /// out in the night). Round 58: twice as fast as before (a segment
  /// every 4 hours awake): about 4.25 a day, a little less than the
  /// batteries bring when each is given as it comes (4.8 a day). His
  /// charging station makes up for it ([PipLink.chargeTick]).
  static const awakePerHour = 1 / 4;
  static const asleepPerHour = 1 / 18;

  /// A battery comes every [batteryEvery] (Round 45: on the clock, they
  /// pile up while away, up to [maxBatteries]).
  static const batteryEvery = Duration(hours: 5);

  /// At most this many held.
  static const maxBatteries = 3;

  /// Bedtime and waking (local time): asleep from 23:00 to 8:00.
  static const bedHour = 23;
  static const wakeHour = 8;

  /// Whether he's asleep at [t] (for how fast he uses energy).
  static bool asleepAt(DateTime t) => t.hour >= bedHour || t.hour < wakeHour;

  /// Round 77: three taps on him asleep wake him ([wakeTaps], each within
  /// [wakeTapGap] of the last). At night, for [nightWake], once a night
  /// (so he can be charged), drowsy, then back to sleep; from [earlyHour],
  /// for the day. His energy goes as asleep all the same.
  static const wakeTaps = 3;
  static const wakeTapGap = Duration(milliseconds: 800);
  static const nightWake = Duration(minutes: 15);
  static const earlyHour = 7;

  /// Woken at [woken] early (from [earlyHour]): up for the day.
  static bool _early(DateTime woken) => woken.hour == earlyHour;

  /// Whether, woken at [woken], he's up at [now] (in his sleeping hours:
  /// after them he's up anyway).
  static bool wokenAt(DateTime? woken, DateTime now) {
    if (woken == null || now.isBefore(woken)) return false;
    if (_early(woken)) {
      return now
          .isBefore(DateTime(woken.year, woken.month, woken.day, wakeHour));
    }
    return now.isBefore(woken.add(nightWake));
  }

  /// Woken at night and up at [now]: drowsy (his face as at one segment,
  /// his pace too).
  static bool drowsyAt(DateTime? woken, DateTime now) =>
      woken != null && !_early(woken) && wokenAt(woken, now);

  /// Whether three taps may wake him at [now], last woken at [woken]: in
  /// his sleeping hours, early any time, at night if he wasn't this night.
  static bool mayWakeAt(DateTime? woken, DateTime now) {
    if (!asleepAt(now) || wokenAt(woken, now)) return false;
    if (now.hour == earlyHour) return true;
    return woken == null || nightKey(woken) != nightKey(now);
  }

  /// The next moment after [t] that sleep starts or ends.
  static DateTime _nextChange(DateTime t) {
    final wake = DateTime(t.year, t.month, t.day, wakeHour);
    final bed = DateTime(t.year, t.month, t.day, bedHour);
    if (t.isBefore(wake)) return wake;
    if (t.isBefore(bed)) return bed;
    return DateTime(t.year, t.month, t.day + 1, wakeHour);
  }

  /// Energy used from [from] to [to] (none if the clock went back).
  static double usedBetween(DateTime from, DateTime to) {
    var used = 0.0;
    var at = from;
    while (at.isBefore(to)) {
      final next = _nextChange(at);
      final end = next.isBefore(to) ? next : to;
      final hours = end.difference(at).inSeconds / 3600;
      used += hours * (asleepAt(at) ? asleepPerHour : awakePerHour);
      at = end;
    }
    return used;
  }

  /// [level] at [since], used until [now]: at least 0.
  static double levelAt(double level, DateTime since, DateTime now) =>
      math.max(0, level - usedBetween(since, now));

  /// Charging (Round 45): plugged in, he uses energy as ever, but can't
  /// run out: he stops at [chargingFloor] (unless he was out already).
  /// Round 58: his battery icon shows what he has (it used to keep the
  /// segments he was plugged in with, and could look full for days); at
  /// his station, watched, he charges fast ([PipLink.chargeTick]).
  static const chargingFloor = 0.05;
  static double chargingLevelAt(double level, DateTime since, DateTime now) =>
      level <= 0
          ? 0
          : math.max(
              levelAt(level, since, now), math.min(level, chargingFloor));

  /// [level] at [since] at [now], worked out by [rule] ([levelAt], or
  /// [chargingLevelAt]) except over the [paused] spans (Round 67: on his
  /// ski trip's bus he uses none).
  static double levelPausing(
    double level,
    DateTime since,
    DateTime now,
    List<(DateTime, DateTime)> paused, {
    double Function(double, DateTime, DateTime) rule = levelAt,
  }) {
    final spans = [...paused]..sort((a, b) => a.$1.compareTo(b.$1));
    var at = since;
    var left = level;
    for (final (from, to) in spans) {
      if (!to.isAfter(at) || !from.isBefore(now)) continue;
      if (from.isAfter(at)) left = rule(left, at, from);
      at = to.isBefore(now) ? to : now;
    }
    return now.isAfter(at) ? rule(left, at, now) : left;
  }

  /// When [level] at [since] runs out (a minute's precision), or null
  /// if it's already empty.
  static DateTime? emptyAt(double level, DateTime since) {
    if (level <= 0) return null;
    var left = level;
    var at = since;
    while (true) {
      final next = _nextChange(at);
      final rate = asleepAt(at) ? asleepPerHour : awakePerHour;
      final hours = next.difference(at).inSeconds / 3600;
      if (hours * rate >= left) {
        return at.add(Duration(minutes: (left / rate * 60).ceil()));
      }
      left -= hours * rate;
      at = next;
    }
  }

  /// The battery icon's segments for [level]: 3 above 2, 2 above 1, 1
  /// above 0, 0 empty.
  static int segments(double level) =>
      level <= 0 ? 0 : level.ceil().clamp(1, 3);

  /// When the battery after [now] comes.
  static DateTime nextBattery(DateTime now) => now.add(batteryEvery);

  /// Batteries come on the clock (Round 45): with [held] and the next due
  /// at [next], at [now] how many are held (at most [maxBatteries]) and
  /// when the next comes. Time away counts; the clock keeps going while
  /// he's full of them.
  static (int, DateTime) batteriesAt(int held, DateTime next, DateTime now) {
    if (now.isBefore(next)) return (held, next);
    final every = batteryEvery.inMinutes;
    final due = now.difference(next).inMinutes ~/ every + 1;
    return (
      math.min(maxBatteries, held + due),
      next.add(Duration(minutes: due * every)),
    );
  }
}

/// What to show of Pip when he's looked at (Round 37), from his energy
/// and the time of night.
enum PipShow {
  /// Up and about (coming out of the ground if it's a fresh start).
  awake,

  /// Seen between 23:00 and 0:00 for the first time that night: he
  /// falls asleep in front of you.
  fallAsleep,

  /// Simply asleep.
  asleep,

  /// Seen between 8:00 and 9:00 for the first time that morning: he
  /// wakes up in front of you.
  wakeUp,

  /// He ran out since last seen: he turns off and falls over (this wins
  /// at night too).
  powerOff,

  /// Off, and already seen so: lying there, screen dark.
  off,
}

/// The evening a night belongs to (its 23:00 is on this date), or the
/// morning's date, as a key like "2026-10-14".
String dayKey(DateTime t) => '${t.year}-${t.month.toString().padLeft(2, '0')}-'
    '${t.day.toString().padLeft(2, '0')}';

/// The night [t] is in (Round 77): its evening's [dayKey] (before
/// [PipEnergy.wakeHour], the day before's).
String nightKey(DateTime t) => dayKey(
    t.hour < PipEnergy.wakeHour ? DateTime(t.year, t.month, t.day - 1) : t);

/// What to show at [now], given his [level] then, whether he was already
/// seen off, and the night ([sleepSeen]) and morning ([wakeSeen]) whose
/// animations were already shown (as [dayKey]s). Round 77: woken by taps
/// at [wokenAt], he's up while [PipEnergy.wokenAt] says.
PipShow pipShowAt(
  DateTime now, {
  required double level,
  required bool offSeen,
  String? sleepSeen,
  String? wakeSeen,
  DateTime? wokenAt,
}) {
  if (level <= 0) return offSeen ? PipShow.off : PipShow.powerOff;
  if (PipEnergy.wokenAt(wokenAt, now)) return PipShow.awake;
  final h = now.hour;
  if (h == PipEnergy.bedHour) {
    return sleepSeen == dayKey(now) ? PipShow.asleep : PipShow.fallAsleep;
  }
  if (h < PipEnergy.wakeHour) return PipShow.asleep;
  if (h == PipEnergy.wakeHour) {
    return wakeSeen == dayKey(now) ? PipShow.awake : PipShow.wakeUp;
  }
  return PipShow.awake;
}

/// How Pip's life reaches his room (Round 37): what to show now, that
/// an animation was shown, and a battery given. The room is a widget and
/// can't read the app's data; this is handed to it.
abstract class PipLink {
  /// Collects a battery that's due, and says what to show now with his
  /// energy's segments.
  (PipShow, int) look();

  /// [show]'s animation started (or he was shown so): remembered, so it
  /// isn't played again.
  void shown(PipShow show);

  /// A battery given, if there's one and he isn't full or asleep: true
  /// if it was (he then gets its energy).
  bool giveBattery();

  /// Round 77: three taps on him asleep: woken, if he may be now (at
  /// night once, for a while; from 07:00 for the day). True if he was.
  bool wake();

  /// Woken at night and up: drowsy (his face and pace as at one segment).
  bool get drowsy;

  /// The phone is plugged in now (Round 44): his charging station. Round
  /// 64: null till Android has said (the app just opened: what was known
  /// last time made his station flash up and sink again).
  bool? get plugged;

  /// The time now (Round 52: how long his room was left).
  DateTime get now;

  /// Whether a notification came after [from], up to [to] (Round 52: his
  /// screen shows one).
  bool notifiedBetween(DateTime from, DateTime to);

  /// A medicine dose due and not marked (Round 53: the red dot): he
  /// reminds of it.
  bool get medicineDue;

  /// When a recipe was last read a while (Round 53): he eats, seen within
  /// the hour after.
  DateTime? get recipeReadAt;

  /// Someone's birthday today, or his own (Round 57): the party hat.
  bool get partyHat;

  /// Today's hat otherwise (Round 61): a day of the year's or a random
  /// day's ([pipHatOn]); null: none.
  PipHat? get hatToday;

  /// A segment from his station (Round 58): every [PipBrain.chargeEvery]
  /// he's at it, watched, and the drone's charge when he's off. True if
  /// he took it (not when full).
  bool chargeTick();

  /// His day out now (Round 63), or null: he isn't out. Looked at, so his
  /// break starts if it's due (Round 64); on it, how far through (0–1).
  PipOut? outing();

  /// His adventure level now (Round 63: a level up seen, a flash), by
  /// the XP shown (Round 73).
  int get level;

  /// Round 73: he's watched fighting on his day out ([on]), or not: his
  /// XP shown then goes up only as he strikes bugs ([defeated]).
  void fighting(bool on);

  /// A bug (or a [boss]) struck down, watched: the XP shown collects
  /// what he's gained since the last; a boss brings more. The XP shown
  /// gained.
  int defeated({bool boss = false});

  /// Whether a boss may still come today (one a day out).
  bool get bossDue;

  /// Round 74: how long he's been running on his day out (seconds, his
  /// break not counted), or null: not out. His field's trees go by with
  /// it, so the menu's room and Pip Home's show them alike.
  double? outRun();

  /// His ski trip now (Round 67): on its bus, snowy, skiing today.
  PipTripNow trip();

  /// Round 127: at his quest's work now (quest hours, on, not away):
  /// where the quest is and the seconds into its step; else null.
  PipQuestNow? questNow();
}

/// His quest's work at a moment (Round 127).
typedef PipQuestNow = ({QuestAt at, double seconds});

/// Out on his adventure (Round 63): on his break or not, and how far
/// through it (0 to 1).
typedef PipOut = ({bool onBreak, double breakDone});
