import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:the_app/core/theme.dart';
import 'package:the_app/widgets/choices_sheet.dart';

/// Round 131: a page's things as text, copied and pasted: **import** (the
/// pasted things listed, picked, then added), **export** (the things
/// picked, for someone to import into their app) and **agent
/// instructions** (the rules, so an AI agent writes new ones to import).
/// A page gives what's its own; the sheets are the same everywhere.
class TransferKit<T, I> {
  /// One and many of what's moved ("recipe", "recipes").
  final String one, many;

  /// What there is to export now, and each one's name.
  final List<T> Function() items;
  final String Function(T) nameOf;

  /// The picked things as text to import.
  final String Function(List<T>) export;

  /// The rules for an agent.
  final String Function() agentInstructions;

  /// What's in pasted text; throws a [FormatException] saying what's
  /// wrong.
  final List<I> Function(String) parse;

  /// An imported one's name, a line about it, and whether one like it is
  /// here already (then it starts unpicked).
  final String Function(I) importName;
  final String Function(I) importDetail;
  final bool Function(I) alreadyHere;

  /// Adds the picked ones.
  final void Function(List<I>) importAll;

  const TransferKit({
    required this.one,
    required this.many,
    required this.items,
    required this.nameOf,
    required this.export,
    required this.agentInstructions,
    required this.parse,
    required this.importName,
    required this.importDetail,
    required this.alreadyHere,
    required this.importAll,
  });

  String count(int n) => n == 1 ? '1 $one' : '$n $many';
}

/// The app bar's Import / export button's menu, and what's picked in it.
Future<void> showTransferMenu<T, I>(
    BuildContext context, TransferKit<T, I> kit) async {
  final choice = await showChoicesSheet(context, 'Import / export', const [
    (Icons.content_paste, 'Import (paste)', 'import'),
    (Icons.ios_share, 'Export', 'export'),
    (Icons.smart_toy_outlined, 'Agent instructions', 'agent'),
  ]);
  if (choice == null || !context.mounted) return;
  switch (choice) {
    case 'import':
      await _import(context, kit);
    case 'export':
      await _export(context, kit);
    default:
      await Clipboard.setData(ClipboardData(text: kit.agentInstructions()));
      if (context.mounted) {
        _toast(context, 'Copied: instructions for an agent');
      }
  }
}

Future<void> _export<T, I>(BuildContext context, TransferKit<T, I> kit) async {
  final items = kit.items();
  if (items.isEmpty) return _toast(context, 'No ${kit.many} to export');
  final picked = await _pickSheet(
    context,
    title: 'Export which ${kit.many}?',
    names: [for (final t in items) kit.nameOf(t)],
    details: null,
    startPicked: [for (final _ in items) true],
    action: (n) => 'Copy ${kit.count(n)}',
  );
  if (picked == null || picked.isEmpty || !context.mounted) return;
  await Clipboard.setData(
      ClipboardData(text: kit.export([for (final i in picked) items[i]])));
  if (context.mounted) _toast(context, 'Copied ${kit.count(picked.length)}');
}

Future<void> _import<T, I>(BuildContext context, TransferKit<T, I> kit) async {
  final text = (await Clipboard.getData(Clipboard.kTextPlain))?.text ?? '';
  if (!context.mounted) return;
  if (text.trim().isEmpty) {
    return _toast(context, 'Copy some ${kit.many} first, then import');
  }
  final List<I> found;
  try {
    found = kit.parse(text);
  } on FormatException catch (e) {
    return _toast(context, e.message);
  }
  final picked = await _pickSheet(
    context,
    title: found.length == 1
        ? 'Import this ${kit.one}?'
        : 'Import which ${kit.many}?',
    names: [for (final i in found) kit.importName(i)],
    details: [
      for (final i in found)
        [
          kit.importDetail(i),
          if (kit.alreadyHere(i)) 'You have one by this name',
        ].where((s) => s.isNotEmpty).join(' · '),
    ],
    startPicked: [for (final i in found) !kit.alreadyHere(i)],
    action: (n) => 'Import ${kit.count(n)}',
  );
  if (picked == null || picked.isEmpty || !context.mounted) return;
  kit.importAll([for (final i in picked) found[i]]);
  _toast(context, 'Imported ${kit.count(picked.length)}');
}

void _toast(BuildContext context, String message) =>
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));

/// A list to tick in a bottom sheet (capped in height, scrolled when
/// long), All / None, and the button doing it; the indexes picked, or
/// null if closed.
Future<List<int>?> _pickSheet(
  BuildContext context, {
  required String title,
  required List<String> names,
  required List<String>? details,
  required List<bool> startPicked,
  required String Function(int) action,
}) =>
    showModalBottomSheet<List<int>>(
      context: context,
      isScrollControlled: true,
      builder: (context) => _PickSheet(
        title: title,
        names: names,
        details: details,
        startPicked: startPicked,
        action: action,
      ),
    );

class _PickSheet extends StatefulWidget {
  final String title;
  final List<String> names;
  final List<String>? details;
  final List<bool> startPicked;
  final String Function(int) action;

  const _PickSheet({
    required this.title,
    required this.names,
    required this.details,
    required this.startPicked,
    required this.action,
  });

  @override
  State<_PickSheet> createState() => _PickSheetState();
}

class _PickSheetState extends State<_PickSheet> {
  late final _picked = [...widget.startPicked];

  @override
  Widget build(BuildContext context) {
    final n = _picked.where((p) => p).length;
    final all = n == _picked.length;
    return SafeArea(
      child: ConstrainedBox(
        constraints:
            BoxConstraints(maxHeight: MediaQuery.sizeOf(context).height * 0.75),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 4, 0),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      widget.title,
                      style: TextStyle(
                          color: context.colors.textSecondary, fontSize: 14),
                    ),
                  ),
                  if (_picked.length > 1)
                    TextButton(
                      key: const Key('transferAll'),
                      onPressed: () => setState(
                          () => _picked.fillRange(0, _picked.length, !all)),
                      child: Text(all ? 'None' : 'All'),
                    ),
                ],
              ),
            ),
            Flexible(
              child: ListView(
                shrinkWrap: true,
                children: [
                  for (var i = 0; i < widget.names.length; i++)
                    CheckboxListTile(
                      key: Key('transferItem-$i'),
                      value: _picked[i],
                      onChanged: (v) => setState(() => _picked[i] = v ?? false),
                      title: Text(widget.names[i],
                          maxLines: 1, overflow: TextOverflow.ellipsis),
                      subtitle: switch (widget.details?[i]) {
                        final d? when d.isNotEmpty => Text(d),
                        _ => null,
                      },
                    ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
              child: SizedBox(
                width: double.infinity,
                child: FilledButton(
                  key: const Key('transferGo'),
                  onPressed: n == 0
                      ? null
                      : () => Navigator.of(context).pop([
                            for (var i = 0; i < _picked.length; i++)
                              if (_picked[i]) i,
                          ]),
                  child: Text(widget.action(n)),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
