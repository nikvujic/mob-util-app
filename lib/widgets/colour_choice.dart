import 'package:flutter/material.dart';
import 'package:the_app/core/theme.dart';

/// The colour row: none, or one of the [BlockColor]s (planner blocks, P9;
/// counters, O5).
class ColourChoice extends StatelessWidget {
  final BlockColor? selected;
  final ValueChanged<BlockColor?> onSelected;

  const ColourChoice({
    super.key,
    required this.selected,
    required this.onSelected,
  });

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    Widget dot(BlockColor? colour) {
      final isSelected = colour == selected;
      return Semantics(
        button: true,
        selected: isSelected,
        label: 'Colour: ${colour?.label ?? 'none'}',
        excludeSemantics: true,
        child: InkResponse(
          onTap: () => onSelected(colour),
          radius: 24,
          child: SizedBox.square(
            dimension: 48,
            child: Center(
              child: Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: colour?.stripe ?? Colors.transparent,
                  border: Border.all(
                    color: isSelected ? colors.textPrimary : colors.textHint,
                    width: isSelected ? 3 : 1,
                  ),
                ),
                child: colour == null
                    ? Icon(Icons.block, size: 18, color: colors.textSecondary)
                    : null,
              ),
            ),
          ),
        ),
      );
    }

    return Wrap(
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        Padding(
          padding: const EdgeInsets.only(right: 4),
          child: Text(
            'Colour',
            style: TextStyle(color: colors.textSecondary),
          ),
        ),
        dot(null),
        for (final colour in BlockColor.values) dot(colour),
      ],
    );
  }
}
