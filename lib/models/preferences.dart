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

  const Preferences({
    this.theme = 'clay',
    this.counterFeedback = true,
    this.noteLineNumbers = true,
    this.fingerprintFor,
    this.medicineReminders = true,
    this.medicineFollowUp,
    this.medicineDot = true,
    this.medicinePausedUntil,
  });

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
      );
}
