import 'package:flutter/material.dart';
import 'package:the_app/widgets/empty_state.dart';
import 'package:the_app/widgets/main_app_bar.dart';

/// Lists additional tools; each opens as its own page (requirement O1).
class OtherPage extends StatelessWidget {
  const OtherPage({super.key});

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      appBar: MainAppBar(title: 'Other'),
      body: EmptyState(
        icon: Icons.apps_outlined,
        message: 'More tools are coming soon',
      ),
    );
  }
}
