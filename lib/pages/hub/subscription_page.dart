import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:the_app/core/clock.dart';
import 'package:the_app/core/format.dart';
import 'package:the_app/core/id.dart';
import 'package:the_app/core/theme.dart';
import 'package:the_app/models/subscription.dart';
import 'package:the_app/pages/hub/subscriptions.dart';
import 'package:the_app/providers/dates_alerts_provider.dart';
import 'package:the_app/providers/subscriptions_alerts_provider.dart';
import 'package:the_app/providers/subscriptions_provider.dart';
import 'package:the_app/widgets/confirm_dialog.dart';
import 'package:the_app/widgets/pull_down_list.dart';

/// A subscription (Round 79): its name, price (about, currency, every
/// month or year), state and date, card, reminder before and note. Saved
/// as it's changed, once it has a name; a new one left without one is
/// dropped. Delete at the end, asked first, with Undo.
class SubscriptionPage extends ConsumerStatefulWidget {
  /// The subscription to open, or null for a new one.
  final String? subscriptionId;

  const SubscriptionPage({super.key, this.subscriptionId});

  @override
  ConsumerState<SubscriptionPage> createState() => _SubscriptionPageState();
}

class _SubscriptionPageState extends ConsumerState<SubscriptionPage> {
  late Subscription _draft =
      ref.read(subscriptionsProvider).byId(widget.subscriptionId ?? '') ??
          Subscription(
            id: generateId(),
            name: '',
            date: _monthOn(_today),
          );

  late final _name = TextEditingController(text: _draft.name);
  late final _price = TextEditingController(
      text: _draft.price == null ? '' : amountLabel(_draft.price!));
  late final _currency = TextEditingController(text: _draft.currency);
  late final _card = TextEditingController(text: _draft.card);
  late final _note = TextEditingController(text: _draft.note);

  SubscriptionsNotifier get _notifier =>
      ref.read(subscriptionsProvider.notifier);

  DateTime get _today => dayOf(ref.read(clockProvider)());

  /// A month on from [day] (a new one's renewal).
  static DateTime _monthOn(DateTime day) {
    final last = DateTime(day.year, day.month + 2, 0).day;
    return DateTime(day.year, day.month + 1, day.day > last ? last : day.day);
  }

  @override
  void dispose() {
    _name.dispose();
    _price.dispose();
    _currency.dispose();
    _card.dispose();
    _note.dispose();
    super.dispose();
  }

  /// [s] as it is now: kept, and saved once it has a name.
  void _change(Subscription s) {
    setState(() => _draft = s);
    if (s.name.trim().isNotEmpty) _notifier.save(s);
  }

  /// A price typed: "20", "4,99" (a comma as a point); anything else none.
  static double? _parsePrice(String text) {
    final value = double.tryParse(text.trim().replaceAll(',', '.'));
    return value == null || value < 0 ? null : value;
  }

  void _pickState(SubscriptionState state) {
    final s = _draft;
    _change(s.copyWith(
      state: state,
      // One with a day needs one: a month on, if it had none.
      date: () =>
          s.date ??
          (state == SubscriptionState.inactive ? null : _monthOn(_today)),
      // To cancel: a reminder before, unless one's set.
      remindBefore: () => state == SubscriptionState.toCancel
          ? s.remindBefore ?? Subscription.toCancelRemind
          : s.remindBefore,
    ));
  }

  Future<void> _pickDate() async {
    final today = _today;
    final picked = await showDatePicker(
      context: context,
      initialDate: _draft.dateOn(today) ?? today,
      firstDate: DateTime(today.year - 5),
      lastDate: DateTime(today.year + 10, 12, 31),
    );
    if (picked == null || !mounted) return;
    _change(_draft.copyWith(date: () => picked));
  }

  Future<void> _pickCardExpiry() async {
    final today = _today;
    final picked = await showDatePicker(
      context: context,
      initialDate: _draft.cardExpires ?? _monthOn(today),
      firstDate: DateTime(today.year - 5),
      lastDate: DateTime(today.year + 15, 12, 31),
      helpText: 'Card expires',
    );
    if (picked == null || !mounted) return;
    _change(_draft.copyWith(cardExpires: () => picked));
  }

  /// Asked first, then gone, with Undo.
  Future<void> _delete() async {
    final confirmed = await showConfirmDialog(
      context,
      title: 'Delete ${_draft.name.trim()}?',
      confirmLabel: 'Delete',
      destructive: true,
    );
    if (!confirmed || !mounted) return;
    final s = _draft;
    final notifier = _notifier;
    final before = notifier.delete(s.id);
    final messenger = ScaffoldMessenger.of(context);
    Navigator.of(context).pop();
    messenger
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(
        content: Text('${s.name} deleted'),
        action: SnackBarAction(
          label: 'Undo',
          onPressed: () => notifier.replaceAll(before),
        ),
      ));
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
    // Kept in step with the book (an Undo elsewhere, a restore).
    final saved = ref.watch(subscriptionsProvider).byId(_draft.id) != null;
    final s = _draft;
    final colors = context.colors;
    final today = _today;
    final at = s.dateOn(today);
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.subscriptionId == null && !saved
            ? 'New subscription'
            : 'Subscription'),
      ),
      body: PullDownList.children(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
            child: TextField(
              key: const Key('subscriptionName'),
              controller: _name,
              autofocus: widget.subscriptionId == null,
              textCapitalization: TextCapitalization.sentences,
              decoration: const InputDecoration(labelText: 'Name'),
              onChanged: (text) => _change(_draft.copyWith(name: text)),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
            child: Row(
              children: [
                Expanded(
                  flex: 3,
                  child: TextField(
                    key: const Key('subscriptionPrice'),
                    controller: _price,
                    keyboardType:
                        const TextInputType.numberWithOptions(decimal: true),
                    decoration: const InputDecoration(labelText: 'Price'),
                    onChanged: (text) => _change(
                        _draft.copyWith(price: () => _parsePrice(text))),
                  ),
                ),
                const SizedBox(width: 12),
                SizedBox(
                  width: 72,
                  child: TextField(
                    key: const Key('subscriptionCurrency'),
                    controller: _currency,
                    decoration: const InputDecoration(labelText: 'Currency'),
                    onChanged: (text) => _change(_draft.copyWith(
                        currency: text.trim().isEmpty
                            ? Subscription.defaultCurrency
                            : text.trim())),
                  ),
                ),
              ],
            ),
          ),
          SwitchListTile(
            key: const Key('subscriptionAbout'),
            title: const Text('About'),
            subtitle: const Text('Not exactly this (shown with a ~)'),
            value: s.about,
            onChanged: (on) => _change(_draft.copyWith(about: on)),
          ),
          _heading('RENEWS EVERY'),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Wrap(
              spacing: 8,
              children: [
                for (final every in SubscriptionEvery.values)
                  ChoiceChip(
                    key: Key('subscriptionEvery-${every.name}'),
                    label: Text(
                        every == SubscriptionEvery.month ? 'Month' : 'Year'),
                    selected: s.every == every,
                    onSelected: (_) => _change(_draft.copyWith(every: every)),
                  ),
              ],
            ),
          ),
          _heading('STATE'),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Wrap(
              spacing: 8,
              runSpacing: 4,
              children: [
                for (final state in SubscriptionState.values)
                  ChoiceChip(
                    key: Key('subscriptionStateChip-${state.name}'),
                    avatar:
                        CircleAvatar(radius: 6, backgroundColor: state.colour),
                    label: Text(state.label),
                    selected: s.state == state,
                    onSelected: (_) => _pickState(state),
                  ),
              ],
            ),
          ),
          if (s.state != SubscriptionState.inactive && at != null)
            ListTile(
              key: const Key('subscriptionDate'),
              leading: const Icon(Icons.calendar_today),
              title: Text(switch (s.state) {
                SubscriptionState.toCancel => 'Cancel by (it renews)',
                SubscriptionState.cancelled => 'Active until',
                _ => 'Renews on',
              }),
              trailing: Text(formatDay(at, today: today)),
              onTap: _pickDate,
            ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 0),
            child: Text(
              key: const Key('subscriptionStateLine'),
              stateLabel(s, today),
              style: TextStyle(
                  color: subscriptionColour(s, today),
                  fontWeight: FontWeight.w600),
            ),
          ),
          _heading('REMINDER BEFORE'),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Wrap(
              spacing: 8,
              runSpacing: 4,
              children: [
                for (final days in [null, ...Subscription.remindChoices])
                  ChoiceChip(
                    key: Key('subscriptionRemind-${days ?? 'none'}'),
                    label: Text(days == null ? 'None' : beforeLabel(days)),
                    selected: s.remindBefore == days,
                    onSelected: (_) =>
                        _change(_draft.copyWith(remindBefore: () => days)),
                  ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 6, 16, 0),
            child: Text(
              s.state == SubscriptionState.inactive
                  ? 'No reminders while it\'s inactive.'
                  : 'Also on its day at 09:00.',
              style: TextStyle(color: colors.textMuted, fontSize: 12),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
            child: TextField(
              key: const Key('subscriptionCardField'),
              controller: _card,
              decoration: const InputDecoration(
                labelText: 'Card',
                hintText: 'Which card pays it (empty: unknown)',
              ),
              onChanged: (text) => _change(_draft.copyWith(card: text.trim())),
            ),
          ),
          // Round 80 (Nikola): when the card paying it expires.
          ListTile(
            key: const Key('subscriptionCardExpires'),
            leading: const Icon(Icons.credit_card_off_outlined),
            title: const Text('Card expires'),
            subtitle: s.cardRunsOutOn(today)
                ? Text('Before it renews',
                    style: TextStyle(color: colors.danger))
                : null,
            trailing: s.cardExpires == null
                ? Text('Not set', style: TextStyle(color: colors.textMuted))
                : Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(formatDay(s.cardExpires!, today: today)),
                      IconButton(
                        key: const Key('subscriptionCardExpiresClear'),
                        tooltip: 'No expiry date',
                        icon: const Icon(Icons.close),
                        onPressed: () =>
                            _change(_draft.copyWith(cardExpires: () => null)),
                      ),
                    ],
                  ),
            onTap: _pickCardExpiry,
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
            child: TextField(
              key: const Key('subscriptionNoteField'),
              controller: _note,
              minLines: 1,
              maxLines: 6,
              textCapitalization: TextCapitalization.sentences,
              decoration: const InputDecoration(
                labelText: 'Note',
                hintText: 'Real price, payment failed…',
              ),
              onChanged: (text) => _change(_draft.copyWith(note: text)),
            ),
          ),
          if (saved)
            Padding(
              padding: const EdgeInsets.fromLTRB(8, 0, 16, 24),
              child: Align(
                alignment: Alignment.centerLeft,
                child: TextButton.icon(
                  key: const Key('deleteSubscription'),
                  style: TextButton.styleFrom(foregroundColor: colors.danger),
                  icon: const Icon(Icons.delete_outline),
                  label: const Text('Delete subscription'),
                  onPressed: _delete,
                ),
              ),
            ),
        ],
      ),
    );
  }
}
