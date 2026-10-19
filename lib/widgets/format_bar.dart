import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:the_app/core/theme.dart';

/// The text field's usual selection handles, but no cursor handle (the
/// pointer under the caret) while [hideCursor] is true (Round 29): with
/// the format bar open it sat over the bar. Selection handles stay.
///
/// Round 45: also no handle whose end of the selection is out of view
/// ([offScreen]): a note's text scrolls inside a bigger scroll, so
/// Flutter would draw it anyway, over the app bar.
class FormatBarSelectionControls extends MaterialTextSelectionControls
    with TextSelectionHandleControls {
  final ValueListenable<bool> hideCursor;
  final ValueListenable<Set<TextSelectionHandleType>> offScreen;

  FormatBarSelectionControls(
    this.hideCursor, {
    ValueListenable<Set<TextSelectionHandleType>>? offScreen,
  }) : offScreen = offScreen ?? ValueNotifier(const {});

  /// Round 64: each handle as tall as a finger's touch area, drawn at its
  /// top: its touch area then starts at the handle and reaches down,
  /// not up into the line it marks (where a tap on the text grabbed it).
  @override
  Size getHandleSize(double textLineHeight) {
    final size = super.getHandleSize(textLineHeight);
    return Size(size.width, math.max(size.height, kMinInteractiveDimension));
  }

  @override
  Widget buildHandle(
    BuildContext context,
    TextSelectionHandleType type,
    double textHeight, [
    VoidCallback? onTap,
  ]) {
    // Its width too: the cursor's handle is given room to spread into,
    // and centred in it, it was drawn off to the side.
    final handle = SizedBox.fromSize(
      size: getHandleSize(textHeight),
      child: Align(
        alignment: Alignment.topCenter,
        child: super.buildHandle(context, type, textHeight, onTap),
      ),
    );
    final shown = ValueListenableBuilder(
      valueListenable: offScreen,
      builder: (_, off, child) => off.contains(type)
          ? SizedBox.shrink(key: Key('handleOffScreen-${type.name}'))
          : child!,
      child: handle,
    );
    if (type != TextSelectionHandleType.collapsed) return shown;
    return ValueListenableBuilder(
      valueListenable: hideCursor,
      builder: (_, hidden, child) => hidden
          ? const SizedBox.shrink(key: Key('cursorHandleHidden'))
          : child!,
      child: shown,
    );
  }
}

/// One button of a [FormatBar].
class FormatButton {
  final IconData icon;
  final String tooltip;
  final VoidCallback onPressed;

  const FormatButton(this.icon, this.tooltip, this.onPressed);
}

/// A row of formatting buttons above the keyboard (N17, Round 27): it
/// scrolls sideways when they don't fit. Tapping one leaves the text
/// field focused and the keyboard up (the bar counts as part of the
/// field, so a tap there isn't a tap outside it).
class FormatBar extends StatelessWidget {
  final List<FormatButton> buttons;

  const FormatBar({super.key, required this.buttons});

  /// How tall it is, for the room the text leaves under it.
  static const height = 52.0;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return TextFieldTapRegion(
      child: Material(
        key: const Key('formatBar'),
        color: colors.surface,
        elevation: 3,
        borderRadius: BorderRadius.circular(height / 2),
        clipBehavior: Clip.antiAlias,
        child: SizedBox(
          height: height,
          child: ListView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 4),
            children: [
              for (final button in buttons)
                IconButton(
                  icon: Icon(button.icon),
                  tooltip: button.tooltip,
                  color: colors.textPrimary,
                  onPressed: button.onPressed,
                ),
            ],
          ),
        ),
      ),
    );
  }
}
