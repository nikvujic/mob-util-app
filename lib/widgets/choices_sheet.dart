import 'package:flutter/material.dart';
import 'package:the_app/core/theme.dart';

/// A small sheet of choices at the bottom (one-handed); the value picked,
/// or null.
Future<String?> showChoicesSheet(
  BuildContext context,
  String? title,
  List<(IconData, String, String)> choices,
) =>
    showModalBottomSheet<String>(
      context: context,
      // Round 108: as tall as its choices (six relation kinds overflowed
      // the default nine-sixteenths on a short screen).
      isScrollControlled: true,
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (title != null)
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                child: Text(
                  title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: context.colors.textSecondary,
                    fontSize: 14,
                  ),
                ),
              )
            else
              const SizedBox(height: 8),
            for (final (icon, label, value) in choices)
              ListTile(
                key: Key('choice-$value'),
                leading: Icon(icon),
                title: Text(label),
                onTap: () => Navigator.of(context).pop(value),
              ),
          ],
        ),
      ),
    );
