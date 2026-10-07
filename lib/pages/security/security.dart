import 'package:flutter/material.dart';
import 'package:the_app/core/theme.dart';

/// Master password and section locks (requirements L1–L5). The entries are
/// placeholders until those roadmap steps land.
class SecurityPage extends StatelessWidget {
  const SecurityPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Security')),
      body: ListView(
        children: const [
          ListTile(
            enabled: false,
            leading: Icon(Icons.password),
            title: Text('Master password'),
            subtitle: Text(
              'Coming soon',
              style: TextStyle(color: AppColors.textSecondary),
            ),
          ),
          ListTile(
            enabled: false,
            leading: Icon(Icons.lock_outline),
            title: Text('Section locks'),
            subtitle: Text(
              'Lock whole sections · coming soon',
              style: TextStyle(color: AppColors.textSecondary),
            ),
          ),
        ],
      ),
    );
  }
}
