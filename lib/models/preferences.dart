import 'package:the_app/models/notify_settings.dart';
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

  /// Medicine (O12): reminders and the dot are paused through this day;
  /// null (or a day gone by): not paused.
  final DateTime? medicinePausedUntil;

  /// The planner's notifications (Round 31): on, and paused through a day.
  final bool plannerReminders;
  final DateTime? plannerPausedUntil;

  /// Birthdays & dates' notifications (Round 57): on, and paused through
  /// a day; and the day the Dates page was last opened (the green dot on
  /// a birthday goes once it's been looked at that day).
  final bool datesReminders;
  final DateTime? datesPausedUntil;
  final DateTime? datesSeenOn;

  /// How each page's notifications look and sound (Round 31); a page not
  /// here is [NotifyStyle.plain].
  final Map<NotifyPage, NotifyStyle> notifyStyles;

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

  /// How far down the Introduction was read (Round 29), to open there
  /// again; back to the top when it's new or restored.
  final double introScroll;

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

  /// The to-do note at the top of Notes (Round 28); its list stays when
  /// it's turned off.
  final bool todoNote;

  /// The to-do note's *Waiting* list (Round 45): off, waiting things show
  /// with the rest, still marked.
  final bool todoWaiting;

  /// Automatic backup (Round 39): the folder picked (Android's uri for it,
  /// and its name to show), or null: off. This phone only.
  final String? autoBackupFolder;
  final String? autoBackupFolderName;

  /// When the last automatic backup was written; and whether the last try
  /// failed (the folder gone, or its permission taken back).
  final DateTime? lastAutoBackupAt;
  final bool autoBackupFailed;

  /// The phone was plugged in when last seen (Round 44: Pip's charging
  /// station); so after a restart, time away plugged in still counts as
  /// charging. This phone only.
  final bool pipPlugged;

  const Preferences({
    this.theme = 'clay',
    this.counterFeedback = true,
    this.noteLineNumbers = true,
    this.fingerprintFor,
    this.medicineReminders = true,
    this.medicinePausedUntil,
    this.plannerReminders = true,
    this.plannerPausedUntil,
    this.datesReminders = true,
    this.datesPausedUntil,
    this.datesSeenOn,
    this.notifyStyles = const {},
    this.introDeleted = false,
    this.introOnUpdates = true,
    this.introVersion,
    this.introUnread = false,
    this.introScroll = 0,
    this.resetBlockedUntil,
    this.lastBackupAt,
    this.backupCountFrom,
    this.backupReminder = true,
    this.todoNote = true,
    this.todoWaiting = false,
    this.autoBackupFolder,
    this.autoBackupFolderName,
    this.lastAutoBackupAt,
    this.autoBackupFailed = false,
    this.pipPlugged = false,
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
      introScroll: bringUp ? 0 : introScroll,
    );
  }

  /// Whether medicine reminders and the dot are paused on [day].
  bool medicinePausedOn(DateTime day) => _pausedOn(medicinePausedUntil, day);

  /// Whether the planner's notifications are paused on [day] (Round 31).
  bool plannerPausedOn(DateTime day) => _pausedOn(plannerPausedUntil, day);

  /// Whether the dates' notifications are paused on [day] (Round 57).
  bool datesPausedOn(DateTime day) => _pausedOn(datesPausedUntil, day);

  static bool _pausedOn(DateTime? until, DateTime day) =>
      until != null && !DateTime(day.year, day.month, day.day).isAfter(until);

  /// How [page]'s notifications look and sound.
  NotifyStyle styleOf(NotifyPage page) =>
      notifyStyles[page] ?? NotifyStyle.plain;

  Preferences copyWith({
    String? theme,
    bool? counterFeedback,
    bool? noteLineNumbers,
    String? Function()? fingerprintFor,
    bool? medicineReminders,
    DateTime? Function()? medicinePausedUntil,
    bool? plannerReminders,
    DateTime? Function()? plannerPausedUntil,
    bool? datesReminders,
    DateTime? Function()? datesPausedUntil,
    DateTime? Function()? datesSeenOn,
    Map<NotifyPage, NotifyStyle>? notifyStyles,
    bool? introDeleted,
    bool? introOnUpdates,
    String? Function()? introVersion,
    bool? introUnread,
    double? introScroll,
    DateTime? Function()? resetBlockedUntil,
    DateTime? Function()? lastBackupAt,
    DateTime? Function()? backupCountFrom,
    bool? backupReminder,
    bool? todoNote,
    bool? todoWaiting,
    String? Function()? autoBackupFolder,
    String? Function()? autoBackupFolderName,
    DateTime? Function()? lastAutoBackupAt,
    bool? autoBackupFailed,
    bool? pipPlugged,
  }) =>
      Preferences(
        theme: theme ?? this.theme,
        counterFeedback: counterFeedback ?? this.counterFeedback,
        noteLineNumbers: noteLineNumbers ?? this.noteLineNumbers,
        fingerprintFor:
            fingerprintFor == null ? this.fingerprintFor : fingerprintFor(),
        medicineReminders: medicineReminders ?? this.medicineReminders,
        medicinePausedUntil: medicinePausedUntil == null
            ? this.medicinePausedUntil
            : medicinePausedUntil(),
        plannerReminders: plannerReminders ?? this.plannerReminders,
        plannerPausedUntil: plannerPausedUntil == null
            ? this.plannerPausedUntil
            : plannerPausedUntil(),
        datesReminders: datesReminders ?? this.datesReminders,
        datesPausedUntil: datesPausedUntil == null
            ? this.datesPausedUntil
            : datesPausedUntil(),
        datesSeenOn: datesSeenOn == null ? this.datesSeenOn : datesSeenOn(),
        notifyStyles: notifyStyles ?? this.notifyStyles,
        introDeleted: introDeleted ?? this.introDeleted,
        introOnUpdates: introOnUpdates ?? this.introOnUpdates,
        introVersion: introVersion == null ? this.introVersion : introVersion(),
        introUnread: introUnread ?? this.introUnread,
        introScroll: introScroll ?? this.introScroll,
        resetBlockedUntil: resetBlockedUntil == null
            ? this.resetBlockedUntil
            : resetBlockedUntil(),
        lastBackupAt: lastBackupAt == null ? this.lastBackupAt : lastBackupAt(),
        backupCountFrom:
            backupCountFrom == null ? this.backupCountFrom : backupCountFrom(),
        backupReminder: backupReminder ?? this.backupReminder,
        todoNote: todoNote ?? this.todoNote,
        todoWaiting: todoWaiting ?? this.todoWaiting,
        autoBackupFolder: autoBackupFolder == null
            ? this.autoBackupFolder
            : autoBackupFolder(),
        autoBackupFolderName: autoBackupFolderName == null
            ? this.autoBackupFolderName
            : autoBackupFolderName(),
        lastAutoBackupAt: lastAutoBackupAt == null
            ? this.lastAutoBackupAt
            : lastAutoBackupAt(),
        autoBackupFailed: autoBackupFailed ?? this.autoBackupFailed,
        pipPlugged: pipPlugged ?? this.pipPlugged,
      );

  Map<String, dynamic> toJson() => {
        'theme': theme,
        'counterFeedback': counterFeedback,
        'noteLineNumbers': noteLineNumbers,
        if (fingerprintFor != null) 'fingerprintFor': fingerprintFor,
        'medicineReminders': medicineReminders,
        if (medicinePausedUntil != null)
          'medicinePausedUntil': PlannerTask.dayToJson(medicinePausedUntil!),
        'plannerReminders': plannerReminders,
        if (plannerPausedUntil != null)
          'plannerPausedUntil': PlannerTask.dayToJson(plannerPausedUntil!),
        'datesReminders': datesReminders,
        if (datesPausedUntil != null)
          'datesPausedUntil': PlannerTask.dayToJson(datesPausedUntil!),
        if (datesSeenOn != null)
          'datesSeenOn': PlannerTask.dayToJson(datesSeenOn!),
        if (notifyStyles.isNotEmpty)
          'notifyStyles': {
            for (final MapEntry(:key, :value) in notifyStyles.entries)
              key.name: value.toJson(),
          },
        'introDeleted': introDeleted,
        'introOnUpdates': introOnUpdates,
        if (introVersion != null) 'introVersion': introVersion,
        'introUnread': introUnread,
        if (introScroll > 0) 'introScroll': introScroll,
        if (resetBlockedUntil != null)
          'resetBlockedUntil': resetBlockedUntil!.toIso8601String(),
        if (lastBackupAt != null)
          'lastBackupAt': lastBackupAt!.toIso8601String(),
        if (backupCountFrom != null)
          'backupCountFrom': backupCountFrom!.toIso8601String(),
        'backupReminder': backupReminder,
        'todoNote': todoNote,
        if (todoWaiting) 'todoWaiting': true,
        if (autoBackupFolder != null) 'autoBackupFolder': autoBackupFolder,
        if (autoBackupFolderName != null)
          'autoBackupFolderName': autoBackupFolderName,
        if (lastAutoBackupAt != null)
          'lastAutoBackupAt': lastAutoBackupAt!.toUtc().toIso8601String(),
        'autoBackupFailed': autoBackupFailed,
        if (pipPlugged) 'pipPlugged': true,
      };

  /// Missing values take their defaults, so older files stay readable.
  factory Preferences.fromJson(Map<String, dynamic> json) => Preferences(
        theme: json['theme'] as String? ?? 'clay',
        counterFeedback: json['counterFeedback'] as bool? ?? true,
        noteLineNumbers: json['noteLineNumbers'] as bool? ?? true,
        fingerprintFor: json['fingerprintFor'] as String?,
        medicineReminders: json['medicineReminders'] as bool? ?? true,
        medicinePausedUntil: json['medicinePausedUntil'] == null
            ? null
            : PlannerTask.dayFromJson(json['medicinePausedUntil']),
        plannerReminders: json['plannerReminders'] as bool? ?? true,
        plannerPausedUntil: json['plannerPausedUntil'] == null
            ? null
            : PlannerTask.dayFromJson(json['plannerPausedUntil']),
        datesReminders: json['datesReminders'] as bool? ?? true,
        datesPausedUntil: json['datesPausedUntil'] == null
            ? null
            : PlannerTask.dayFromJson(json['datesPausedUntil']),
        datesSeenOn: json['datesSeenOn'] == null
            ? null
            : PlannerTask.dayFromJson(json['datesSeenOn']),
        // Pages unknown here (from a newer app) are skipped.
        notifyStyles: {
          for (final MapEntry(:key, :value)
              in (json['notifyStyles'] as Map<String, dynamic>? ?? const {})
                  .entries)
            if (NotifyPage.fromName(key) case final page?)
              page: NotifyStyle.fromJson(value as Map<String, dynamic>),
        },
        introDeleted: json['introDeleted'] as bool? ?? false,
        introOnUpdates: json['introOnUpdates'] as bool? ?? true,
        introVersion: json['introVersion'] as String?,
        introUnread: json['introUnread'] as bool? ?? false,
        introScroll: (json['introScroll'] as num?)?.toDouble() ?? 0,
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
        todoNote: json['todoNote'] as bool? ?? true,
        todoWaiting: json['todoWaiting'] as bool? ?? false,
        autoBackupFolder: json['autoBackupFolder'] as String?,
        autoBackupFolderName: json['autoBackupFolderName'] as String?,
        lastAutoBackupAt: json['lastAutoBackupAt'] == null
            ? null
            : DateTime.parse(json['lastAutoBackupAt'] as String).toLocal(),
        autoBackupFailed: json['autoBackupFailed'] as bool? ?? false,
        pipPlugged: json['pipPlugged'] as bool? ?? false,
      );
}
