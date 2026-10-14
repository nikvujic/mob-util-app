import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:the_app/core/clock.dart';
import 'package:the_app/core/pip_brain.dart';
import 'package:the_app/core/pip_scene.dart';
import 'package:the_app/core/theme.dart';
import 'package:the_app/models/pip_life.dart';
import 'package:the_app/providers/pip_life_provider.dart';
import 'package:the_app/providers/pip_provider.dart';
import 'package:the_app/providers/preferences_provider.dart';
import 'package:the_app/widgets/pip_portrait.dart';
import 'package:the_app/widgets/pip_room.dart';
import 'package:the_app/widgets/pixel_text.dart';

/// Pip Home (Round 35): his field, big, on top, following the time of
/// day; under it a card in his own pixel letters, swiped between his
/// status and his settings (rename, animations, backgrounds). Everything
/// happens in the card: renaming has its own keyboard.
class PipHomePage extends ConsumerStatefulWidget {
  const PipHomePage({super.key});

  @override
  ConsumerState<PipHomePage> createState() => _PipHomePageState();
}

/// What the settings side of the card shows.
enum _Settings { menu, rename, animations, backgrounds }

class _PipHomePageState extends ConsumerState<PipHomePage> {
  /// His own, here: the menu's Pip stays where he was.
  final _brain = PipBrain();
  final _pages = PageController();
  int _page = 0;
  _Settings _settings = _Settings.menu;

  /// The scene's pixel, bigger than the menu's.
  static const _pixel = 4.0;

  @override
  void dispose() {
    _pages.dispose();
    super.dispose();
  }

  void _show(_Settings settings) => setState(() => _settings = settings);

  @override
  Widget build(BuildContext context) {
    final background = PipBackground.byId(
      ref.watch(preferencesProvider.select((p) => p.pipBackground)),
    );
    final scene = PipScene.at(
      PipPlace.home,
      ref.watch(clockProvider)(),
      background: background,
    );
    return Scaffold(
      appBar: AppBar(title: const Text('Pip')),
      body: LayoutBuilder(
        builder: (context, box) {
          // Half the page for his field (Round 36).
          // (His pixels are whole device pixels, as PipRoom draws them.)
          final ratio = MediaQuery.devicePixelRatioOf(context);
          final pixel = math.max(1.0, (_pixel * ratio).floorToDouble()) / ratio;
          final rows = (box.maxHeight * 0.5 / pixel).floor().clamp(40, 160);
          return Column(
            children: [
              PipRoom(
                brain: _brain,
                animate: ref.watch(pipAnimatesProvider),
                scene: scene,
                height: rows,
                pixel: _pixel,
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
                            onPageChanged: (page) =>
                                setState(() => _page = page),
                            children: [
                              const _Status(),
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
                                    back: () => _show(_Settings.menu),
                                  ),
                                _Settings.backgrounds => _Backgrounds(
                                    current: background,
                                    back: () => _show(_Settings.menu),
                                  ),
                              },
                            ],
                          ),
                        ),
                        _Dots(count: 2, current: _page),
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
class _Status extends ConsumerWidget {
  const _Status();

  static String _date(DateTime d) =>
      '${d.day}.${d.month.toString().padLeft(2, '0')}.${d.year}';

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final pip = ref.watch(pipLifeProvider);
    final now = ref.watch(clockProvider)();
    final born = pip.born?.toLocal();
    return SingleChildScrollView(
      key: const Key('pipStatus'),
      padding: const EdgeInsets.all(16),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const PipPortrait(),
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
        // Picked from a list (Round 36); the one in use beside it.
        _CardRow(
          key: const Key('pipBackground'),
          label: 'BACKGROUND',
          value: '${background.label.toUpperCase()} >',
          onTap: () => open(_Settings.backgrounds),
        ),
      ],
    );
  }
}

/// His backgrounds to pick from (Round 36: one for now, Field; day and
/// night are the same one), the one in use marked.
class _Backgrounds extends ConsumerWidget {
  final PipBackground current;
  final VoidCallback back;

  const _Backgrounds({required this.current, required this.back});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
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
                  onTap: () => ref
                      .read(preferencesProvider.notifier)
                      .setPipBackground(b.name),
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

  const _Animations({required this.brain, required this.back});

  @override
  State<_Animations> createState() => _AnimationsState();
}

class _AnimationsState extends State<_Animations> {
  bool _busy = false;
  Timer? _hide;

  @override
  void dispose() {
    _hide?.cancel();
    super.dispose();
  }

  void _play(PipAnimation animation) {
    final started = widget.brain.play(animation);
    if (started) {
      HapticFeedback.selectionClick();
      return;
    }
    _hide?.cancel();
    setState(() => _busy = true);
    _hide = Timer(const Duration(milliseconds: 1200), () {
      if (mounted) setState(() => _busy = false);
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
                _CardRow(
                  key: Key('pipPlay-${a.name}'),
                  label: a.label.toUpperCase(),
                  value: '>',
                  onTap: () => _play(a),
                ),
            ],
          ),
        ),
        if (_busy)
          Padding(
            padding: const EdgeInsets.only(bottom: 4),
            child: _words("HE'S BUSY, A MOMENT", colour: PipColours.light),
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
