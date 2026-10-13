import 'package:the_app/models/planner_task.dart';

/// How the user likes the app: look and feel, kept on this phone (not in
/// backups).
class Preferences {
  /// The chosen theme's id (see `AppThemeChoice` in core/theme.dart).
  final String theme;

  /// Vibration and a click sound on counter buttons (U6).
  final bool counterFeedback;

  /// Line numbers beside a note's text (N12).
  final bool noteLineNumbers;

  /// Fingerprint unlock (L6): the salt (base64) of the master password
  /// whose key is in the phone's keystore, or null when it's off. Not a
  /// secret; it tells which password the stored key belongs to.
  final String? fingerprintFor;

  /// Medicine (O12): a notification at each dose time not yet marked.
  final bool medicineReminders;

  /// Medicine (O12): a red dot on its Hub tile and the Hub tab while one of
  /// today's doses is due and not marked.
  final bool medicineDot;

  /// Medicine (O12): reminders and the dot are paused through this day;
  /// null (or a day gone by): not paused.
  final DateTime? medicinePausedUntil;

  /// The Introduction note (N16): deleted from the Notes list (the menu
  /// brings it back).
  final bool introDeleted;

  /// The Introduction comes back after each update (unless off).
  final bool introOnUpdates;

  /// The app version the Introduction was last brought up for; null
  /// before the first start (or before N16).
  final String? introVersion;

  /// It's new to the user (a fresh install or an update), until opened.
  final bool introUnread;

  /// "Forgot master password?" is greyed out until then (Round 21): its
  /// Reset was tapped instead of held, as someone not in on it would.
  /// Cleared by the next unlock.
  final DateTime? resetBlockedUntil;

  /// When the last backup was exported (D8), or null if none yet.
  final DateTime? lastBackupAt;

  /// Where the weekly backup reminder counts from while there's been no
  /// backup: the first start of a version that has it.
  final DateTime? backupCountFrom;

  /// The weekly backup reminder (D8): a dot on the menu and a notification
  /// once a week has gone by without a backup.
  final bool backupReminder;

  const Preferences({
    this.theme = 'clay',
    this.counterFeedback = true,
    this.noteLineNumbers = true,
    this.fingerprintFor,
    this.medicineReminders = true,
    this.medicineDot = true,
    this.medicinePausedUntil,
    this.introDeleted = false,
    this.introOnUpdates = true,
    this.introVersion,
    this.introUnread = false,
    this.resetBlockedUntil,
    this.lastBackupAt,
    this.backupCountFrom,
    this.backupReminder = true,
  });

  /// How long until a backup is due again (D8).
  static const backupEvery = Duration(days: 7);

  /// When the next backup is due, or null when the reminder is off (or
  /// there's nothing to count from yet).
  DateTime? get backupDueAt {
    if (!backupReminder) return null;
    return (lastBackupAt ?? backupCountFrom)?.add(backupEvery);
  }

  /// Whether a backup is due at [now].
  bool backupDueBy(DateTime now) {
    final due = backupDueAt;
    return due != null && !now.isBefore(due);
  }

  /// Started at [now]: the backup reminder starts counting, if it hasn't.
  Preferences startedAt(DateTime now) =>
      lastBackupAt == null && backupCountFrom == null
          ? copyWith(backupCountFrom: () => now)
          : this;

  /// Whether resetting the master password is blocked at [now].
  bool resetBlockedAt(DateTime now) {
    final until = resetBlockedUntil;
    return until != null && now.isBefore(until);
  }

  /// After starting [version] of the app: a first start or an update
  /// brings the Introduction up (an update only if [introOnUpdates]),
  /// marked new. The same version: nothing changes.
  Preferences startedVersion(String version) {
    if (introVersion == version) return this;
    final bringUp = introVersion == null || introOnUpdates;
    return copyWith(
      introVersion: () => version,
      introDeleted: bringUp ? false : introDeleted,
      introUnread: bringUp || introUnread,
    );
  }

  /// Whether medicine reminders and the dot are paused on [day].
  bool medicinePausedOn(DateTime day) {
    final until = medicinePausedUntil;
    return until != null &&
        !DateTime(day.year, day.month, day.day).isAfter(until);
  }

  Preferences copyWith({
    String? theme,
    bool? counterFeedback,
    bool? noteLineNumbers,
    String? Function()? fingerprintFor,
    bool? medicineReminders,
    bool? medicineDot,
    DateTime? Function()? medicinePausedUntil,
    bool? introDeleted,
    bool? introOnUpdates,
    String? Function()? introVersion,
    bool? introUnread,
    DateTime? Function()? resetBlockedUntil,
    DateTime? Function()? lastBackupAt,
    DateTime? Function()? backupCountFrom,
    bool? backupReminder,
  }) =>
      Preferences(
        theme: theme ?? this.theme,
        counterFeedback: counterFeedback ?? this.counterFeedback,
        noteLineNumbers: noteLineNumbers ?? this.noteLineNumbers,
        fingerprintFor:
            fingerprintFor == null ? this.fingerprintFor : fingerprintFor(),
        medicineReminders: medicineReminders ?? this.medicineReminders,
        medicineDot: medicineDot ?? this.medicineDot,
        medicinePausedUntil: medicinePausedUntil == null
            ? this.medicinePausedUntil
            : medicinePausedUntil(),
        introDeleted: introDeleted ?? this.introDeleted,
        introOnUpdates: introOnUpdates ?? this.introOnUpdates,
        introVersion: introVersion == null ? this.introVersion : introVersion(),
        introUnread: introUnread ?? this.introUnread,
        resetBlockedUntil: resetBlockedUntil == null
            ? this.resetBlockedUntil
            : resetBlockedUntil(),
        lastBackupAt: lastBackupAt == null ? this.lastBackupAt : lastBackupAt(),
        backupCountFrom:
            backupCountFrom == null ? this.backupCountFrom : backupCountFrom(),
        backupReminder: backupReminder ?? this.backupReminder,
      );

  Map<String, dynamic> toJson() => {
        'theme': theme,
        'counterFeedback': counterFeedback,
        'noteLineNumbers': noteLineNumbers,
        if (fingerprintFor != null) 'fingerprintFor': fingerprintFor,
        'medicineReminders': medicineReminders,
        'medicineDot': medicineDot,
        if (medicinePausedUntil != null)
          'medicinePausedUntil': PlannerTask.dayToJson(medicinePausedUntil!),
        'introDeleted': introDeleted,
        'introOnUpdates': introOnUpdates,
        if (introVersion != null) 'introVersion': introVersion,
        'introUnread': introUnread,
        if (resetBlockedUntil != null)
          'resetBlockedUntil': resetBlockedUntil!.toIso8601String(),
        if (lastBackupAt != null)
          'lastBackupAt': lastBackupAt!.toIso8601String(),
        if (backupCountFrom != null)
          'backupCountFrom': backupCountFrom!.toIso8601String(),
        'backupReminder': backupReminder,
      };

  /// Missing values take their defaults, so older files stay readable.
  factory Preferences.fromJson(Map<String, dynamic> json) => Preferences(
        theme: json['theme'] as String? ?? 'clay',
        counterFeedback: json['counterFeedback'] as bool? ?? true,
        noteLineNumbers: json['noteLineNumbers'] as bool? ?? true,
        fingerprintFor: json['fingerprintFor'] as String?,
        medicineReminders: json['medicineReminders'] as bool? ?? true,
        medicineDot: json['medicineDot'] as bool? ?? true,
        medicinePausedUntil: json['medicinePausedUntil'] == null
            ? null
            : PlannerTask.dayFromJson(json['medicinePausedUntil']),
        introDeleted: json['introDeleted'] as bool? ?? false,
        introOnUpdates: json['introOnUpdates'] as bool? ?? true,
        introVersion: json['introVersion'] as String?,
        introUnread: json['introUnread'] as bool? ?? false,
        resetBlockedUntil: json['resetBlockedUntil'] == null
            ? null
            : DateTime.tryParse(json['resetBlockedUntil'] as String),
        lastBackupAt: json['lastBackupAt'] == null
            ? null
            : DateTime.tryParse(json['lastBackupAt'] as String),
        backupCountFrom: json['backupCountFrom'] == null
            ? null
            : DateTime.tryParse(json['backupCountFrom'] as String),
        backupReminder: json['backupReminder'] as bool? ?? true,
      );
}
