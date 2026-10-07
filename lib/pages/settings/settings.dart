import 'package:flutter/material.dart';
import 'package:the_app/core/theme.dart';

/// App settings, opened from any main section's app bar (requirement G8).
class SettingsPage extends StatelessWidget {
  const SettingsPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Settings')),
      body: ListView(
        children: const [
          _SettingsTile(
            icon: Icons.lock_outline,
            title: 'Security',
            subtitle: 'Master password and section locks · coming soon',
          ),
          _SettingsTile(
            icon: Icons.save_alt,
            title: 'Backup',
            subtitle: 'Export and import all data · coming soon',
          ),
        ],
      ),
    );
  }
}

/// A settings entry. Not tappable yet: Security and Backup are added in
/// later roadmap steps.
class _SettingsTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;

  const _SettingsTile({
    required this.icon,
    required this.title,
    required this.subtitle,
  });

  @override
  Widget build(BuildContext context) {
    return ListTile(
      enabled: false,
      leading: Icon(icon),
      title: Text(title),
      subtitle: Text(
        subtitle,
        style: const TextStyle(color: AppColors.textSecondary),
      ),
    );
  }
}
