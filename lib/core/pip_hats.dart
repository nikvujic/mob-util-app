import 'package:the_app/core/pip_brain.dart';

/// Pip's hat for a day (Round 61; a birthday's party hat comes first, the
/// room's say): a day of the year's, else now and then a random one.
///
/// - A **Santa hat** from 25 December to 2 January.
/// - A **witch hat** on 31 October.
/// - **Bunny ears** on Easter Sunday and Monday (the Orthodox Easter,
///   as kept where the app's made).
/// - A **heart band** on 14 February.
/// - Any other day: an everyday hat, picked at random, about
///   [hatDaysAMonth] days a month; mostly none.
///
/// The same all day and on every screen (worked out from the date, and
/// [seed]: each Pip his own days), so it doesn't change as he's looked at
/// again.
PipHat? pipHatOn(DateTime day, {int seed = 0}) {
  if (seasonalHatOn(day) case final hat?) return hat;
  final roll = _hash('${day.year}-${day.month}-${day.day}#$seed');
  if (roll % 10000 >= hatChance * 10000) return null;
  final everyday = [
    for (final hat in PipHat.values)
      if (hat.everyday && hat != PipHat.party) hat,
  ];
  return everyday[(roll ~/ 10000) % everyday.length];
}

/// About this many hat days a month (6 or 7).
const hatDaysAMonth = 6.5;

/// A day's chance of a hat.
const hatChance = hatDaysAMonth / 30.44;

/// The hat [day] has of itself, if any.
PipHat? seasonalHatOn(DateTime day) {
  final (m, d) = (day.month, day.day);
  if ((m == 12 && d >= 25) || (m == 1 && d <= 2)) return PipHat.santa;
  if (m == 10 && d == 31) return PipHat.witch;
  if (m == 2 && d == 14) return PipHat.heart;
  final easter = orthodoxEaster(day.year);
  final monday = DateTime(easter.year, easter.month, easter.day + 1);
  if (_sameDay(day, easter) || _sameDay(day, monday)) return PipHat.bunny;
  return null;
}

/// The Orthodox Easter Sunday of [year] (Meeus's Julian reckoning, moved
/// to the Gregorian calendar: 13 days, right from 1900 to 2099).
DateTime orthodoxEaster(int year) {
  final a = year % 4, b = year % 7, c = year % 19;
  final d = (19 * c + 15) % 30;
  final e = (2 * a + 4 * b - d + 34) % 7;
  final month = (d + e + 114) ~/ 31;
  final dayOf = (d + e + 114) % 31 + 1;
  return DateTime(year, month, dayOf + 13);
}

bool _sameDay(DateTime a, DateTime b) =>
    a.year == b.year && a.month == b.month && a.day == b.day;

/// A steady hash of [text] (FNV-1a, 31 bits): the same on every run.
int _hash(String text) {
  var h = 0x811c9dc5;
  for (final unit in text.codeUnits) {
    h ^= unit;
    h = (h * 0x01000193) & 0xffffffff;
  }
  // A last mix, so neighbouring dates spread.
  h ^= h >> 15;
  h = (h * 0x2c1b3c6d) & 0xffffffff;
  h ^= h >> 12;
  return h & 0x7fffffff;
}
