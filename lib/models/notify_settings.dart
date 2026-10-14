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
  // Round 39: hacky 8-bit ones, to try (Chime, Bell and Soft are gone).
  coin('Coin', 'notify_coin'),
  powerUp('Power-up', 'notify_powerup'),
  blip('Blip', 'notify_blip'),
  alert('Alert', 'notify_alert'),
  zap('Zap', 'notify_zap'),
  jingle('Jingle', 'notify_jingle'),
  silent('Silent');

  final String label;

  /// Its sound file (an Android raw resource, `tool/make_notify_sounds.py`);
  /// none for the phone's own and for silence.
  final String? resource;

  const NotifySound(this.label, [this.resource]);

  /// The one stored as [name]; the gone ones (Round 39) as the nearest
  /// new one; unknown: the phone's.
  static NotifySound fromName(String? name) =>
      values.where((s) => s.name == name).firstOrNull ??
      switch (name) {
        'chime' => coin,
        'bell' => alert,
        'soft' => blip,
        _ => phone,
      };
}

/// How loud the app's own sounds are (Round 41: they were loud). Android
/// plays a notification's sound at the phone's notification volume, so
/// each level is its own copy of the sound, quieter
/// (`tool/make_notify_sounds.py`); the phone's own sound can't be made
/// quieter by the app.
enum NotifyVolume {
  loud('Loud', 1, ''),
  medium('Medium', 0.5, '_medium'),
  quiet('Quiet', 0.25, '_quiet');

  final String label;

  /// About how loud, against [loud].
  final double level;

  /// What its sound files' names end in.
  final String suffix;

  const NotifyVolume(this.label, this.level, this.suffix);

  /// [sound]'s file at this volume, or null for none of the app's.
  String? resourceOf(NotifySound sound) =>
      sound.resource == null ? null : '${sound.resource}$suffix';

  static NotifyVolume fromName(String? name) =>
      values.where((v) => v.name == name).firstOrNull ?? loud;
}

/// How one page's notifications look and sound (Round 31).
class NotifyStyle {
  /// Names left out ("A task at 10:00", "A dose is due"), so nothing
  /// private shows on the lock screen.
  final bool private;

  /// The tint (a planner block colour's name), or null: the phone's own.
  final String? colour;

  final NotifySound sound;

  /// How loud its sound (Round 41), if it's one of the app's.
  final NotifyVolume volume;

  const NotifyStyle({
    this.private = false,
    this.colour,
    this.sound = NotifySound.phone,
    this.volume = NotifyVolume.loud,
  });

  static const plain = NotifyStyle();

  NotifyStyle copyWith({
    bool? private,
    String? Function()? colour,
    NotifySound? sound,
    NotifyVolume? volume,
  }) =>
      NotifyStyle(
        private: private ?? this.private,
        colour: colour == null ? this.colour : colour(),
        sound: sound ?? this.sound,
        volume: volume ?? this.volume,
      );

  Map<String, dynamic> toJson() => {
        if (private) 'private': true,
        if (colour != null) 'colour': colour,
        if (sound != NotifySound.phone) 'sound': sound.name,
        if (volume != NotifyVolume.loud) 'volume': volume.name,
      };

  factory NotifyStyle.fromJson(Map<String, dynamic> json) => NotifyStyle(
        private: json['private'] as bool? ?? false,
        colour: json['colour'] as String?,
        sound: NotifySound.fromName(json['sound'] as String?),
        volume: NotifyVolume.fromName(json['volume'] as String?),
      );

  @override
  bool operator ==(Object other) =>
      other is NotifyStyle &&
      other.private == private &&
      other.colour == colour &&
      other.sound == sound &&
      other.volume == volume;

  @override
  int get hashCode => Object.hash(private, colour, sound, volume);
}
