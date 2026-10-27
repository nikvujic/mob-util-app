import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:the_app/core/clock.dart';
import 'package:the_app/core/format.dart';
import 'package:the_app/core/theme.dart';
import 'package:the_app/models/date_entry.dart';
import 'package:the_app/models/hub_tool.dart';
import 'package:the_app/pages/hub/date_page.dart';
import 'package:the_app/pages/hub/dates_calendar.dart';
import 'package:the_app/pages/hub/page_gate.dart';
import 'package:the_app/providers/dates_alerts_provider.dart';
import 'package:the_app/providers/dates_provider.dart';
import 'package:the_app/providers/preferences_provider.dart';
import 'package:the_app/widgets/bottom_actions.dart';
import 'package:the_app/widgets/pull_down_list.dart';
import 'package:the_app/widgets/selection.dart';

/// A kind of date's colour and icon (Round 57).
extension DateTypeLook on DateType {
  Color get colour => switch (this) {
        DateType.birthday => DateColours.birthday,
        DateType.anniversary => DateColours.anniversary,
        DateType.holiday => DateColours.holiday,
        DateType.event => DateColours.event,
        DateType.other => DateColours.other,
      };

  IconData get icon => switch (this) {
        DateType.birthday => Icons.cake_outlined,
        DateType.anniversary => Icons.favorite_border,
        DateType.holiday => Icons.celebration_outlined,
        DateType.event => Icons.event_outlined,
        DateType.other => Icons.bookmark_border,
      };
}

/// How a holiday's or an event's kind looks (Round 61).
extension DateKindLook on DateKind {
  IconData get icon => switch (this) {
        DateKind.skiing => Icons.downhill_skiing,
        DateKind.beach => Icons.beach_access,
        DateKind.trip => Icons.luggage,
        DateKind.wedding => Icons.favorite,
      };
}

/// Opens one of the Dates page's own pages, behind its lock.
void openDatesPage(BuildContext context, Widget page) {
  Navigator.of(context).push(
    MaterialPageRoute<void>(
      builder: (_) => PageGate(page: HubTool.dates, child: page),
    ),
  );
}

/// Birthdays & dates (Round 57): a month calendar (dots on the days with
/// dates), then what's coming; a tap on a day shows its dates instead
/// (again: back to what's coming). + adds a date (on the day picked).
class DatesPage extends ConsumerStatefulWidget {
  const DatesPage({super.key});

  @override
  ConsumerState<DatesPage> createState() => _DatesPageState();
}

class _DatesPageState extends ConsumerState<DatesPage> {
  DateTime? _picked;

  @override
  void initState() {
    super.initState();
    // Opened: today's green dot (a birthday) is seen (Round 57).
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) ref.read(preferencesProvider.notifier).sawDates(_today);
    });
  }

  DateTime get _today => dayOf(ref.read(clockProvider)());

  @override
  Widget build(BuildContext context) {
    final book = ref.watch(datesProvider);
    final today = _today;
    final colors = context.colors;
    final picked = _picked;
    // Round 72: what's on today, what's coming, and one-off dates gone
    // by; a day picked on the calendar, only its dates.
    final now = picked == null ? book.today(today) : const <DateOn>[];
    final onNow = {for (final d in now) d.date.id};
    final shown = picked == null
        ? [
            for (final d in book.upcoming(today))
              if (!onNow.contains(d.date.id)) d,
          ]
        // Round 59: each from its first day (it may last several).
        : [
            for (final d in book.on(picked))
              (date: d, on: d.startCovering(picked) ?? picked),
          ];
    final past = picked == null ? book.past(today) : const <DateOn>[];
    Widget heading(String text, Key key) => Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
          child: Text(
            key: key,
            text,
            style: TextStyle(
              color: colors.accent,
              fontSize: 12,
              fontWeight: FontWeight.w600,
              letterSpacing: 1,
            ),
          ),
        );
    Widget cards(List<DateOn> items) => SliverList.list(
          children: [
            for (final item in items)
              Padding(
                key: ValueKey('${item.date.id}-${item.on}'),
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 3),
                child: DateCard(
                  date: item.date,
                  on: item.on,
                  today: today,
                  onTap: () =>
                      openDatesPage(context, DatePage(dateId: item.date.id)),
                ),
              ),
          ],
        );
    return Scaffold(
      appBar: AppBar(title: Text(HubTool.dates.label)),
      body: PullDownList(
        bottomSpace: BottomActions.contentClearance,
        slivers: [
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.only(top: 4),
              child: DatesCalendar(
                book: book,
                today: today,
                picked: picked,
                onDay: (day) =>
                    setState(() => _picked = day == _picked ? null : day),
              ),
            ),
          ),
          if (now.isNotEmpty) ...[
            SliverToBoxAdapter(
                child: heading('TODAY', const Key('datesToday'))),
            cards(now),
          ],
          SliverToBoxAdapter(
            child: heading(
              picked == null
                  ? 'UPCOMING'
                  : formatDay(picked, today: today).toUpperCase(),
              const Key('datesHeading'),
            ),
          ),
          if (shown.isEmpty)
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
                child: Text(
                  book.dates.isEmpty
                      ? 'No dates'
                      : picked == null
                          ? 'Nothing in the coming year'
                          : 'Nothing on this day',
                  style: TextStyle(color: colors.textMuted),
                ),
              ),
            ),
          cards(shown),
          if (past.isNotEmpty) ...[
            SliverToBoxAdapter(child: heading('PAST', const Key('datesPast'))),
            cards(past),
          ],
        ],
      ),
      // Round 59: always on the right (as Medicine): opened from the Hub,
      // the tile's side isn't the hand's.
      floatingActionButton: BottomActions(
        side: HandSide.right,
        actions: [
          BottomAction(
            icon: Icons.add,
            tooltip: 'Add a date',
            primary: true,
            onPressed: () =>
                openDatesPage(context, DatePage(on: _picked ?? today)),
          ),
        ],
      ),
    );
  }
}

/// A date on the day [on]: its type's icon in its colour, the title, the
/// day, how soon, and its years.
class DateCard extends StatelessWidget {
  final DateEntry date;
  final DateTime on;
  final DateTime today;
  final VoidCallback onTap;

  const DateCard({
    super.key,
    required this.date,
    required this.on,
    required this.today,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return SelectableCard(
      selected: false,
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 10, 16, 10),
        child: Row(
          children: [
            Container(
              width: 36,
              height: 36,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: date.type.colour,
              ),
              // Round 61: its kind's icon (skis, a heart...), if it has one.
              child: Icon(
                date.kindNow?.icon ?? date.type.icon,
                size: 20,
                color: DateColours.ink,
                semanticLabel: date.kindNow?.label ?? date.type.label,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Flexible(
                        child: Text(
                          date.title,
                          style: TextStyle(
                              color: colors.textPrimary, fontSize: 15),
                        ),
                      ),
                      // Round 108: a person's birthday, from People.
                      if (date.personId != null) ...[
                        const SizedBox(width: 6),
                        Icon(Icons.people_outline,
                            key: Key('datePerson-${date.id}'),
                            size: 15,
                            color: colors.textSecondary),
                      ],
                    ],
                  ),
                  const SizedBox(height: 2),
                  Text(
                    key: Key('dateWhen-${date.id}'),
                    whenLabel(date, on, today),
                    style: TextStyle(color: colors.textSecondary, fontSize: 12),
                  ),
                  // Round 61: all there is to know about it; Round 72: its
                  // reminders on a line of their own, with a bell.
                  if (dateDetails(date, reminders: false) case final details
                      when details.isNotEmpty)
                    Text(
                      key: Key('dateDetails-${date.id}'),
                      details.join('  ·  '),
                      style: TextStyle(color: colors.textMuted, fontSize: 12),
                    ),
                  if (remindersLabel(date) case final reminders?)
                    Row(
                      key: Key('dateReminders-${date.id}'),
                      children: [
                        Icon(Icons.notifications_none,
                            size: 13, color: colors.textMuted),
                        const SizedBox(width: 3),
                        Flexible(
                          child: Text(
                            reminders,
                            style: TextStyle(
                                color: colors.textMuted, fontSize: 12),
                          ),
                        ),
                      ],
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
