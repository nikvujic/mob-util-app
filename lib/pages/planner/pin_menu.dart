import 'package:flutter/material.dart';
import 'package:the_app/core/format.dart';
import 'package:the_app/core/theme.dart';
import 'package:the_app/models/planner_pin.dart';

/// A reminder mark's menu (P14), from the bottom: its reminders, each with
/// a box to tick it off; tapping one edits it. Resolves to the reminder
/// and whether it was ticked (else: to edit), or null if closed.
Future<(PlannerPin, bool)?> showPinMenu(
  BuildContext context,
  List<PlannerPin> pins,
) {
  return showModalBottomSheet<(PlannerPin, bool)>(
    context: context,
    builder: (context) => SafeArea(
      // Scrolls only when there are many; it's at the bottom already.
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            for (final pin in pins)
              _PinTile(
                pin,
                onEdit: () => Navigator.of(context).pop((pin, false)),
                onDone: () => Navigator.of(context).pop((pin, true)),
              ),
          ],
        ),
      ),
    ),
  );
}

/// A reminder in a mark's menu: bell, title, time and a box to tick it
/// off; tapping it edits it.
class _PinTile extends StatelessWidget {
  final PlannerPin pin;
  final VoidCallback onEdit;
  final VoidCallback onDone;

  const _PinTile(this.pin, {required this.onEdit, required this.onDone});

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return ListTile(
      leading: Icon(Icons.notifications_none, color: colors.accent),
      title: Text(
        pin.title,
        style: const TextStyle(fontWeight: FontWeight.w600),
      ),
      subtitle: Text(
        'Reminder at ${formatMinutes(pin.time)}',
        style: TextStyle(color: colors.textSecondary),
      ),
      trailing: Checkbox(
        value: false,
        semanticLabel: 'Done: ${pin.title}',
        onChanged: (_) => onDone(),
      ),
      onTap: onEdit,
    );
  }
}
