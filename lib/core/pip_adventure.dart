import 'dart:math' as math;

/// Pip's adventures (Round 63, `docs/ADVENTURES_SPEC.md`): plain rules,
/// worked out from the clock, as his energy is. Once registered, he goes
/// out every day from [startHour] to [endHour], gaining an XP a minute.
abstract final class PipAdventure {
  /// He's out from 12:00 to 18:00 (local time).
  static const startHour = 12;
  static const endHour = 18;

  /// Registering is offered from 13:00 to 17:00 (an hour in from each
  /// end of his day out).
  static const registerFrom = 13;
  static const registerUntil = 17;

  /// Powered down at 12:00, a battery until 17:00 sends him out.
  static const lastStartHour = 17;

  /// His break (Round 64): half an hour, starting when he's looked at
  /// between 14:00 and 16:00. Round 66: if he was seen setting off (just
  /// registered, or back on with a battery), not till he's gone unseen at
  /// least [unseenFor] (so he doesn't set off and stop at once).
  static const breakFromHour = 14;
  static const breakUntilHour = 16;
  static const breakLength = Duration(minutes: 30);
  static const unseenFor = Duration(minutes: 5);

  /// An XP a minute out: a full day is 360.
  static const xpPerDay = (endHour - startHour) * 60;

  /// The start and end of [t]'s day out.
  static DateTime startOf(DateTime t) =>
      DateTime(t.year, t.month, t.day, startHour);
  static DateTime endOf(DateTime t) =>
      DateTime(t.year, t.month, t.day, endHour);

  /// Whether registering is offered at [t].
  static bool canRegisterAt(DateTime t) =>
      t.hour >= registerFrom && t.hour < registerUntil;

  /// Whole minutes from [from] to [to] (none if the clock went back).
  static int minutesBetween(DateTime from, DateTime to) =>
      to.isAfter(from) ? to.difference(from).inMinutes : 0;

  /// Whether a break may start at [now] for an adventure out since
  /// [from] (none had yet); not while his setting off was [startSeen]
  /// (and he hasn't gone unseen since).
  static bool breakDueAt(DateTime now, DateTime from,
          {bool startSeen = false}) =>
      now.hour >= breakFromHour &&
      now.hour < breakUntilHour &&
      !startSeen &&
      !now.isBefore(from) &&
      now.isBefore(endOf(from));

  /// The days out (of 360 XP) [level] takes. The yearly targets: about
  /// 90 after a year out, 160 after two, 230 after three, 280 after
  /// four, then 50 a year. Year one is a curve (early levels come fast),
  /// then straight lines; each level costs a little more than the last.
  static double _daysFor(int level) {
    if (level <= 1) return 0;
    if (level <= 90) return 365 * math.pow((level - 1) / 89, 1.25).toDouble();
    if (level <= 230) return 365 + (level - 90) * 365 / 70;
    return 1095 + (level - 230) * 365 / 50;
  }

  /// The XP [level] is reached at (level 1 at none).
  static int xpFor(int level) {
    final xp = _daysFor(level) * xpPerDay;
    // Whole XP, without a float's crumbs making 131400 into 131401.
    return (xp - 1e-6).ceil();
  }

  /// His level with [xp]: the highest whose [xpFor] is reached. No cap.
  static int levelFor(int xp) {
    var low = 1;
    var high = 2;
    while (xpFor(high) <= xp) {
      low = high;
      high *= 2;
    }
    while (high - low > 1) {
      final mid = (low + high) ~/ 2;
      if (xpFor(mid) <= xp) {
        low = mid;
      } else {
        high = mid;
      }
    }
    return low;
  }

  /// How far into his level he is (0 to 1), for the XP bar.
  static double progressFor(int xp) {
    final level = levelFor(xp);
    final from = xpFor(level);
    final to = xpFor(level + 1);
    return ((xp - from) / (to - from)).clamp(0.0, 1.0);
  }

  /// His titles: a new one every 10 levels, up to 80.
  static const titles = [
    'Rookie',
    'Bug Squasher',
    'Squire',
    'Debugger',
    'Knight',
    'Veteran',
    'Champion',
    'Hero',
    'Legend',
  ];

  /// The title at [level].
  static String titleFor(int level) =>
      titles[math.min(titles.length - 1, math.max(0, level) ~/ 10)];
}

/// Which way his ski trip's bus is going (Round 67).
enum TripLeg { there, back }

/// His ski trip at a moment (Round 67; worked out from Dates in
/// `providers/pip_trip.dart`): on the bus (which way, how far, 0 to 1)
/// or not; the snowy look; and whether today his adventure is skiing.
typedef PipTripNow = ({
  TripLeg? leg,
  double progress,
  bool snowy,
  bool skiing,
});

/// No trip: the usual day.
const PipTripNow noTrip = (leg: null, progress: 0, snowy: false, skiing: false);
