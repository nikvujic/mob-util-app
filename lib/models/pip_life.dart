/// Pip, the pet (Round 34): whether he's hatched, when (his birthday),
/// and his name. In backups; his age isn't stored, it comes from his
/// birthday, so restored he's as old as he really is.
class PipLife {
  /// When he hatched, or null: still an egg.
  final DateTime? born;

  /// His name, changeable later (shown in the app's pixel letters).
  final String name;

  const PipLife({this.born, this.name = defaultName});

  static const defaultName = 'Pip';

  /// Still an egg.
  static const egg = PipLife();

  bool get hatched => born != null;

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

  /// "1 DAY", "12 DAYS".
  static String ageText(int days) => days == 1 ? '1 DAY' : '$days DAYS';

  PipLife copyWith({DateTime? born, String? name}) =>
      PipLife(born: born ?? this.born, name: name ?? this.name);

  Map<String, dynamic> toJson() => {
        if (born != null) 'born': born!.toUtc().toIso8601String(),
        'name': name,
      };

  factory PipLife.fromJson(Map<String, dynamic> json) => PipLife(
        born: json['born'] == null
            ? null
            : DateTime.parse(json['born'] as String).toLocal(),
        name: json['name'] as String? ?? defaultName,
      );

  @override
  bool operator ==(Object other) =>
      other is PipLife && other.born == born && other.name == name;

  @override
  int get hashCode => Object.hash(born, name);
}
