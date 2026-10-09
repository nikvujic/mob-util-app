import 'package:flutter/material.dart';
import 'package:the_app/core/theme.dart';
import 'package:the_app/pages/other/counters.dart';
import 'package:the_app/pages/other/dzoni.dart';
import 'package:the_app/widgets/main_app_bar.dart';

/// Lists additional tools as square icon tiles, filled in from the bottom
/// right (thumb reach, O3). Each opens as its own page on top, and back
/// returns here (O1).
class OtherPage extends StatelessWidget {
  const OtherPage({super.key});

  static final _tools = [
    (
      icon: Icons.exposure_plus_1,
      label: 'Counters',
      page: () => const CountersPage(),
    ),
    (
      icon: Icons.record_voice_over_outlined,
      label: 'Džoni',
      page: () => const DzoniPage(),
    ),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: const MainAppBar(title: 'Other'),
      // Right to left, bottom to top: the first tool sits in the bottom
      // right corner.
      body: Directionality(
        textDirection: TextDirection.rtl,
        child: GridView.extent(
          reverse: true,
          maxCrossAxisExtent: 104,
          padding: const EdgeInsets.all(16),
          mainAxisSpacing: 12,
          crossAxisSpacing: 12,
          children: [
            for (final tool in _tools)
              _ToolTile(
                icon: tool.icon,
                label: tool.label,
                onTap: () => Navigator.of(context).push(
                  MaterialPageRoute<void>(builder: (_) => tool.page()),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

/// A square tile with only an icon; its name is the tooltip and what
/// screen readers say.
class _ToolTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  const _ToolTile({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: label,
      child: Material(
        color: context.colors.card,
        borderRadius: BorderRadius.circular(16),
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: onTap,
          child: Center(
            child: Icon(icon, size: 40, color: context.colors.accent),
          ),
        ),
      ),
    );
  }
}
