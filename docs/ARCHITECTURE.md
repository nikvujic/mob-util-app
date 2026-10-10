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
| `pages/<feature>/` | One folder per feature (notes, shop, planner, other, security). A feature never imports another feature — shared UI goes to `widgets/`. | `core`, `models`, `providers`, `widgets` |
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

## Themes and preferences

`AppPalette` (in `core/theme.dart`) holds a theme's colours; `AppTheme.of`
builds the app's look from one, and widgets read it with `context.colors`.
The chosen theme and other look-and-feel choices are `Preferences`, kept
in `preferences.json` on the phone (not in backups). The design checks run
every screen in every theme.

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
