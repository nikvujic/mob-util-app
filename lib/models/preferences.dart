/// How the user likes the app: look and feel, kept on this phone (not in
/// backups).
class Preferences {
  /// The chosen theme's id (see `AppThemeChoice` in core/theme.dart).
  final String theme;

  /// Vibration and a click sound on counter buttons (U6).
  final bool counterFeedback;

  /// The count on the "Džoni" page (O4).
  final int dzoniCount;

  const Preferences({
    this.theme = 'green',
    this.counterFeedback = true,
    this.dzoniCount = 0,
  });

  Preferences copyWith({
    String? theme,
    bool? counterFeedback,
    int? dzoniCount,
  }) =>
      Preferences(
        theme: theme ?? this.theme,
        counterFeedback: counterFeedback ?? this.counterFeedback,
        dzoniCount: dzoniCount ?? this.dzoniCount,
      );

  Map<String, dynamic> toJson() => {
        'theme': theme,
        'counterFeedback': counterFeedback,
        'dzoniCount': dzoniCount,
      };

  /// Missing values take their defaults, so older files stay readable.
  factory Preferences.fromJson(Map<String, dynamic> json) => Preferences(
        theme: json['theme'] as String? ?? 'green',
        counterFeedback: json['counterFeedback'] as bool? ?? true,
        dzoniCount: json['dzoniCount'] as int? ?? 0,
      );
}
