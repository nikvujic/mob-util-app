import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:the_app/core/theme.dart';
import 'package:the_app/providers/preferences_provider.dart';

/// "Džoni što ćutiš?" (O4): sideways, big text and a count under it.
/// Holding anywhere counts one up with a shake and a pop. The count is
/// kept for good.
class DzoniPage extends ConsumerStatefulWidget {
  static const text = 'Džoni što ćutiš?';

  const DzoniPage({super.key});

  @override
  ConsumerState<DzoniPage> createState() => _DzoniPageState();
}

class _DzoniPageState extends ConsumerState<DzoniPage>
    with SingleTickerProviderStateMixin {
  late final AnimationController _bump = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 450),
  );

  @override
  void initState() {
    super.initState();
    SystemChrome.setPreferredOrientations([
      DeviceOrientation.landscapeLeft,
      DeviceOrientation.landscapeRight,
    ]);
  }

  @override
  void dispose() {
    // Back to whatever the phone allows.
    SystemChrome.setPreferredOrientations([]);
    _bump.dispose();
    super.dispose();
  }

  void _count() {
    ref.read(preferencesProvider.notifier).countDzoni();
    HapticFeedback.heavyImpact();
    _bump.forward(from: 0);
  }

  @override
  Widget build(BuildContext context) {
    final count = ref.watch(preferencesProvider.select((p) => p.dzoniCount));
    return Scaffold(
      appBar: AppBar(title: const Text('Džoni')),
      body: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onLongPress: _count,
        child: Center(
          child: AnimatedBuilder(
            animation: _bump,
            builder: (context, child) {
              final t = _bump.value;
              // A few quick shakes that fade out, and a pop that settles.
              final shake = (1 - t) * 0.08 * math.sin(t * 6 * 2 * math.pi);
              final pop = 1 + 0.25 * math.sin(t * math.pi);
              return Transform.rotate(
                angle: shake,
                child: Transform.scale(scale: pop, child: child),
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
                      DzoniPage.text,
                      style: TextStyle(
                        color: context.colors.textPrimary,
                        fontSize: 56,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      '$count',
                      style: TextStyle(
                        color: context.colors.accent,
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
