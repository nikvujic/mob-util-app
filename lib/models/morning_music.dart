/// Spotify in the morning (Round 93, Nikola): at [minutes] on the
/// [weekdays] picked, while [on], the phone's music volume is set to
/// [volume] percent and play is pressed for it, so Spotify (or whatever
/// played last) carries on. Kept in the preferences.
class MorningMusic {
  final bool on;

  /// The time, in minutes from midnight.
  final int minutes;

  /// Monday 1 … Sunday 7 (as `DateTime.weekday`).
  final Set<int> weekdays;

  /// The music volume it's set to, 0–100 (percent).
  final int volume;

  const MorningMusic({
    this.on = false,
    this.minutes = 7 * 60,
    this.weekdays = const {1, 2, 3, 4, 5},
    this.volume = 30,
  });

  static const initial = MorningMusic();

  MorningMusic copyWith({
    bool? on,
    int? minutes,
    Set<int>? weekdays,
    int? volume,
  }) =>
      MorningMusic(
        on: on ?? this.on,
        minutes: minutes ?? this.minutes,
        weekdays: weekdays ?? this.weekdays,
        volume: volume ?? this.volume,
      );

  /// When it next plays after [now] (on one of its days, at its time);
  /// null while off or with no day picked.
  DateTime? nextAfter(DateTime now) {
    if (!on || weekdays.isEmpty) return null;
    for (var days = 0; days <= 7; days++) {
      final at = DateTime(
          now.year, now.month, now.day + days, minutes ~/ 60, minutes % 60);
      if (at.isAfter(now) && weekdays.contains(at.weekday)) return at;
    }
    return null;
  }

  Map<String, dynamic> toJson() => {
        'on': on,
        'minutes': minutes,
        'weekdays': [...weekdays]..sort(),
        'volume': volume,
      };

  /// Anything unreadable falls back to its default.
  factory MorningMusic.fromJson(Map<String, dynamic> json) => MorningMusic(
        on: json['on'] as bool? ?? false,
        minutes: ((json['minutes'] as num?)?.toInt() ?? 7 * 60).clamp(0, 1439),
        weekdays: {
          for (final d in json['weekdays'] as List<dynamic>? ?? const [])
            if (d is int && d >= 1 && d <= 7) d,
        },
        volume: ((json['volume'] as num?)?.toInt() ?? 30).clamp(0, 100),
      );

  @override
  bool operator ==(Object other) =>
      other is MorningMusic &&
      other.on == on &&
      other.minutes == minutes &&
      other.volume == volume &&
      other.weekdays.length == weekdays.length &&
      other.weekdays.containsAll(weekdays);

  @override
  int get hashCode =>
      Object.hash(on, minutes, volume, Object.hashAllUnordered(weekdays));
}
