import 'package:flutter/material.dart';
import 'package:the_app/core/theme.dart';
import 'package:the_app/pages/other/counters.dart';
import 'package:the_app/widgets/main_app_bar.dart';

/// Lists additional tools; each opens as its own page on top, and back
/// returns here (O1).
class OtherPage extends StatelessWidget {
  const OtherPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: const MainAppBar(title: 'Other'),
      body: ListView(
        children: [
          ListTile(
            leading: const Icon(Icons.exposure_plus_1),
            title: const Text('Counters'),
            subtitle: Text(
              'Count anything with big − and + buttons',
              style: TextStyle(color: context.colors.textSecondary),
            ),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => Navigator.of(context).push(
              MaterialPageRoute<void>(builder: (_) => const CountersPage()),
            ),
          ),
        ],
      ),
    );
  }
}
