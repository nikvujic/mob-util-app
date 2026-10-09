/// A named counter (O2), e.g. "Push-ups" or "Days without sugar".
class Counter {
  final String id;
  final String name;
  final int value;

  const Counter({required this.id, required this.name, this.value = 0});

  Counter copyWith({String? name, int? value}) =>
      Counter(id: id, name: name ?? this.name, value: value ?? this.value);

  Map<String, dynamic> toJson() => {'id': id, 'name': name, 'value': value};

  factory Counter.fromJson(Map<String, dynamic> json) => Counter(
        id: json['id'] as String,
        name: json['name'] as String,
        value: json['value'] as int,
      );
}
