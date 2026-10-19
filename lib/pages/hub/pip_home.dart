import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:the_app/providers/weather_provider.dart';
import 'package:the_app/core/weather.dart';
import 'package:the_app/core/clock.dart';
import 'package:the_app/core/pip_adventure.dart';
import 'package:the_app/core/sound.dart';
import 'package:the_app/core/pip_brain.dart';
import 'package:the_app/core/pip_energy.dart';
import 'package:the_app/core/pip_scene.dart';
import 'package:the_app/core/pip_weather.dart';
import 'package:the_app/core/theme.dart';
import 'package:the_app/models/pip_life.dart';
import 'package:the_app/providers/dates_provider.dart';
import 'package:the_app/providers/pip_life_provider.dart';
import 'package:the_app/providers/pip_trip.dart';
import 'package:the_app/providers/pip_provider.dart';
import 'package:the_app/widgets/pip_energy_bar.dart';
import 'package:the_app/widgets/pip_portrait.dart';
import 'package:the_app/widgets/pip_room.dart';
import 'package:the_app/widgets/pip_sprites.dart';
import 'package:the_app/widgets/pixel_text.dart';

/// Pip Home (Round 35): his field, big, on top, following the time of
/// day; under it a card in his own pixel letters, swiped between his
/// status and his settings (rename, animations, backgrounds). Everything
/// happens in the card: renaming has its own keyboard. Round 73: two
/// views, switched from the first card: his info (and his settings), or
/// his adventures (his level, XP and items; later more cards), the one
/// it opens in while he's out.
class PipHomePage extends ConsumerStatefulWidget {
  const PipHomePage({super.key});

  @override
  ConsumerState<PipHomePage> createState() => _PipHomePageState();
}

/// What the settings side of the card shows.
enum _Settings { menu, rename, animations, adventures, backgrounds, hats }

class _PipHomePageState extends ConsumerState<PipHomePage> {
  /// His own, here: the menu's Pip stays where he was.
  final _brain = PipBrain();
  final _pages = PageController();
  int _page = 0;
  _Settings _settings = _Settings.menu;

  /// Round 73: the adventure view (his adventure card, no settings), or
  /// his info; it opens in the adventure view while he's out.
  late bool _adventureView = _outNow();

  bool _outNow() {
    final now = ref.read(clockProvider)();
    return ref.read(pipLifeProvider.notifier).outAt(now) &&
        // On his ski trip's bus there's no adventure to see.
        !PipTrip.busDay(ref.read(datesProvider), now);
  }

  void _switchView() => setState(() {
        _adventureView = !_adventureView;
        _settings = _Settings.menu;
      });

  /// Previews (Round 57): a background and a hat tried, together with
  /// his animations; back to his info card (or leaving), they're gone.
  PipBackground _background = PipBackground.field;

  /// Round 70: a season, the weather, an occasion or a time of day tried
  /// on his field, with the background.
  PipLook _look = PipLook.none;

  void _endPreviews() {
    _background = PipBackground.field;
    _look = PipLook.none;
    _brain.stopTryingOn();
    // Round 67: an adventure preview stops too.
    _brain.stopPreviews();
  }

  /// The scene's pixel: Pip as big as in the menu (Round 38), in a
  /// bigger field.
  static const _pixel = PipRoom.smallPixel;

  @override
  void dispose() {
    _pages.dispose();
    super.dispose();
  }

  void _show(_Settings settings) => setState(() => _settings = settings);

  @override
  Widget build(BuildContext context) {
    final background = _background;
    final scene = PipScene.at(
      PipPlace.home,
      ref.watch(clockProvider)(),
      background: background,
      // Round 70: the weather, if it's on in Internet Access.
      weatherCode: ref.watch(skyWeatherProvider),
      windSpeed: ref.watch(skyWindProvider),
      look: _look,
    );
    return Scaffold(
      appBar: AppBar(title: const Text('Pip')),
      body: LayoutBuilder(
        builder: (context, box) {
          // Half the page for his field (Round 36).
          // (His pixels are whole device pixels, as PipRoom draws them.)
          final ratio = MediaQuery.devicePixelRatioOf(context);
          final pixel = math.max(1.0, (_pixel * ratio).floorToDouble()) / ratio;
          final rows = (box.maxHeight * 0.5 / pixel).floor().clamp(40, 400);
          return Column(
            children: [
              PipRoom(
                brain: _brain,
                animate: ref.watch(pipAnimatesProvider),
                link: ref.watch(pipLinkProvider),
                scene: scene,
                height: rows,
                pixel: _pixel,
                // Round 52: out of the ground or from the sky (thrown in
                // only by the menu's swing).
                entrances: const {PipEntrance.ground, PipEntrance.sky},
              ),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(12, 12, 12, 16),
                  child: _Panel(
                    child: Column(
                      children: [
                        Expanded(
                          child: PageView(
                            key: const Key('pipCard'),
                            controller: _pages,
                            // Inside a setting, it stays put.
                            physics: _settings == _Settings.menu
                                ? null
                                : const NeverScrollableScrollPhysics(),
                            onPageChanged: (page) => setState(() {
                              _page = page;
                              if (page == 0) _endPreviews();
                            }),
                            children: [
                              _Status(
                                adventure: _adventureView,
                                switchView: _switchView,
                                cheer: () => setState(_brain.cheer),
                              ),
                              // Round 73: the settings (animations and
                              // the rest) are his info's.
                              if (!_adventureView)
                                switch (_settings) {
                                  _Settings.menu => _SettingsMenu(
                                      background: background,
                                      open: _show,
                                    ),
                                  _Settings.rename => _Rename(
                                      back: () => _show(_Settings.menu),
                                    ),
                                  _Settings.animations => _Animations(
                                      brain: _brain,
                                      // Round 75: the weather's, tried on.
                                      tryWeather: (kind) =>
                                          setState(() => _look = PipLook(
                                                season: _look.season,
                                                weather: kind,
                                                occasion: _look.occasion,
                                                part: _look.part,
                                              )),
                                      back: () => _show(_Settings.menu),
                                    ),
                                  _Settings.adventures => _Adventures(
                                      brain: _brain,
                                      back: () => _show(_Settings.menu),
                                    ),
                                  _Settings.backgrounds => _Backgrounds(
                                      current: background,
                                      pick: (b) =>
                                          setState(() => _background = b),
                                      look: _look,
                                      tryOn: (key) => setState(
                                          () => _look = _look.toggled(key)),
                                      back: () => _show(_Settings.menu),
                                    ),
                                  _Settings.hats => _Hats(
                                      current: _brain.hat,
                                      pick: (hat) =>
                                          setState(() => _brain.tryOn(hat)),
                                      back: () => _show(_Settings.menu),
                                    ),
                                },
                            ],
                          ),
                        ),
                        if (!_adventureView) _Dots(count: 2, current: _page),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

/// The card: a dark panel with a pixel edge.
class _Panel extends StatelessWidget {
  final Widget child;

  const _Panel({required this.child});

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: PipColours.panel,
        border: Border.all(color: PipColours.panelEdge, width: 4),
      ),
      child: Material(type: MaterialType.transparency, child: child),
    );
  }
}

/// Which side of the card shows: a square for each.
class _Dots extends StatelessWidget {
  final int count;
  final int current;

  const _Dots({required this.count, required this.current});

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: 'Card ${current + 1} of $count. Swipe for more',
      child: Padding(
        padding: const EdgeInsets.only(bottom: 10, top: 4),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            for (var i = 0; i < count; i++)
              Container(
                width: 8,
                height: 8,
                margin: const EdgeInsets.symmetric(horizontal: 4),
                color: i == current ? PipColours.light : PipColours.panelEdge,
              ),
          ],
        ),
      ),
    );
  }
}

/// Words on the card, in his letters.
Widget _words(String text, {Color colour = PipColours.screen, double? pixel}) =>
    PixelText([(text, colour)], pixel: pixel ?? 3, label: text);

/// His status: how he looks, his name, age and birthday.
class _Status extends ConsumerStatefulWidget {
  /// Round 73: his adventure card (the adventure view) or his info card,
  /// and the row on it that switches between them.
  final bool adventure;
  final VoidCallback switchView;

  /// Just registered as an adventurer (Round 63): his sword up high.
  final VoidCallback cheer;

  const _Status({
    required this.adventure,
    required this.switchView,
    required this.cheer,
  });

  @override
  ConsumerState<_Status> createState() => _StatusState();
}

class _StatusState extends ConsumerState<_Status> {
  /// The next battery's countdown, kept current.
  late final Timer _tick = Timer.periodic(
    const Duration(seconds: 30),
    (_) => setState(() {}),
  );

  @override
  void initState() {
    super.initState();
    _tick;
  }

  @override
  void dispose() {
    _tick.cancel();
    super.dispose();
  }

  static String _date(DateTime d) =>
      '${d.day}.${d.month.toString().padLeft(2, '0')}.${d.year}';

  /// "2H 15M", "40M" (at least a minute).
  static String _until(Duration d) {
    final minutes = math.max(1, (d.inSeconds / 60).ceil());
    final h = minutes ~/ 60, m = minutes % 60;
    return h == 0 ? '${m}M' : (m == 0 ? '${h}H' : '${h}H ${m}M');
  }

  /// What the adventure card says after a tap on Register outside its
  /// hours (Round 63).
  String? _message;

  void _toggle() {
    setState(() => _message = null);
    widget.switchView();
  }

  /// Registers him (Round 63): from 13:00 to 17:00; else come back then.
  void _register() {
    final now = ref.read(clockProvider)();
    if (!PipAdventure.canRegisterAt(now)) {
      HapticFeedback.selectionClick();
      setState(() => _message = 'COME BACK BETWEEN '
          '${PipAdventure.registerFrom}:00 AND '
          '${PipAdventure.registerUntil}:00');
      return;
    }
    if (!ref.read(pipLifeProvider.notifier).register(now)) return;
    setState(() => _message = null);
    HapticFeedback.heavyImpact();
    AppSound.fanfare();
    widget.cheer();
  }

  @override
  Widget build(BuildContext context) {
    final pip = ref.watch(pipLifeProvider);
    final life = ref.read(pipLifeProvider.notifier);
    final now = ref.watch(clockProvider)();
    final born = pip.born?.toLocal();
    final segments = life.segmentsAt(now);
    final show = life.showAt(now);
    final face = switch (show) {
      PipShow.off || PipShow.powerOff => PipFace.off,
      PipShow.asleep => PipFace.asleep,
      // Round 77: woken at night, drowsy.
      _ when life.drowsyAt(now) => PipFace.veryTired,
      _ => switch (segments) {
          3 => PipFace.normal,
          2 => PipFace.tired,
          _ => PipFace.veryTired,
        },
    };
    if (widget.adventure) return _adventureCard(pip, life, now, face);
    final next = pip.nextBatteryAt;
    // What a tap on his field would do (Round 37).
    final hint = switch (life.refusalAt(now)) {
      null => 'TAP THE FIELD TO GIVE HIM ONE',
      PipRefusal.full => "HE'S FULL",
      PipRefusal.asleep =>
        life.mayWakeAt(now) ? 'TAP HIM 3 TIMES TO WAKE HIM' : "HE'S ASLEEP",
      PipRefusal.charging => "HE'S CHARGING",
      PipRefusal.travelling => "HE'S ON HIS TRIP",
      PipRefusal.noBatteries || PipRefusal.egg => null,
    };
    return SingleChildScrollView(
      key: const Key('pipStatus'),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              PipPortrait(face: face),
              const SizedBox(width: 20),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _words(pip.name, colour: PipColours.light, pixel: 5),
                    const SizedBox(height: 16),
                    _line('AGE', PipLife.ageText(pip.ageOn(now) ?? 1)),
                    const SizedBox(height: 10),
                    if (born != null) _line('BORN', _date(born)),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          // His energy and batteries (Round 37).
          Row(
            children: [
              _words('ENERGY  ', colour: PipColours.dim),
              PipEnergyBar(
                key: const Key('pipStatusEnergy'),
                segments: segments,
                pixel: 3,
              ),
            ],
          ),
          const SizedBox(height: 10),
          _line('BATTERIES', '${pip.batteries}/${PipEnergy.maxBatteries}'),
          if (next != null) ...[
            const SizedBox(height: 10),
            _line('NEXT IN', _until(next.difference(now))),
          ],
          if (hint != null) ...[
            const SizedBox(height: 16),
            _words(hint, colour: PipColours.light),
          ],
          // Round 63: his adventures, always here.
          const SizedBox(height: 12),
          _CardRow(
            key: const Key('pipAdventures'),
            label: 'ADVENTURES',
            value: '>',
            onTap: _toggle,
          ),
        ],
      ),
    );
  }

  /// His adventure card (Round 63): his level and title, the XP to the
  /// next, his weapon, off-hand and hat; not registered yet, a button to.
  Widget _adventureCard(
      PipLife pip, PipLifeNotifier life, DateTime now, PipFace face) {
    // Round 73: as shown in his room (up as he strikes bugs, watched).
    final xp = pipShownXp(ref, now);
    final level = PipAdventure.levelFor(xp);
    final from = PipAdventure.xpFor(level);
    final to = PipAdventure.xpFor(level + 1);
    final message = _message;
    return SingleChildScrollView(
      key: const Key('pipAdventure'),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              PipPortrait(face: face),
              const SizedBox(width: 20),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _words(pip.name, colour: PipColours.light, pixel: 5),
                    const SizedBox(height: 16),
                    if (pip.adventurer) ...[
                      _line('LEVEL', '$level'),
                      const SizedBox(height: 10),
                      _words(PipAdventure.titleFor(level).toUpperCase(),
                          colour: PipColours.light),
                    ] else
                      // Round 66: wrapped, clear of the card's edge.
                      const PixelParagraph('NOT AN ADVENTURER YET',
                          colour: PipColours.dim, pixel: 3),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          if (pip.adventurer) ...[
            Row(
              children: [
                _words('XP  ', colour: PipColours.dim),
                Expanded(
                  child: _XpBar(
                    key: const Key('pipXp'),
                    progress: PipAdventure.progressFor(xp),
                  ),
                ),
                _words('  ${xp - from}/${to - from}', colour: PipColours.dim),
              ],
            ),
            const SizedBox(height: 20),
            const Row(
              children: [
                _ItemBox(
                  key: Key('pipWeapon'),
                  label: 'WEAPON',
                  item: PipSprites.sword,
                ),
                SizedBox(width: 12),
                _ItemBox(key: Key('pipOffHand'), label: 'OFF-HAND'),
                SizedBox(width: 12),
                _ItemBox(key: Key('pipHatBox'), label: 'HAT'),
              ],
            ),
          ] else
            _CardRow(
              key: const Key('pipRegister'),
              label: 'REGISTER AS ADVENTURER',
              onTap: _register,
            ),
          if (message != null) ...[
            const SizedBox(height: 12),
            PixelParagraph(message, colour: PipColours.light, pixel: 3),
          ],
          const SizedBox(height: 12),
          _CardRow(
            key: const Key('pipInfo'),
            label: 'INFO',
            value: '<',
            onTap: _toggle,
          ),
        ],
      ),
    );
  }

  static Widget _line(String what, String value) => PixelText(
        [('$what  ', PipColours.dim), (value, PipColours.screen)],
        pixel: 3,
        label: '$what $value',
      );
}

/// A row on the card to tap: words on the left, more on the right.
class _CardRow extends StatelessWidget {
  final String label;
  final String? value;
  final Color valueColour;
  final VoidCallback onTap;

  const _CardRow({
    super.key,
    required this.label,
    this.value,
    this.valueColour = PipColours.dim,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: value == null ? label : '$label, $value',
      child: ExcludeSemantics(
        child: InkWell(
          onTap: onTap,
          child: SizedBox(
            height: 48,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Row(
                children: [
                  _words(label),
                  const Spacer(),
                  if (value case final value?)
                    _words(value, colour: valueColour),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Settings: rename, animations, background.
class _SettingsMenu extends StatelessWidget {
  final PipBackground background;
  final ValueChanged<_Settings> open;

  const _SettingsMenu({required this.background, required this.open});

  @override
  Widget build(BuildContext context) {
    return ListView(
      key: const Key('pipSettings'),
      padding: const EdgeInsets.symmetric(vertical: 8),
      children: [
        _CardRow(
          key: const Key('pipRename'),
          label: 'RENAME',
          value: '>',
          onTap: () => open(_Settings.rename),
        ),
        _CardRow(
          key: const Key('pipAnimations'),
          label: 'ANIMATIONS',
          value: '>',
          onTap: () => open(_Settings.animations),
        ),
        // Round 67: his adventures, as previews (no XP).
        _CardRow(
          key: const Key('pipAdventurePreviews'),
          label: 'ADVENTURES',
          value: '>',
          onTap: () => open(_Settings.adventures),
        ),
        // Picked from a list (Round 36); the one in use beside it. Round
        // 57: a preview, like a hat.
        _CardRow(
          key: const Key('pipBackground'),
          label: 'BACKGROUND',
          value: '${background.label.toUpperCase()} >',
          onTap: () => open(_Settings.backgrounds),
        ),
        // Round 57: hats to try on him.
        _CardRow(
          key: const Key('pipHats'),
          label: 'HATS',
          value: '>',
          onTap: () => open(_Settings.hats),
        ),
      ],
    );
  }
}

/// His backgrounds to pick from (Round 36: one for now, Field; day and
/// night are the same one), the one in use marked. Round 57: a preview,
/// not kept. Round 70: under it, what can be tried on it: the seasons,
/// the weather, the occasions and the times of day (one of each at a
/// time, tapped again to take it off).
class _Backgrounds extends StatelessWidget {
  final PipBackground current;
  final ValueChanged<PipBackground> pick;
  final PipLook look;
  final ValueChanged<Object> tryOn;
  final VoidCallback back;

  const _Backgrounds({
    required this.current,
    required this.pick,
    required this.look,
    required this.tryOn,
    required this.back,
  });

  /// What can be tried, in groups: each one's key, label and whether on.
  static const weathers = [
    WeatherKind.partlyCloudy,
    WeatherKind.cloudy,
    WeatherKind.fog,
    WeatherKind.drizzle,
    WeatherKind.rain,
    WeatherKind.storm,
    WeatherKind.snow,
  ];

  @override
  Widget build(BuildContext context) {
    Widget row(Object key, String label, bool on) => _CardRow(
          key: Key('pipLook-${(key as Enum).name}'),
          // The pixel letters have no apostrophe.
          label: label.replaceAll("'", '').toUpperCase(),
          value: on ? 'ON' : null,
          valueColour: PipColours.light,
          onTap: () => tryOn(key),
        );
    Widget heading(String text) => Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
          child: Align(
            alignment: Alignment.centerLeft,
            child: _words(text, colour: PipColours.dim, pixel: 2),
          ),
        );
    return Column(
      key: const Key('pipBackgroundList'),
      children: [
        Expanded(
          child: ListView(
            padding: const EdgeInsets.symmetric(vertical: 8),
            children: [
              for (final b in PipBackground.values)
                _CardRow(
                  key: Key('pipBackground-${b.name}'),
                  label: b.label.toUpperCase(),
                  value: b == current ? 'IN USE' : null,
                  valueColour: PipColours.light,
                  onTap: () => pick(b),
                ),
              heading('SEASONS'),
              for (final season in Season.values)
                row(season, season.label, look.season == season),
              heading('WEATHER'),
              for (final weather in weathers)
                row(weather, weather.label, look.weather == weather),
              heading('DAYS'),
              for (final occasion in PipOccasion.values)
                row(occasion, occasion.label, look.occasion == occasion),
              heading('TIME OF DAY'),
              for (final part in DayPart.values)
                row(part, part.name, look.part == part),
            ],
          ),
        ),
        _back(back),
      ],
    );
  }
}

/// Hats to try on him (Round 57): a tap puts one on (None takes it off),
/// the one he has marked. Not kept: back to his info card, it's gone.
class _Hats extends StatelessWidget {
  final PipHat? current;
  final ValueChanged<PipHat?> pick;
  final VoidCallback back;

  const _Hats({required this.current, required this.pick, required this.back});

  @override
  Widget build(BuildContext context) {
    return Column(
      key: const Key('pipHatList'),
      children: [
        Expanded(
          child: ListView(
            padding: const EdgeInsets.symmetric(vertical: 8),
            children: [
              for (final hat in [null, ...PipHat.values])
                _CardRow(
                  key: Key('pipHat-${hat?.name ?? 'none'}'),
                  label: (hat?.label ?? 'None').toUpperCase(),
                  value: hat == current ? 'ON' : null,
                  valueColour: PipColours.light,
                  onTap: () => pick(hat),
                ),
            ],
          ),
        ),
        _back(back),
      ],
    );
  }
}

/// A setting's back button, at the bottom of the card.
Widget _back(VoidCallback back) => _CardRow(
      key: const Key('pipBack'),
      label: '< BACK',
      onTap: back,
    );

/// Each of his animations, played in the scene on a tap; while he's
/// busy (e.g. coming out of the ground), it says so.
class _Animations extends StatefulWidget {
  final PipBrain brain;
  final VoidCallback back;

  /// Round 75: tries a weather on his field (the weather's animations,
  /// and his tent and umbrella), as Background's list does.
  final ValueChanged<WeatherKind> tryWeather;

  const _Animations({
    required this.brain,
    required this.tryWeather,
    required this.back,
  });

  @override
  State<_Animations> createState() => _AnimationsState();
}

class _AnimationsState extends State<_Animations> {
  Timer? _hide;

  @override
  void dispose() {
    _hide?.cancel();
    super.dispose();
  }

  /// Why he can't now, said on the card for a moment.
  String? _why;

  void _play(PipAnimation animation) {
    final brain = widget.brain;
    // Round 75: the weather's in its weather (tried on, as Background's).
    if (PipBrainWeather.eventOf(animation) case final event?) {
      widget.tryWeather(weatherFor(event));
    }
    if (brain.play(animation, demo: true)) {
      HapticFeedback.selectionClick();
      return;
    }
    _hide?.cancel();
    setState(() => _why = switch (brain.activity) {
          PipActivity.asleep => "HE'S ASLEEP",
          PipActivity.off => "HE'S OFF",
          // Round 45: at his station (the phone plugged in).
          PipActivity.toStation ||
          PipActivity.plugging ||
          PipActivity.charging ||
          PipActivity.unplugging =>
            "HE'S CHARGING",
          _ => "HE'S BUSY, A MOMENT",
        });
    _hide = Timer(const Duration(milliseconds: 1200), () {
      if (mounted) setState(() => _why = null);
    });
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      key: const Key('pipAnimationList'),
      children: [
        Expanded(
          child: ListView(
            padding: const EdgeInsets.symmetric(vertical: 8),
            children: [
              for (final a in PipAnimation.values)
                if (a.listed)
                  _CardRow(
                    key: Key('pipPlay-${a.name}'),
                    label: a.label.toUpperCase(),
                    value: '>',
                    onTap: () => _play(a),
                  ),
              // Round 75: the weather's cover, seen coming (it goes when
              // the weather's taken off, in Background).
              for (final (kind, label) in const [
                (WeatherKind.storm, 'HIS TENT IN A STORM'),
                (WeatherKind.rain, 'HIS UMBRELLA IN THE RAIN'),
                (WeatherKind.fog, 'SLOW IN THE FOG'),
              ])
                _CardRow(
                  key: Key('pipWeather-${kind.name}'),
                  label: label,
                  value: '>',
                  onTap: () {
                    HapticFeedback.selectionClick();
                    widget.tryWeather(kind);
                  },
                ),
            ],
          ),
        ),
        if (_why case final why?)
          Padding(
            padding: const EdgeInsets.only(bottom: 4),
            child: _words(why, colour: PipColours.light),
          ),
        _back(widget.back),
      ],
    );
  }
}

/// His adventures as previews (Round 67): a day out, a ski run, a bus
/// trip, played in his field; no XP, nothing kept, stopped back on his
/// info card.
class _Adventures extends StatefulWidget {
  final PipBrain brain;
  final VoidCallback back;

  const _Adventures({required this.brain, required this.back});

  @override
  State<_Adventures> createState() => _AdventuresState();
}

class _AdventuresState extends State<_Adventures> {
  Timer? _hide;
  String? _why;

  @override
  void dispose() {
    _hide?.cancel();
    super.dispose();
  }

  void _play(bool Function() play) {
    if (play()) {
      HapticFeedback.selectionClick();
      return;
    }
    _hide?.cancel();
    setState(() => _why = switch (widget.brain.activity) {
          PipActivity.asleep => "HE'S ASLEEP",
          PipActivity.off => "HE'S OFF",
          PipActivity.adventuring => "HE'S OUT",
          PipActivity.riding => "HE'S ON HIS TRIP",
          _ => "HE'S BUSY, A MOMENT",
        });
    _hide = Timer(const Duration(milliseconds: 1200), () {
      if (mounted) setState(() => _why = null);
    });
  }

  @override
  Widget build(BuildContext context) {
    final brain = widget.brain;
    return Column(
      key: const Key('pipAdventureList'),
      children: [
        Expanded(
          child: ListView(
            padding: const EdgeInsets.symmetric(vertical: 8),
            children: [
              _CardRow(
                key: const Key('pipPreview-adventure'),
                label: 'ADVENTURE',
                value: '>',
                onTap: () => _play(brain.previewAdventure),
              ),
              // Round 73: the boss's fight (a real one's luck: once a
              // day out, while watched).
              _CardRow(
                key: const Key('pipPreview-boss'),
                label: 'BOSS',
                value: '>',
                onTap: () => _play(() => brain.previewAdventure(boss: true)),
              ),
              _CardRow(
                key: const Key('pipPreview-skiing'),
                label: 'SKIING',
                value: '>',
                onTap: () => _play(() => brain.previewAdventure(ski: true)),
              ),
              _CardRow(
                key: const Key('pipPreview-bus'),
                label: 'BUS TRIP',
                value: '>',
                onTap: () => _play(brain.previewBus),
              ),
            ],
          ),
        ),
        if (_why case final why?)
          Padding(
            padding: const EdgeInsets.only(bottom: 4),
            child: _words(why, colour: PipColours.light),
          ),
        _back(widget.back),
      ],
    );
  }
}

/// Renaming him, on the card's own keyboard (no phone keyboard): up to
/// [PipLifeNotifier.maxName] letters or numbers.
class _Rename extends ConsumerStatefulWidget {
  final VoidCallback back;

  const _Rename({required this.back});

  @override
  ConsumerState<_Rename> createState() => _RenameState();
}

class _RenameState extends ConsumerState<_Rename> {
  late String _name = ref.read(pipLifeProvider).name.toUpperCase();
  bool _numbers = false;

  /// Seven keys a row at most (the last row's end has space and delete),
  /// each a full tap target, so a phone's width holds them.
  static const _letters = ['ABCDEFG', 'HIJKLMN', 'OPQRSTU', 'VWXYZ'];
  static const _digits = ['1234567', '890-.'];

  void _type(String char) {
    if (_name.length >= PipLifeNotifier.maxName) return;
    HapticFeedback.selectionClick();
    setState(() => _name += char);
  }

  void _delete() {
    if (_name.isEmpty) return;
    HapticFeedback.selectionClick();
    setState(() => _name = _name.substring(0, _name.length - 1));
  }

  void _save() {
    ref.read(pipLifeProvider.notifier).rename(_name);
    widget.back();
  }

  @override
  Widget build(BuildContext context) {
    final full = _name.length >= PipLifeNotifier.maxName;
    final blanks = PipLifeNotifier.maxName - _name.length;
    final rows = _numbers ? _digits : _letters;
    return Column(
      key: const Key('pipRenameKeys'),
      children: [
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(8, 12, 8, 4),
            child: Column(
              children: [
                // The name so far, and room for the rest.
                PixelText(
                  [
                    (_name, PipColours.light),
                    ('_' * blanks, PipColours.dim),
                  ],
                  key: const Key('pipNewName'),
                  pixel: 5,
                  label: _name.isEmpty ? 'No name yet' : 'New name $_name',
                ),
                const SizedBox(height: 12),
                for (final (i, row) in rows.indexed)
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      for (final char in row.split(''))
                        Flexible(
                          child: _Key(
                            label: char,
                            said: char,
                            onTap: full ? null : () => _type(char),
                          ),
                        ),
                      // The last row's end: a space and delete.
                      if (i == rows.length - 1) ...[
                        Flexible(
                          child: _Key(
                            label: '_',
                            said: 'Space',
                            onTap: full || _name.isEmpty || _name.endsWith(' ')
                                ? null
                                : () => _type(' '),
                          ),
                        ),
                        Flexible(
                          child: _Key(
                            key: const Key('pipKeyDelete'),
                            label: '<',
                            said: 'Delete',
                            onTap: _name.isEmpty ? null : _delete,
                          ),
                        ),
                      ],
                    ],
                  ),
              ],
            ),
          ),
        ),
        // At the bottom, in reach: back, letters or numbers, OK.
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8),
          child: Row(
            children: [
              Expanded(child: _back(widget.back)),
              _Key(
                key: const Key('pipKeyMode'),
                label: _numbers ? 'ABC' : '123',
                said: _numbers ? 'Letters' : 'Numbers',
                wide: true,
                onTap: () => setState(() => _numbers = !_numbers),
              ),
              _Key(
                key: const Key('pipKeySave'),
                label: 'OK',
                said: 'Save the name',
                wide: true,
                highlight: true,
                onTap: _name.trim().isEmpty ? null : _save,
              ),
            ],
          ),
        ),
      ],
    );
  }
}

/// One key of the card's keyboard.
class _Key extends StatelessWidget {
  final String label;
  final String said;
  final VoidCallback? onTap;
  final bool wide;
  final bool highlight;

  const _Key({
    super.key,
    required this.label,
    required this.said,
    required this.onTap,
    this.wide = false,
    this.highlight = false,
  });

  @override
  Widget build(BuildContext context) {
    final on = onTap != null;
    return Semantics(
      button: true,
      enabled: on,
      label: said,
      child: ExcludeSemantics(
        // Up to 48 wide; a little less on a narrow phone, in a row.
        child: ConstrainedBox(
          constraints: BoxConstraints(maxWidth: wide ? 64 : 48),
          child: SizedBox(
            width: double.infinity,
            height: 48,
            child: Padding(
              padding: const EdgeInsets.all(3),
              child: Material(
                color: highlight && on ? PipColours.body : PipColours.key,
                child: InkWell(
                  onTap: onTap,
                  child: Center(
                    child: _words(
                      label,
                      colour: on ? PipColours.screen : PipColours.panelEdge,
                      pixel: 3,
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// How far into his level he is (Round 63): a bar filling up.
class _XpBar extends StatelessWidget {
  final double progress;

  const _XpBar({super.key, required this.progress});

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: 'XP ${(progress * 100).round()}% to the next level',
      child: Container(
        height: 12,
        decoration: BoxDecoration(
          border: Border.all(color: PipColours.panelEdge, width: 3),
        ),
        alignment: Alignment.centerLeft,
        child: FractionallySizedBox(
          widthFactor: progress.clamp(0.0, 1.0),
          heightFactor: 1,
          child: const ColoredBox(color: PipColours.light),
        ),
      ),
    );
  }
}

/// A box for what he carries (Round 63): his weapon (the sword), his
/// off-hand and his hat (empty for now; later from his inventory).
class _ItemBox extends StatelessWidget {
  final String label;
  final List<String>? item;

  const _ItemBox({super.key, required this.label, this.item});

  @override
  Widget build(BuildContext context) {
    final art = item;
    return Semantics(
      label: art == null ? '$label: empty' : '$label: a sword',
      child: ExcludeSemantics(
        child: Column(
          children: [
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                border: Border.all(color: PipColours.panelEdge, width: 3),
              ),
              alignment: Alignment.center,
              child: art == null
                  ? null
                  : CustomPaint(
                      size: Size(art.first.length * 2.5, art.length * 2.5),
                      painter: _ItemPainter(art),
                    ),
            ),
            const SizedBox(height: 6),
            _words(label, colour: PipColours.dim, pixel: 2),
          ],
        ),
      ),
    );
  }
}

class _ItemPainter extends CustomPainter {
  final List<String> art;

  _ItemPainter(this.art);

  @override
  void paint(Canvas canvas, Size size) {
    final pixel = size.height / art.length;
    final paint = Paint()..isAntiAlias = false;
    for (var y = 0; y < art.length; y++) {
      for (var x = 0; x < art[y].length; x++) {
        final colour = PipSprites.fieldColours[art[y][x]];
        if (colour == null) continue;
        canvas.drawRect(Rect.fromLTWH(x * pixel, y * pixel, pixel, pixel),
            paint..color = colour);
      }
    }
  }

  @override
  bool shouldRepaint(_ItemPainter old) => old.art != art;
}
