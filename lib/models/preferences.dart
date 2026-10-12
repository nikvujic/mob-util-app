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

  /// Medicine (O12): minutes after a dose's time to remind again if it's
  /// still not marked; null: no second reminder.
  final int? medicineFollowUp;

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

  const Preferences({
    this.theme = 'clay',
    this.counterFeedback = true,
    this.noteLineNumbers = true,
    this.fingerprintFor,
    this.medicineReminders = true,
    this.medicineFollowUp,
    this.medicineDot = true,
    this.medicinePausedUntil,
    this.introDeleted = false,
    this.introOnUpdates = true,
    this.introVersion,
    this.introUnread = false,
  });

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
    int? Function()? medicineFollowUp,
    bool? medicineDot,
    DateTime? Function()? medicinePausedUntil,
    bool? introDeleted,
    bool? introOnUpdates,
    String? Function()? introVersion,
    bool? introUnread,
  }) =>
      Preferences(
        theme: theme ?? this.theme,
        counterFeedback: counterFeedback ?? this.counterFeedback,
        noteLineNumbers: noteLineNumbers ?? this.noteLineNumbers,
        fingerprintFor:
            fingerprintFor == null ? this.fingerprintFor : fingerprintFor(),
        medicineReminders: medicineReminders ?? this.medicineReminders,
        medicineFollowUp: medicineFollowUp == null
            ? this.medicineFollowUp
            : medicineFollowUp(),
        medicineDot: medicineDot ?? this.medicineDot,
        medicinePausedUntil: medicinePausedUntil == null
            ? this.medicinePausedUntil
            : medicinePausedUntil(),
        introDeleted: introDeleted ?? this.introDeleted,
        introOnUpdates: introOnUpdates ?? this.introOnUpdates,
        introVersion: introVersion == null ? this.introVersion : introVersion(),
        introUnread: introUnread ?? this.introUnread,
      );

  Map<String, dynamic> toJson() => {
        'theme': theme,
        'counterFeedback': counterFeedback,
        'noteLineNumbers': noteLineNumbers,
        if (fingerprintFor != null) 'fingerprintFor': fingerprintFor,
        'medicineReminders': medicineReminders,
        if (medicineFollowUp != null) 'medicineFollowUp': medicineFollowUp,
        'medicineDot': medicineDot,
        if (medicinePausedUntil != null)
          'medicinePausedUntil': PlannerTask.dayToJson(medicinePausedUntil!),
        'introDeleted': introDeleted,
        'introOnUpdates': introOnUpdates,
        if (introVersion != null) 'introVersion': introVersion,
        'introUnread': introUnread,
      };

  /// Missing values take their defaults, so older files stay readable.
  factory Preferences.fromJson(Map<String, dynamic> json) => Preferences(
        theme: json['theme'] as String? ?? 'clay',
        counterFeedback: json['counterFeedback'] as bool? ?? true,
        noteLineNumbers: json['noteLineNumbers'] as bool? ?? true,
        fingerprintFor: json['fingerprintFor'] as String?,
        medicineReminders: json['medicineReminders'] as bool? ?? true,
        medicineFollowUp: json['medicineFollowUp'] as int?,
        medicineDot: json['medicineDot'] as bool? ?? true,
        medicinePausedUntil: json['medicinePausedUntil'] == null
            ? null
            : PlannerTask.dayFromJson(json['medicinePausedUntil']),
        introDeleted: json['introDeleted'] as bool? ?? false,
        introOnUpdates: json['introOnUpdates'] as bool? ?? true,
        introVersion: json['introVersion'] as String?,
        introUnread: json['introUnread'] as bool? ?? false,
      );
}
