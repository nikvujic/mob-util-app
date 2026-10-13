/// The app's pages that send notifications (Round 31), each with its own
/// settings on the Notifications page.
enum NotifyPage {
  planner('Planner'),
  medicine('Medicine'),
  backup('Backup');

  final String label;

  const NotifyPage(this.label);

  static NotifyPage? fromName(String? name) =>
      values.where((p) => p.name == name).firstOrNull;
}

/// A notification's sound (Round 31). Android fixes a channel's sound when
/// it's made, so each is a channel of its own.
enum NotifySound {
  phone('Phone\'s default'),
  chime('Chime', 'notify_chime'),
  bell('Bell', 'notify_bell'),
  soft('Soft', 'notify_soft'),
  silent('Silent');

  final String label;

  /// Its sound file (an Android raw resource, `tool/make_notify_sounds.py`);
  /// none for the phone's own and for silence.
  final String? resource;

  const NotifySound(this.label, [this.resource]);

  static NotifySound fromName(String? name) =>
      values.where((s) => s.name == name).firstOrNull ?? phone;
}

/// How one page's notifications look and sound (Round 31).
class NotifyStyle {
  /// Names left out ("A task at 10:00", "A dose is due"), so nothing
  /// private shows on the lock screen.
  final bool private;

  /// The tint (a planner block colour's name), or null: the phone's own.
  final String? colour;

  final NotifySound sound;

  const NotifyStyle({
    this.private = false,
    this.colour,
    this.sound = NotifySound.phone,
  });

  static const plain = NotifyStyle();

  NotifyStyle copyWith({
    bool? private,
    String? Function()? colour,
    NotifySound? sound,
  }) =>
      NotifyStyle(
        private: private ?? this.private,
        colour: colour == null ? this.colour : colour(),
        sound: sound ?? this.sound,
      );

  Map<String, dynamic> toJson() => {
        if (private) 'private': true,
        if (colour != null) 'colour': colour,
        if (sound != NotifySound.phone) 'sound': sound.name,
      };

  factory NotifyStyle.fromJson(Map<String, dynamic> json) => NotifyStyle(
        private: json['private'] as bool? ?? false,
        colour: json['colour'] as String?,
        sound: NotifySound.fromName(json['sound'] as String?),
      );

  @override
  bool operator ==(Object other) =>
      other is NotifyStyle &&
      other.private == private &&
      other.colour == colour &&
      other.sound == sound;

  @override
  int get hashCode => Object.hash(private, colour, sound);
}
