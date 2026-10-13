import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:the_app/core/sound.dart';
import 'package:the_app/core/theme.dart';
import 'package:the_app/widgets/app_dialog.dart';

/// How long the button is held to take an important medicine's dose.
const holdToTakeTime = Duration(seconds: 5);

/// Asks to take a dose of an important medicine (Round 24): [name] at
/// [time]. A big round button has to be held for [holdToTakeTime]: it
/// fills up like a glass, with a sound and small ticks while held, and
/// drains if let go early. True once held to the end; false if cancelled.
Future<bool> showHoldToTake(
  BuildContext context, {
  required String name,
  required String time,
}) async {
  final taken = await showDialog<bool>(
    context: context,
    builder: (_) => _HoldToTakeDialog(name: name, time: time),
  );
  return taken ?? false;
}

class _HoldToTakeDialog extends StatefulWidget {
  final String name;
  final String time;

  const _HoldToTakeDialog({required this.name, required this.time});

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
    _finished = true;
    _waves.stop();
    AppSound.stopFill();
    if (mounted) Navigator.of(context).pop(true);
  }

  @override
  void dispose() {
    if (_holding && !_finished) AppSound.stopFill();
    _fill.dispose();
    _waves.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return AppDialog(
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
                animation: Listenable.merge([_fill, _waves]),
                builder: (context, _) {
                  final fill = _fill.value;
                  // A little swell while held, growing as it fills.
                  final scale = 1.0 + (_holding ? 0.04 + 0.04 * fill : 0.0);
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
                                  Icons.medication_outlined,
                                  size: 40,
                                  color: fill > 0.62
                                      ? colors.onAccent
                                      : colors.textPrimary,
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  _holding ? 'Keep holding' : 'Hold',
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
          onPressed: () => Navigator.of(context).pop(false),
        ),
      ],
    );
  }
}

/// A round glass filling up to [fill] (0–1), its surface waving with
/// [wave] (0–1, a cycle), inside a ring that goes round as it fills.
class _GlassPainter extends CustomPainter {
  final double fill;
  final double wave;
  final Color ground;
  final Color liquid;
  final Color ring;
  final Color track;

  _GlassPainter({
    required this.fill,
    required this.wave,
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
      final top = center.dy + inner - 2 * inner * fill;
      final phase = wave * 2 * math.pi;
      // Two waves, the back one lighter, moving the other way.
      for (final (shift, alpha, height) in [
        (math.pi, 0.45, 5.0),
        (0.0, 1.0, 4.0),
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
  }

  @override
  bool shouldRepaint(_GlassPainter old) =>
      old.fill != fill ||
      old.wave != wave ||
      old.ground != ground ||
      old.liquid != liquid;
}
