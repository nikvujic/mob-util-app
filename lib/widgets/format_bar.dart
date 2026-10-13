import 'package:flutter/material.dart';
import 'package:the_app/core/theme.dart';

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
