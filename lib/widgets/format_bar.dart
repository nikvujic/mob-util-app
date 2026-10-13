import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:the_app/core/theme.dart';

/// The text field's usual selection handles, but no cursor handle (the
/// pointer under the caret) while [hideCursor] is true (Round 29): with
/// the format bar open it sat over the bar. Selection handles stay.
class FormatBarSelectionControls extends MaterialTextSelectionControls
    with TextSelectionHandleControls {
  final ValueListenable<bool> hideCursor;

  FormatBarSelectionControls(this.hideCursor);

  @override
  Widget buildHandle(
    BuildContext context,
    TextSelectionHandleType type,
    double textHeight, [
    VoidCallback? onTap,
  ]) {
    final handle = super.buildHandle(context, type, textHeight, onTap);
    if (type != TextSelectionHandleType.collapsed) return handle;
    return ValueListenableBuilder(
      valueListenable: hideCursor,
      builder: (_, hidden, child) => hidden
          ? const SizedBox.shrink(key: Key('cursorHandleHidden'))
          : child!,
      child: handle,
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
