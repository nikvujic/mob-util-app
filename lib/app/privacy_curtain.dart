import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:the_app/core/theme.dart';
import 'package:the_app/providers/session_provider.dart';

/// Covers the app as it leaves while it's unlocked (L4), so the last
/// frame Android keeps (shown in recent apps, and for a moment on coming
/// back) has nothing protected in it. Without this, coming back after the
/// auto-lock showed the unlocked page for a moment before it locked
///. The cover goes once the app is back in front, after the
/// session has decided whether to lock.
class PrivacyCurtain extends ConsumerStatefulWidget {
  final Widget child;

  const PrivacyCurtain({super.key, required this.child});

  @override
  ConsumerState<PrivacyCurtain> createState() => _PrivacyCurtainState();
}

class _PrivacyCurtainState extends ConsumerState<PrivacyCurtain> {
  bool _covered = false;

  late final AppLifecycleListener _lifecycle = AppLifecycleListener(
    onInactive: _cover,
    onHide: _cover,
    onResume: () {
      if (_covered) setState(() => _covered = false);
    },
  );

  void _cover() {
    if (!_covered && ref.read(sessionProvider) != null) {
      setState(() => _covered = true);
    }
  }

  @override
  void initState() {
    super.initState();
    _lifecycle; // start listening
  }

  @override
  void dispose() {
    _lifecycle.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      textDirection: TextDirection.ltr,
      children: [
        widget.child,
        if (_covered)
          Positioned.fill(
            key: const Key('privacyCurtain'),
            child: ColoredBox(
              color: context.colors.background,
              child: Center(
                child: Icon(
                  Icons.lock_outline,
                  size: 48,
                  color: context.colors.textMuted,
                ),
              ),
            ),
          ),
      ],
    );
  }
}
