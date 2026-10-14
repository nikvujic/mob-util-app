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
and the session locks as soon as it does. The reset button has to be held
for ten seconds (`resetHold`); a plain tap returns `ResetChoice.tapped`
and blocks the reset (`Preferences.resetBlockedUntil`, phone only) until
the next unlock or a day later.

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

The Hub's pages lock on their own too (O7): `pageLocksProvider`, saved in
the same `settings.json` under `pageLocks` (page ids; a file without them
has none). Every Hub page opens behind a `PageGate` (`pages/hub/`), which
shows the same `LockedScreen` (widgets/) in place of the page while it's
locked and the app is locked, and the page itself once unlocked, so a
notification's target simply waits behind it. A page lock is independent
of the Hub's; either closes it. Backups ask for the password while any
page is closed, a password reset clears locked pages' data
(`SectionData.clearOf`), and medicine reminders leave names out while the
Medicine page is locked.

The note editor gets a locked note's text already decrypted, plus the key
to save it with; it closes (after saving) when the session locks, so
decrypted text never stays on screen after locking.

## Planner timeline

A planner task has a day and, since planner.json version 3, a start and
an end in minutes from midnight; `freeSlots` gives the gaps of a day, and
`PlannerNotifier.addTask` refuses overlaps. `planner.json` has its own
format version (`AppStorage.plannerFormatVersion`), so an older app sets a
newer planner file aside instead of dropping the times.

## Restoring part of a backup (D10, Round 28)

`BackupImporter.restorePart` takes the ids picked, by kind
(`BackupPart`), and adds those things to what's in the app instead of
replacing it: notes on top, list items at the end. Something with an id
still in the app comes back as a copy with a new id and "(Copy)" after
its title (`copyTitle`, Round 30) (a locked note is
opened and sealed again, as its seal names its id); planner tasks and
routines go through their notifiers' `restoreTask` / `restore`, so one
whose time is taken (or that is still there) is left out and counted. A
medicine brings its dose marks (renamed with a copy's id). Locked notes
are re-locked as in a full restore. Undo is a full restore's: the data as
it was before. The page picking them is `pages/backup/restore_part.dart`.

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
in `preferences.json` on the phone (not in backups), as are a Hub page's
settings (Medicine's reminders, follow-up, dot and pause; O12): they're
about this phone, and missing values read as defaults, so the file needs
no version. The design checks run
every screen in every theme.

Custom icons (the Hub tiles) are SVGs in `assets/icons/`, drawn in
black and tinted with the theme's accent when shown (`flutter_svg`), so
they follow every theme like the built-in icons.

## Actions at the bottom

Pages put their actions in `BottomActions` (round buttons as the floating
action button), never in the top bar. `HandTracker` (around the whole app)
notes which half of the screen each touch lands on; when the buttons
appear they take that side and keep it — bottom right in order, or bottom
left mirrored. Content leaves `BottomActions.contentClearance` free below
it, so nothing hides behind them.

## UI conventions (Round 33)

Written down after the to-do page broke several (Nikola's review of
1.4.0). Check a new page against these, and against a page like it
(Shop for lists), before building it.

- **Adding** is the page's main action: a round **+** in the app's add
  button look (the theme's FAB colours: `FloatingActionButton` on the
  main tabs, `BottomAction(primary: true)` elsewhere), at the bottom.
  Not a grey button.
- **Buttons at the bottom** follow the hand (`BottomActions`), except
  where Nikola fixed them to the right (Medicine).
- **Deleting several** (selection, "completed" lists): ask with
  `showDeleteConfirmDialog` ("This cannot be undone."), and then **no
  Undo** after it (the dialog said there's none). Deleting **one** thing
  from its menu: ask or not, but say so with a toast that has **Undo**.
  Deleting something important (an important medicine, all data): type
  DELETE (`showTypeToConfirmDialog`).
- **A list's own action** (e.g. *Delete all* of Completed) is a quiet
  text button on its section's header line, not a red round button.
- **Holding** a row selects it, or edits it where there's no selecting
  (the to-do); done / bought rows can't be edited.
- **Toasts** only say what happened when it isn't plain on screen, and
  carry **Undo** when it can be undone. A new one **replaces** the one
  showing (`hideCurrentSnackBar` first; Round 39), so they never queue
  up; the architecture test checks it.

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

Checkboxes (N15) aren't characters of a font: a checkbox's `[` and mark
are drawn as a square space (an em space and a zero-width one, two for
two), and `CheckboxBoxes`, a render object around the field, paints a
box over each from the field's own layout (like `LineNumbers`).
`CheckboxTaps` ticks one when its box is tapped. Phones' fonts drew ☐ /
☑ at their own size and colour, so the app doesn't rely on them.

## The Introduction note (N16)

Not a stored note: a page (`pages/notes/introduction.dart`) and a tile
at the top of Notes. Its text is `assets/introduction.md` (the guide,
kept up to date with the features) followed by the version's section of
`CHANGELOG.md`, which is bundled too (`core/changelog.dart` finds it;
`data/bundled_text.dart` reads the files). Whether it shows, and whether
it's new, are preferences: `main()` passes the version this start is
(`startedVersionProvider`), and a version not seen before brings it
back. Most tests don't pass one, so their Notes hold only their notes.

## The to-do note (N18, Round 28)

Like the Introduction, a tile at the top of Notes (under it, Round 30)
and a page (`pages/notes/todo.dart`), not a stored note. Its list is
`List<TodoItem>` (`models/todo_item.dart`: id, text, done) in
`todo.json` (version 2; 1 had no `done`) and in backups (`todo`, backup
v15; v16 with `done`), counted and cleared with Notes (`SectionData`).
Like Shop, one ordered list shown as two (to do, *Completed*);
`TodoNotifier.toggle` moves a thing between them, `deleteCompleted`
clears the done ones. The
`todoNote` preference turns the tile on and off (the list stays); like
the Introduction it only shows in the app as started
(`introductionAvailableProvider`), so tests that don't ask see only their
notes.

## Automatic backup (Round 39)

`providers/auto_backup_provider.dart` (`AutoBackup.run`) writes a plain
snapshot (`BackupExporter.snapshot`) once a day into the folder picked,
when `HomeScreen` starts or comes back; not while a section is closed.
The folder is Android's: `data/backup_folder.dart` talks to
`MainActivity` over `the_app/backup_folder` (`pick`: the folder picker,
with a persisted permission; `write`: a new document, then the oldest of
its own files beyond 7 deleted, off the main thread). The folder, its
name, the last time and a failure flag are in `Preferences` (this phone
only). Tests use `FakeBackupFolder`.

## Recipes (Round 42)

`models/recipe.dart`: `Recipe` (name, prep minutes, `RecipeType`, its
`RecipeIngredient`s, the method as Markdown) and the ingredients list
(`IngredientBook` → `IngredientSection` → `Ingredient`), in
`recipes.json` and `ingredients.json` (both version 1) and backups
(v20). A recipe's ingredient keeps the list's id **and** its name, so it
stays whole if the ingredient is deleted or the list isn't restored;
`IngredientsNotifier.rename` renames it in recipes too. Restoring part of
a backup brings a recipe's ingredients the list lacks (`withIngredients`).
*To Shop* (`sendToShop`) reads a quantity as Shop's weight or count
(`shopQuantityOf`), else none. Quantities stay text, written by the
picker (Round 43: `Amount`, `amountText`, `readAmount`; "2", "200 g",
"1½ tsp", "2 tbsp"), so older typed ones still read. The first
ingredients section is pinned on top (`moveSection` and
`deleteSection` leave it). Before a sheet or page opens over a recipe in
edit mode the text fields lose focus: closing it would give the method
its focus back and scroll to its cursor. The pages: `pages/hub/recipes.dart` (the
list), `recipe_page.dart` (view and edit modes; edit saves as it goes,
with its own Undo and Discard), `ingredients.dart` (edit and pick
modes; one `SliverReorderableList` of section names and ingredients, so
a drag can cross sections). The pages opened from Recipes sit in a
`PageGate` too, so a locked Recipes page closes them. While a recipe is
open the screen stays on: `core/screen.dart` → `MainActivity` over
`the_app/screen` (`FLAG_KEEP_SCREEN_ON`, which Android drops in the
background by itself).

## Pip, the pet (Round 34)

`PipLife` (`models/pip_life.dart`: birthday, name) is his lasting data,
in `pip.json` and backups (v17); his age is worked out from his
birthday (`ageOn`). `PipBrain` starts as an `egg` when he isn't
hatched: `tapEgg` counts taps (cracks at 1, 3, 5; the 7th starts
`hatching`), and the room reports the hatch (`onHatched`), which records
his birthday. Letters for him are `core/pixel_font.dart` (3 x 5 glyphs)
drawn by `widgets/pixel_text.dart` on the room's pixel grid.

One system for his world (Round 35), so nothing shows or plays where it
doesn't belong. `core/pip_scene.dart`: a `PipPlace` (the menu's `room`,
Pip Home's `home`), the `DayPart` from the clock (`dayPartAt`), a
`PipBackground` (each gives its sky per part of the day), and `PipProp`s
(stars, moon, sun, clouds; later snow, hats...), each declaring the
places, parts of the day and backgrounds it shows in. `PipScene.at` is
the one place that works out what's showing (Round 38: with the real
moon's phase, `moonPhaseAt`, counted from a known new moon; no moon
drawn at a new moon); `PipRoom` only draws it.
What he does goes through one table too: `mayStart(activity,
animation)` in `pip_brain.dart`, and `play` asks it first (nothing
interrupts the egg, the hatch or coming up). New props and animations
add a row to these tables; tests check the tables, not each screen.

His energy and sleep (Round 37): `core/pip_energy.dart` has the rules
as plain functions of the clock (`PipEnergy.usedBetween`, `levelAt`,
`emptyAt`, `segments`, `nextBattery`; `pipShowAt` says what to show:
awake, fallAsleep, asleep, wakeUp, powerOff, off). Nothing runs in the
background: `PipLife` keeps his energy as a level at a moment, and the
battery due is collected when the app starts or comes back
(`HomeScreen`'s lifecycle) or when he's looked at. `PipRoom` reaches his
life through `PipLink` (`pipLinkProvider`): every second it asks what to
show, makes a change so with `PipBrain.show` (straight away instead of
the ground entrance, or with its animation; false while busy, tried
again), and tells it back (`shown`, so an animation isn't replayed); a
tap gives a battery (`giveBattery`, then `PipBrain.takeBattery`). Tests
override the link with `FakePipLink` unless they ask for the real one.
The brain's new activities all have their row in `mayStart`.

Pip Home (`pages/hub/pip_home.dart`, `HubTool.pip`): its own `PipBrain`
(the menu's stays put) in a `PipRoom` with the menu's `pixel` (Round 38)
and half the page's `height`, and a `PageView` card (status, settings) drawn with
`PixelText` and `widgets/pip_portrait.dart` in `PipColours`' panel
colours, whatever the theme. `HubTool.lockable` and `clearable` keep it
out of page locks and Clear data; the Hub shows it once hatched, moving
tiles by their place in the whole stored order. The background switch is
the `pipBackground` preference: a background's id (`PipBackground.byId`; 1.5.0's on/off reads as Field).

## Notifications page (E3, Round 31)

Settings per page (`models/notify_settings.dart`: `NotifyPage`,
`NotifyStyle` with private, colour and sound) live in `Preferences`, with
the planner's on/off and pause beside Medicine's and Backup's.
`ReminderPlanner` follows them: private pages plan without names (as a
locked section does), `withNotifySettings` drops the planner's while off
or paused and tints each page's reminders (`Reminder.colour` → Android's
notification colour). The history is `NotificationLog`
(`notifications.json`, this phone only): each plan is logged; what was
scheduled and whose time has come, today or yesterday, is the history
(Android doesn't tell an app which were shown). Sounds (E2):
`NotifySound` names a raw resource (`tool/make_notify_sounds.py`); the
scheduler gives each sound its own channel (Android fixes a channel's
sound), and `MainActivity` loads them to play when one is picked. A
tapped entry sets
`pendingTargetProvider`, as a tapped notification does. The page is
`pages/notifications/notifications.dart`, opened from the menu and, by
name (`AppRoutes.notifications`), from Medicine.

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

Medicine reminders (O13) come from `planMedicineReminders`
(`providers/medicine_alerts_provider.dart`) and go through the same
planner, merged with the planner's and capped together; it also runs on
medicine and medicine-setting changes. Each `Reminder` has a kind, and
each kind its own Android channel (`planner-reminders`,
`medicine-reminders`). A locked section's reminders leave out titles and
names.

## Years of medicine history (Round 18)

Marks are found through an index (`MedicineBook.markFor`), made once per
book (a book never changes; a new one comes with each change), so a
lookup stays quick with thousands of marks. The histories build their
days lazily (`SliverList.builder`), and opening a medicine's history at
a day scrolls there in steps until that day is built. `medicine.json`
grows by about 80 bytes a mark: ten years of three doses a day is about
a megabyte, written whole on each change, which is still quick.

## Tapping a notification (Round 19)

Each `Reminder` carries a target (`models/notification_target.dart`):
`planner|day|minutes` or `medicine`, as the notification's payload. The
scheduler reports taps (`opened`) and the notification that started the
app (`takeLaunch`); `notificationOpenerProvider` turns them into
`pendingTargetProvider`. The home screen closes pages on top and goes to
the section; the page itself (Planner, Hub) takes the target when it's
built, which a locked section's isn't, so a target waits until the
section is unlocked.

## Red dots (O13)

A Hub page can ask for attention with a red dot on its tile
(`hubToolDotProvider`, an exhaustive switch over `HubTool` in
`providers/hub_dots_provider.dart`); the Hub tab shows one when any page
does, even while the Hub is locked (it tells nothing of what's inside).
Medicine's dot is a dose due today and not marked, or yesterday's from
22:00 until 02:00 (`medicineDotProvider`).
Nothing changes in the data when a dose comes due, so the home screen
looks again every 30 seconds and when the app comes back.

## Pages as a system (O9)

The tab is the **Hub** throughout (`AppSection.hub`, `HubTool`,
`pages/hub/`). It was "Other" before (O11): `other` in a section lock or in
`layout.json` version 1 is still read as the Hub.

The Hub's pages are listed once, in `models/hub_tool.dart` (`HubTool`).
Each value's `name` is a stable id: it's what's stored, so a page is never
renamed there, only its label. Everything that lists pages reads them from
there, and a new page has to be added to a few exhaustive switches, so it
doesn't compile until it's complete:

- `pages/hub/tools.dart` — its icon and page;
- `providers/hub_dots_provider.dart` — whether its tile shows a red dot;
- `providers/section_data_provider.dart` — how many things it holds and
  how to clear them (Settings → Clear data lists the Hub page by page; a
  locked Hub is cleared page by page on a password reset).

Where pages go is `PageLayout` (`layout.json`, its own version): the
Hub's order as page ids. Unknown ids are dropped and pages missing from it are
added at the end, so a new page needs no change to stored data. It's a
setting, like the theme, so it isn't in backups. The quick-access menu,
sections in the Hub (O10) are meant to be more fields
of the layout and lists of the same ids, not a rework. Each page keeps its
data in its own file and, in backups, under its own key.


## Sounds

The app plays its own short sounds through Android's SoundPool
(`MainActivity.kt`, channel `the_app/sound`; `core/sound.dart`): the
counters' click, the medicine tracker's "taken" gulp, and the Placard's
inflating and pop (the inflating one is stopped when the finger lifts).
They're WAV files in `android/app/src/main/res/raw/`, generated by
`tool/make_done_sound.py` (the gulp: two low rising bloops) and
`tool/make_placard_sounds.py`. Played as game audio,
so they follow the media volume, the click at a third of full.

The weekly backup reminder (D9) lives in `Preferences` (`lastBackupAt`,
set by a saved export; `backupCountFrom`, the first start, while there's
none; `backupReminder`). `backupDueProvider` drives the dots: the home
screen hands it to every section's `MainAppBar` through `MenuDot` (an
inherited widget, so widgets/ stays free of providers) and re-reads it
with the medicine dot. `planBackupReminders` adds its notifications
(their own Android channel, `backup-reminders`) to the reminder plan; a
`BackupTarget` opens Backup on top of whatever is shown.

Reliability (E1): medicine doses due at the same moment are merged into
one reminder in `planMedicineReminders` (Android rate-limits exact
alarms that follow each other while idle). `withKeepGoing` caps the plan
at `maxReminders` and, when it would run on past what's planned, adds a
`ReminderKind.notice` the evening before the last one asking to open the
app. `notificationsAllowedProvider` (re-read on resume) shows Settings'
warning when notifications are blocked.

Failed saves (D6): each `JsonFileStore` keeps the document it couldn't
write and a `failing` flag; `AppStorage.saveFailing` is true while any
store fails, `retryFailed` writes the kept documents again (the home
screen calls it when the app comes back), and the home screen says when
saving starts failing and when it works again (`saveFailingProvider`).

Important medicines (Round 24): `Medicine.important` (medicine.json v4,
backup v14). The red dot (`doseDue`) counts only important medicines.
Ticking one's dose goes through `showHoldToTake` (`pages/hub/
hold_to_take.dart`): a 5-second `AnimationController` drives a painted
glass, the native `fill` sound (`tool/make_fill_sound.py`) and haptic
ticks; letting go reverses it.

Pip (Round 25), the mascot: `widgets/pip.dart` draws him standing (his
room's idle frame, `widgets/pip_sprites.dart`), each grid pixel snapped
to whole device pixels, in his own colours; the menu's header shows him.
The launcher icon (`tool/make_icon.py`) holds a copy of the same frame
and colours; `test/widgets/pip_sprites_test.dart` keeps them equal, so
after changing his look, update the tool's `SPRITE` and run it.

Pip's room (Round 26): `core/pip_brain.dart` is his behaviour, plain
Dart (spawning, standing, walking; where he is, his frame, squash and
stretch), stepped with the time gone by and a `Random` (seeded in
tests). `widgets/pip_room.dart` draws the field and his frames
(`widgets/pip_sprites.dart`: a 20 x 19 grid composed from head, a
14 x 9 screen with his face, and legs) with a `Ticker` while
the menu is open; `pipBrainProvider` keeps one brain for the app's run,
so he spawns only the first time. `pipAnimatesProvider` is off in tests
(an endless animation never settles) except Pip's own.

Stuck Shift (Round 26): Flutter's text fields extend the selection on a
tap while Shift is held, and some phone keyboards leave Shift "held".
`app/stuck_shift.dart` wraps the app's pointer input (installed in
`main`): a touch going down first sends a synthetic key-up for a held
Shift.

More formats (N17, Round 27): `markdownRuns` also reads inline code,
highlights, quotes, dividers and ``` blocks (a block's lines are code,
nothing else). Drawn by `MarkdownEditingController` as styles, and by
`RenderCheckboxBoxes` around the text: code panels under it, quote bars
and divider lines over it (the `>` and `---` keep their characters,
unseen, so positions never move). The format bar's edits are pure
functions in `core/markdown.dart` (`toggleWrap`, `toggleLines`,
`cycleHeading`, `toggleCodeBlock`, `insertDivider`) returning the new text
and selection; `widgets/format_bar.dart` is the row, in `BottomActions`'
`bar` slot.
