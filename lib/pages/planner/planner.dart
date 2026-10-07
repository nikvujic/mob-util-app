import 'package:flutter/material.dart';
import 'package:the_app/widgets/empty_state.dart';
import 'package:the_app/widgets/main_app_bar.dart';

/// Placeholder for the planner (requirements P1–P4).
class PlannerPage extends StatelessWidget {
  const PlannerPage({super.key});

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      appBar: MainAppBar(title: 'Planner'),
      body: EmptyState(
        icon: Icons.event_note_outlined,
        message: 'The planner is coming soon',
      ),
    );
  }
}
