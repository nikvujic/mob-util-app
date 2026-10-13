import 'package:flutter/material.dart';
import 'package:the_app/widgets/bottom_actions.dart';
import 'package:the_app/widgets/pull_down_list.dart';

/// A "back to top" button over a long [PullDownList] in [child] (Round 20):
/// shown only once it's scrolled far (more than [screens] screens down),
/// at the bottom on the side of the hand in use; a tap scrolls up
/// smoothly.
class BackToTop extends StatefulWidget {
  final Widget child;
  final double screens;

  const BackToTop({super.key, required this.child, this.screens = 2});

  @override
  State<BackToTop> createState() => _BackToTopState();
}

class _BackToTopState extends State<BackToTop> {
  bool _shown = false;

  /// Somewhere inside the list, to reach it.
  BuildContext? _inside;

  bool _onScroll(ScrollNotification notification) {
    if (notification.depth != 0) return false;
    final inside = notification.context;
    if (inside == null) return false;
    _inside = inside;
    final far = PullDownList.scrolledOf(inside) >
        widget.screens * notification.metrics.viewportDimension;
    if (far != _shown) setState(() => _shown = far);
    return false;
  }

  @override
  Widget build(BuildContext context) {
    final right = HandTracker.sideOf(context) == HandSide.right;
    final inset = MediaQuery.paddingOf(context).bottom;
    return Stack(
      children: [
        NotificationListener<ScrollNotification>(
          onNotification: _onScroll,
          child: widget.child,
        ),
        Positioned(
          bottom: 16 + inset,
          left: right ? null : 16,
          right: right ? 16 : null,
          child: ExcludeSemantics(
            excluding: !_shown,
            child: AnimatedScale(
              scale: _shown ? 1 : 0,
              duration: const Duration(milliseconds: 150),
              child: FloatingActionButton.small(
                key: const Key('backToTop'),
                heroTag: null,
                tooltip: 'Back to top',
                onPressed: _shown
                    ? () {
                        final inside = _inside;
                        if (inside != null && inside.mounted) {
                          PullDownList.scrollToTop(inside);
                        }
                      }
                    : null,
                child: const Icon(Icons.vertical_align_top),
              ),
            ),
          ),
        ),
      ],
    );
  }
}
