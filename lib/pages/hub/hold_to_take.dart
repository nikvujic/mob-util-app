import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:the_app/core/sound.dart';
import 'package:the_app/core/theme.dart';
import 'package:the_app/widgets/app_dialog.dart';

/// How long the button is held to take an important medicine's dose.
const holdToTakeTime = Duration(seconds: 5);

/// Once full (Round 25): a small pop, a tick in place of the icon, and
/// this long before the dialog closes.
const holdToTakeEnd = Duration(milliseconds: 900);

/// Asks to take a dose of an important medicine (Round 24): [name] at
/// [time]. A big round button has to be held for [holdToTakeTime]: it
/// fills up like a glass, with a sound and small ticks while held, and
/// drains if let go early. True once held to the end; false if cancelled.
/// Round 92 (Nikola: a take was lost): while it's held, and once full,
/// it can't be closed (no Cancel, no tap outside, no Back), and a full
/// one counts however the dialog goes.
Future<bool> showHoldToTake(
  BuildContext context, {
  required String name,
  required String time,
}) async {
  final full = ValueNotifier(false);
  final taken = await showDialog<bool>(
    context: context,
    builder: (_) => _HoldToTakeDialog(name: name, time: time, full: full),
  );
  final done = (taken ?? false) || full.value;
  full.dispose();
  return done;
}

class _HoldToTakeDialog extends StatefulWidget {
  final String name;
  final String time;

  /// Set once it's held to the end.
  final ValueNotifier<bool> full;

  const _HoldToTakeDialog({
    required this.name,
    required this.time,
    required this.full,
  });

  @override
  State<_HoldToTakeDialog> createState() => _HoldToTakeDialogState();
}

class _HoldToTakeDialogState extends State<_HoldToTakeDialog>
    with TickerProviderStateMixin {
  /// 0 → 1 while held: how full it is.
  late final AnimationController _fill = AnimationController(
    vsync: this,
    duration: holdToTakeTime,
    reverseDuration: const Duration(milliseconds: 400),
  )
    ..addListener(_tick)
    ..addStatusListener((status) {
      if (status == AnimationStatus.completed) _done();
    });

  /// The surface's waves: moving only while held.
  late final AnimationController _waves = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1200),
  );

  /// The ending (Round 25): 0 → 1, a burst out and a ring spreading.
  late final AnimationController _pop = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 450),
  );

  bool _holding = false;
  bool _finished = false;

  /// Fingers on the button: it fills while there's at least one.
  int _fingers = 0;

  /// The tenth of the way the last tick was at.
  int _lastTick = 0;

  /// A small tick every tenth of the way, so the hold is felt.
  void _tick() {
    final tenth = (_fill.value * 10).floor();
    if (_holding && tenth > _lastTick) HapticFeedback.selectionClick();
    _lastTick = tenth;
  }

  void _press() {
    if (_finished) return;
    setState(() => _holding = true);
    _fill.forward();
    _waves.repeat();
    AppSound.fill();
  }

  void _lift() {
    _fingers = (_fingers - 1).clamp(0, 10);
    if (_fingers == 0) _release();
  }

  void _release() {
    if (_finished || !_holding) return;
    setState(() => _holding = false);
    _fill.reverse();
    _waves.stop();
    AppSound.stopFill();
  }

  void _done() {
    if (_finished) return;
    widget.full.value = true;
    setState(() {
      _finished = true;
      _holding = false;
    });
    _waves.stop();
    AppSound.stopFill();
    HapticFeedback.mediumImpact();
    _pop.forward(from: 0);
    // Stays full, with its tick, for a moment.
    Future<void>.delayed(holdToTakeEnd, () {
      if (mounted) Navigator.of(context).pop(true);
    });
  }

  @override
  void dispose() {
    if (_holding && !_finished) AppSound.stopFill();
    _fill.dispose();
    _waves.dispose();
    _pop.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    // Held, or full: nothing closes it (it closes itself when full).
    final locked = _holding || _finished;
    return PopScope(
      canPop: !locked,
      child: AppDialog(
        title: 'Take ${widget.name}?',
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            DialogMessage(
              'The ${widget.time} dose. Hold the button until it fills up.',
            ),
            const SizedBox(height: 20),
            Semantics(
              button: true,
              label: 'Hold to take',
              // Screen readers: a long press does it.
              onLongPress: _done,
              child: Listener(
                key: const Key('holdToTake'),
                onPointerDown: (_) {
                  if (++_fingers == 1) _press();
                },
                onPointerUp: (_) => _lift(),
                onPointerCancel: (_) => _lift(),
                child: AnimatedBuilder(
                  animation: Listenable.merge([_fill, _waves, _pop]),
                  builder: (context, _) {
                    final fill = _fill.value;
                    // A little swell while held, growing as it fills.
                    // The pop: a quick swell past full size, then back.
                    final burst = math.sin(math.pi * _pop.value);
                    final scale = _finished
                        ? 1.0 + 0.16 * burst
                        : 1.0 + (_holding ? 0.04 + 0.04 * fill : 0.0);
                    return AnimatedScale(
                      scale: scale,
                      duration: const Duration(milliseconds: 150),
                      // How full, for screen readers (and tests).
                      child: Semantics(
                        key: const Key('holdToTakeFill'),
                        value: '${(fill * 100).round()}%',
                        child: SizedBox.square(
                          dimension: 168,
                          child: CustomPaint(
                            painter: _GlassPainter(
                              fill: fill,
                              wave: _waves.value,
                              pop: _pop.value,
                              ground: colors.card,
                              liquid: colors.accent,
                              ring: colors.accent,
                              track: colors.divider,
                            ),
                            child: Center(
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  // Light once the liquid is over it.
                                  Icon(
                                    // A tick once taken (Round 25).
                                    _finished
                                        ? Icons.check_rounded
                                        : Icons.medication_outlined,
                                    key: Key(
                                        _finished ? 'holdTaken' : 'holdIcon'),
                                    size: 40,
                                    color: fill > 0.62
                                        ? colors.onAccent
                                        : colors.textPrimary,
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    _finished
                                        ? 'Taken'
                                        : _holding
                                            ? 'Keep holding'
                                            : 'Hold',
                                    style: TextStyle(
                                      color: fill > 0.47
                                          ? colors.onAccent
                                          : colors.textPrimary,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ),
            ),
          ],
        ),
        actions: [
          DialogButton(
            label: 'Cancel',
            onPressed: locked ? null : () => Navigator.of(context).pop(false),
          ),
        ],
      ),
    );
  }
}

/// A round glass filling up to [fill] (0–1), its surface waving with
/// [wave] (0–1, a cycle), inside a ring that goes round as it fills.
/// The liquid's surface (its waves' middle) in a glass of [inner] radius
/// around [centerY], [fill] full (Round 41): from below the bottom to
/// past the top by more than a wave is high, so it's really full at 1
/// (the waves' troughs had left a gap under the rim).
@visibleForTesting
double surfaceTop(double centerY, double inner, double fill) {
  const beyond = maxWave + 1;
  return centerY + inner + beyond - (2 * inner + 2 * beyond) * fill;
}

/// How high the surface's waves reach above and below it.
@visibleForTesting
const maxWave = 5.0;

class _GlassPainter extends CustomPainter {
  final double fill;
  final double wave;

  /// The ending, 0 → 1: a ring spreading out and fading, and a few sparks.
  final double pop;
  final Color ground;
  final Color liquid;
  final Color ring;
  final Color track;

  _GlassPainter({
    required this.fill,
    required this.wave,
    this.pop = 0,
    required this.ground,
    required this.liquid,
    required this.ring,
    required this.track,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = size.center(Offset.zero);
    final radius = size.shortestSide / 2;
    final inner = radius - 8;

    canvas.drawCircle(center, inner, Paint()..color = ground);

    if (fill > 0) {
      canvas.save();
      canvas.clipPath(
          Path()..addOval(Rect.fromCircle(center: center, radius: inner)));
      final top = surfaceTop(center.dy, inner, fill);
      final phase = wave * 2 * math.pi;
      // Two waves, the back one lighter, moving the other way.
      for (final (shift, alpha, height) in [
        (math.pi, 0.45, maxWave),
        (0.0, 1.0, maxWave - 1),
      ]) {
        final path = Path()..moveTo(center.dx - inner, size.height);
        for (var x = -inner; x <= inner; x += 4) {
          final y = top +
              height *
                  math.sin(x / inner * 2 * math.pi +
                      (shift == 0 ? phase : -phase) +
                      shift);
          path.lineTo(center.dx + x, y);
        }
        path
          ..lineTo(center.dx + inner, size.height)
          ..close();
        canvas.drawPath(path, Paint()..color = liquid.withValues(alpha: alpha));
      }
      canvas.restore();
    }

    final stroke = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 5
      ..strokeCap = StrokeCap.round;
    canvas.drawCircle(center, radius - 3, stroke..color = track);
    if (fill > 0) {
      canvas.drawArc(
        Rect.fromCircle(center: center, radius: radius - 3),
        -math.pi / 2,
        2 * math.pi * fill,
        false,
        stroke..color = ring,
      );
    }

    if (pop > 0 && pop < 1) {
      final fade = 1 - pop;
      // A ring spreading out from the rim.
      canvas.drawCircle(
        center,
        radius + 4 + 18 * pop,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 4 * fade
          ..color = ring.withValues(alpha: fade),
      );
      // Eight sparks flying out.
      final spark = Paint()..color = liquid.withValues(alpha: fade);
      for (var i = 0; i < 8; i++) {
        final angle = i * math.pi / 4 + math.pi / 8;
        final distance = radius + 6 + 26 * pop;
        canvas.drawCircle(
          center + Offset(math.cos(angle), math.sin(angle)) * distance,
          4 * fade,
          spark,
        );
      }
    }
  }

  @override
  bool shouldRepaint(_GlassPainter old) =>
      old.fill != fill ||
      old.wave != wave ||
      old.pop != pop ||
      old.ground != ground ||
      old.liquid != liquid;
}
