import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:the_app/core/clock.dart';
import 'package:the_app/core/theme.dart';
import 'package:the_app/models/people.dart';
import 'package:the_app/models/people_layout.dart';
import 'package:the_app/pages/hub/people_board.dart';
import 'package:the_app/pages/hub/people_panel.dart';
import 'package:the_app/pages/hub/recipe_page.dart';
import 'package:the_app/providers/people_provider.dart';
import 'package:the_app/widgets/confirm_dialog.dart';

/// People (Round 108, spec `docs/PEOPLE_SPEC.md`): the board on top, and
/// under it a bar (Find, Tidy, Add) or, with someone selected, their
/// panel, taking half the screen.
class PeoplePage extends ConsumerStatefulWidget {
  const PeoplePage({super.key});

  @override
  ConsumerState<PeoplePage> createState() => _PeoplePageState();
}

class _PeoplePageState extends ConsumerState<PeoplePage> {
  final _board = GlobalKey<PeopleBoardState>();

  /// Selected: the panel shows them; a new one (not kept yet) too.
  String? _selected;
  Person? _new;

  PeopleNotifier get _people => ref.read(peopleProvider.notifier);

  void _toast(String message) => ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(SnackBar(content: Text(message)));

  void _select(String? id) {
    FocusManager.instance.primaryFocus?.unfocus();
    setState(() {
      _selected = id;
      _new = null;
    });
  }

  /// A new person, in the middle of what the board shows (nudged right
  /// off anyone there), the panel open to name them.
  void _add() {
    final book = ref.read(peopleProvider);
    var x = book.view.x, y = book.view.y;
    bool taken(double x, double y) => book.people.any((p) =>
        (p.x - x).abs() < BoardSizes.boxWidth &&
        (p.y - y).abs() < BoardSizes.boxHeight);
    for (var i = 0; i < 40 && taken(x, y); i++) {
      x += BoardSizes.columnStep;
    }
    setState(() {
      _new = _people.draft(x: x, y: y);
      _selected = _new!.id;
    });
  }

  Future<void> _tidy() async {
    final ok = await showConfirmDialog(
      context,
      title: 'Tidy everyone?',
      message: 'Tidy moves everyone into a default layout; your own '
          'placing is lost.',
      confirmLabel: 'Tidy',
    );
    // Round 109: no toast after; the dialog already asked.
    if (!ok || !mounted) return;
    _people.tidy();
  }

  /// The board's options (Round 109): center on the main person, their
  /// family highlighted, Tidy.
  Future<void> _options() async {
    final book = ref.read(peopleProvider);
    final choice = await showChoicesSheet(context, null, [
      (Icons.center_focus_strong_outlined, 'Center on main person', 'main'),
      book.highlightFamily
          ? (Icons.highlight_off, 'Stop highlighting family', 'family')
          : (Icons.family_restroom, 'Highlight family', 'family'),
      (Icons.account_tree_outlined, 'Tidy', 'tidy'),
    ]);
    if (!mounted) return;
    switch (choice) {
      case 'main':
        final main = book.main;
        if (main == null) {
          _toast('No main person yet: set one in Edit');
        } else {
          _board.currentState?.centerOn(main.id);
        }
      case 'family':
        if (book.main == null && !book.highlightFamily) {
          _toast('No main person yet: set one in Edit');
        } else {
          _people.setHighlightFamily(!book.highlightFamily);
        }
      case 'tidy':
        await _tidy();
    }
  }

  Future<void> _find() async {
    final id = await pickPerson(context, ref.read(peopleProvider).people,
        title: 'Find');
    if (id == null || !mounted) return;
    _select(id);
    _board.currentState?.centerOn(id);
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final book = ref.watch(peopleProvider);
    final now = ref.watch(clockProvider)();
    final selected = _selected;
    // Kept or new; one deleted (or Undo'ne) closes the panel.
    final person = selected == null
        ? null
        : book.byId(selected) ?? (_new?.id == selected ? _new : null);
    return Scaffold(
      appBar: AppBar(title: const Text('People')),
      body: LayoutBuilder(builder: (context, constraints) {
        final open = person != null;
        final panelHeight = open ? constraints.maxHeight * 0.5 : 64.0;
        return Column(
          children: [
            Expanded(
              child: Stack(
                children: [
                  Positioned.fill(
                    child: PeopleBoard(
                      key: _board,
                      book: book,
                      now: now,
                      selectedId: selected,
                      onTap: (id) {
                        if (id == null && _new != null) return;
                        _select(id);
                      },
                      onMoved: _people.move,
                      onView: _people.setView,
                    ),
                  ),
                  if (book.people.isEmpty)
                    Center(
                      child: Text(
                        'No people yet',
                        key: const Key('peopleEmpty'),
                        style: TextStyle(color: colors.textHint, fontSize: 16),
                      ),
                    ),
                ],
              ),
            ),
            AnimatedContainer(
              duration: const Duration(milliseconds: 250),
              curve: Curves.easeOut,
              height: panelHeight,
              decoration: BoxDecoration(
                color: colors.card,
                border: Border(top: BorderSide(color: colors.divider)),
              ),
              child: open
                  ? PersonPanel(
                      key: ValueKey(person.id),
                      person: person,
                      startEditing: _new?.id == person.id,
                      onSelect: (id) {
                        _select(id);
                        _board.currentState?.centerOn(id);
                      },
                      onClose: () => _select(null),
                    )
                  : _bar(context, book),
            ),
          ],
        );
      }),
    );
  }

  /// Nothing selected: how many, and Find, Tidy, Add (spec 1).
  Widget _bar(BuildContext context, PeopleBook book) {
    final colors = context.colors;
    final n = book.people.length;
    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12),
        child: Row(
          children: [
            Expanded(
              child: Text(
                n == 1 ? '1 person' : '$n people',
                key: const Key('peopleCount'),
                style: TextStyle(color: colors.textSecondary),
              ),
            ),
            IconButton(
              key: const Key('peopleFind'),
              tooltip: 'Find',
              icon: const Icon(Icons.search),
              onPressed: n == 0 ? null : _find,
            ),
            IconButton(
              key: const Key('peopleOptions'),
              tooltip: 'Options',
              icon: const Icon(Icons.more_vert),
              onPressed: n == 0 ? null : _options,
            ),
            const SizedBox(width: 4),
            FilledButton.icon(
              key: const Key('peopleAdd'),
              icon: const Icon(Icons.person_add_alt_1),
              label: const Text('Add'),
              onPressed: _add,
            ),
          ],
        ),
      ),
    );
  }
}
