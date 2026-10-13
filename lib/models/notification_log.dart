/// One notification the app scheduled (Round 31): what it said, when,
/// from which page, and where tapping it leads.
class LoggedNotification {
  final DateTime at;
  final String title;
  final String body;

  /// The kind of reminder it is (`ReminderKind.name`: planner, medicine,
  /// backup, notice).
  final String kind;

  /// Where tapping it leads (a `NotificationTarget` payload), if anywhere.
  final String? target;

  const LoggedNotification({
    required this.at,
    required this.title,
    required this.body,
    required this.kind,
    this.target,
  });

  Map<String, dynamic> toJson() => {
        'at': at.toUtc().toIso8601String(),
        'title': title,
        'body': body,
        'kind': kind,
        if (target != null) 'target': target,
      };

  factory LoggedNotification.fromJson(Map<String, dynamic> json) =>
      LoggedNotification(
        at: DateTime.parse(json['at'] as String).toLocal(),
        title: json['title'] as String,
        body: json['body'] as String,
        kind: json['kind'] as String,
        target: json['target'] as String?,
      );
}

/// What the app scheduled (Round 31), kept on this phone: Android doesn't
/// tell an app which notifications were shown, but a scheduled one shows
/// at its time, so those whose time has come are the history.
class NotificationLog {
  /// Oldest first: those already shown (today's and yesterday's), then
  /// those still to come.
  final List<LoggedNotification> scheduled;

  /// History cleared at this moment: nothing from before it shows.
  final DateTime? clearedAt;

  NotificationLog(
      {List<LoggedNotification> scheduled = const [], this.clearedAt})
      : scheduled = List.unmodifiable(scheduled);

  static final empty = NotificationLog();

  static DateTime _yesterday(DateTime now) =>
      DateTime(now.year, now.month, now.day - 1);

  /// The history at [now]: shown today or yesterday (and not cleared),
  /// newest first.
  List<LoggedNotification> historyAt(DateTime now) {
    final from = _yesterday(now);
    final cleared = clearedAt;
    return [
      for (final n in scheduled.reversed)
        if (!n.at.isAfter(now) &&
            !n.at.isBefore(from) &&
            (cleared == null || n.at.isAfter(cleared)))
          n,
    ];
  }

  /// Planned again at [now] with [upcoming] (the new schedule): what was
  /// shown today or yesterday stays, the rest of the old schedule goes.
  NotificationLog planned(List<LoggedNotification> upcoming, DateTime now) {
    final from = _yesterday(now);
    return NotificationLog(
      scheduled: [
        for (final n in scheduled)
          if (!n.at.isAfter(now) && !n.at.isBefore(from)) n,
        for (final n in upcoming)
          if (n.at.isAfter(now)) n,
      ],
      clearedAt: clearedAt,
    );
  }

  /// The history cleared at [now].
  NotificationLog clearedAtTime(DateTime now) =>
      NotificationLog(scheduled: scheduled, clearedAt: now);

  Map<String, dynamic> toJson() => {
        'scheduled': [for (final n in scheduled) n.toJson()],
        if (clearedAt != null)
          'clearedAt': clearedAt!.toUtc().toIso8601String(),
      };

  factory NotificationLog.fromJson(Map<String, dynamic> json) =>
      NotificationLog(
        scheduled: [
          for (final n in json['scheduled'] as List<dynamic>? ?? const [])
            LoggedNotification.fromJson(n as Map<String, dynamic>),
        ],
        clearedAt: json['clearedAt'] == null
            ? null
            : DateTime.parse(json['clearedAt'] as String).toLocal(),
      );
}
