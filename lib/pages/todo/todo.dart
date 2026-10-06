import 'package:flutter/material.dart';
import 'package:the_app/widgets/empty_state.dart';

/// Placeholder for the to-do list (requirement T2).
class TodoPage extends StatelessWidget {
  const TodoPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('To Do')),
      body: const EmptyState(
        icon: Icons.checklist,
        message: 'To-do lists are coming soon',
      ),
    );
  }
}
