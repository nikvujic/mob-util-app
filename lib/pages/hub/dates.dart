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
    final shown = picked == null
        ? book.upcoming(today)
        : [for (final d in book.on(picked)) (date: d, on: picked)];
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
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
              child: Text(
                key: const Key('datesHeading'),
                picked == null
                    ? 'UPCOMING'
                    : formatDay(picked, today: today).toUpperCase(),
                style: TextStyle(
                  color: colors.accent,
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 1,
                ),
              ),
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
          SliverList.list(
            children: [
              for (final item in shown)
                Padding(
                  key: ValueKey(item.date.id),
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
          ),
        ],
      ),
      floatingActionButton: BottomActions(
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
    final years = yearsLabel(date, on);
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
              child: Icon(
                date.type.icon,
                size: 20,
                color: DateColours.ink,
                semanticLabel: date.type.label,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    date.title,
                    style: TextStyle(color: colors.textPrimary, fontSize: 15),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    key: Key('dateWhen-${date.id}'),
                    [
                      formatDay(on, today: today),
                      howSoon(on, today),
                      if (years != null) years,
                    ].join('  ·  '),
                    style: TextStyle(color: colors.textSecondary, fontSize: 12),
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
