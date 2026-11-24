import 'package:flutter/material.dart';
import 'package:the_app/core/theme.dart';

/// A button that deletes: outlined in red, with its icon (as *Delete
/// person*). Full width at the end of a page; [wide] false where it sits
/// in a row beside other buttons; [compact] beside a list's heading.
class DangerButton extends StatelessWidget {
  final String label;
  final IconData icon;
  final VoidCallback? onPressed;
  final bool wide;
  final bool compact;

  const DangerButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.icon = Icons.delete_outline,
    this.wide = true,
    this.compact = false,
  });

  @override
  Widget build(BuildContext context) {
    final danger = context.colors.delete;
    return OutlinedButton.icon(
      style: OutlinedButton.styleFrom(
        foregroundColor: danger,
        side: BorderSide(color: danger),
        minimumSize:
            wide ? const Size.fromHeight(44) : Size(0, compact ? 32 : 44),
        padding: compact ? const EdgeInsets.symmetric(horizontal: 10) : null,
        visualDensity: compact ? VisualDensity.compact : null,
        tapTargetSize: compact ? MaterialTapTargetSize.shrinkWrap : null,
      ),
      icon: Icon(icon, size: compact ? 18 : null),
      label: Text(label),
      onPressed: onPressed,
    );
  }
}
