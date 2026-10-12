/// A named counter (O2), e.g. "Push-ups" or "Days without sugar", with
/// its options (O5): how much − / + count by ([step]), a [color], and
/// optional limits ([min], [max]).
class Counter {
  final String id;
  final String name;
  final int value;

  /// How much one tap of − or + counts (at least 1).
  final int step;

  /// A `BlockColor` name, or null for the card's own colour.
  final String? color;

  /// The lowest and highest it may go; null: no limit.
  final int? min;
  final int? max;

  const Counter({
    required this.id,
    required this.name,
    this.value = 0,
    this.step = 1,
    this.color,
    this.min,
    this.max,
  });

  /// [v] within [min] and [max].
  int clamped(int v) {
    if (min != null && v < min!) return min!;
    if (max != null && v > max!) return max!;
    return v;
  }

  /// What a reset goes back to: 0, or the nearest limit if 0 is outside.
  int get start => clamped(0);

  bool get canGoDown => min == null || value > min!;
  bool get canGoUp => max == null || value < max!;

  Counter copyWith({String? name, int? value}) => Counter(
        id: id,
        name: name ?? this.name,
        value: value ?? this.value,
        step: step,
        color: color,
        min: min,
        max: max,
      );

  /// The options only differ from the defaults where written.
  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'value': value,
        if (step != 1) 'step': step,
        if (color != null) 'color': color,
        if (min != null) 'min': min,
        if (max != null) 'max': max,
      };

  factory Counter.fromJson(Map<String, dynamic> json) => Counter(
        id: json['id'] as String,
        name: json['name'] as String,
        value: json['value'] as int,
        step: (json['step'] as int?) ?? 1,
        color: json['color'] as String?,
        min: json['min'] as int?,
        max: json['max'] as int?,
      );
}

/// A counter's options, as picked in its sheet (O5).
typedef CounterOptions = ({
  String name,
  int step,
  String? color,
  int? min,
  int? max,
});
