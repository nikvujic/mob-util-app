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

  const Preferences({
    this.theme = 'clay',
    this.counterFeedback = true,
    this.noteLineNumbers = true,
    this.fingerprintFor,
  });

  Preferences copyWith({
    String? theme,
    bool? counterFeedback,
    bool? noteLineNumbers,
    String? Function()? fingerprintFor,
  }) =>
      Preferences(
        theme: theme ?? this.theme,
        counterFeedback: counterFeedback ?? this.counterFeedback,
        noteLineNumbers: noteLineNumbers ?? this.noteLineNumbers,
        fingerprintFor:
            fingerprintFor == null ? this.fingerprintFor : fingerprintFor(),
      );

  Map<String, dynamic> toJson() => {
        'theme': theme,
        'counterFeedback': counterFeedback,
        'noteLineNumbers': noteLineNumbers,
        if (fingerprintFor != null) 'fingerprintFor': fingerprintFor,
      };

  /// Missing values take their defaults, so older files stay readable.
  factory Preferences.fromJson(Map<String, dynamic> json) => Preferences(
        theme: json['theme'] as String? ?? 'clay',
        counterFeedback: json['counterFeedback'] as bool? ?? true,
        noteLineNumbers: json['noteLineNumbers'] as bool? ?? true,
        fingerprintFor: json['fingerprintFor'] as String?,
      );
}
