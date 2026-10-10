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
  final VoidCallback? onPressed;

  /// Destructive (e.g. Delete): shown in red.
  final bool danger;

  /// Shown greyed out and doing nothing when false (e.g. Undo with nothing
  /// to undo), so the buttons around it keep their places.
  final bool enabled;

  const BottomAction({
    required this.icon,
    required this.tooltip,
    this.onPressed,
    this.danger = false,
    this.enabled = true,
  });
}

/// A page's actions as round buttons along the bottom, on the side of the
/// hand in use (G11): bottom right in the given order, or bottom left with
/// the order mirrored, so the last action is always outermost, under the
/// thumb. An extra, less used action can sit [above] the row, smaller, on
/// the same side. The side is taken when the buttons appear and kept while
/// they're shown. Use as the page's floating action button.
class BottomActions extends StatefulWidget {
  /// Space to leave below content so it can scroll clear of the buttons.
  static const contentClearance = 88.0;

  /// Extra space to leave with a button [above] the row.
  static const aboveClearance = 56.0;

  final List<BottomAction> actions;

  /// A smaller button above the row, at its outer end.
  final BottomAction? above;

  /// How many of the last [actions] keep their order on the left side
  /// too, as a group (e.g. ↶ ↷, which read left to right): the group is
  /// still outermost, only not reversed.
  final int keepOrderOfLast;

  const BottomActions({
    super.key,
    required this.actions,
    this.above,
    this.keepOrderOfLast = 0,
  });

  @override
  State<BottomActions> createState() => _BottomActionsState();
}

class _BottomActionsState extends State<BottomActions> {
  HandSide? _side;

  Widget _button(BuildContext context, BottomAction action,
      {bool small = false}) {
    final colors = context.colors;
    final background = action.danger ? colors.danger : colors.surface;
    final foreground = !action.enabled
        ? colors.textHint
        : action.danger
            ? colors.background
            : colors.textPrimary;
    final onPressed = action.enabled ? action.onPressed : null;
    final icon = Icon(action.icon);
    // Several on screen at once (and tabs kept alive side by side): no
    // shared hero animation.
    return small
        ? FloatingActionButton.small(
            heroTag: null,
            tooltip: action.tooltip,
            backgroundColor: background,
            foregroundColor: foreground,
            onPressed: onPressed,
            child: icon,
          )
        : FloatingActionButton(
            heroTag: null,
            tooltip: action.tooltip,
            backgroundColor: background,
            foregroundColor: foreground,
            onPressed: onPressed,
            child: icon,
          );
  }

  /// [buttons] for the left side: reversed, except the last
  /// [BottomActions.keepOrderOfLast], which lead in their own order.
  List<Widget> _mirrored(List<Widget> buttons) {
    final kept = widget.keepOrderOfLast.clamp(0, buttons.length);
    final split = buttons.length - kept;
    return [
      ...buttons.sublist(split),
      ...buttons.sublist(0, split).reversed,
    ];
  }

  @override
  Widget build(BuildContext context) {
    final side = _side ??= HandTracker.sideOf(context);
    final right = side == HandSide.right;
    final buttons = [
      for (final action in widget.actions)
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 6),
          child: _button(context, action),
        ),
    ];
    final above = widget.above;
    // As wide as the screen (minus the usual margins), so the row can sit
    // at either side whatever the page's button location.
    return SizedBox(
      width: MediaQuery.sizeOf(context).width - 32,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment:
            right ? CrossAxisAlignment.end : CrossAxisAlignment.start,
        children: [
          if (above != null)
            Padding(
              // Centred over the outermost button: its 48 dp touch area
              // (a 40 dp button) in the 56 dp button's 6 dp margins.
              padding: const EdgeInsets.fromLTRB(10, 0, 10, 8),
              child: _button(context, above, small: true),
            ),
          Row(
            mainAxisAlignment:
                right ? MainAxisAlignment.end : MainAxisAlignment.start,
            children: right ? buttons : _mirrored(buttons),
          ),
        ],
      ),
    );
  }
}
