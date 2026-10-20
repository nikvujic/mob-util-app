import 'package:flutter/material.dart';
import 'package:the_app/core/theme.dart';
import 'package:the_app/models/packing.dart';
import 'package:the_app/widgets/low_handles.dart';

/// Copy list (Nikola): a name for the copy (" (Copy)" offered) and which
/// of the list's sections come along, all at first (e.g. Documents and
/// Clothes, not the ski gear). Resolves to them, or null if closed.
Future<({String name, Set<String> sectionIds})?> showCopyListSheet(
  BuildContext context, {
  required PackingList list,
  required List<(PackingSection, List<PackingItem>)> groups,
}) =>
    showModalBottomSheet<({String name, Set<String> sectionIds})>(
      context: context,
      isScrollControlled: true,
      builder: (_) => _CopySheet(list: list, groups: groups),
    );

class _CopySheet extends StatefulWidget {
  final PackingList list;

  /// The list's sections with something in them, and what.
  final List<(PackingSection, List<PackingItem>)> groups;

  const _CopySheet({required this.list, required this.groups});

  @override
  State<_CopySheet> createState() => _CopySheetState();
}

class _CopySheetState extends State<_CopySheet> {
  late final _name = TextEditingController(
    text:
        '${widget.list.name.trim().isEmpty ? 'Untitled' : widget.list.name.trim()} (Copy)',
  )..addListener(() => setState(() {}));
  late final _picked = {for (final (s, _) in widget.groups) s.id};

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final name = _name.text.trim();
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
      child: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text('Copy list',
                  style: TextStyle(
                    color: colors.textPrimary,
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                  )),
              TextField(
                key: const Key('packingCopyName'),
                selectionControls: lowHandles,
                controller: _name,
                textCapitalization: TextCapitalization.sentences,
                style: TextStyle(color: colors.textPrimary),
                decoration: InputDecoration(
                  labelText: 'Name',
                  hintStyle: TextStyle(color: colors.textHint),
                ),
              ),
              const SizedBox(height: 12),
              if (widget.groups.isEmpty)
                Text('Nothing in it yet: the copy starts empty.',
                    style: TextStyle(color: colors.textMuted))
              else ...[
                Text('Sections to copy',
                    style: TextStyle(color: colors.textSecondary)),
                for (final (s, items) in widget.groups)
                  CheckboxListTile(
                    key: Key('packingCopySection-${s.id}'),
                    contentPadding: EdgeInsets.zero,
                    controlAffinity: ListTileControlAffinity.leading,
                    value: _picked.contains(s.id),
                    title: Text(s.name),
                    subtitle: Text(
                        items.length == 1 ? '1 item' : '${items.length} items'),
                    onChanged: (on) => setState(() {
                      if (on ?? false) {
                        _picked.add(s.id);
                      } else {
                        _picked.remove(s.id);
                      }
                    }),
                  ),
              ],
              const SizedBox(height: 12),
              FilledButton(
                key: const Key('packingCopyGo'),
                style: FilledButton.styleFrom(
                  minimumSize: const Size.fromHeight(48),
                ),
                onPressed: name.isEmpty
                    ? null
                    : () => Navigator.of(context)
                        .pop((name: name, sectionIds: {..._picked})),
                child: const Text('Copy'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
