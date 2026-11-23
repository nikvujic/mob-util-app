import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:the_app/core/clock.dart';
import 'package:the_app/core/format.dart';
import 'package:the_app/core/theme.dart';
import 'package:the_app/models/document_item.dart';
import 'package:the_app/models/hub_tool.dart';
import 'package:the_app/pages/hub/barcode_pages.dart';
import 'package:the_app/pages/hub/document_page.dart';
import 'package:the_app/pages/hub/document_pictures.dart';
import 'package:the_app/pages/hub/page_gate.dart';
import 'package:the_app/providers/documents_provider.dart';
import 'package:the_app/widgets/bottom_actions.dart';
import 'package:the_app/widgets/choices_sheet.dart';
import 'package:the_app/widgets/empty_state.dart';
import 'package:the_app/widgets/low_handles.dart';
import 'package:the_app/widgets/pull_down_list.dart';
import 'package:the_app/widgets/selection.dart';
import 'package:the_app/widgets/smooth_reorderable_list.dart';

/// A kind's icon, on its card and in the type chooser.
extension DocKindLook on DocKind {
  IconData get icon => switch (this) {
        DocKind.document => Icons.badge_outlined,
        DocKind.receipt => Icons.receipt_long_outlined,
        DocKind.barcode => Icons.credit_card,
        DocKind.qr => Icons.qr_code_2,
        DocKind.ticket => Icons.confirmation_number_outlined,
      };

  /// What it's for, in the type chooser.
  String get hint => switch (this) {
        DocKind.document => 'Passport, ID, licence',
        DocKind.receipt => 'A purchase, its warranty',
        DocKind.barcode => 'A loyalty or membership card',
        DocKind.qr => 'A pass, a card or a booking with a QR code',
        DocKind.ticket => 'A boarding pass, an event, a train',
      };
}

/// Opens a document's page, behind the Documents lock.
void openDocumentPage(BuildContext context, Widget page) {
  Navigator.of(context).push(
    MaterialPageRoute<void>(
      builder: (_) => PageGate(page: HubTool.documents, child: page),
    ),
  );
}

/// Asks which kind a new one is, then opens it (the camera first for a
/// receipt, a card or a ticket).
Future<void> addDocument(BuildContext context) async {
  final picked = await showChoicesSheet(context, 'New', [
    for (final kind in DocKind.values) (kind.icon, kind.label, kind.name),
  ]);
  if (picked == null || !context.mounted) return;
  openDocumentPage(context, DocumentPage(newKind: DocKind.fromId(picked)));
}

/// Whether [d] matches [query] (its name, shop or note, any case).
bool documentMatches(DocItem d, String query) {
  final q = query.trim().toLowerCase();
  if (q.isEmpty) return true;
  return d.name.toLowerCase().contains(q) ||
      d.shop.toLowerCase().contains(q) ||
      d.note.toLowerCase().contains(q) ||
      (d.scanned?.text.toLowerCase().contains(q) ?? false);
}

/// Documents (`docs/DOCUMENTS_SPEC.md`): a card for each, in the user's
/// order (the handle moves them), with its first picture, name and kind;
/// a search (name, shop, note) and a filter by kind above them. A tap
/// opens one; + asks its kind and makes one.
class DocumentsPage extends ConsumerStatefulWidget {
  const DocumentsPage({super.key});

  @override
  ConsumerState<DocumentsPage> createState() => _DocumentsPageState();
}

class _DocumentsPageState extends ConsumerState<DocumentsPage> {
  final _search = TextEditingController();
  String _query = '';
  DocKind? _kind;

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final book = ref.watch(documentsProvider);
    final colors = context.colors;
    final today = dayOf(ref.watch(clockProvider)());
    final shown = [
      for (final d in book.items)
        if ((_kind == null || d.kind == _kind) && documentMatches(d, _query)) d,
    ];
    // Shown narrowed, the order can't be changed.
    final reorderable = shown.length == book.items.length;
    final notifier = ref.read(documentsProvider.notifier);
    return Scaffold(
      appBar: AppBar(title: Text(HubTool.documents.label)),
      body: book.items.isEmpty
          ? const EmptyState(
              icon: Icons.folder_outlined,
              message: 'No documents',
            )
          : PullDownList(
              bottomSpace: BottomActions.contentClearance,
              slivers: [
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(12, 8, 12, 0),
                    // The icon beside the field, both centred on one line
                    // (as the field's own prefix it sat off its text).
                    child: Container(
                      decoration: BoxDecoration(
                        color: colors.card,
                        borderRadius: BorderRadius.circular(24),
                      ),
                      padding: const EdgeInsets.only(left: 14),
                      child: Row(
                        children: [
                          Icon(Icons.search, color: colors.textSecondary),
                          const SizedBox(width: 10),
                          Expanded(
                            child: TextField(
                              key: const Key('documentsSearch'),
                              selectionControls: lowHandles,
                              controller: _search,
                              textInputAction: TextInputAction.search,
                              decoration: const InputDecoration(
                                hintText: 'Search name, shop, note',
                                border: InputBorder.none,
                                enabledBorder: InputBorder.none,
                                focusedBorder: InputBorder.none,
                                filled: false,
                                isDense: true,
                                contentPadding:
                                    EdgeInsets.symmetric(vertical: 14),
                              ),
                              onChanged: (text) =>
                                  setState(() => _query = text),
                            ),
                          ),
                          if (_query.isEmpty)
                            const SizedBox(width: 14)
                          else
                            IconButton(
                              tooltip: 'Clear',
                              icon: const Icon(Icons.close),
                              onPressed: () => setState(() {
                                _search.clear();
                                _query = '';
                              }),
                            ),
                        ],
                      ),
                    ),
                  ),
                ),
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(12, 10, 12, 4),
                    // As far apart down as across: a chip on a new row
                    // stays one of the group.
                    child: Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        for (final kind in DocKind.values)
                          FilterChip(
                            key: Key('documentsFilter-${kind.name}'),
                            materialTapTargetSize:
                                MaterialTapTargetSize.shrinkWrap,
                            avatar: Icon(kind.icon, size: 16),
                            label: Text(kind.label),
                            selected: _kind == kind,
                            onSelected: (on) =>
                                setState(() => _kind = on ? kind : null),
                          ),
                      ],
                    ),
                  ),
                ),
                if (shown.isEmpty)
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Text(
                        'Nothing matches',
                        style: TextStyle(color: colors.textMuted),
                      ),
                    ),
                  ),
                SliverPadding(
                  padding: const EdgeInsets.only(top: 4),
                  sliver: SmoothSliverReorderableList(
                    itemCount: shown.length,
                    // onReorderItem only exists on newer Flutter than we
                    // target.
                    // ignore: deprecated_member_use
                    onReorder: reorderable ? notifier.reorder : (_, __) {},
                    proxyDecorator: (child, _, __) => Material(
                      type: MaterialType.transparency,
                      elevation: 6,
                      child: child,
                    ),
                    itemBuilder: (context, index) {
                      final d = shown[index];
                      return Padding(
                        key: ValueKey(d.id),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 3,
                        ),
                        child: DocumentCard(
                          document: d,
                          index: index,
                          today: today,
                          reorderable: reorderable,
                          onTap: () => openDocumentPage(
                              context, DocumentPage(documentId: d.id)),
                          onShowBarcode: d.barcode == null
                              ? null
                              : () => openDocumentPage(
                                    context,
                                    ShowBarcodePage(documentId: d.id),
                                  ),
                        ),
                      );
                    },
                  ),
                ),
              ],
            ),
      floatingActionButton: BottomActions(
        side: HandSide.right,
        actions: [
          BottomAction(
            icon: Icons.add,
            tooltip: 'Add a document',
            primary: true,
            onPressed: () => addDocument(context),
          ),
        ],
      ),
    );
  }
}

/// A document's card: its first picture, name, kind and date line.
class DocumentCard extends StatelessWidget {
  final DocItem document;
  final int index;
  final DateTime today;
  final bool reorderable;
  final VoidCallback onTap;

  /// Its barcode shown at once (a card or a ticket with one); null: none.
  final VoidCallback? onShowBarcode;

  const DocumentCard({
    super.key,
    required this.document,
    required this.index,
    required this.today,
    required this.reorderable,
    required this.onTap,
    this.onShowBarcode,
  });

  @override
  Widget build(BuildContext context) {
    final d = document;
    final colors = context.colors;
    final untitled = d.name.trim().isEmpty;
    final line = documentDateLine(d, today);
    return SelectableCard(
      key: Key('document-${d.id}'),
      selected: false,
      onTap: onTap,
      child: ReorderableRow(
        content: Padding(
          padding: const EdgeInsets.fromLTRB(10, 10, 0, 10),
          child: Row(
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(6),
                child: SizedBox.square(
                  dimension: 56,
                  child: d.pictures.isEmpty
                      ? ColoredBox(
                          color: colors.background,
                          child: Icon(d.kind.icon, color: colors.textHint),
                        )
                      : DocThumb(picture: d.pictures.first),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      untitled ? 'Untitled' : d.name,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 16,
                        color: untitled
                            ? colors.textSecondary
                            : colors.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Row(
                      children: [
                        Icon(d.kind.icon, size: 14, color: colors.textMuted),
                        const SizedBox(width: 4),
                        Flexible(
                          child: Text(
                            [
                              d.kind.label,
                              if (d.shop.trim().isNotEmpty) d.shop.trim(),
                            ].join(' · '),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                                fontSize: 12, color: colors.textSecondary),
                          ),
                        ),
                      ],
                    ),
                    if (line != null)
                      Padding(
                        padding: const EdgeInsets.only(top: 2),
                        child: Text(
                          line.text,
                          key: Key('documentDate-${d.id}'),
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: line.tone == DateTone.plain
                                ? FontWeight.normal
                                : FontWeight.w600,
                            color: switch (line.tone) {
                              DateTone.plain => colors.textSecondary,
                              DateTone.soon => DocumentColours.soon,
                              DateTone.gone => colors.danger,
                              DateTone.past => colors.textHint,
                            },
                          ),
                        ),
                      ),
                  ],
                ),
              ),
              // Straight to its barcode, at the till.
              if (onShowBarcode != null)
                IconButton(
                  key: Key('documentQuickBarcode-${d.id}'),
                  tooltip: 'Show barcode',
                  icon: const Icon(Icons.qr_code_scanner),
                  color: colors.accent,
                  onPressed: onShowBarcode,
                ),
            ],
          ),
        ),
        indicator: ReorderOrSelectIndicator(
          index: index,
          selectionMode: false,
          selected: false,
          reorderable: reorderable,
        ),
      ),
    );
  }
}

/// How a document's date line is coloured (as in Subscriptions).
enum DateTone { plain, soon, gone, past }

/// The orange of a date within its reminder.
abstract final class DocumentColours {
  static const soon = SubscriptionColours.toCancel;
}

/// A document's date line on [today], or null if it has none: *Expires
/// 3 Mar 2031*, *Warranty until 12 Nov 2028*, *Warranty ended*,
/// *Tomorrow* (a ticket).
({String text, DateTone tone})? documentDateLine(DocItem d, DateTime today) {
  final due = d.dueDate;
  if (due == null) return null;
  final days = DateTime.utc(due.year, due.month, due.day)
      .difference(DateTime.utc(today.year, today.month, today.day))
      .inDays;
  final soonWithin = d.remind == DocRemind.none ? 30 : d.remind.days;
  DateTone tone(bool gone) => gone
      ? DateTone.gone
      : days <= soonWithin
          ? DateTone.soon
          : DateTone.plain;
  return switch (d.kind) {
    DocKind.document => days < 0
        ? (text: 'Expired ${formatShortDate(due)}', tone: DateTone.gone)
        : (text: 'Expires ${formatShortDate(due)}', tone: tone(false)),
    DocKind.receipt => days < 0
        ? (text: 'Warranty ended', tone: DateTone.past)
        : (text: 'Warranty until ${formatShortDate(due)}', tone: tone(false)),
    DocKind.ticket => switch (days) {
        < 0 => (text: formatShortDate(due), tone: DateTone.past),
        0 => (text: 'Today', tone: DateTone.soon),
        1 => (text: 'Tomorrow', tone: DateTone.soon),
        _ => (text: formatShortDate(due), tone: DateTone.plain),
      },
    DocKind.barcode || DocKind.qr => null,
  };
}
