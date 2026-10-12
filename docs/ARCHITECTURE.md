# Architecture

The code in `lib/` is split into layers. Each layer may only depend on the
layers listed for it, so UI never leaks into data code, features stay
independent, and shared pieces stay reusable.
`test/architecture_test.dart` enforces these rules on every test run (and so
in CI) — a change that breaks them fails the build.

```
main.dart ──► app/ ──► pages/<feature>/ ──► widgets/
                │            │
                │            ▼
                └──────► providers/ ──► data/ ──► models/
                                                     ▲
                core/  (used by every layer except models)
```

| Layer | What lives there | May import |
|-------|------------------|------------|
| `main.dart` | Startup: load storage and app info, then run the app with them. | `app`, `core`, `data` |
| `app/` | The app shell: `MyApp`, home screen, bottom navigation, the menu. | `core`, `models`, `providers`, `pages`, `widgets` |
| `pages/<feature>/` | One folder per feature (notes, shop, planner, other, security, backup, settings). A feature never imports another feature — shared UI goes to `widgets/`. | `core`, `models`, `providers`, `widgets` |
| `widgets/` | Reusable, feature-agnostic UI: dialogs, selection mode, empty state, app bars, input sheet. | `core` |
| `providers/` | App state (Riverpod notifiers): the rules for changing notes, shop items, … Every change is saved through `data/`. | `core`, `data`, `models` |
| `data/` | Storage: reading and writing files. The only place that touches `dart:io`. | `core`, `models` |
| `models/` | Plain immutable value classes with JSON conversion. No Flutter, no imports at all. | — |
| `core/` | App-wide basics: theme (the only file allowed to define colors), ids, app info, encryption (`crypto.dart`). | — |

## Other rules (also enforced)

- Imports are always `package:the_app/...`, never relative.
- Colors come from the active theme's palette (`context.colors`, an
  `AppPalette` defined in `core/theme.dart`); no `Colors.*` (except
  `Colors.transparent`) or `Color(0x…)` anywhere else, so every screen
  follows the chosen theme.
- No `print()`; use `debugPrint`.
- A feature that opens another feature's page does it by route name
  (`core/routes.dart`); `app/` maps names to pages, so features still never
  import each other.
- Scrolling lists in `app/` and `pages/` are `PullDownList` (reach mode),
  not plain `ListView`s; the few exceptions are listed with a reason in
  the architecture test.
- Platform plugins are confined: `path_provider` and `file_picker` to
  `data/` (behind small interfaces like `BackupFiles`, so tests can fake
  them), `package_info_plus` to `main.dart`, `cryptography` to
  `core/crypto.dart` (the app's only encryption code).

## Design checks

`test/design_test.dart` checks every screen against Android's
accessibility guidelines — tap targets of at least 48×48 dp, every tap
target labelled for screen readers, text contrast — and pins what the
requirements ask of the layout (e.g. shop rows are exactly one tap target
high and ≥20% smaller than note rows). Conventions it relies on:

- List rows are one screen-reader element: the content is the label, state
  (checked, selected) is a semantic flag. Drag handles and selection ticks
  are decorative (`ExcludeSemantics`); reordering is offered to screen
  readers as the list's "Move up/down" actions.
- Highlights (selection) never change a row's size.
- Layouts must survive a 2× system font size without overflowing.

## Encryption keys

`core/crypto.dart` is the only encryption code. Keys form a small
hierarchy (envelope encryption):

- **Password key** — derived from the master password with Argon2id
  (parameters and salt stored in `security.json`). Never stored.
- **Data key** — random; encrypts locked notes. Stored only *wrapped*
  (sealed) with the password key, next to a check value for the password.
  Changing the password re-wraps this one key in a single atomic write.
- **Session** (`providers/session_provider.dart`) holds both keys in
  memory while unlocked; nothing unwrapped is ever written to disk.
  `app/privacy_curtain.dart` covers the whole app as soon as it starts
  leaving while unlocked (inactive or hidden), so the frame Android keeps
  for recent apps and for coming back shows nothing protected; it lifts
  on resume, after the session has decided whether to auto-lock (L8).

Every sealed box is bound to a purpose string (`context`), so data sealed
for one purpose can't be passed off as another. A locked note's content is
sealed for that note's id, so it can't be moved into a different note; its
title stays plain text so the list can show it. Only `NotesNotifier`
seals and opens note content, and plain content of a locked note is never
accepted (`updateNote` refuses it). Its encrypted changes run one at a
time, in order, and one still pending is dropped if the note is restored
meanwhile (Discard), so it can't undo that.

Removing the master password first unlocks every locked note in one
write and waits until it's on disk; only then is the password removed. If
any note doesn't open, nothing changes. A crash at any point leaves either
the password or plain notes, never locked notes without a password.

**Fingerprint unlock** (`providers/fingerprint_provider.dart`, L6) keeps
the *password key* in Android's keystore (`data/fingerprint_vault.dart`,
via `biometric_storage`): encrypted with a keystore key that needs a
fingerprint for every use (strong biometrics only) and is voided when a
new fingerprint is enrolled. A fingerprint gives back the password key,
which unlocks the session exactly as typing the password would (it must
unwrap the data key). The password itself is never stored. The salt of
the password the key belongs to is noted in `preferences.json` (phone
only, not in backups); when the master password changes, is removed or
reset, the stored key is cleared. Tests use a fake keystore.

A forgotten password is reset (`providers/password_reset_provider.dart`)
the same way round: locked notes and the content of locked sections are
deleted and on disk first, then the password goes. Section locks clear
and the session locks as soon as it does.

What a section holds as a whole (the planner: tasks, routines and
reminders) is counted and cleared in one place,
`providers/section_data_provider.dart`, used by that reset and by
Settings → Clear data (D7), which saves before saying it's done.

Backups keep locked notes sealed and carry the master password record
(as in `security.json`) that holds their key. Restoring on a phone without
a master password adopts that record (saved before the notes); otherwise
the notes are opened with this phone's key or the backup's, and re-sealed
under this phone's.

Section locks (`settings.json`) are a gate in the app shell, not
encryption: `SectionGate` shows a lock screen instead of the section's
page while the section is locked and the app is locked, and the home
screen closes anything open on top of it when that happens.

The note editor gets a locked note's text already decrypted, plus the key
to save it with; it closes (after saving) when the session locks, so
decrypted text never stays on screen after locking.

## Planner timeline

A planner task has a day and, since planner.json version 3, a start and
an end in minutes from midnight; `freeSlots` gives the gaps of a day, and
`PlannerNotifier.addTask` refuses overlaps. `planner.json` has its own
format version (`AppStorage.plannerFormatVersion`), so an older app sets a
newer planner file aside instead of dropping the times.

## Android's own backup

The app keeps Android's Auto Backup on (the default, decided with Nikola):
if Google backup is on in the phone's settings, Android copies the app's
files to a hidden area of the Google account, end-to-end encrypted with
the phone's screen lock (Android 9+), and puts them back when the app is
installed again. It's a safety net beside the app's own export. The
fingerprint key doesn't move with it (it lives in the phone's keystore);
fingerprint unlock is just turned on again.

## Themes and preferences

`AppPalette` (in `core/theme.dart`) holds a theme's colours; `AppTheme.of`
builds the app's look from one, and widgets read it with `context.colors`.
The chosen theme and other look-and-feel choices are `Preferences`, kept
in `preferences.json` on the phone (not in backups). The design checks run
every screen in every theme.

Custom icons (the Other tiles) are SVGs in `assets/icons/`, drawn in
black and tinted with the theme's accent when shown (`flutter_svg`), so
they follow every theme like the built-in icons.

## Actions at the bottom

Pages put their actions in `BottomActions` (round buttons as the floating
action button), never in the top bar. `HandTracker` (around the whole app)
notes which half of the screen each touch lands on; when the buttons
appear they take that side and keep it — bottom right in order, or bottom
left mirrored. Content leaves `BottomActions.contentClearance` free below
it, so nothing hides behind them.

## Back button

The home screen owns the only back handler for the main sections (Flutter
calls every back callback on a screen, so several would all fire). It
closes an open menu first, then offers back to `BackHandlers` registered by
pages (selection mode uses `SelectionPopScope`), and only then runs the
"press back again to exit" logic.

## State and persistence

- Each feature has one `StateNotifier` holding an immutable list; pages read
  it with `ref.watch` and change it only through the notifier's methods.
- Notifiers save every new state through `AppStorage` (one JSON file per
  feature, crash-safe writes). Storage is loaded once in `main()` and
  injected with a provider override; tests inject in-memory storage.
- Slow work (key derivation) runs in a background isolate. Widget tests
  run it for real with `tester.runAsync`, via the `settleBusy` helper.

## Markdown in notes (N9)

Notes are stored as plain text; Markdown is only *shown*. `core/markdown.dart`
splits a note's text into styled runs (headings, list markers, bold,
italic, strike; the symbols themselves as faint markers) and works out
list continuation on Enter. `widgets/markdown_text.dart` applies it: a
`TextEditingController` whose `buildTextSpan` styles the runs (the text is
never changed, so the cursor, undo and saving work as for plain text), and
an input formatter for Enter in lists. Formatting symbols are drawn as
nothing (no width, transparent) except on the lines the cursor is on
while the field has focus, so the note reads clean but stays editable.

## Planner routines (P8)

A routine (`models/routine.dart`) is one stored item — times, weekdays,
from / until — never copies on days. `routines.json` holds the routines
and a `RoutineDay` per routine and day where something happened (ticked
off or skipped). A day's view is computed: its one-off tasks plus
`routinesOn(day, book)` (`providers/routines_provider.dart`), which
leaves out skipped routines.

Two kinds, two rules (P12): `PlannerNotifier` keeps tasks from
overlapping each other, `RoutinesNotifier` keeps routines from
overlapping each other on any day they could share; a task and a routine
may overlap. So at most one of each is at any moment, and the timeline
(`pages/planner/timeline.dart`) cuts each block into pieces
(`blockPieces`): full width alone, half width while the other kind is
there (task left, routine right). A block is one `SelectableCard` whose
`shape` (`_PiecesBorder`) is the union of its pieces, rounded on outer
corners only; the shape also limits where it takes taps. Free time is
time with neither; a task's room (`PlannerNotifier.roomFor` / `freeOn`)
only counts tasks, and the add sheet switches to the routines' room
while Repeat is on.

## The timeline's scale (Round 10)

`TimeScale` (`pages/planner/timeline.dart`) maps minutes to heights: an
hour is `hourHeight`, but every block gets at least `minBlockHeight` (a
touch target), so a short block stretches the stretch of the day it's in
(that hour is taller) instead of being squeezed. Everything on the
timeline (hour lines, free time, blocks and their pieces, reminders)
goes through the same scale.

## Planner reminders (P14)

A reminder (`models/planner_pin.dart`, "pin" in code) is a title at a time
on one day, with no end, kept in `pins.json` by `PinsNotifier`. It isn't
a block: it takes no time, so free time and the overlap rules ignore it,
and `PlannerTimeline` draws it last (`TimelinePin`), over everything, one
touch target high, cascading when two would cover each
other. Ticking it off deletes it (`remove` / `restore` for undo).
`planReminders` notifies at its time.

## Reminders (P10)

`planReminders` (`providers/reminders_provider.dart`) works out, purely
from tasks and routines, the reminders due in the next 14 days.
`ReminderPlanner` runs it again on every planner, routine or lock change
and when the app comes back, and hands the result to a
`ReminderScheduler` (`data/reminder_scheduler.dart`): on the phone,
flutter_local_notifications with exact alarms, which survive a restart;
in tests, a fake that records them. Scheduling everything anew each time
keeps it simple and keeps routines reminding indefinitely.

## Pages as a system (O9)

The tab users see as **Hub** is `other` in the code and in stored data
(`AppSection.other`, `OtherTool`, `layout.json`'s `other`): only its label
changed, so nothing saved had to.

Other's pages are listed once, in `models/other_tool.dart` (`OtherTool`).
Each value's `name` is a stable id: it's what's stored, so a page is never
renamed there, only its label. Everything that lists pages reads them from
there, and a new page has to be added to a few exhaustive switches, so it
doesn't compile until it's complete:

- `pages/other/tools.dart` — its icon and page;
- `providers/section_data_provider.dart` — how many things it holds and
  how to clear them (Settings → Clear data lists Other page by page; a
  locked Other section is cleared page by page on a password reset).

Where pages go is `PageLayout` (`layout.json`, its own version): Other's
order as page ids. Unknown ids are dropped and pages missing from it are
added at the end, so a new page needs no change to stored data. It's a
setting, like the theme, so it isn't in backups. The quick-access menu,
sections in Other and per-page locks (O10, O7) are meant to be more fields
of the layout and lists of the same ids, not a rework. Each page keeps its
data in its own file and, in backups, under its own key.

