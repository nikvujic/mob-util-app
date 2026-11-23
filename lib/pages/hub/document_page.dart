import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:the_app/core/clock.dart';
import 'package:the_app/core/format.dart';
import 'package:the_app/core/id.dart';
import 'package:the_app/core/theme.dart';
import 'package:the_app/models/document_item.dart';
import 'package:the_app/pages/hub/barcode_pages.dart';
import 'package:the_app/pages/hub/document_pictures.dart';
import 'package:the_app/providers/document_pictures_provider.dart';
import 'package:the_app/providers/documents_provider.dart';
import 'package:the_app/widgets/choices_sheet.dart';
import 'package:the_app/widgets/confirm_dialog.dart';
import 'package:the_app/widgets/date_pick.dart';
import 'package:the_app/widgets/discard_scope.dart';
import 'package:the_app/widgets/low_handles.dart';
import 'package:the_app/widgets/pull_down_list.dart';

/// A document: its name, pictures, the fields of its kind and a note.
/// Saved as it's changed, once it holds anything; a new one left empty
/// is dropped. A receipt, a card or a ticket opens the camera first;
/// closed without a photo, the form stays, empty. Delete at the end,
/// asked first, with Undo.
class DocumentPage extends ConsumerStatefulWidget {
  /// The document to open; or null, with [newKind], for a new one.
  final String? documentId;
  final DocKind? newKind;

  const DocumentPage({super.key, this.documentId, this.newKind})
      : assert(documentId != null || newKind != null);

  @override
  ConsumerState<DocumentPage> createState() => _DocumentPageState();
}

class _DocumentPageState extends ConsumerState<DocumentPage> {
  late DocItem _draft =
      ref.read(documentsProvider).byId(widget.documentId ?? '') ??
          DocItem(
            id: generateId(),
            kind: widget.newKind ?? DocKind.document,
            // A ticket reminds on its day unless turned off.
            remind: widget.newKind == DocKind.ticket
                ? DocRemind.onTheDay
                : DocRemind.none,
            createdAt: ref.read(clockProvider)(),
          );

  /// As it was when the page opened (null: a new one), for Discard.
  late final DocItem? _original =
      ref.read(documentsProvider).byId(widget.documentId ?? '');

  late final _name = TextEditingController(text: _draft.name);
  late final _shop = TextEditingController(text: _draft.shop);
  late final _price = TextEditingController(text: _draft.price);
  late final _note = TextEditingController(text: _draft.note);

  /// A camera or gallery being used: their buttons wait.
  bool _picking = false;

  DocumentsNotifier get _notifier => ref.read(documentsProvider.notifier);

  @override
  void initState() {
    super.initState();
    if (_original == null && _draft.kind.startsWithCamera) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _takePhoto());
    }
  }

  @override
  void dispose() {
    _name.dispose();
    _shop.dispose();
    _price.dispose();
    _note.dispose();
    super.dispose();
  }

  /// [d] as it is now: kept, and saved once it holds anything (a new one
  /// emptied again is taken out).
  void _change(DocItem d) {
    setState(() => _draft = d);
    if (!d.isEmpty) {
      _notifier.save(d);
    } else if (_original == null &&
        ref.read(documentsProvider).byId(d.id) != null) {
      _notifier.delete(d.id);
    }
  }

  static bool _same(DocItem? a, DocItem? b) => a == null || b == null
      ? a == b
      : jsonEncode(a.toJson()) == jsonEncode(b.toJson());

  void _message(String text) => ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(SnackBar(content: Text(text)));

  /// Pictures stored: added to its own, after them. A new card or
  /// ticket's first photo goes on to the crop step.
  Future<void> _added(PicturesAdded added, {bool first = false}) async {
    if (!mounted) return;
    if (added.unavailable) {
      _message("The camera didn't open. If it's not allowed, allow it in "
          "the phone's settings; the gallery still works.");
    }
    if (added.ids.isEmpty) return;
    _change(_draft.copyWith(pictures: [
      ..._draft.pictures,
      for (final id in added.ids) DocPicture(id),
    ]));
    if (first && _draft.kind.hasBarcode && _draft.barcode == null) {
      await _cropFrom(_draft.pictures.last);
    }
  }

  Future<void> _pick(Future<PicturesAdded> Function() how,
      {bool first = false}) async {
    if (_picking) return;
    FocusManager.instance.primaryFocus?.unfocus();
    setState(() => _picking = true);
    try {
      final added = await how();
      if (mounted) setState(() => _picking = false);
      await _added(added, first: first);
    } finally {
      if (mounted && _picking) setState(() => _picking = false);
    }
  }

  /// The camera; for a new card or ticket's first photo, the crop after.
  Future<void> _takePhoto() =>
      _pick(ref.read(documentPicturesProvider).takePhoto,
          first: _draft.pictures.isEmpty);

  /// The crop step on [picture]: its crop, a picture of its own, the
  /// barcode.
  Future<void> _cropFrom(DocPicture picture) async {
    final crop = await Navigator.of(context).push<Uint8List>(
      MaterialPageRoute(builder: (_) => BarcodeCropPage(picture: picture)),
    );
    if (crop == null || !mounted) return;
    final id = await _notifier.addPicture(crop);
    if (!mounted) return;
    _change(_draft.copyWith(barcode: () => id));
  }

  /// *Set barcode*: from its only picture, or the one picked.
  Future<void> _setBarcode() async {
    final pictures = _draft.pictures;
    if (pictures.isEmpty) return;
    var picture = pictures.length == 1 ? pictures.single : null;
    if (picture == null) {
      final picked = await showChoicesSheet(context, 'Crop from', [
        for (final (i, _) in pictures.indexed)
          (Icons.image_outlined, 'Picture ${i + 1}', '$i'),
      ]);
      if (picked == null || !mounted) return;
      picture = pictures[int.parse(picked)];
    }
    await _cropFrom(picture);
  }

  void _showBarcode() => Navigator.of(context).push(
        MaterialPageRoute<void>(
          builder: (_) => ShowBarcodePage(
            barcodeId: _draft.barcode!,
            title: _draft.name,
          ),
        ),
      );

  Future<void> _pickFromGallery() =>
      _pick(ref.read(documentPicturesProvider).pickFromGallery);

  void _openViewer(int index) => Navigator.of(context).push(
        MaterialPageRoute<void>(
          builder: (_) => DocumentViewer(
            pictures: _draft.pictures,
            initial: index,
            title: _draft.name,
          ),
        ),
      );

  /// Held: what to do with the picture at [index].
  Future<void> _pictureMenu(int index) async {
    final count = _draft.pictures.length;
    final picked = await showChoicesSheet(context, null, [
      (Icons.rotate_right, 'Rotate', 'rotate'),
      if (index > 0) (Icons.arrow_back, 'Move earlier', 'earlier'),
      if (index < count - 1) (Icons.arrow_forward, 'Move later', 'later'),
      if (_draft.kind.hasBarcode) (Icons.crop, 'Set as the barcode', 'barcode'),
      (Icons.download_outlined, 'Download to the gallery', 'download'),
      (Icons.delete_outline, 'Delete', 'delete'),
    ]);
    if (picked == null || !mounted) return;
    final pictures = [..._draft.pictures];
    switch (picked) {
      case 'rotate':
        pictures[index] = pictures[index].turned();
        _change(_draft.copyWith(pictures: pictures));
      case 'earlier' || 'later':
        final to = picked == 'earlier' ? index - 1 : index + 1;
        pictures.insert(to, pictures.removeAt(index));
        _change(_draft.copyWith(pictures: pictures));
      case 'barcode':
        await _cropFrom(pictures[index]);
      case 'download':
        await _download(pictures[index], index);
      case 'delete':
        final before = _draft.pictures;
        pictures.removeAt(index);
        _change(_draft.copyWith(pictures: pictures));
        ScaffoldMessenger.of(context)
          ..hideCurrentSnackBar()
          ..showSnackBar(SnackBar(
            content: const Text('Picture deleted'),
            action: SnackBarAction(
              label: 'Undo',
              onPressed: () {
                if (mounted) _change(_draft.copyWith(pictures: before));
              },
            ),
          ));
    }
  }

  Future<void> _download(DocPicture picture, int index) async {
    final base = _draft.name.trim().isEmpty ? _draft.kind.label : _draft.name;
    final name = _draft.pictures.length > 1 ? '$base ${index + 1}' : base;
    final saved =
        await ref.read(documentPicturesProvider).download(picture.id, name);
    if (!mounted) return;
    _message(saved
        ? 'Saved to the gallery'
        : "Couldn't save to the gallery (allow storage and try again)");
  }

  /// Asked first, then gone, with Undo.
  Future<void> _delete() async {
    final d = _draft;
    final title = d.name.trim().isEmpty ? 'this document' : d.name.trim();
    final confirmed = await showConfirmDialog(
      context,
      title: 'Delete $title?',
      confirmLabel: 'Delete',
      destructive: true,
    );
    if (!confirmed || !mounted) return;
    final notifier = _notifier;
    final before = notifier.delete(d.id);
    final messenger = ScaffoldMessenger.of(context);
    Navigator.of(context).pop();
    messenger
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(
        content: Text('${d.name.trim().isEmpty ? 'Document' : d.name} deleted'),
        action: SnackBarAction(
          label: 'Undo',
          onPressed: () => notifier.replaceAll(before),
        ),
      ));
  }

  DateTime get _today => dayOf(ref.read(clockProvider)());

  /// A day picked (null if cancelled), opening on [value] or today.
  Future<DateTime?> _pickDay(DateTime? value, {String? help}) {
    FocusManager.instance.primaryFocus?.unfocus();
    final today = _today;
    return pickDate(
      context,
      today: today,
      value: value,
      helpText: help,
      first: DateTime(today.year - 30),
      last: DateTime(today.year + 30, 12, 31),
    );
  }

  /// [day] moved on by [years] (29 Feb to 28 Feb).
  static DateTime _yearsOn(DateTime day, int years) {
    final last = DateTime(day.year + years, day.month + 1, 0).day;
    return DateTime(
        day.year + years, day.month, day.day > last ? last : day.day);
  }

  /// A day's tile: [label], the day (or *Not set*), cleared by its ×.
  Widget _dayTile({
    required Key key,
    required IconData icon,
    required String label,
    required DateTime? day,
    required VoidCallback onTap,
    VoidCallback? onClear,
  }) {
    final colors = context.colors;
    return ListTile(
      key: key,
      leading: Icon(icon),
      title: Text(label),
      trailing: day == null
          ? Text('Not set', style: TextStyle(color: colors.textMuted))
          : Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(formatShortDate(day)),
                if (onClear != null)
                  IconButton(
                    key: Key('${(key as ValueKey<String>).value}Clear'),
                    tooltip: 'Not set',
                    icon: const Icon(Icons.close),
                    onPressed: onClear,
                  ),
              ],
            ),
      onTap: onTap,
    );
  }

  /// How long before its date a reminder comes.
  Widget _remindChoices() => Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        child: Wrap(
          spacing: 8,
          runSpacing: 4,
          children: [
            for (final r in DocRemind.before)
              ChoiceChip(
                key: Key('documentRemind-${r.name}'),
                label: Text(r.label),
                selected: _draft.remind == r,
                onSelected: (_) => _change(_draft.copyWith(remind: r)),
              ),
          ],
        ),
      );

  Widget _remindNote(String text) => Padding(
        padding: const EdgeInsets.fromLTRB(16, 6, 16, 0),
        child: Text(
          text,
          style: TextStyle(color: context.colors.textMuted, fontSize: 12),
        ),
      );

  /// The fields of its kind with a date: a document's expiry, a
  /// receipt's warranty, a ticket's day; and their reminders.
  List<Widget> _dates(DocItem d) {
    switch (d.kind) {
      case DocKind.document:
        return [
          _heading('EXPIRY'),
          _dayTile(
            key: const ValueKey('documentExpires'),
            icon: Icons.event_busy_outlined,
            label: 'Expires',
            day: d.expires,
            onTap: () async {
              final day = await _pickDay(d.expires, help: 'Expires');
              if (day != null && mounted) {
                _change(_draft.copyWith(expires: () => day));
              }
            },
            onClear: () => _change(_draft.copyWith(expires: () => null)),
          ),
          if (d.expires != null) ...[
            _heading('REMINDER BEFORE'),
            _remindChoices(),
            _remindNote('At 09:00.'),
          ],
        ];
      case DocKind.receipt:
        final from = d.warrantyFrom ?? _today;
        return [
          SwitchListTile(
            key: const Key('documentWarranty'),
            secondary: const Icon(Icons.verified_user_outlined),
            title: const Text('Warranty'),
            value: d.warranty,
            onChanged: (on) => _change(_draft.copyWith(
              warranty: on,
              // From today unless a day's set.
              warrantyFrom: () => on ? from : _draft.warrantyFrom,
            )),
          ),
          if (d.warranty) ...[
            _dayTile(
              key: const ValueKey('documentWarrantyFrom'),
              icon: Icons.play_arrow_outlined,
              label: dayOf(from) == _today ? 'From today' : 'From',
              day: from,
              onTap: () async {
                final day = await _pickDay(from, help: 'Warranty from');
                if (day != null && mounted) {
                  _change(_draft.copyWith(warrantyFrom: () => day));
                }
              },
            ),
            _dayTile(
              key: const ValueKey('documentWarrantyTo'),
              icon: Icons.stop_outlined,
              label: 'Until',
              day: d.warrantyTo,
              onTap: () async {
                final day = await _pickDay(d.warrantyTo ?? _yearsOn(from, 2),
                    help: 'Warranty until');
                if (day != null && mounted) {
                  _change(_draft.copyWith(warrantyTo: () => day));
                }
              },
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Wrap(
                spacing: 8,
                children: [
                  for (final years in [1, 2])
                    ActionChip(
                      key: Key('documentWarrantyYears-$years'),
                      label: Text(years == 1 ? '1 year' : '$years years'),
                      onPressed: () => _change(_draft.copyWith(
                        warrantyFrom: () => from,
                        warrantyTo: () => _yearsOn(from, years),
                      )),
                    ),
                ],
              ),
            ),
            if (d.warrantyTo != null) ...[
              _heading('REMINDER BEFORE IT ENDS'),
              _remindChoices(),
              _remindNote('At 09:00.'),
            ],
          ],
        ];
      case DocKind.ticket:
        return [
          _heading('DATE'),
          _dayTile(
            key: const ValueKey('documentDate'),
            icon: Icons.event_outlined,
            label: 'On',
            day: d.date,
            onTap: () async {
              final day = await _pickDay(d.date, help: 'Ticket for');
              if (day != null && mounted) {
                _change(_draft.copyWith(date: () => day));
              }
            },
            onClear: () => _change(_draft.copyWith(date: () => null)),
          ),
          if (d.date != null)
            SwitchListTile(
              key: const Key('documentTicketRemind'),
              secondary: const Icon(Icons.notifications_none),
              title: const Text('Remind me on the day'),
              subtitle: const Text('At 09:00'),
              value: d.remind != DocRemind.none,
              onChanged: (on) => _change(_draft.copyWith(
                  remind: on ? DocRemind.onTheDay : DocRemind.none)),
            ),
        ];
      case DocKind.barcode:
        return const [];
    }
  }

  Widget _heading(String text) => Padding(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 6),
        child: Text(
          text,
          style: TextStyle(
            color: context.colors.accent,
            fontSize: 12,
            fontWeight: FontWeight.w600,
            letterSpacing: 1,
          ),
        ),
      );

  @override
  Widget build(BuildContext context) {
    final now = ref.watch(documentsProvider).byId(_draft.id);
    final saved = now != null;
    final d = _draft;
    final colors = context.colors;
    return DiscardScope(
      changed: !_same(now, _original),
      isNew: _original == null,
      what: 'document',
      onDiscard: () => switch (_original) {
        final o? => _notifier.save(o),
        null => _notifier.delete(_draft.id),
      },
      child: Scaffold(
        appBar: AppBar(
          title: Text(_original == null && !saved
              ? 'New ${d.kind.label.toLowerCase()}'
              : d.kind.label),
        ),
        body: PullDownList.children(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
              child: TextField(
                selectionControls: lowHandles,
                key: const Key('documentName'),
                controller: _name,
                textCapitalization: TextCapitalization.sentences,
                decoration: const InputDecoration(labelText: 'Name'),
                onChanged: (text) => _change(_draft.copyWith(name: text)),
              ),
            ),
            _heading('PICTURES'),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (final (i, p) in d.pictures.indexed)
                    Semantics(
                      key: Key('documentPicture-$i'),
                      button: true,
                      label: 'Picture ${i + 1}',
                      child: GestureDetector(
                        onTap: () => _openViewer(i),
                        onLongPress: () => _pictureMenu(i),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(8),
                          child: SizedBox.square(
                            dimension: 88,
                            child: DocThumb(picture: p),
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 8, 12, 0),
              child: Wrap(
                spacing: 8,
                children: [
                  OutlinedButton.icon(
                    key: const Key('documentCamera'),
                    icon: const Icon(Icons.photo_camera_outlined),
                    label: const Text('Camera'),
                    onPressed: _picking ? null : _takePhoto,
                  ),
                  OutlinedButton.icon(
                    key: const Key('documentGallery'),
                    icon: const Icon(Icons.photo_library_outlined),
                    label: const Text('Gallery'),
                    onPressed: _picking ? null : _pickFromGallery,
                  ),
                ],
              ),
            ),
            if (d.pictures.isNotEmpty)
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 6, 16, 0),
                child: Text(
                  'Tap a picture to open it; hold it to rotate, move, '
                  'download or delete it.',
                  style: TextStyle(color: colors.textMuted, fontSize: 12),
                ),
              ),
            if (d.kind.hasBarcode) ...[
              _heading('BARCODE'),
              if (d.barcode case final code?)
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: GestureDetector(
                    key: const Key('documentBarcode'),
                    onTap: _showBarcode,
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: SizedBox(
                        height: 96,
                        width: double.infinity,
                        child: ColoredBox(
                          color: ViewerColours.paper,
                          child: DocThumb(
                            picture: DocPicture(code),
                            cacheWidth: 800,
                            fit: BoxFit.contain,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              // Full width: Show on its own, Set / Change beside Remove.
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    if (d.barcode != null) ...[
                      FilledButton.icon(
                        key: const Key('documentShowBarcode'),
                        style: FilledButton.styleFrom(
                            minimumSize: const Size.fromHeight(44)),
                        icon: const Icon(Icons.qr_code_scanner),
                        label: const Text('Show barcode'),
                        onPressed: _showBarcode,
                      ),
                      const SizedBox(height: 8),
                    ],
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton.icon(
                            key: const Key('documentSetBarcode'),
                            style: OutlinedButton.styleFrom(
                                minimumSize: const Size.fromHeight(44)),
                            icon: const Icon(Icons.crop),
                            label: Text(d.barcode == null
                                ? 'Set barcode'
                                : 'Change barcode'),
                            onPressed: d.pictures.isEmpty ? null : _setBarcode,
                          ),
                        ),
                        if (d.barcode != null) ...[
                          const SizedBox(width: 8),
                          OutlinedButton(
                            key: const Key('documentRemoveBarcode'),
                            style: OutlinedButton.styleFrom(
                                minimumSize: const Size(0, 44)),
                            onPressed: () =>
                                _change(_draft.copyWith(barcode: () => null)),
                            child: const Text('Remove'),
                          ),
                        ],
                      ],
                    ),
                  ],
                ),
              ),
              if (d.pictures.isEmpty)
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 6, 16, 0),
                  child: Text(
                    'Add a picture of it, then frame its barcode.',
                    style: TextStyle(color: colors.textMuted, fontSize: 12),
                  ),
                ),
            ],
            if (d.kind == DocKind.receipt) ...[
              _heading('PURCHASE'),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Row(
                  children: [
                    Expanded(
                      flex: 3,
                      child: TextField(
                        selectionControls: lowHandles,
                        key: const Key('documentShop'),
                        controller: _shop,
                        textCapitalization: TextCapitalization.sentences,
                        decoration: const InputDecoration(labelText: 'Shop'),
                        onChanged: (text) =>
                            _change(_draft.copyWith(shop: text)),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      flex: 2,
                      child: TextField(
                        selectionControls: lowHandles,
                        key: const Key('documentPrice'),
                        controller: _price,
                        decoration: const InputDecoration(labelText: 'Price'),
                        onChanged: (text) =>
                            _change(_draft.copyWith(price: text)),
                      ),
                    ),
                  ],
                ),
              ),
            ],
            ..._dates(d),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
              child: TextField(
                selectionControls: lowHandles,
                key: const Key('documentNote'),
                controller: _note,
                minLines: 1,
                maxLines: 8,
                textCapitalization: TextCapitalization.sentences,
                decoration: const InputDecoration(labelText: 'Note'),
                onChanged: (text) => _change(_draft.copyWith(note: text)),
              ),
            ),
            if (saved)
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
                // A full button, as Delete person.
                child: OutlinedButton.icon(
                  key: const Key('deleteDocument'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: colors.danger,
                    side: BorderSide(color: colors.danger),
                    minimumSize: const Size.fromHeight(44),
                  ),
                  icon: const Icon(Icons.delete_outline),
                  label: const Text('Delete document'),
                  onPressed: _delete,
                ),
              ),
          ],
        ),
      ),
    );
  }
}
