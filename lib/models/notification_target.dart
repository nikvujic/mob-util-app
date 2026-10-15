/// Where a notification leads when it's tapped (Round 19): the planner at
/// a day and a time (a block, a routine or a reminder), the medicine
/// page, or Backup. Carried in the notification as a short text ([payload]).
sealed class NotificationTarget {
  const NotificationTarget();

  /// The text a notification carries.
  String get payload;

  /// The target in [payload], or null if it isn't one (e.g. from an older
  /// version of the app).
  static NotificationTarget? parse(String? payload) {
    final parts = payload?.split('|') ?? const [];
    switch (parts) {
      case ['planner', final day, final minutes]:
        final date = DateTime.tryParse(day);
        final time = int.tryParse(minutes);
        if (date == null || time == null) return null;
        return PlannerTarget(date, time);
      case ['medicine']:
        return const MedicineTarget();
      case ['backup']:
        return const BackupTarget();
      case ['dates']:
        return const DatesTarget();
    }
    return null;
  }
}

/// The planner, on [day], scrolled to [minutes] past midnight.
class PlannerTarget extends NotificationTarget {
  final DateTime day;
  final int minutes;

  PlannerTarget(DateTime day, this.minutes)
      : day = DateTime(day.year, day.month, day.day);

  @override
  String get payload {
    String two(int n) => n.toString().padLeft(2, '0');
    return 'planner|${day.year}-${two(day.month)}-${two(day.day)}|$minutes';
  }

  @override
  bool operator ==(Object other) =>
      other is PlannerTarget && other.day == day && other.minutes == minutes;

  @override
  int get hashCode => Object.hash(day, minutes);

  @override
  String toString() => 'PlannerTarget($payload)';
}

/// The medicine page.
class MedicineTarget extends NotificationTarget {
  const MedicineTarget();

  @override
  String get payload => 'medicine';

  @override
  String toString() => 'MedicineTarget()';
}

/// The Backup page (a backup reminder, D8).
class BackupTarget extends NotificationTarget {
  const BackupTarget();

  @override
  String get payload => 'backup';

  @override
  String toString() => 'BackupTarget()';
}

/// The Dates page (Round 57: a date's reminder).
class DatesTarget extends NotificationTarget {
  const DatesTarget();

  @override
  String get payload => 'dates';

  @override
  String toString() => 'DatesTarget()';
}
