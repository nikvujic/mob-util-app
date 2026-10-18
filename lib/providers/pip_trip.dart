import 'package:the_app/core/pip_adventure.dart';
import 'package:the_app/models/date_entry.dart';

/// Pip's ski trips (Round 65–67, `docs/ADVENTURES_SPEC.md` section 8):
/// plain rules from Dates and the clock. A Skiing holiday makes its days
/// snowy and his adventures skiing; with travel set, a bus takes him
/// there and back.

/// A bus ride: from when, until when, which way.
typedef BusRide = ({DateTime from, DateTime to, TripLeg leg});

abstract final class PipTrip {
  /// The snowy look comes in this far into the ride there, and goes this
  /// far into the ride back.
  static const snowThere = 0.8;
  static const snowBack = 0.2;

  /// The Skiing holidays in [book].
  static Iterable<DateEntry> _skiing(DateBook book) =>
      book.dates.where((d) => d.kindNow == DateKind.skiing);

  /// The starts of [date]'s times near [at] (the year before to the year
  /// after: a trip may run into the new year).
  static Iterable<DateTime> _startsNear(DateEntry date, DateTime at) sync* {
    for (final y in [at.year - 1, at.year, at.year + 1]) {
      final start = date.inYear(y);
      if (start != null) yield start;
    }
  }

  /// Every bus ride around [at] (a year either way).
  static List<BusRide> ridesNear(DateBook book, DateTime at) => [
        for (final date in _skiing(book))
          for (final start in _startsNear(date, at))
            if (date.tripsFrom(start) case final t?) ...[
              (from: t.there, to: t.there.add(t.length), leg: TripLeg.there),
              (from: t.back, to: t.back.add(t.length), leg: TripLeg.back),
            ],
      ];

  /// The time he's away on [date]'s trip from [start] in the snowy look:
  /// from 80% of the ride there to 20% of the ride back; without travel,
  /// its days.
  static (DateTime, DateTime) _snowy(DateEntry date, DateTime start) {
    final t = date.tripsFrom(start);
    if (t == null) {
      final end = date.endFrom(start);
      return (start, DateTime(end.year, end.month, end.day + 1));
    }
    return (
      t.there.add(t.length * snowThere),
      t.back.add(t.length * snowBack),
    );
  }

  /// When he's at the resort (off the bus): from arriving to leaving back;
  /// without travel, its days.
  static (DateTime, DateTime) _resort(DateEntry date, DateTime start) {
    final t = date.tripsFrom(start);
    if (t == null) return _snowy(date, start);
    return (t.there.add(t.length), t.back);
  }

  static bool _within(DateTime at, (DateTime, DateTime) span) =>
      !at.isBefore(span.$1) && at.isBefore(span.$2);

  /// Whether the bus is on the road at any time in [day]'s 12:00–18:00:
  /// no adventure shown that day (he still gains its XP).
  static bool busDay(DateBook book, DateTime day) {
    final from = PipAdventure.startOf(day), to = PipAdventure.endOf(day);
    return ridesNear(book, day)
        .any((r) => r.from.isBefore(to) && r.to.isAfter(from));
  }

  /// Whether [day]'s day out is skiing: all of 12:00–18:00 at the resort.
  static bool skiDay(DateBook book, DateTime day) {
    final from = PipAdventure.startOf(day), to = PipAdventure.endOf(day);
    for (final date in _skiing(book)) {
      for (final start in _startsNear(date, day)) {
        final (a, b) = _resort(date, start);
        if (!from.isBefore(a) && !to.isAfter(b)) return true;
      }
    }
    return false;
  }

  /// His trip at [now].
  static PipTripNow at(DateBook book, DateTime now) {
    for (final ride in ridesNear(book, now)) {
      if (!now.isBefore(ride.from) && now.isBefore(ride.to)) {
        final p = now.difference(ride.from).inSeconds /
            ride.to.difference(ride.from).inSeconds;
        final snowy = ride.leg == TripLeg.there ? p >= snowThere : p < snowBack;
        return (leg: ride.leg, progress: p, snowy: snowy, skiing: false);
      }
    }
    var snowy = false;
    for (final date in _skiing(book)) {
      for (final start in _startsNear(date, now)) {
        if (_within(now, _snowy(date, start))) snowy = true;
      }
    }
    if (!snowy) return noTrip;
    return (leg: null, progress: 0, snowy: true, skiing: skiDay(book, now));
  }
}
