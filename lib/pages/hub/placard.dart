import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:the_app/core/clock.dart';
import 'package:the_app/core/sound.dart';
import 'package:the_app/core/theme.dart';
import 'package:the_app/models/placard.dart';
import 'package:the_app/providers/placard_provider.dart';
import 'package:the_app/widgets/app_dialog.dart';

/// Placard (O4): sideways and full screen (no status bar), a big line of
/// text with a count under it. Holding the page inflates it, shaking more
/// and more, until it pops and counts one up; letting go early lets it
/// down again. Five taps in the top-right corner open its settings (the
/// text and the count). Back turns the phone upright first, then closes.
class PlacardPage extends ConsumerStatefulWidget {
  const PlacardPage({super.key});

  /// How long a hold takes to count.
  /// About 4 seconds (Nikola: longer again in Rounds 16 and 20).
  static const holdTime = Duration(milliseconds: 4000);

  /// The corner that, tapped [cornerTaps] times, opens the settings.
  static const cornerSize = 72.0;
  static const cornerTaps = 5;
  static const cornerWindow = Duration(seconds: 2);

  @override
  ConsumerState<PlacardPage> createState() => _PlacardPageState();
}

/// How much bigger it gets when fully inflated.
const inflated = 0.2;

/// The size during the pop, [p] from 0 to 1: from fully inflated, a quick
/// burst a little bigger, then a spring back to its size that wobbles
/// once. Continuous with the inflating: no jump when it pops.
double popScale(double p) {
  const burst = 0.12; // the first part: bigger
  const peak = 1 + inflated + 0.1;
  if (p < burst) {
    return 1 +
        inflated +
        (peak - 1 - inflated) * Curves.easeOut.transform(p / burst);
  }
  final back = Curves.elasticOut.transform((p - burst) / (1 - burst));
  return peak + (1 - peak) * back;
}

/// The burst's ring: grows from the middle and fades out.
class _Burst extends CustomPainter {
  final double p;
  final Color colour;

  const _Burst(this.p, this.colour);

  @override
  void paint(Canvas canvas, Size size) {
    final t = Curves.easeOut.transform(p);
    final radius = size.shortestSide * (0.3 + 0.5 * t);
    canvas.drawCircle(
      size.center(Offset.zero),
      radius,
      Paint()
        ..color = colour.withValues(alpha: (1 - t) * 0.6)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 10 * (1 - t) + 1,
    );
  }

  @override
  bool shouldRepaint(_Burst old) => old.p != p || old.colour != colour;
}

class _PlacardPageState extends ConsumerState<PlacardPage>
    with TickerProviderStateMixin {
  /// 0 → 1 while held: how inflated the page is.
  late final AnimationController _hold = AnimationController(
    vsync: this,
    duration: PlacardPage.holdTime,
    reverseDuration: const Duration(milliseconds: 250),
  )..addStatusListener(_held);

  /// The pop after a count: from fully inflated, a burst, then a spring
  /// back to its size (Round 17: it used to snap back first, then swell
  /// again, which looked odd).
  late final AnimationController _pop = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 600),
  );

  /// False after a count until the finger lifts: one count per hold.
  bool _armed = true;

  /// Turning upright before closing (back).
  bool _leaving = false;
  Timer? _leaveTimer;

  @override
  void initState() {
    super.initState();
    SystemChrome.setPreferredOrientations([
      DeviceOrientation.landscapeLeft,
      DeviceOrientation.landscapeRight,
    ]);
    // Nothing but the placard: no status bar (Nikola).
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
  }

  @override
  void dispose() {
    _leaveTimer?.cancel();
    // Back to whatever the phone allows, with its bars.
    SystemChrome.setPreferredOrientations([]);
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    _hold.dispose();
    _pop.dispose();
    super.dispose();
  }

  void _down() {
    if (!_armed) return;
    _hold.forward();
    AppSound.inflate();
  }

  void _up() {
    if (_armed) AppSound.stopInflate();
    _armed = true;
    // Also when it hasn't moved yet (a quick tap): else it would go on
    // filling up and count with no finger on it.
    if (_hold.isAnimating || _hold.value > 0) _hold.reverse();
  }

  void _held(AnimationStatus status) {
    // Once per press, however long it's held.
    if (status == AnimationStatus.completed && _armed) _count();
  }

  void _count() {
    _armed = false;
    ref.read(placardProvider.notifier).count();
    HapticFeedback.heavyImpact();
    AppSound.stopInflate();
    AppSound.pop();
    // Deflate after the controller is done reporting (resetting it from
    // its own status call made it report "done" again: a double count).
    scheduleMicrotask(() {
      if (mounted) _hold.value = 0;
    });
    _pop.forward(from: 0);
  }

  final _taps = <DateTime>[];

  void _cornerTapped() {
    final now = ref.read(clockProvider)();
    _taps
      ..add(now)
      ..removeWhere((t) => now.difference(t) > PlacardPage.cornerWindow);
    if (_taps.length >= PlacardPage.cornerTaps) {
      _taps.clear();
      _openSettings();
    }
  }

  Future<void> _openSettings() async {
    final set = await showDialog<Placard>(
      context: context,
      builder: (_) => _SettingsDialog(ref.read(placardProvider)),
    );
    if (set != null && mounted) {
      ref.read(placardProvider.notifier).set(text: set.text, count: set.count);
    }
  }

  /// Back: turn upright first, then close (it used to vanish while still
  /// sideways).
  void _leave() {
    if (_leaving) return;
    setState(() => _leaving = true);
    SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
    // In case the phone doesn't turn (e.g. rotation locked to sideways).
    _leaveTimer = Timer(const Duration(milliseconds: 800), _close);
  }

  void _close() {
    _leaveTimer?.cancel();
    if (mounted && (ModalRoute.of(context)?.isCurrent ?? false)) {
      Navigator.of(context).pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    final placard = ref.watch(placardProvider);
    final upright = MediaQuery.orientationOf(context) == Orientation.portrait;
    if (_leaving && upright) {
      // Turned: now it can go.
      WidgetsBinding.instance.addPostFrameCallback((_) => _close());
    }
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _leave();
      },
      child: Scaffold(
        body: Stack(
          children: [
            Positioned.fill(child: _sign(placard)),
            Positioned(
              top: 0,
              right: 0,
              child: SafeArea(
                child: Semantics(
                  // Screen readers get it as one action.
                  button: true,
                  label: 'Placard settings',
                  onTap: _openSettings,
                  excludeSemantics: true,
                  child: GestureDetector(
                    key: const Key('placardCorner'),
                    behavior: HitTestBehavior.opaque,
                    onTap: _cornerTapped,
                    child: const SizedBox.square(
                      dimension: PlacardPage.cornerSize,
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _sign(Placard placard) {
    final colors = context.colors;
    return Semantics(
      label: '${placard.text}, ${placard.count}',
      hint: 'Hold to count',
      onLongPress: () {
        _count();
        _armed = true; // no finger to lift
      },
      excludeSemantics: true,
      child: Listener(
        key: const Key('placardSign'),
        behavior: HitTestBehavior.opaque,
        onPointerDown: (_) => _down(),
        onPointerUp: (_) => _up(),
        onPointerCancel: (_) => _up(),
        child: Center(
          child: AnimatedBuilder(
            animation: Listenable.merge([_hold, _pop]),
            builder: (context, child) {
              final popping = _pop.isAnimating;
              final h = Curves.easeIn.transform(_hold.value);
              // Inflating, and shaking harder the fuller it gets...
              final inflate = 1 + inflated * h;
              final shake = popping
                  ? 0.0
                  : h * h * 0.06 * math.sin(_hold.value * 182 * math.pi);
              final scale = popping ? popScale(_pop.value) : inflate;
              return Stack(
                alignment: Alignment.center,
                children: [
                  // ...then it bursts: a ring flies out and fades.
                  if (popping)
                    Positioned.fill(
                      child: CustomPaint(
                        painter: _Burst(_pop.value, colors.accent),
                      ),
                    ),
                  Transform.rotate(
                    angle: shake,
                    child: Transform.scale(scale: scale, child: child),
                  ),
                ],
              );
            },
            child: FittedBox(
              fit: BoxFit.scaleDown,
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      placard.text,
                      key: const Key('placardText'),
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: colors.textPrimary,
                        fontSize: 56,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      '${placard.count}',
                      key: const Key('placardCount'),
                      style: TextStyle(
                        color: colors.accent,
                        fontSize: 72,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// The text and the count; Reset fills in 0 (Save applies it, so a slip
/// loses nothing).
class _SettingsDialog extends StatefulWidget {
  final Placard placard;

  const _SettingsDialog(this.placard);

  @override
  State<_SettingsDialog> createState() => _SettingsDialogState();
}

class _SettingsDialogState extends State<_SettingsDialog> {
  late final _text = TextEditingController(text: widget.placard.text);
  late final _count = TextEditingController(text: '${widget.placard.count}');
  String? _error;

  @override
  void dispose() {
    _text.dispose();
    _count.dispose();
    super.dispose();
  }

  void _save() {
    final count = int.tryParse(_count.text.trim());
    if (count == null || count < 0) {
      setState(() => _error = 'Enter a whole number, 0 or more');
      return;
    }
    Navigator.of(context).pop(Placard(text: _text.text, count: count));
  }

  @override
  Widget build(BuildContext context) {
    return AppDialog(
      title: 'Placard',
      scrollable: true,
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          TextField(
            key: const Key('placardTextField'),
            controller: _text,
            textCapitalization: TextCapitalization.sentences,
            minLines: 1,
            maxLines: 3,
            decoration: const InputDecoration(labelText: 'Text'),
          ),
          const SizedBox(height: 8),
          TextField(
            key: const Key('placardCountField'),
            controller: _count,
            keyboardType: TextInputType.number,
            inputFormatters: [
              FilteringTextInputFormatter.digitsOnly,
              LengthLimitingTextInputFormatter(9),
            ],
            decoration: InputDecoration(labelText: 'Count', errorText: _error),
            onSubmitted: (_) => _save(),
          ),
        ],
      ),
      actions: [
        DialogButton(
          label: 'Reset',
          danger: true,
          onPressed: () => setState(() {
            _count.text = '0';
            _error = null;
          }),
        ),
        DialogButton(
          label: 'Cancel',
          onPressed: () => Navigator.of(context).pop(),
        ),
        DialogButton(label: 'Save', primary: true, onPressed: _save),
      ],
    );
  }
}
