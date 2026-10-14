import 'dart:math' as math;

/// Pip's energy and sleep (Round 37): plain rules, worked out from the
/// clock, so nothing runs in the background. His energy is kept as a
/// level (0 to [full]) at a moment; at any later moment it's that level
/// less what he's used since: slowly while asleep, faster awake.
abstract final class PipEnergy {
  /// Full: three segments of his battery.
  static const full = 3.0;

  /// Energy used an hour awake, and asleep (much less, so he rarely runs
  /// out in the night).
  static const awakePerHour = 1 / 10;
  static const asleepPerHour = 1 / 36;

  /// A battery comes every [batteryEvery], give or take [batterySpread].
  static const batteryEvery = Duration(hours: 6);
  static const batterySpread = Duration(minutes: 90);

  /// At most this many held.
  static const maxBatteries = 3;

  /// Bedtime and waking (local time): asleep from 23:00 to 8:00.
  static const bedHour = 23;
  static const wakeHour = 8;

  /// Whether he's asleep at [t] (for how fast he uses energy).
  static bool asleepAt(DateTime t) => t.hour >= bedHour || t.hour < wakeHour;

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

  /// When the battery after one at [now] comes: [batteryEvery], give or
  /// take up to [batterySpread], picked by [random].
  static DateTime nextBattery(DateTime now, math.Random random) {
    final spread = batterySpread.inMinutes;
    final minutes =
        batteryEvery.inMinutes - spread + random.nextInt(2 * spread + 1);
    return now.add(Duration(minutes: minutes));
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

/// What to show at [now], given his [level] then, whether he was already
/// seen off, and the night ([sleepSeen]) and morning ([wakeSeen]) whose
/// animations were already shown (as [dayKey]s).
PipShow pipShowAt(
  DateTime now, {
  required double level,
  required bool offSeen,
  String? sleepSeen,
  String? wakeSeen,
}) {
  if (level <= 0) return offSeen ? PipShow.off : PipShow.powerOff;
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
}
