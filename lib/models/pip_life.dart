import 'dart:math' as math;

/// Pip, the pet (Round 34): whether he's hatched, when (his birthday),
/// and his name. In backups; his age isn't stored, it comes from his
/// birthday, so restored he's as old as he really is.
///
/// Round 37: his energy and batteries. His energy is kept as a level at
/// a moment ([energy] at [energyAt]); what it is now is worked out from
/// the time since (`core/pip_energy.dart`), so a restored Pip carries on
/// from where the backup left him. What was already shown (him turning
/// off, falling asleep, waking up) is kept too, so it isn't played again.
class PipLife {
  /// When he hatched, or null: still an egg.
  final DateTime? born;

  /// His name, changeable later (shown in the app's pixel letters).
  final String name;

  /// His energy (0 to 3) at [energyAt]; null [energyAt]: full, from when
  /// he's next looked at (a Pip from before Round 37).
  final double energy;
  final DateTime? energyAt;

  /// Batteries held (0 to 3), and when the next one comes (collected
  /// when the app is opened after it).
  final int batteries;
  final DateTime? nextBatteryAt;

  /// He was seen off (turned off and fell over): not shown again.
  final bool offSeen;

  /// The night (its evening's date, "2026-10-14") he was seen falling
  /// asleep, and the morning he was seen waking up.
  final String? sleepSeen;
  final String? wakeSeen;

  /// His adventures (Round 63): when he registered as an adventurer
  /// (null: not yet), the minutes out banked from his days out before
  /// (Round 73: each worth ten XP, `PipAdventure.xpPerMinute`; stored as
  /// "xp", which they were till then), and his
  /// latest day out: the day ([dayKey]-like, "2026-10-18"), from when
  /// (null: he hasn't gone out that day, or it's banked) and when his
  /// break started (Round 64; null: not had).
  final DateTime? registeredAt;
  final int minutesOut;
  final String? outDay;
  final DateTime? outFrom;
  final DateTime? breakAt;

  const PipLife({
    this.born,
    this.name = defaultName,
    this.energy = fullEnergy,
    this.energyAt,
    this.batteries = 0,
    this.nextBatteryAt,
    this.offSeen = false,
    this.sleepSeen,
    this.wakeSeen,
    this.registeredAt,
    this.minutesOut = 0,
    this.outDay,
    this.outFrom,
    this.breakAt,
  });

  static const defaultName = 'Pip';
  static const fullEnergy = 3.0;

  /// Still an egg.
  static const egg = PipLife();

  bool get hatched => born != null;

  /// Registered as an adventurer.
  bool get adventurer => registeredAt != null;

  /// How many days old he is at [now], the day he hatched being day 1;
  /// null while he's an egg.
  int? ageOn(DateTime now) {
    final b = born;
    if (b == null) return null;
    final from = DateTime(b.year, b.month, b.day);
    final to = DateTime(now.year, now.month, now.day);
    // Whole days between the two dates, whatever the clock changes.
    final days = DateTime.utc(to.year, to.month, to.day)
        .difference(DateTime.utc(from.year, from.month, from.day))
        .inDays;
    return days < 0 ? 1 : days + 1;
  }

  /// Whether [day] is his birthday (Round 57: the party hat): the day he
  /// hatched, each year after (not that day itself); 29 February on the
  /// 28th in a year without it.
  bool birthdayOn(DateTime day) {
    final b = born?.toLocal();
    if (b == null || day.year <= b.year) return false;
    final last = DateTime(day.year, b.month + 1, 0).day;
    return day.month == b.month && day.day == (b.day > last ? last : b.day);
  }

  /// "1 DAY", "12 DAYS".
  static String ageText(int days) => days == 1 ? '1 DAY' : '$days DAYS';

  /// A copy with the given fields changed; the nullable ones are given as
  /// functions, so they can be set to null.
  PipLife copyWith({
    DateTime? born,
    String? name,
    double? energy,
    DateTime? Function()? energyAt,
    int? batteries,
    DateTime? Function()? nextBatteryAt,
    bool? offSeen,
    String? Function()? sleepSeen,
    String? Function()? wakeSeen,
    DateTime? Function()? registeredAt,
    int? minutesOut,
    String? Function()? outDay,
    DateTime? Function()? outFrom,
    DateTime? Function()? breakAt,
  }) =>
      PipLife(
        born: born ?? this.born,
        name: name ?? this.name,
        energy: energy ?? this.energy,
        energyAt: energyAt == null ? this.energyAt : energyAt(),
        batteries: batteries ?? this.batteries,
        nextBatteryAt:
            nextBatteryAt == null ? this.nextBatteryAt : nextBatteryAt(),
        offSeen: offSeen ?? this.offSeen,
        sleepSeen: sleepSeen == null ? this.sleepSeen : sleepSeen(),
        wakeSeen: wakeSeen == null ? this.wakeSeen : wakeSeen(),
        registeredAt: registeredAt == null ? this.registeredAt : registeredAt(),
        minutesOut: minutesOut ?? this.minutesOut,
        outDay: outDay == null ? this.outDay : outDay(),
        outFrom: outFrom == null ? this.outFrom : outFrom(),
        breakAt: breakAt == null ? this.breakAt : breakAt(),
      );

  static String _time(DateTime t) => t.toUtc().toIso8601String();
  static DateTime? _parse(Object? s) =>
      s == null ? null : DateTime.parse(s as String).toLocal();

  Map<String, dynamic> toJson() => {
        if (born != null) 'born': _time(born!),
        'name': name,
        'energy': energy,
        if (energyAt != null) 'energyAt': _time(energyAt!),
        'batteries': batteries,
        if (nextBatteryAt != null) 'nextBatteryAt': _time(nextBatteryAt!),
        'offSeen': offSeen,
        if (sleepSeen != null) 'sleepSeen': sleepSeen,
        if (wakeSeen != null) 'wakeSeen': wakeSeen,
        if (adventurer)
          'adventure': {
            'registeredAt': _time(registeredAt!),
            'xp': minutesOut,
            if (outDay != null) 'outDay': outDay,
            if (outFrom != null) 'outFrom': _time(outFrom!),
            if (breakAt != null) 'breakAt': _time(breakAt!),
          },
      };

  /// Also reads version 1 (no energy yet: full, no batteries) and 2 (not
  /// an adventurer).
  factory PipLife.fromJson(Map<String, dynamic> json) {
    final out = json['adventure'] as Map<String, dynamic>?;
    return PipLife(
      born: _parse(json['born']),
      name: json['name'] as String? ?? defaultName,
      energy: (json['energy'] as num?)?.toDouble().clamp(0, fullEnergy) ??
          fullEnergy,
      energyAt: _parse(json['energyAt']),
      batteries: ((json['batteries'] as num?)?.toInt() ?? 0).clamp(0, 3),
      nextBatteryAt: _parse(json['nextBatteryAt']),
      offSeen: json['offSeen'] as bool? ?? false,
      sleepSeen: json['sleepSeen'] as String?,
      wakeSeen: json['wakeSeen'] as String?,
      registeredAt: _parse(out?['registeredAt']),
      minutesOut: math.max(0, (out?['xp'] as num?)?.toInt() ?? 0),
      outDay: out?['outDay'] as String?,
      outFrom: _parse(out?['outFrom']),
      breakAt: _parse(out?['breakAt']),
    );
  }

  @override
  bool operator ==(Object other) =>
      other is PipLife &&
      other.born == born &&
      other.name == name &&
      other.energy == energy &&
      other.energyAt == energyAt &&
      other.batteries == batteries &&
      other.nextBatteryAt == nextBatteryAt &&
      other.offSeen == offSeen &&
      other.sleepSeen == sleepSeen &&
      other.wakeSeen == wakeSeen &&
      other.registeredAt == registeredAt &&
      other.minutesOut == minutesOut &&
      other.outDay == outDay &&
      other.outFrom == outFrom &&
      other.breakAt == breakAt;

  @override
  int get hashCode => Object.hash(
      born,
      name,
      energy,
      energyAt,
      batteries,
      nextBatteryAt,
      offSeen,
      sleepSeen,
      wakeSeen,
      registeredAt,
      minutesOut,
      outDay,
      outFrom,
      breakAt);
}
