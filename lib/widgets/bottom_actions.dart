import 'package:flutter/material.dart';
import 'package:the_app/core/theme.dart';

/// Which hand the user is holding the phone with, guessed from the side of
/// the screen they touch.
enum HandSide { left, right }

/// Notes which half of the screen each touch lands on, so action buttons
/// can appear on the side of the hand in use (G11). Wraps the whole app.
class HandTracker extends StatefulWidget {
  final Widget child;

  const HandTracker({super.key, required this.child});

  /// The side of the last touch (right if none yet). Read when actions
  /// appear; it doesn't rebuild anything when it changes.
  static HandSide sideOf(BuildContext context) =>
      context.getInheritedWidgetOfExactType<_HandScope>()?.state._side ??
      HandSide.right;

  @override
  State<HandTracker> createState() => _HandTrackerState();
}

class _HandTrackerState extends State<HandTracker> {
  HandSide _side = HandSide.right;

  @override
  Widget build(BuildContext context) {
    return Listener(
      behavior: HitTestBehavior.translucent,
      onPointerDown: (event) {
        final width = MediaQuery.sizeOf(context).width;
        _side = event.position.dx < width / 2 ? HandSide.left : HandSide.right;
      },
      child: _HandScope(state: this, child: widget.child),
    );
  }
}

class _HandScope extends InheritedWidget {
  final _HandTrackerState state;

  const _HandScope({required this.state, required super.child});

  @override
  bool updateShouldNotify(_HandScope old) => false;
}

/// One round action button for [BottomActions].
class BottomAction {
  final IconData icon;
  final String tooltip;

  /// What tapping does; or, with [menu], ignored.
  final VoidCallback? onPressed;

  /// Shown when tapped instead of acting directly (like a ⋮ menu): each
  /// entry's value is run when picked.
  final List<PopupMenuEntry<VoidCallback>> Function()? menu;

  /// Destructive (e.g. Delete): shown in red.
  final bool danger;

  const BottomAction({
    required this.icon,
    required this.tooltip,
    this.onPressed,
    this.menu,
    this.danger = false,
  });
}

/// A page's actions as round buttons along the bottom, on the side of the
/// hand in use (G11): bottom right in the given order, or bottom left with
/// the order mirrored, so the last action is always outermost, under the
/// thumb. The side is taken when the buttons appear and kept while they're
/// shown. Use as the page's floating action button.
class BottomActions extends StatefulWidget {
  /// Space to leave below content so it can scroll clear of the buttons.
  static const contentClearance = 88.0;

  final List<BottomAction> actions;

  const BottomActions({super.key, required this.actions});

  @override
  State<BottomActions> createState() => _BottomActionsState();
}

class _BottomActionsState extends State<BottomActions> {
  HandSide? _side;

  Future<void> _openMenu(BuildContext context, BottomAction action) async {
    final button = context.findRenderObject()! as RenderBox;
    final overlay =
        Overlay.of(context).context.findRenderObject()! as RenderBox;
    final rect = Rect.fromPoints(
      button.localToGlobal(Offset.zero, ancestor: overlay),
      button.localToGlobal(
        button.size.bottomRight(Offset.zero),
        ancestor: overlay,
      ),
    );
    final picked = await showMenu<VoidCallback>(
      context: context,
      position: RelativeRect.fromRect(rect, Offset.zero & overlay.size),
      items: action.menu!(),
    );
    picked?.call();
  }

  @override
  Widget build(BuildContext context) {
    final side = _side ??= HandTracker.sideOf(context);
    final buttons = [
      for (final action in widget.actions)
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 6),
          child: Builder(
            builder: (context) => FloatingActionButton(
              // Several on screen at once (and tabs kept alive side by
              // side): no shared hero animation.
              heroTag: null,
              tooltip: action.tooltip,
              backgroundColor:
                  action.danger ? AppColors.danger : AppColors.surface,
              foregroundColor:
                  action.danger ? AppColors.background : AppColors.textPrimary,
              onPressed: action.menu != null
                  ? () => _openMenu(context, action)
                  : action.onPressed,
              child: Icon(action.icon),
            ),
          ),
        ),
    ];
    // As wide as the screen (minus the usual margins), so the row can sit
    // at either side whatever the page's button location.
    return SizedBox(
      width: MediaQuery.sizeOf(context).width - 32,
      child: Row(
        mainAxisAlignment: side == HandSide.right
            ? MainAxisAlignment.end
            : MainAxisAlignment.start,
        children: side == HandSide.right ? buttons : buttons.reversed.toList(),
      ),
    );
  }
}
