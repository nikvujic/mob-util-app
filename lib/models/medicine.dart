import 'package:the_app/models/planner_task.dart';

/// A medicine to take (O6): [times] a day (minutes past midnight, one per
/// dose, in order), from the day [from] until [until] (or for good).
class Medicine {
  final String id;
  final String name;

  /// When each dose is due; at least one. How many doses a day = length.
  final List<int> times;
  final DateTime from;

  /// The last day it's taken; null: for good.
  final DateTime? until;

  Medicine({
    required this.id,
    required this.name,
    required List<int> times,
    required DateTime from,
    DateTime? until,
  })  : times = List.unmodifiable([...times]..sort()),
        from = DateTime(from.year, from.month, from.day),
        until = until == null
            ? null
            : DateTime(until.year, until.month, until.day) {
    if (this.times.isEmpty) {
      throw ArgumentError('A medicine needs at least one dose');
    }
  }

  int get dosesADay => times.length;

  /// Whether it's taken on [day].
  bool isOn(DateTime day) {
    final d = DateTime(day.year, day.month, day.day);
    return !d.isBefore(from) && (until == null || !d.isAfter(until!));
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'times': times,
        'from': PlannerTask.dayToJson(from),
        if (until != null) 'until': PlannerTask.dayToJson(until!),
      };

  factory Medicine.fromJson(Map<String, dynamic> json) => Medicine(
        id: json['id'] as String,
        name: json['name'] as String,
        times: [for (final t in json['times'] as List<dynamic>) t as int],
        from: PlannerTask.dayFromJson(json['from']),
        until: json['until'] == null
            ? null
            : PlannerTask.dayFromJson(json['until']),
      );
}

/// A dose marked taken (O6): which medicine, on which day, which of its
/// doses (0 = the first time of the day), and when it was marked.
class DoseTaken {
  final String medicine;
  final DateTime day;
  final int dose;
  final DateTime at;

  DoseTaken({
    required this.medicine,
    required DateTime day,
    required this.dose,
    required this.at,
  }) : day = DateTime(day.year, day.month, day.day);

  bool isFor(String medicine, DateTime day, int dose) =>
      this.medicine == medicine &&
      this.dose == dose &&
      this.day.year == day.year &&
      this.day.month == day.month &&
      this.day.day == day.day;

  Map<String, dynamic> toJson() => {
        'medicine': medicine,
        'day': PlannerTask.dayToJson(day),
        'dose': dose,
        'at': at.toIso8601String(),
      };

  factory DoseTaken.fromJson(Map<String, dynamic> json) => DoseTaken(
        medicine: json['medicine'] as String,
        day: PlannerTask.dayFromJson(json['day']),
        dose: json['dose'] as int,
        at: DateTime.parse(json['at'] as String),
      );
}

/// Everything the medicine tracker keeps (O6): the medicines and every dose
/// marked taken (its history).
class MedicineBook {
  final List<Medicine> medicines;
  final List<DoseTaken> taken;

  MedicineBook({
    List<Medicine> medicines = const [],
    List<DoseTaken> taken = const [],
  })  : medicines = List.unmodifiable(medicines),
        taken = List.unmodifiable(taken);

  const MedicineBook._none()
      : medicines = const [],
        taken = const [];

  static const empty = MedicineBook._none();

  /// The mark for [medicine]'s [dose] on [day], if taken.
  DoseTaken? takenFor(String medicine, DateTime day, int dose) =>
      taken.where((t) => t.isFor(medicine, day, dose)).firstOrNull;

  /// How many things it holds (for Clear data).
  int get size => medicines.length;

  Map<String, dynamic> toJson() => {
        'medicines': [for (final m in medicines) m.toJson()],
        'taken': [for (final t in taken) t.toJson()],
      };

  factory MedicineBook.fromJson(Map<String, dynamic> json) => MedicineBook(
        medicines: [
          for (final m in json['medicines'] as List<dynamic>? ?? const [])
            Medicine.fromJson(m as Map<String, dynamic>),
        ],
        taken: [
          for (final t in json['taken'] as List<dynamic>? ?? const [])
            DoseTaken.fromJson(t as Map<String, dynamic>),
        ],
      );
}
