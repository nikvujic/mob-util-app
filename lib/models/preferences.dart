/// How the user likes the app: look and feel, kept on this phone (not in
/// backups, except the Džoni count).
class Preferences {
  /// The chosen theme's id (see `AppThemeChoice` in core/theme.dart).
  final String theme;

  /// Vibration and a click sound on counter buttons (U6).
  final bool counterFeedback;

  /// The count on the "Džoni" page (O4).
  final int dzoniCount;

  /// Fingerprint unlock (L6): the salt (base64) of the master password
  /// whose key is in the phone's keystore, or null when it's off. Not a
  /// secret; it tells which password the stored key belongs to.
  final String? fingerprintFor;

  const Preferences({
    this.theme = 'green',
    this.counterFeedback = true,
    this.dzoniCount = 0,
    this.fingerprintFor,
  });

  Preferences copyWith({
    String? theme,
    bool? counterFeedback,
    int? dzoniCount,
    String? Function()? fingerprintFor,
  }) =>
      Preferences(
        theme: theme ?? this.theme,
        counterFeedback: counterFeedback ?? this.counterFeedback,
        dzoniCount: dzoniCount ?? this.dzoniCount,
        fingerprintFor:
            fingerprintFor == null ? this.fingerprintFor : fingerprintFor(),
      );

  Map<String, dynamic> toJson() => {
        'theme': theme,
        'counterFeedback': counterFeedback,
        'dzoniCount': dzoniCount,
        if (fingerprintFor != null) 'fingerprintFor': fingerprintFor,
      };

  /// Missing values take their defaults, so older files stay readable.
  factory Preferences.fromJson(Map<String, dynamic> json) => Preferences(
        theme: json['theme'] as String? ?? 'green',
        counterFeedback: json['counterFeedback'] as bool? ?? true,
        dzoniCount: json['dzoniCount'] as int? ?? 0,
        fingerprintFor: json['fingerprintFor'] as String?,
      );
}
