import 'dart:math' as math;

import 'package:flutter/material.dart';

/// Every text field's selection handles (Round 92, the notes'
/// lowered grab area everywhere): give it `selectionControls: lowHandles`.
final lowHandles = LowHandleSelectionControls();

/// Round 64: each handle as tall as a finger's touch area, drawn at its
/// top: its touch area then starts at the handle and reaches down,
/// not up into the line it marks (where a tap on the text grabbed it).
/// Round 74: as wide as one too, the drawn handle at its inner edge
/// ([inner] from it): the touch area reaches out away from the text
/// (right of the end's handle, left of the start's), barely over it.
/// The cursor's one handle is in its middle.
class LowHandleSelectionControls extends MaterialTextSelectionControls
    with TextSelectionHandleControls {
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

  /// The drawn handle in its finger-sized box, at the box's inner edge
  /// (the cursor's in the middle), so the touch area reaches away from
  /// the text.
  @override
  Widget buildHandle(
    BuildContext context,
    TextSelectionHandleType type,
    double textHeight, [
    VoidCallback? onTap,
  ]) {
    final drawn = super.buildHandle(context, type, textHeight, onTap);
    return SizedBox.fromSize(
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
  }
}
