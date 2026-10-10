import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:the_app/core/clock.dart';
import 'package:the_app/core/theme.dart';
import 'package:the_app/providers/preferences_provider.dart';
import 'package:the_app/widgets/app_dialog.dart';

/// "Džoni što ćutiš?" (O4): sideways, big text and a count under it.
/// Holding anywhere counts one up with a shake and a pop. The count is
/// kept for good; a triple tap in the top-right corner sets it (or resets
/// it to 0). No top bar: system back leaves.
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

  /// The corner that, tapped three times, sets the count.
  static const cornerSize = 72.0;

  /// The taps in the corner, three within this long open the dialog.
  static const tripleTapWindow = Duration(milliseconds: 800);
  final _cornerTaps = <DateTime>[];

  void _cornerTapped() {
    final now = ref.read(clockProvider)();
    _cornerTaps
      ..add(now)
      ..removeWhere((t) => now.difference(t) > tripleTapWindow);
    if (_cornerTaps.length >= 3) {
      _cornerTaps.clear();
      _setCount();
    }
  }

  Future<void> _setCount() async {
    final count = await showDialog<int>(
      context: context,
      builder: (_) => _SetCountDialog(
        ref.read(preferencesProvider).dzoniCount,
      ),
    );
    if (count != null) {
      ref.read(preferencesProvider.notifier).setDzoniCount(count);
    }
  }

  @override
  Widget build(BuildContext context) {
    final count = ref.watch(preferencesProvider.select((p) => p.dzoniCount));
    return Scaffold(
      body: Stack(
        children: [
          Positioned.fill(child: _counter(count)),
          Positioned(
            top: 0,
            right: 0,
            child: SafeArea(
              child: Semantics(
                // Screen readers get it as one action.
                button: true,
                label: 'Set the count',
                onTap: _setCount,
                excludeSemantics: true,
                child: GestureDetector(
                  key: const Key('dzoniCorner'),
                  behavior: HitTestBehavior.opaque,
                  onTap: _cornerTapped,
                  // It covers the page here: holding still counts.
                  onLongPress: _count,
                  child: const SizedBox.square(dimension: cornerSize),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _counter(int count) {
    return GestureDetector(
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
    );
  }
}

/// Sets the count to a number typed in; Reset fills in 0.
class _SetCountDialog extends StatefulWidget {
  final int count;

  const _SetCountDialog(this.count);

  @override
  State<_SetCountDialog> createState() => _SetCountDialogState();
}

class _SetCountDialogState extends State<_SetCountDialog> {
  late final _field = TextEditingController(text: '${widget.count}');
  String? _error;

  @override
  void dispose() {
    _field.dispose();
    super.dispose();
  }

  void _save() {
    final count = int.tryParse(_field.text.trim());
    if (count == null || count < 0) {
      setState(() => _error = 'Enter a whole number, 0 or more');
      return;
    }
    Navigator.of(context).pop(count);
  }

  @override
  Widget build(BuildContext context) {
    return AppDialog(
      title: 'Set count',
      content: TextField(
        key: const Key('dzoniCount'),
        controller: _field,
        autofocus: true,
        keyboardType: TextInputType.number,
        inputFormatters: [
          FilteringTextInputFormatter.digitsOnly,
          LengthLimitingTextInputFormatter(9),
        ],
        decoration: InputDecoration(labelText: 'Count', errorText: _error),
        onSubmitted: (_) => _save(),
      ),
      actions: [
        DialogButton(
          label: 'Reset',
          danger: true,
          // Only fills in 0: Save applies it, so a slip loses nothing.
          onPressed: () => setState(() {
            _field.text = '0';
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
