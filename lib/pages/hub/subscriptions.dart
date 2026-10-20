import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:the_app/core/clock.dart';
import 'package:the_app/core/format.dart';
import 'package:the_app/core/theme.dart';
import 'package:the_app/models/hub_tool.dart';
import 'package:the_app/models/subscription.dart';
import 'package:the_app/pages/hub/page_gate.dart';
import 'package:the_app/pages/hub/subscription_page.dart';
import 'package:the_app/providers/subscriptions_alerts_provider.dart';
import 'package:the_app/providers/subscriptions_provider.dart';
import 'package:the_app/widgets/bottom_actions.dart';
import 'package:the_app/widgets/pull_down_list.dart';
import 'package:the_app/widgets/selection.dart';

/// A subscription state's colour (Round 79): a card's tint and edge.
extension SubscriptionStateLook on SubscriptionState {
  Color get colour => switch (this) {
        SubscriptionState.active => SubscriptionColours.active,
        SubscriptionState.toCancel => SubscriptionColours.toCancel,
        SubscriptionState.cancelled => SubscriptionColours.cancelled,
        SubscriptionState.inactive => SubscriptionColours.inactive,
      };
}

/// [s]'s colour on [today]: its state's, grey once ended.
Color subscriptionColour(Subscription s, DateTime today) =>
    s.endedOn(today) ? SubscriptionColours.inactive : s.state.colour;

/// Opens a subscription's page, behind the Subscriptions lock.
void openSubscriptionPage(BuildContext context, Widget page) {
  Navigator.of(context).push(
    MaterialPageRoute<void>(
      builder: (_) => PageGate(page: HubTool.subscriptions, child: page),
    ),
  );
}

/// Subscriptions (Round 79, `docs/SUBSCRIPTIONS_SPEC.md`): what the running
/// ones come to a month, then a card for each, two to a row, tinted by
/// its state. A tap opens one; + adds one.
class SubscriptionsPage extends ConsumerWidget {
  const SubscriptionsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final book = ref.watch(subscriptionsProvider);
    final today = dayOf(ref.watch(clockProvider)());
    final colors = context.colors;
    // Round 89 (Nikola): in his order, set by dragging their cards.
    final shown = book.subscriptions;
    final notifier = ref.read(subscriptionsProvider.notifier);
    final totals = book.monthly();
    return Scaffold(
      appBar: AppBar(title: Text(HubTool.subscriptions.label)),
      body: PullDownList(
        bottomSpace: BottomActions.contentClearance,
        slivers: [
          if (totals.isNotEmpty)
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
                child: Text(
                  key: const Key('subscriptionsTotal'),
                  '${totals.map((t) => '${t.about ? '~' : ''}'
                      '${amountLabel(t.amount)}${t.currency}').join(' + ')}'
                  ' a month',
                  style: TextStyle(
                    color: colors.textPrimary,
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),
          if (shown.isEmpty)
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                child: Text(
                  'Add your subscriptions to keep track of what\'s paid '
                  'and when.',
                  style: TextStyle(color: colors.textMuted),
                ),
              ),
            ),
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(10, 8, 10, 8),
            sliver: SliverToBoxAdapter(
              child: _TwoColumns(
                children: [
                  for (final (index, s) in shown.indexed)
                    _MovableCard(
                      key: ValueKey(s.id),
                      id: s.id,
                      // Dragged over another card: takes its place at once.
                      onHover: (dragged) => notifier.moveTo(dragged, index),
                      onMove: (by) => notifier.moveTo(s.id, index + by),
                      canMoveBy: (by) =>
                          index + by >= 0 && index + by < shown.length,
                      card: SubscriptionCard(
                        subscription: s,
                        today: today,
                        onTap: () => openSubscriptionPage(
                            context, SubscriptionPage(subscriptionId: s.id)),
                      ),
                    ),
                ],
              ),
            ),
          ),
        ],
      ),
      floatingActionButton: BottomActions(
        side: HandSide.right,
        actions: [
          BottomAction(
            icon: Icons.add,
            tooltip: 'Add a subscription',
            primary: true,
            onPressed: () =>
                openSubscriptionPage(context, const SubscriptionPage()),
          ),
        ],
      ),
    );
  }
}

/// A card held and dragged to a new place (Round 89, as the Hub's tiles,
/// O8); screen readers get "Move earlier" / "Move later" instead.
class _MovableCard extends StatelessWidget {
  final String id;
  final Widget card;
  final ValueChanged<String> onHover;
  final ValueChanged<int> onMove;
  final bool Function(int by) canMoveBy;

  const _MovableCard({
    super.key,
    required this.id,
    required this.card,
    required this.onHover,
    required this.onMove,
    required this.canMoveBy,
  });

  @override
  Widget build(BuildContext context) {
    // As wide as a card in its column (the page's 10 at each side, 8
    // between them), as tall as it needs.
    final width = (MediaQuery.sizeOf(context).width - 28) / 2;
    return DragTarget<String>(
      onWillAcceptWithDetails: (details) {
        if (details.data != id) onHover(details.data);
        return true;
      },
      builder: (context, _, __) => Semantics(
        customSemanticsActions: {
          if (canMoveBy(-1))
            const CustomSemanticsAction(label: 'Move earlier'): () =>
                onMove(-1),
          if (canMoveBy(1))
            const CustomSemanticsAction(label: 'Move later'): () => onMove(1),
        },
        child: LongPressDraggable<String>(
          data: id,
          onDragStarted: HapticFeedback.selectionClick,
          // The card under the finger, a little lifted.
          feedback: SizedBox(
            width: width,
            child: Opacity(opacity: 0.9, child: card),
          ),
          // Its place stays marked while it moves.
          childWhenDragging: Opacity(opacity: 0.3, child: card),
          child: card,
        ),
      ),
    );
  }
}

/// [children] two to a row, each row as tall as its taller card.
class _TwoColumns extends StatelessWidget {
  final List<Widget> children;

  const _TwoColumns({required this.children});

  @override
  Widget build(BuildContext context) => Column(
        children: [
          for (var i = 0; i < children.length; i += 2)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: IntrinsicHeight(
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Expanded(child: children[i]),
                    const SizedBox(width: 8),
                    Expanded(
                      child: i + 1 < children.length
                          ? children[i + 1]
                          : const SizedBox.shrink(),
                    ),
                  ],
                ),
              ),
            ),
        ],
      );
}

/// A subscription's card (Round 79): tinted by its state (Round 80: a
/// thin outline, its state a pill), its name, price, state and date, card
/// (and when it expires), reminder and note.
class SubscriptionCard extends StatelessWidget {
  final Subscription subscription;
  final DateTime today;
  final VoidCallback onTap;

  /// Its small lines' height, a multiple of their size.
  static const _lineHeight = 1.35;

  const SubscriptionCard({
    super.key,
    required this.subscription,
    required this.today,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final s = subscription;
    final colors = context.colors;
    final colour = subscriptionColour(s, today);
    final small = TextStyle(
      color: colors.textSecondary,
      fontSize: 12,
      height: _lineHeight,
      leadingDistribution: TextLeadingDistribution.even,
    );
    // Round 85 (Nikola): each icon centred on its text's first line (it
    // sat high), whatever the text size.
    final firstLine = MediaQuery.textScalerOf(context).scale(12) * _lineHeight;
    Widget line(IconData icon, Widget text, {Key? key}) => Padding(
          key: key,
          padding: const EdgeInsets.only(top: 3),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SizedBox(
                height: firstLine,
                child: Center(
                  child: Icon(icon, size: 13, color: colors.textMuted),
                ),
              ),
              const SizedBox(width: 4),
              Expanded(child: text),
            ],
          ),
        );
    // Round 80 (Nikola: no thick edge): a plain rounded card, lightly
    // tinted, a thin outline in its state's colour.
    return SelectableCard(
      selected: false,
      color: Color.alphaBlend(colour.withValues(alpha: 0.08), colors.card),
      shape: RoundedRectangleBorder(
        borderRadius: const BorderRadius.all(Radius.circular(12)),
        side: BorderSide(color: colour.withValues(alpha: 0.45)),
      ),
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              s.name,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: colors.textPrimary,
                fontSize: 15,
                fontWeight: FontWeight.w600,
              ),
            ),
            if (priceLabel(s) case final price?)
              Text(
                key: Key('subscriptionPrice-${s.id}'),
                '$price / ${s.every.label}',
                style: TextStyle(color: colors.textPrimary, fontSize: 13),
              ),
            const SizedBox(height: 6),
            // Its state and day, as a small pill in its colour.
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              decoration: BoxDecoration(
                color: colour.withValues(alpha: 0.18),
                borderRadius: const BorderRadius.all(Radius.circular(10)),
              ),
              child: Text(
                key: Key('subscriptionState-${s.id}'),
                stateLabel(s, today),
                style: TextStyle(
                  color: colour,
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            const SizedBox(height: 2),
            line(
              Icons.credit_card,
              // Round 84: its expiry orange a week or less ahead, red gone by.
              switch ((cardExpiryLabel(s, today), s.cardExpiryOn(today))) {
                (final expiry?, final state) when state != CardExpiry.fine =>
                  Text.rich(
                    key: Key('subscriptionCardExpiry-${s.id}'),
                    TextSpan(children: [
                      TextSpan(text: '${s.card.isEmpty ? 'Card' : s.card} · '),
                      TextSpan(
                        // Kept on one line ("expires 10/26").
                        text: expiry.replaceAll(' ', '\u00A0'),
                        style: TextStyle(
                          color: state == CardExpiry.expired
                              ? colors.danger
                              : SubscriptionColours.toCancel,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ]),
                    style: small,
                  ),
                _ => Text(
                    cardLabel(s, today),
                    style: s.card.isEmpty && s.cardExpires == null
                        ? small.copyWith(fontStyle: FontStyle.italic)
                        : small,
                  ),
              },
              key: Key('subscriptionCard-${s.id}'),
            ),
            // Round 80: its card runs out before it renews.
            if (s.cardRunsOutOn(today))
              line(
                Icons.warning_amber_rounded,
                Text(
                  'Card expires before it renews',
                  style: small.copyWith(color: colors.danger),
                ),
                key: Key('subscriptionCardRunsOut-${s.id}'),
              ),
            if (remindLabel(s) case final remind?)
              line(
                Icons.notifications_none,
                Text(remind, style: small),
                key: Key('subscriptionRemind-${s.id}'),
              ),
            if (s.note.trim().isNotEmpty)
              line(
                Icons.notes,
                Text(
                  s.note.trim(),
                  maxLines: 3,
                  overflow: TextOverflow.ellipsis,
                  style: small,
                ),
                key: Key('subscriptionNote-${s.id}'),
              ),
          ],
        ),
      ),
    );
  }
}
