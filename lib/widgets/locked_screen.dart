import 'package:flutter/material.dart';
import 'package:the_app/core/theme.dart';

/// What a closed section (L5) or Hub page (O7) shows instead of itself:
/// "[title] is locked" and an Unlock button.
class LockedScreen extends StatelessWidget {
  final String title;
  final PreferredSizeWidget appBar;
  final VoidCallback onUnlock;

  const LockedScreen({
    super.key,
    required this.title,
    required this.appBar,
    required this.onUnlock,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: appBar,
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.lock_outline,
                size: 48,
                color: context.colors.textSecondary,
              ),
              const SizedBox(height: 16),
              Text(
                '$title is locked',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: context.colors.textPrimary,
                  fontSize: 18,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Enter the master password to open it.',
                textAlign: TextAlign.center,
                style: TextStyle(color: context.colors.textSecondary),
              ),
              const SizedBox(height: 24),
              FilledButton.icon(
                icon: const Icon(Icons.lock_open_outlined),
                label: const Text('Unlock'),
                onPressed: onUnlock,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
