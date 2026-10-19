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
  /// Round 74: as wide as one too, the drawn handle at its inner edge
  /// ([inner] from it): the touch area reaches out away from the text
  /// (right of the end's handle, left of the start's), barely over it.
  /// The cursor's one handle is in its middle.
  @override
  Size getHandleSize(double textLineHeight) {
    final size = super.getHandleSize(textLineHeight);
    return Size(math.max(size.width, kMinInteractiveDimension),
        math.max(size.height, kMinInteractiveDimension));
  }

  /// How much of the touch area is on the text's side of a selection's
  /// handle.
  static const inner = 2.0;

  @override
  Offset getHandleAnchor(TextSelectionHandleType type, double textLineHeight) {
    final width = getHandleSize(textLineHeight).width;
    final material = super.getHandleAnchor(type, textLineHeight);
    return switch (type) {
      // Its point at the drawn handle's top right corner.
      TextSelectionHandleType.left => Offset(width - inner, material.dy),
      // At its top left.
      TextSelectionHandleType.right => Offset(inner, material.dy),
      TextSelectionHandleType.collapsed => Offset(width / 2, material.dy),
    };
  }

  @override
  Widget buildHandle(
    BuildContext context,
    TextSelectionHandleType type,
    double textHeight, [
    VoidCallback? onTap,
  ]) {
    final drawn = super.buildHandle(context, type, textHeight, onTap);
    final handle = SizedBox.fromSize(
      size: getHandleSize(textHeight),
      child: switch (type) {
        TextSelectionHandleType.left => Padding(
            padding: const EdgeInsets.only(right: inner),
            child: Align(alignment: Alignment.topRight, child: drawn),
          ),
        TextSelectionHandleType.right => Padding(
            padding: const EdgeInsets.only(left: inner),
            child: Align(alignment: Alignment.topLeft, child: drawn),
          ),
        // Centred, so it's drawn under the cursor (1.28.1: it was off to
        // the side).
        TextSelectionHandleType.collapsed =>
          Align(alignment: Alignment.topCenter, child: drawn),
      },
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
