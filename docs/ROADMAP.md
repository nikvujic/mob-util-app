# Roadmap

The plan for getting from today's app to everything in
[REQUIREMENTS.md](REQUIREMENTS.md), as a sequence of **small, complete steps**.
Each step is one focused change that is finished on its own: code, tests,
`flutter analyze` clean, and the requirement statuses updated in the same
commit.

Legend: `[x]` done · `[~]` in progress · `[ ]` to do

## Way of working

- One step = one small, reviewable commit (occasionally two). No
  half-finished features on `main`.
- Every step adds or updates tests; CI must be green before moving on.
- Data safety first: anything touching storage, export/import or encryption
  gets round-trip tests with real files, including failure cases.
- Commits are authored by Nikola Vujic, unsigned, pushed to `main`.
- Every step that changes the app ends with a release: version bump,
  `CHANGELOG.md` entry, then the Release workflow → GitHub Release with
  the APK ([RELEASING.md](RELEASING.md)).
- Release signing key is set up (2026-10-08); v0.10.0 is the first
  release, installed and working on the phone.
- **Releases are started by Nikola** (Actions → Release → Run workflow).
  Steps end with the version bump and changelog pushed; Claude doesn't
  start releases unless asked.
- After a group of steps, a **device checkpoint**: build the APK and try it on
  the phone (listed below where it matters most).

## Done

- [x] Notes list with editable title/body, custom order, select & delete (N1–N4)
- [x] Shop with To buy / Items lists, drag reorder, select & delete (S1–S3)
- [x] Shared widgets: confirm dialog, selection mode, empty state, input sheet (G3–G5)
- [x] Local persistence with crash-safe writes and autosave (G6)

## Next steps

### Foundation

1. [x] **CI** — GitHub Actions workflow running format check,
   `flutter analyze` and `flutter test` on Flutter 3.29.3 for every push. Gives every later step an
   automatic check (and a green tick on GitHub).
2. [x] **Android only (G9)** — remove the web/iOS/macOS/Linux/Windows
   platform folders and the web code path; stop committing Android native
   build output (`android/app/.cxx/`) and ignore it.
3. [x] **Navigation skeleton (G1, G7, G8)** — rename To Do → Planner, add the
   Other tab (empty), add a menu (hamburger) with a Security page and the
   app version. Widget
   tests pin down back-button behavior: back on a main section exits; back
   from a menu page / a note returns to where we were.

### Notes & Shop polish

4. [x] **Discard changes in a note (N5)** — snapshot when the editor opens,
   undo action restores it (or removes a just-created note), with confirm.
   - [x] Back asks *Save changes?* (Yes/No, outside tap = Yes); ↶ only
     for existing notes and keeps you in the editor (N5, N5a).
5. [x] **Compact shop rows (S4)** — plus architecture rules (test +
   `ARCHITECTURE.md`) and design/accessibility tests for every screen (G10).

### Backup & privacy — device checkpoint after step 10

Encrypted backups use the master password, so the security basics come
before import (decided 2026-10-08), and import is written once for both
kinds of file.

6. [x] **Export (D1, D4)** — one versioned JSON file with all data, saved via
   the Android file picker / share sheet.
7. [x] **Crypto core (L2, L3)** — Argon2id key derivation (parameters stored
   with the data), AES-256-GCM seal/open with context binding; checked
   against OpenSSL-generated known answers. No UI.
8. [x] **Master password (L1)** — Menu → Security: set / change / remove;
   only a verifier is stored. Warns that a forgotten password can't be
   recovered.
9. [x] **Plain or encrypted export (D2a)** — choice on export; encrypted
   needs the master password (asks to confirm it until session unlock
   exists).
10. [x] **Import (D2, D2a)** — validate, preview counts, confirm, replace;
    asks for the master password for encrypted files. Invalid files never
    touch current data.

### From the first phone test (2026-10-08)

Small fixes, not urgent; can go out together as one polish release.

- [x] **New note appears in the list before the editor slides in**
  (visible shift). Create the note so it's saved immediately, but only
  show it in the list once the editor's transition has finished (N2).
- [x] **Save dialog redesign (N5):** clear title / content / actions
  layout, more square; real buttons **Discard** and **Save** instead of
  text links; the content explains that edits are saved automatically.
- [x] **Double back to exit (G7):** on a main section, the first back
  shows "Press back again to exit"; a second back within ~2 s closes the
  app.

### Locking

11. [x] **Session unlock (L4)** — unlock once; stays unlocked through short
    trips to other apps; locks after 5 min in the background, on app close,
    or "Lock now". Encrypted export then needs no typing while unlocked.
12. [x] **Lock notes (N6, N7, D3)** — in sub-steps. Design: *envelope
    encryption* — a random **data key** encrypts locked notes; the master
    password only wraps that key (in `security.json`). Changing the
    password re-wraps one key in one atomic write, so a crash can never
    leave notes split between two passwords; backups can carry the wrapped
    key. Storage format becomes v2 in 12b (sealed note content depends on
    the data key); v2 storage fixtures are frozen there, v2 backup
    fixtures in 12e (same release, so no v2 backup exists before).
    - [x] 12a Key hierarchy: data key wrapped by the master password;
      existing master passwords get one on first unlock; changing the
      password keeps the same data key. No UI change. (The optional
      `dataKey` field is safe under format v1: nothing depends on it yet.)
    - [x] 12b Note format v2 (sealed content) + lock/unlock/read logic;
      v2 fixtures; v1 still read. A locked note keeps its title in plain
      text; its content is sealed for that note only (can't be swapped
      into another). No UI change.
    - [x] 12c UI: lock icon in the list, lock/unlock (editor menu and
      selection mode), unlock prompt on open, set-up route if no master
      password. Setting the master password also unlocks the app; an open
      locked note is saved and closed when the app locks.
    - [x] 12d Removing the master password unlocks all locked notes first
      (the form says how many). All are opened before anything changes and
      saved before the password goes; if one doesn't open, nothing changes.
    - [x] 12e Backups with locked notes: carry the wrapped data key;
      import re-seals under this phone's key (or adopts it if none).
      v2 backup fixtures frozen.

- [x] ~~After 12e: **explain to Nikola in plain terms** how locked notes~~
  Dropped (Round 30): not needed any more.
  
  work (what's encrypted, what the password protects, what backups
  carry) — he asked for it.

### One-handed use & touch polish (from the second phone test)

- [x] **Bug:** closing the keyboard (its back key) while adding shop items
  left the add field hanging over a dimmed page; the sheet now closes
  with the keyboard.

After locked notes, before section locks.

- [x] **Bigger drag-handle grab area** — keep the icon size, but the whole
  area around it (full row height, 80 dp wide, reaching left of the
  icon) starts a drag.
- [x] **Ripple effects** — review: they look off (e.g. clipping, colour,
  ripple under selection highlight); make them consistent. Ripples were
  switched off app-wide but some widgets drew their own; now one plain
  ripple (white 12%) everywhere, clipped to the card; the shop checkbox
  only shows state, so the whole row ripples as one.
- [x] **Selection actions at the bottom right** — in selection mode, *select
  all* and *delete* become two buttons side by side in the lower right
  (thumb reach), with extra bottom space so the list can scroll clear of
  them.
- [x] **Pull the list down for one-handed reach** (Notes, Shop; others
  later) — the list can be dragged further down than its top, into an
  empty space, so the top items come within thumb reach; it always opens
  at the top and springs back when scrolled back up. Needs a prototype to
  get the feel right. *Prototype in (`PullDownList`): up to 40% of the
  screen height; the list stays where it's let go. Tune on the phone.*
- [x] **Shop: new items at the end of *To buy*** (S5) instead of the top,
  so the list keeps the order things were added in. Items moved back
  from *Items* go to the end too.

### New sections

13. [x] **Section locks (L5)** — Security switches to lock whole sections.
    A locked section shows a lock screen while the app is locked (it hides
    the section; it doesn't encrypt it). Turning a lock off needs the app
    unlocked; removing the master password removes the locks; backups
    need unlocking while a section is locked.
14. [x] **Planner v1 (P1, P2)** — a to-do list per day with a day strip at
    the bottom (Nikola's shape); included in backups (backup format 3).
15. [x] **Other → Counters (O1, O2).** Included in backups (format 3).

### Round 3 — feedback from using 0.12 (2026-10-09)

Nikola's notes, grouped. Proposed order: small fixes first, then the
patterns other work builds on (G11, themes), then the bigger features.

**A. Quick fixes**
- [x] **U4 Snap back to the top** when scrolling up leaves only a little
  pulled-down space (all pull-down lists: Notes, Shop, …).
- [x] **U5 Drag area a little smaller** (Notes, Shop): 80 → 72 dp.
- [x] **No ripples at all** — the touch ripple feels obstructive; remove
  it everywhere (replaces the "one plain ripple" decision).
- [x] **G13 Going to a section resets its pulled-down space.** (Coming
  back from a note keeps it.)
- [x] **P5 Remove the planner's Today button.**
- [x] **Planner day strip: fast swipes travel far** (it now moves about
  one day per swipe); needed once there's no Today button, to swing back
  to the start. Together with **P6** (greyed past, starting at the oldest
  unfinished task), since that defines where "the start" is.

**B. Actions at the bottom, on the hand's side (G11)**
- [x] Shared bottom action buttons that sit bottom-right or bottom-left
  depending on which half of the screen was tapped; no action buttons in
  top bars except ☰ (← back stays at the top: navigation, with the back
  gesture as alternative).
- [x] **N10 Note editor:** Discard (new icon, not ↶) and ⋮ move to the
  bottom; the text scrolls clear of them.
- [x] Apply the side rule to the selection actions too: their side
  follows the side of the long-press. Selection's ✕ moves down too, as
  the last button. Switching sides mirrors both the side and the order
  of the buttons.

**C. Themes (G12)**
- [x] Colours come from the theme (not fixed constants); design checks
  run on every theme.
- [x] Menu → **Themes** page: Green (original), Black (true black for
  OLED), Clay (warm greys + clay orange, in the spirit of Claude Code).
  No light theme (Nikola).

**D. Other: tiles, sounds, a new tool**
- [x] **O3** Tools as icon tiles from the bottom right.
- [x] **U6** Counters: vibration + click sound on − / +, switch in
  Menu → Settings. The click is Android's touch sound (follows the
  phone's *Touch sounds* setting); a bundled sound could come later.
- [x] **O4** "Džoni što ćutiš?" page (landscape, big text, hold to
  count with shake + pop). The count is kept in preferences.json and
  travels in backups (format 4).
  Later: a hidden way to reset or set the count.

**E. Planner: time blocks**
- [x] **P7** Time blocks: each day is a timeline 00:00–24:00; tasks are
  blocks with a checkbox in the top-right corner; tapping free time adds
  a task there (start = start of the free time, end 1 h later or a quick
  option / the end of the free time / a picked time). No overlaps, no +
  button. Old tasks without times show above the timeline, marked, to
  delete. planner.json version 3, backups version 4 (with the Džoni
  count).

**Answers so far (2026-10-09):**
- G11: yes, the side rule also applies to selection actions, and ✕ is
  added to them as the last action. Switching sides mirrors side and
  order.
- U6: on/off with a switch on a Settings page (Menu → Settings).
- G12: Green, Black, and one like Claude Code's look; no light theme.
- O4: one count per hold; the count is saved for good. Later: a hidden
  way to reset or set the count.
- P7: the timeline covers the whole day, 00:00–24:00. **No + button:**
  a new day is one big free slot; tapping a free slot adds a task in it
  (start = start of that slot, end = 1 h later or a quick option, up to
  the end of the slot). Adding 08:00–09:00 to an empty day leaves three
  blocks: free, the task, free; the next task goes into one of the free
  slots. **Blocks never overlap.**

**Still open:**


### Round 4 — after 0.13 (2026-10-10)

- [x] **Planner: edit a block** — tap it to change title and times (within
  the free time around it, up to its neighbours); overlaps refused.
- [x] **Planner: smarter default start** — on today, in free time that's
  going on now, a new task starts at the next full hour.
- [x] **Pull-down reach, rethought (replaces U3/U4 behaviour):** a *reach
  mode* rather than a free scroll area. Entering: only by pulling down a
  list that's already at its top, with a new gesture (scrolling up from
  further down stops at the normal top). In reach mode the list is
  shifted down so the first rows are in thumb reach; any scroll the other
  way leaves the mode and snaps fully back to the top — no half-way
  positions. A small pull springs back. The shift is half of before (20%
  of the screen height). (Nikola, after using 0.13: the old snap felt
  odd, sometimes didn't snap, and sometimes snapped instead of
  scrolling.)
- [x] **Planner day strip: live preview** — the day in the middle is
  selected while swiping (header and timeline follow), not only on
  letting go; a fixed frame marks the middle slot (Nikola: "fast and
  dynamic", smoother like before).
- [x] **Planner: 00:00 label cut off** — small inset above the timeline.
- [x] **Theme switch flashed the old theme** on the next page: the theme
  change was animated (200 ms) and the palette switched half-way; now it
  switches at once.
- [x] **Clay closer to the Claude app** (Nikola: too light, orange off):
  Anthropic's brand colours — background #141413, accent #C96442, text
  #FAF9F5 / #B0AEA5. Tune with a screenshot if still off.
- [x] **Reach mode everywhere it makes sense** (G14): the menu, Security,
  Backup, Themes, Settings; an architecture rule flags plain scrolling
  lists in pages, with a short list of explained exceptions.
- [x] **Swipe right along the bottom bar opens the menu** (G15).
- [x] **Forgot master password → reset** (L7): deletes locked notes and
  the content of locked sections (Nikola chose this, so a section lock
  can't be bypassed by resetting); everything else stays.
- [x] **Notes: undo / redo while typing** (N8): ↶ / ↷ in the editor;
  typing bursts and pastes are steps; Discard can be undone too.
- [x] **Shop: scroll to an item as it's added** (S6).
- [x] **Džoni: hidden reset / set of the count** — long-press the page
  title.

### Goal: v1.0.0 — the version Nikola starts using for real (2026-10-12)

Refreshed in Round 22 (2026-10-13). Done so far: the main pages (now
line, reminders as marks, toasts, shop quantities, checkboxes), pages as
a system (O9) with the Hub arranged by dragging (O8), Counters, Placard,
Medicine, notification taps opening their page, the security pass
(Round 21: nothing protected destroyed without the password, hidden
reset), **per-page Hub locks (O7)**, Clear data per Hub page, frozen
fixtures for every stored format.

**Left for v1** (in this order):
1. [x] **Backup reminder** (D8, first part; D9): Backup shows when the last
   export was; after a week without one, a quiet reminder (a dot on the
   menu's Backup and a notification) to export. So a lost or reset phone
   never costs more than a week.
2. [x] **Notifications, reliability check** (E1): after a restart of the
   phone, with the app swiped away, with battery saving on, when the
   clock or time zone changes, with exact alarms not allowed. Fix what's
   missing; a short phone test list for Nikola.
3. [x] **The app's own icon**: an 8-bit pixel character of our own,
   replacing Flutter's logo (launcher icon and the notification icon's
   look checked).
4. [x] **Last pass before v1**: a read through everything that saves
   (D6's remaining part: updates, crashes while saving, a full disk),
   the Introduction checked against the app, the docs tidied.
5. [ ] **Release v1.0.0.** Then Nikola clears the test data (Settings →
   Clear data) and starts using it.

**After v1** (v1.x / v2, roughly by size):
- **Notifications page** in the menu (E3, Round 23): recent ones (today
  and yesterday) that open their page, a clear button, and the
  notification settings: sounds per kind, picked in the app (E2;
  Android's own per-channel settings work meanwhile).
- More Markdown and a formatting bar (N17, Round 20).
- **Automatic backup** to a folder Nikola picks (D8, second part), then
  a self-hosted cloud backup (D5).
- **Food tracker** (O14, design waiting for Nikola's review).
- **Page organizer** (O10): a quick-access menu from the right side
  with pages picked for it, maybe sections in the Hub, later pages for
  Nikola's servers and connectors to his projects. Built on O9, so it
  adds places to put pages, not a rework.
- New Hub pages (see *Later / ideas*), **Recipes first** (Round 27): birthdays & yearly dates, days
  since / until, coin flip / decision helper, life percentage, recipes,
  workout log, timer, habits, weight log, expenses, packing lists, a
  converter.
- UI polish (U1): animations, shake on a wrong password, transitions.

### Round 32 — Nikola's review of 1.3.1 (2026-10-13)

**1. Formats**
- [x] Bold, italic and strikethrough **toggle**: pressing one again on
  formatted text takes it off, instead of stacking more symbols.
- [ ] Later (a lot later): **proper code blocks**, multi-line, with a
  nicer look, from a button of their own (strikethrough's button can go
  to make room: it's not used).

**2. Improvements**
- [x] Sometimes after an update there are **two of the app** in the
  recent apps: look into it. *Found:* the manifest's empty
  `taskAffinity` (Flutter's template) made a launch from the installer or
  a notification start a second task; removed.
- [x] Medicine: deleting an **important** medicine asks to type DELETE,
  like other places.
- [x] Medicine: the **number of doses** can't be changed once added (it
  confused the history); their times still can.

### Pip, a virtual pet (Nikola's plan, Round 32) — bit by bit, between other features

Nikola wants more say on sprites and visuals: show him drafts first.

**Phase 1: hatching, name, age, his home**
- [ ] Until he's hatched, the menu's room shows an **egg**; a few taps
  crack it, and Pip jumps out. His **birthday** is that moment.
- [ ] Above the room, his **name and age** in tiny pixel text.
- [ ] **Pip Home** (a Hub page; only once he's hatched, then opened;
  special, so it can't be locked): his avatar, name (changeable), age,
  birthday, and the same room as the menu's.
- [ ] The field's **background follows the time of day**.

**Phase 2: energy and batteries**
- [ ] A tiny **energy bar** above the room.
- [ ] **Batteries**: about 3 a day, earned by visiting the app; tap the
  room to drop one, he runs over and picks it up to fill his energy.
- [ ] While the phone **charges** (if the app can tell): a charging
  station, he runs to it and plugs in.

**Later: more life**
- [ ] Entrances: from the ground (now; also when the app is opened again
  after a while), falling from the sky, from the sides.
- [ ] Random events: **bugs** (computer bugs) appear and he draws a sword
  to fight them; moments where he **shows something on his screen**
  (also when a notification comes).
- [ ] **Sleeping** at night; opening the app wakes him.
- [ ] Careful **flow control**, so things can't clash (no battery during
  a fight, etc.).
- [ ] On Pip Home: a **background** pick for the room, and an **info
  page** playing every animation he has.
- [ ] Much later: Godville-style items and phrases made to fit him,
  items and levelling up.

### Round 30 — Nikola's review of 1.3.0 (2026-10-13)

Then the notifications page (Round 28, part 3).

- [x] To-do: **under** the Introduction (the Introduction stays on top).
- [x] To-do: its buttons follow the **hand-side rule** like every page.
- [x] To-do: **two lists**: done things go down to a *Completed* list;
  tapping toggles them back; a **Delete completed** button.
- [x] Restore part: the **Restore** button is broken (text and icon in
  one line, over the round button's sides).
- [x] Restored copies get **(Copy)** in their titles.

### Round 29 — Nikola's notes on 1.2.0 and 1.2.1 (2026-10-13)

After the to-do note and partial restore are released; before the
notifications page. (1.2.1: Pip is good.)

- [x] Placard: the pop sound a **bubbly pop**, like a bubble bursting.
- [x] Introduction: **remembers where it was scrolled to**, unless it's
  new or was just restored.
- [x] **Code formatting** looks bad and unreadable; improve it. In the
  Introduction (1.2.0) most of "What's new" showed as code, with `- `
  and `### Changed` unformatted: the code example likely opened a block
  that never closed. Fix both. *Done:* a block needs its closing ```
  (a lone one is text); code 0.88 of the text's size; no line numbers
  beside hidden fences; a test reads every version's "What's new".
- [x] The **Format** button's icon (an A with a line under it): pick a
  better one. *Done:* "Tt".
- [x] The format bar goes **under** the little handle pointing at the
  line being edited; it can go over it (it's easy to close). *Done:*
  Android draws that handle above everything, so it's hidden while the
  bar is open (selection handles stay).
- [x] The **bigger list dots** sit too high next to the text and the
  line number (as the checkboxes did once); align them. *Done:* drawn
  as a circle centred on the text's middle (one character still).

### Round 28 — to-do note, partial restore; the notifications page planned (2026-10-13)

Nikola, after 1.2.1: the to-do note and partial restore now; the
notifications page later (it is bigger than it looked).

**1. To-do note** (Round 26, part 3) — [x] done (N18): above the
  Introduction, the first thing and a count on its tile; tap completes
  (Undo), hold edits, the handle moves; Settings turns it off.

**2. Restore only part of a backup** (Round 26, part 3) — [x] done
  (D10): Backup → Restore part of a backup; pick by kind, added to
  what's there; ones still there come back as copies; tasks and routines
  whose time is taken are left out.

**3. Notifications page** (later; replaces Round 23's plan and E2/E3):
one page in the menu, history and settings together.
- [x] At the top, a window with the **3 most recent** notifications;
  tapping it opens the **full history** (each one tapped goes to its
  page / item; a button clears it).
- [x] Under it, **settings for each page** (Planner, Medicine, Backup,
  ...): mute, sound, pause (Medicine's pause moves here), colour,
  **plain or private** (private says just "a medicine" / "a task"
  instead of its name, so nothing sensitive shows on the lock screen),
  maybe an icon.

How it's built (Round 31), in chunks:
- [x] **Settings per page** (Planner, Medicine, Backup), kept on this
  phone: on / off; **pause** until a day (Planner, Medicine; Medicine's
  switch and pause move here from its Hub settings); **private** (the
  name left out: "A task at 10:00", "A dose is due"); **colour** (the
  notification's tint); **sound**. The scheduler follows them. *Done*
  (the model and the scheduler; the page next; sounds in their own
  chunk).
- [x] **History**: the app keeps what it scheduled (`notifications.json`,
  this phone only); those whose time has come, today and yesterday, are
  the history (Android doesn't tell an app which were shown, but a
  scheduled one is shown at its time). *Clear* hides them.
- [x] **The page** (menu → Notifications): the 3 latest in a window,
  tapped: the whole history (tapping one goes to its page); under it,
  each page's settings.
- [x] **Sounds**: the phone's default, a few of the app's own, or
  silent. (Android fixes a channel's sound when it's made, so each sound
  is a channel of its own.)
- Icon per page: later, if wanted.

### Round 27 — polish and note formatting (2026-10-13)

Nikola is importing his notes: the extra formats and their buttons now
(Round 20, part 3, brought forward), with the small fixes from Round 26.

**1. Small fixes** (Round 26, part 2 and 3)
- [x] No toast when deleting the Introduction.
- [x] Backup: one space between the date and time of the last backup.
- [x] Menu header: "The App" a little lower, level with Pip.
- [x] A sharper launcher icon (a vector, crisp at any size).
- [x] Markdown lists: slightly bigger dots.
- [x] Smaller headings: `####`, a bit bigger than the text, bold.
- [x] A new note's title (default or "Untitled") selected on tapping the
  title button.

**2. More formats, and a formatting bar** (N17)
- [x] Inline `code`, code blocks (```), quotes (>), highlight (==…==), a
  divider (---).
- [x] A Format button (in place of Checkbox) opening a row of format
  buttons above the keyboard, without leaving or covering the text.

**4. Pip's head** (concepts, Nikola choosing)
- [x] The screen a little taller (now 14 x 8 looks flat; 14 x 11 too
  tall: try one row more), kept simple: no bezel line, solid eyes as
  now. A finer grid is fine, but the pixel look stays (the grass as it
  is). **Chosen: one row more (14 x 9)**, for the room and the app icon
  too.
- [x] First: example pictures on his screen, to see whether the screen
  needs a finer grid. **No**: pictures in his own pixels look more
  natural; a finer screen-only grid is kept for an occasional detailed
  picture (later, on Pip's page).
- [x] The room: the 14 x 9 screen in every frame, and the animations
  (spawn, hop, walk, blink) checked and improved where needed: he now
  starts fully underground (his antenna peeked out), and standing he
  turns to look the other way now and then.
- [x] The menu header's Pip and the app icon: the room's idle frame,
  the same grid (the face a little to one side, as in the room: goofy,
  and Nikola likes it), not a centred face.

**3. Hub pages: Recipes next** — of the new Hub pages (not the food
  tracker or Pip's page, which have their own places), Recipes is the
  next one built.

### Round 26 — after v1: Pip's room, and notes on 1.0.0 (2026-10-13)

**1. Pip's room in the menu** (now; see Round 24, part 8)
- [x] A small field at the bottom of the menu. The first time the menu
  opens, Pip pops out of the ground; then he stands about and walks.
  Drawn finer than the icon, crisp, squash and stretch on the jump.

**1b. Bug, next in line (important)**
- [x] Notes: stuck selecting text. Tapping anywhere in the text no longer
  placed the cursor; it selected everything from the start to the tap.
  Cause: the app thought Shift was held (a phone keyboard's Shift
  "down" without its "up"), and a Shift-tap extends the selection. Now
  a finger touching the screen first lets go of a stuck Shift.

**2. Notes for later** (on 1.0.0)
- [x] No toast when deleting the Introduction.
- [x] Backup: "Last backup" has two spaces between date and time; one
  there (the notes' dates keep theirs).
- [x] Menu header: "The App" a little lower, level with Pip.
- [x] The launcher icon looks a bit soft next to other apps' icons:
  sharper (e.g. drawn as a vector, crisp at any size).

**3. More notes for later** (after Pip's room and its revisions)
- [x] Markdown lists: slightly bigger dots.
- [x] Even smaller headings: `####`, just a bit bigger than the text,
  bold.
- [x] **To-do note** (new): a special note at the top of Notes, turned
  on and off like the Introduction; just a list, like Shop without
  sections: add items; tapping one completes (removes) it, with a "Task
  completed" toast and Undo.
- [x] A new note's title (the default or "Untitled"): tapping the title
  button selects its text, so it's quick to replace.
- [x] **Restore only part of a backup** (a backup extractor): open a
  backup and pick what to bring back (e.g. one note), added to what's
  there instead of replacing everything.

### Round 25 — Nikola's notes on 0.28.0, then v1 (2026-10-13)

- [x] Hub tiles: the page lock at the bottom left (outside the icon),
  not centred.
- [x] Medicine, Important: drop the part in parentheses from its
  explanation.
- [x] Hold-to-take: an ending, a small pop, a tick in place of the
  icon, staying a moment before the dialog closes.
- [x] Menu: Pip next to "The App" in the header, and the header always
  the same height (the Lock button made it taller, shifting the menu).
- [x] Placard: the pop's volume as before (only the inflate louder).
- Pip's room in the menu: the first thing after v1.
- Then release v1.0.0 (Nikola: yes, after these).

### Round 24 — Nikola's notes before v1 (2026-10-13)

Nikola meant the notification tests and a final review to come before
v1, with a stop for his go-ahead; v1 waits for these. (The icon was
done without him: kept for now, but he picks the real one, see 6.)

**1. Medicine: important medicines** (before v1)
- [x] **Important** (set when adding or editing, with a note on what it
  does): ticking one of its doses as taken opens a dialog with a big
  button to **hold for 5 seconds**: it fills while held, animated, with
  a sound while holding (in the spirit of Placard's, not the same).
- [x] The **red dot** only for important medicines; the "Red dot"
  switch in Medicine settings goes (the important flag decides).
- [x] Settings wording: "at each dose time, unless it's marked" — say
  what marked means (taken, missed or not sure).
- [x] The add / edit view like the routines one: scrolls to the lower
  options, closes only with back. After editing, closing it leaves the
  medicine's menu (history / edit / delete) open.
- [x] The tick sound for a normal medicine louder.

**2. Bug**
- [x] On an unlocked page, open the menu and lock: the menu closes and
  shows the page. It should lock silently, the menu staying open.

**3. From the 0.27.0 review**
- [x] Hub tiles: the lock icon not in the corner — under the icon,
  centred at the bottom (outside the icon's area).
- [x] The Introduction keeps up with features (each round).
- [x] Back to top in the histories always on the right, and room left
  at the end so it doesn't cover the last entries.
- [x] Placard: the pop timing as before Round 20 (revert that change).
- [x] Medicine and Placard sounds louder.

**4. After v1 (v2)**
- [ ] Medicine: pick weekdays (supplements taken some days only).

**5. Install problem** — solved: a bad download (Nikola installed it).

**8. Pip, a virtual pet** (idea; Nikola decides after seeing the cost)
- [x] Before v1 maybe: a small **room** at the bottom of the menu (a
  field); the first time the menu opens, Pip pops out of the ground,
  then stands and walks about. Drawn at a finer pixel scale than the
  icon so walking and squash/stretch look right.
- [ ] Later: his own Hub page (tamagotchi-like); doing things by
  himself: sleeping at night, something on his screen, waking up after
  the app was away.
- [ ] On his page, a section that **plays each of his animations** on
  demand (pop out, hop, walk, blink, …) (Nikola, Round 26).
- [ ] On his page, besides the pet side: **Godville-style random
  events** (Nikola, Round 26): little things happening to him by
  themselves, told as a log.

**7. Order to v1** — 0.28.0 is a test build of all this; Nikola tests,
  sends small fixes and his icon pick; then v1.0.0.

**6. The icon** — [x] **Pip** (Nikola's pick, a 16 × 16 grid) drawn by
  `tool/make_icon.py`. (Prompt given in chat, Round 24:) a prompt for Nikola to ask Claude for icon ideas
  (from the theme and what the app is), and how to send the chosen one
  back (a screenshot, a file, or instructions to draw the same).

### Round 23 — order to v1 (2026-10-13)

Nikola: the backup reminder, then release (0.27.0); then the icon, the
notification checks and the last pass.
- [x] Backup reminder (D9).
- [x] Released 0.27.0; the next is 1.0.0.
- [x] The icon: a pixel robot of our own (`tool/make_icon.py`), legacy
  and adaptive, with a one-colour layer for themed icons.
- [x] Notifications (E1). Already right: plans again after a restart or
  an update, exact alarms, absolute times re-planned on every start.
  Fixed: doses at the same minute come as one (Android holds back alarms
  close together while idle); a notice the evening before planned
  reminders run out (an app left unopened two weeks went quiet); Settings
  says when notifications are blocked.

- [x] Last pass (D6): saving was already crash-safe; a failed save (a
  full phone) is now said, kept and retried, with "Saved again" once it
  works. The Introduction checked against the app (Settings' list,
  medicine notifications).

**Phone test list (E1)** — for Nikola, on 1.0.0:
1. Two medicines at the same time: one notification naming both.
2. Restart the phone: the next reminder still comes.
3. Swipe the app away from recent apps: reminders still come.
4. Battery: set The App to *Unrestricted* (Settings → Apps → The App →
   Battery); some phones (Xiaomi, Samsung) stop alarms of restricted
   apps.
5. Turn notifications off for The App: Settings in the app says so;
   tapping it asks again.
6. Change the time zone (or travel): open the app once afterwards, so
   reminders move to the new local times.
7. A week without a backup: the red dot on the menu and an evening
   notification that opens Backup.

A note for after v1:
- [ ] **Notifications page** (menu → Notifications; E3): a **history**
  of recent notifications — today and yesterday — because ones cleared
  from the phone's drawer (e.g. by opening the app instead of tapping
  them) are otherwise gone unseen. Tapping one goes to its page / item
  (like tapping the notification), and a button clears the list. The
  same page holds the notification settings planned with E2 (sounds per
  kind).

### Round 22 — towards v1 (2026-10-13)

Nikola: Round 20's extra Markdown and the formatting bar wait (v2
maybe); per-page Hub locks first; then get v1 working so he can start
using the app: a list of what's in v1 and what's later.
- [x] Per-page Hub locks (Round 21, part 3).
- [x] Round 20's Markdown (N17) moved to after v1.
- [x] The v1 list and the later list (above, "Goal: v1.0.0").

### Round 21 — security (2026-10-13), before Round 20's Markdown

**1. Bugs**
- [x] Security: the Hub sometimes missing from the section locks (it
  seemed to go after locking it). Cause: the list's last row sat under
  the phone's own bar (no room for it on pages without bottom buttons);
  every list now leaves that room.
- [x] A tapped notification's "go to" outlives a change of course: Hub
  locked, a medicine notification tapped, then Planner and back to Hub,
  unlocked: it still went to Medicine. Going elsewhere drops it.

**2. Nothing protected can be destroyed without the password**
- [x] Locked notes can't be deleted without the master password (the
  list's Delete asks for it when a locked one is selected).
- [x] **Reset (forgot password)** is hidden in plain sight: after typing
  RESET, the button must be **held 10 seconds**. A normal tap greys
  reset out until the next unlock, or a full day.
- [x] A check of every other way to lose protected data without the
  password (Clear data, importing a backup over it, deleting from
  selection mode, …), fixing what's open. Clear data, removing or
  changing the password and turning a section lock off already asked
  for it; exporting keeps locked notes sealed. **Importing** a backup
  replaced locked notes without it: now asks first.

**3. Lock each Hub page on its own** (O7; built first, Round 22)
- [x] In Security, under the Hub: a switch per Hub page. The Hub and its
  pages lock independently: a locked Hub with some pages free (for the
  quick-access menu, later), or a free Hub with some pages locked.

### Round 20 — Nikola's review of 0.26.0 (2026-10-13)

**1. Quick fixes**
- [x] Medicine: the card's total a bit higher, level with the drag
  handle.
- [x] Placard: the inflating a bit longer; the pop quieter (the inflate
  tone is soft, the pop was loud next to it).
- [x] Settings: line numbers first.
- [x] Notes: **Discard changes** always there (greyed out until there's
  something to discard), not appearing and shifting the buttons.

**2. Back to top in the medicine histories**
- [x] A button that scrolls to the top, in the history of all and in a
  medicine's own; only once scrolled far (when it helps).

**3. More Markdown, and a formatting bar** (N17; after v1, Round 22)
- [x] More formats: inline `code`, code blocks (```), quotes (>),
  highlighted text (==…==), a divider (---).
- [x] Controls for all of them, like the checkbox button: one button
  (in place of the checkbox one) that opens a row of format buttons
  above the keyboard, without leaving the text or covering it; tapping
  one applies it to the selection or the line.

### Round 19 — Nikola's notes before the night (2026-10-13)

**1. Reminder marks on the timeline**
- [x] The bell marks a little **bigger**, keeping the circle the same
  distance from the timeline and from the hour labels.
- [x] A new **merge** rule: two reminders that aren't really close got
  merged into one mark, which makes them harder to work with. Now they
  merge only when their icons would overlap (about 12 minutes apart on a
  normal hour, was about 27); closer touch targets share the space
  between them, each tap going to the nearer mark.

**2. Tapping a notification opens what it's about**
- [x] A planner block, routine or reminder: the Planner, on that day,
  scrolled to it. A medicine: the Medicine page.
- [x] Locks stay as they are: a locked section asks first. If it isn't
  unlocked then, the "go to" waits and happens on the next visit to the
  page once unlocked.

### Round 18 — Nikola's review of 0.25.0 (2026-10-13)

**1. Quick fixes**
- [x] Planner: hour labels a touch further right (6 → 7).
- [x] Medicine: **undo** the red on late dose buttons (Round 17 misread:
  "mark red missed" meant the calendar, where missed looked lighter than
  taken).
- [x] Medicine history and calendar: **fixed colours**, not the theme's:
  green for taken, a clear red for missed (it looked disabled), and
  distinct ones for some / not sure.
- [x] Placard: the inflating sound without the white noise (keep the
  rising "wuwuwu" tone).
- [x] Medicine: unticking a taken dose **asks first** (an accidental
  touch); ticking doesn't.
- [x] Medicine: each card shows its **total doses taken**, small.
- [x] Medicine calendar: a tap on a day **doesn't** change states (it
  shows that day below instead).
- [x] Counters: the feel of the first taps after opening is "off"
  (a double sound or a different buzz?): look for a cause. Nothing
  doubles in the code (one click and one buzz per tap, the button's own
  feedback off); likely the first click after a while lags its buzz while
  Android's player wakes up, so the page now wakes it silently on
  opening.

**2. Medicine history for all**
- [x] The medicines at the top; a tap opens one's own history.
- [x] Each day as a small **table** (medicine × doses); tapping an item
  opens that medicine's history, scrolled to the day.
- [x] Ready for years of doses (thousands of marks): lookups by an
  index, lists built lazily.

### Round 17 — Nikola's review of 0.24.0 (2026-10-13)

**1. Quick fixes**
- [x] Medicine dot: at 00:50 it showed for yesterday's 11:00–22:00
  doses. Only yesterday's doses at **22:00 or later** (Nikola changed it from 23:00) keep it until
  02:00.
- [x] Planner: the hour labels' margin smaller (about 6).
- [x] Medicine: the vibration on ticking follows the gulp (two soft
  pulses).
- [x] Medicine: a dose whose time has passed and isn't taken shows
  **red**.
- [x] Check every place the Round 14–16 timeline features should be
  (tap position, reach mode…), not just the planner: the Routines
  screen still lacks reach mode.

- [x] Introduction: not in the menu (it's in Notes); deleted, Settings
  offers to restore it.
- [x] Introduction: room at the bottom so Delete doesn't cover the last
  lines (the phone's own bar wasn't counted on pages opened on top).

**2. Placard**
- [x] The pop looks odd: find out why and improve it (the inflating is
  right). Why: on popping, the inflated size (and the shake) reset in one
  frame, then the pop swelled again, so it shrank before bursting. Now
  the pop starts from fully inflated, bursts a little bigger with a ring
  flying out, and springs back.
- [x] Sounds: a rising sound while inflating, and a **pop**.

(The medicine **month calendar** with marks is Round 16's chunk 3, next
after these.)

### Round 16 — Nikola's review of 0.23.0 (2026-10-12)

Before Round 15's chunks 2–3 (fixes first):

**1. Quick fixes**
- [x] Medicine: the chime hurts the ears; something fun and soft
  instead, like a **swallow / gulp** (or a crunch).
- [x] Counters: the click is loud and ignores the media volume; quieter,
  and following the **media volume**.
- [x] Placard: the hold a bit longer again.
- [x] Routines screen: tapping free time doesn't start where tapped
  (Round 14 did it only on the planner).
- [x] Planner / routine sheet: an **End of day** button for the end
  time.
- [x] Medicine: "Mark the past days taken" only when more than **10
  doses** are not set (counting back from yesterday), on adding and in
  its history.

**2. Note checkboxes, drawn by the app**
- [x] On the phone the empty box is small again and the ticked one still
  grey: the font's glyphs can't be trusted. Draw both boxes ourselves
  over the text (same size, the accent, a tick), like the line numbers.

**3. Medicine, per medicine**
- [x] "Remind again" belongs to **each medicine** (in its sheet), not
  the page settings (medicine.json 3). The page keeps reminders on/off,
  the dot and the pause.
- [x] The calendar in a medicine's history **taller**: a month grid
  (weeks as rows), swiped left for older months, not a single strip.

### Round 15 — Nikola's notes on 0.23.0 (2026-10-12)

Chunks, in order (each its own commit; release when a few are in):

**1. Quick fixes**
- [x] Planner: the hour labels sit on the very edge of the screen; give
  them their small margin back, even if the timeline gets a bit
  narrower.
- [x] Shop: holding − (and + ) shows a tooltip; no tooltips on long
  press on buttons that are pressed often (find the similar cases). Done
  for every button, in the theme (screen readers still get the name).
- [x] Notes: holding to select text shows a magnifier lens; none.
- [x] Notes editor: the action row over the text (Checkbox, Edit title)
  has a background that **hides the lines under it** and catches taps
  there (seen after redo: the restored "F" lines looked missing, and
  tapping where they were made the scroll jump). Transparent, taps go
  through to the text, and the line being edited is kept scrolled above
  the actions.
- [x] Medicine dot: a dose still counts as due until **02:00** the next
  day (a dose at 23:30 that's missed still shows when going to bed).
- Discarded: the cut-off note on tapping a stacked reminder (a
  mistake).

**2. Introduction note** (N16)
- [x] A special note, **"Introduction"**, at the top of Notes: what each
  part of the app does and how to use it (for any user, plain and
  objective), and under it **what's new** (only the latest version's
  changes). Shown after a fresh install and again after each update.
- [x] Read-only, nicely drawn markdown; can't be edited. Can be deleted;
  the menu (or Settings) can bring it back.
- [x] A Settings switch: don't bring it back on updates.

**3. Food tracker** (O14) — first in line when new Hub pages come
- [ ] A Hub page for what was eaten each day and how well it agreed
  (asked for by someone; details left to Claude): a list of foods,
  each day's meals from it with a rating, a day view, and **statistics
  that point out what tends to cause trouble** (and what's fine).
  Design to propose first.

  **Proposal (for Nikola's review, nothing built yet):**
  - *Foods* are a list that grows as you log (name, optional tags like
    dairy, gluten, spicy, fried, alcohol, caffeine). Typing a name that
    exists picks it; a new name adds it.
  - *Logging* a meal: when (breakfast / lunch / dinner / snack, or a
    time), and the foods in it, picked as chips (the most used first, a
    search for the rest). Takes a few taps; the last meals can be
    repeated with one tap.
  - *How it went*, per meal, rated some hours later (a reminder can ask):
    five faces from Great to Awful, plus optional symptoms (bloating,
    heartburn, cramps, nausea, tiredness, headache, other) and a note.
    Per meal, not per food: rating each ingredient is too much work and
    no more accurate. (Also a whole-day "how I felt", for days without
    a clear culprit.)
  - *Day view*: the day's meals in order, each with its foods and its
    rating colour; a strip / month calendar coloured by the day's worst
    rating, like the medicine calendar.
  - *Statistics*, the point of it: for each food, how meals with it went
    compared with meals without it (average rating, and how often a
    symptom followed). Shown as "likely trouble" (clearly worse than
    your usual, after enough meals, e.g. 5+), "seems fine", and "not
    enough data yet", with the numbers behind it ("7 meals, 5 rated bad
    or worse; usually 1 in 5"). The same for tags (e.g. "meals with
    dairy go worse") and for symptoms (e.g. "bloating follows onions").
    Honest about uncertainty: a food seen twice is never "trouble".
  - Stored in its own `food.json`, in backups, with fixtures, like the
    other pages; a Hub tile (and a settings page for the reminder to
    rate).

### Round 14 — Nikola's notes on 0.21–0.22 (2026-10-12)

Chunks, in order (each its own commit; release when a few are in):

**1. Quick fixes**
- [x] Planner sheet: the clash line looks like the info line (icon +
  text), only red; **Find a free time** is a real button, left-aligned
  with the rest.
- [x] Planner sheet: ticking a weekday that clashes makes the line
  appear and **pushes the form down** (the chip just tapped scrolls out
  of view): keep what's under the finger in place.
- [x] Notes checkboxes: the empty box sits too high next to the text and
  the ticked one, so ticking jumps; the ticked box still shows **white**
  on the phone (an emoji), not the accent. Both drawn the same way, same
  size, in the accent.
- [x] Counters: no "none" placeholder in Min / Max; the no-colour
  buttons look green (Material's tonal colour), and colours look washed
  out: use the vivid colours; every counter the same height (limits
  made the card taller); more compact overall.
- [x] Placard: the hold is **2–3× longer**.

**2. Planner touches**
- [x] **Reach mode on the timeline**: pull down to bring the top block
  into reach, with the snap back, like the lists.
- [x] Tapping free time starts the new block **near where it was tapped**
  (to :00 / :30); tapping the **left edge** (by the hour labels) adds a
  reminder there (to 15 minutes).
- [x] ~~(Nikola's note on tapping a stacked reminder was cut off: ask.)~~
  Dropped (Round 30): too long ago to recall.

**3. Medicine, how it handles**
- [x] Its buttons always on the **right** (one-handed side can't be told
  here).
- [x] No undo after unticking (just tick again); a **sound and vibration**
  on ticking (a nice one, not the click).
- [x] Dose boxes: **two per row, same width**; one dose takes the first
  column, not the whole row.
- [x] **Drag handles** to order medicines.
- [x] A tap anywhere on a card (not on a dose) opens it, like its name.
- [x] Its menu: "for good" isn't written; no end date just shows none.

**4. Medicine, history and states**
- [x] History easier to read: coloured day titles, a mark per dose
  (taken / missed / not sure), not plain text lines.
- [x] **A medicine's own history** (from its menu): a **calendar strip**
  at the top (each day coloured by taken or not, scrolls to the left),
  every day below, and a **lifetime total** taken.
- [x] **Start in the past** and fill it in: e.g. "mark all past days
  taken", then set the one missed day.
- [x] In history every dose can be set freely: **taken, missed, not
  sure** (for days not ticked at the time).

**5. Hub page settings, notifications, the red dot**
- [x] Each Hub page that has settings gets a **settings button in its
  top bar** (Counters and Placard don't need one).
- [x] Medicine settings: notifications on/off; the red dot on/off;
  **pause** notifications / the dot for a day or more.
- [x] Medicine **notifications** at dose times, and an optional **second
  one if a dose is still not taken** (e.g. 4 hours later).
- [x] A **red dot** on the Medicine tile and on the Hub tab when a dose
  is missed (seen even when the Hub is locked). Done as: due and not
  marked today; marking it missed or not sure clears the dot too.

### Round 13 — Nikola's notes on 0.20.0 (2026-10-12)

- [x] **Checkbox button** in notes: a small button next to *Edit title*,
  shown only while typing (keyboard up), instead of in the main row.
- [x] **Checkbox look:** the empty box bigger; the ticked box in the
  theme's accent (Clay's orange).
- [x] **Clay first and the default theme**, and more themes for fun to
  fill out the list (all dark, no light mode).
- [x] **Clear data:** no icon on the big Clear button; type **DELETE**
  there instead of RESET.
- [x] **Edit routine sheet:** the Save button isn't all the way to the
  side since the ✕ went (fix its place).
- [x] **Overlaps in the sheet: don't move the time by itself.** Today a
  time that clashes on a picked weekday is moved to a free one (seen: a
  Mon/Wed/Fri routine 23:30–23:59, then a Tuesday one at the same time,
  picking Wed moved it). Instead keep the time, show it in red, disable
  Save, and offer a button that finds a free time on request.
- Later, tests: **long inputs** everywhere (titles, notes, items,
  counters…): any length is allowed (a personal app), but the layout must
  never break because of it.
- Later, locks (with O7/O10): Other (whatever it's renamed to) can still
  be locked as a whole, **and each page in it can be locked on its own**
  for when Other isn't locked. The quick-access menu, when it comes,
  locks the same way Other does.

### Round 12 — Nikola's notes on 0.19.0 (2026-10-12)
- [x] **No button flashes when it turns on, anywhere, now and later**
  (seen on the planner sheet's Add): one rule in the app's theme for
  every button kind, checked by a test.
- [x] **Planner sheet buttons:** no ✕ (back closes, still asking about
  changes); editing a routine has a plain **Delete** on the left.
- [x] **Short blocks show one line of description** (their time is
  beside the title, so there's room below), down to the smallest block.
- [x] **Clear data** in Settings (Z1): pick sections (Notes, Shop,
  Planner, Other) and clear everything in them, after typing RESET and,
  with a master password set, entering it. For clearing test data.
- [x] Later: **lock each Other page on its own** (like section locks).
- [ ] Later (with E2): **default notification sounds** for tasks,
  routines and reminders separately, and for medicine (Nikola, Round
  17: a sound per kind, picked in the app; each kind already has its own
  Android channel, so Android's per-channel sound works meanwhile).
- [ ] Later (with D6): **what if the app is deleted?** Uninstalling
  deletes the app's files; ways to survive it: Android's backup (on, see
  ARCHITECTURE), exports, an automatic export to a folder the user picks
  (outside the app, so it stays), cloud save (D5).

### Round 11 — Nikola's notes, evening of 2026-10-11

Sorted from one long message. Order of work is at the end.

**A. Planner: the sheet and tapping blocks** ✅
- [x] **Save / Add greyed out** until the title is valid (not blank).
- [x] **No autofocus on the title when editing** (tapping a small block
  just to see what it is shouldn't open the keyboard). Adding still
  focuses it.
- [x] **Tapping a task shows it first** (like a routine): its title,
  time, colour and reminder, with options (Edit, Delete, …); only Edit
  opens the sheet. (P15)

**B. Planner: colours** ✅
- [x] **More colours** in the palette.
- [x] **Defaults:** new tasks are **blue**, new routines **purple**.

**A2. Planner: descriptions** ✅ (Nikola, after chunk 2) — tasks and
  routines get an optional description; it shows on the block when
  there's room, and in the block's menu. (P20)
- [x] Model and storage (planner.json v5, routines.json v2, backup v7,
  frozen fixtures v7); the sheet's field; on blocks; in the menu.

**C. Planner: reminders, redesigned** (replaces the see-through block)
- [x] A reminder is a **small mark on the timeline's left edge**, by the
  hour labels, at its time; nothing covers the blocks.
- [x] **Tapping it** shows a bubble that looks like a block, with its
  title, time and a checkbox (ticking deletes it, with undo) and
  Edit / Delete.
- [x] **Reminders close together merge** into one mark (with a count);
  tapping it lists them, each tickable. (P14 updated)

**D. Planner: a "now" line** across the timeline at the current time,
  today only, moving with the clock. (P16)

**E. Notifications**
- [ ] **Make them solid** (P17): they must arrive with the app open, in
  the background, swiped away, the screen off and the phone locked, and
  after a restart. Check: exact alarms (and the permission on Android
  12+), Doze, battery optimisation (ask to be exempt if needed), boot
  rescheduling, notifications while the app is in front, and what the
  phone maker's battery savers do. Test each state on the phone.
- [ ] **Notification settings** in Settings (P18): sound (Android lets a
  channel's sound be chosen in its system settings; offer that, or a few
  channels), and the notification's **colour**: the block's colour where
  it has one, else the accent; or set per reminder.

**F. Toasts** (the messages at the bottom, e.g. Undo): restyle them to
  match the app (rounded, themed colours, spacing, clear action). (U7)

**G. Leaving a page clears its state** ✅: selection mode ends and the
  planner goes back to today when switching tabs (a note was still
  selected on coming back). (G18)

**H. Notes: empty notes go away** ✅ — a note with no title ("Untitled")
  and no content (only spaces / new lines) is removed on leaving, even
  after editing; if something changed, back still asks first, so the
  change can be discarded. (N14)

**I. Shop: quantities** (S7)
- [x] A small button on the right of each item toggles **none → count →
  weight**. Count: − / + by 1 (default 1). Weight in grams with smart
  − / + steps (no typing). Each kind remembers its value when toggled
  away and back. Shown but not editable in the bought list.
- [x] Weight: − / + jump through a list of **common amounts** (e.g. 50,
  80, 100, 150, 200, 250, 280, 300, 400, 500, 750 g, 1 / 1.5 / 2 kg …);
  **default 200 g**. **Tapping the weight** opens a quick edit to type an
  exact amount (a number, may be below 1 g).

**J. Counters, expanded** (O2/O5)
- [x] Adding a counter offers options: **step**, **colour**, **min**,
  **max** (and more later).
- [x] Better style: margins, rounder corners.

**K. Džoni back, configurable** (O4, instead of removed) ✅ as **Placard**
- [x] **Five taps in the top-right corner** open its settings: the text
  (default **"Add text here!"**, Nikola sets his own on the phone) and
  the count.
- [x] **Better count animation**: while holding (a bit longer than now)
  the page **inflates and shakes**, then **pops** when it counts.
- [x] **Hide the status bar** while it's open.
- [x] Fix: on back the page **disappears before the screen turns back
  upright**; turn first, then close.

**L. New page: medicine tracker** (O6) ✅ — Nikola takes a pill every
  morning and notes it in a sheet; make that one tap. Agreed shape (all
  of it combined):
  - Add medicines, each with **how many** (doses a day), **when** (times),
    from a date **until a date or forever**.
  - A clear **"taken today"** view: one tap per dose, with medicines taken
    more than once a day showing each dose (e.g. 1 of 2).
  - **History**: each day, and the time each dose was marked taken.

**M. Later**
- [ ] **Data-safety sweep** (D6): everything that could lose data
  (storage, updates, restore, locks, crashes, phone changes), how safe
  export is, and when cloud saving should come in.
- [ ] **Cloud save** (D5): the server is **typed in** (connection
  details entered in the app), never hard-coded.

**N. Ideas for more Other pages** — listed under *Later / ideas*.

**Process**
- [x] After a release Nikola confirmed, Claude runs it and gives a
  **checklist of what to test** (docs/RELEASING.md).

**Chunks** (small, one at a time; each can be released on its own):
1. [x] G + H — switching tabs clears state; empty notes go away.
2. [x] A + B — the planner sheet and tapping a task; colours.
3. [x] D — the "now" line.
4. [ ] C — reminders as marks on the timeline.
5. [ ] E1 — notifications: check every state, fix what's missing; a
   phone test list.
6. [ ] E2 — notification settings (sound, colour).
7. [ ] F — toasts.
8. [ ] I — shop quantities.
9. [ ] J — counters options and style.
10. [ ] K — Džoni back, configurable.
11. [ ] L — medicine tracker (model and storage, then the page).
12. [ ] New Other pages, one per chunk (see *Later / ideas*).
M (data-safety sweep, cloud) later.

### Round 10 — Nikola's notes on 0.18.0 (2026-10-11)
- [x] **Remove the timeline zoom** (P13): a 5-minute block looked bad and
  zooming didn't help.
- [x] **Blocks have a minimum height** (one touch target, like a
  30-minute block). A shorter block isn't squeezed: the timeline
  **stretches there** instead, so e.g. 11:00–12:00 with a 5-minute shower
  in it is a bit taller than other hours. The timeline is a visual
  representation, not to scale everywhere. (Blocks stay at least
  5 minutes long.)

### Housekeeping (2026-10-11, after 0.18.0)
- [x] Removed the Džoni page (O4): the repo is public and anyone building
  it gets the app, so it didn't belong. Its count is no longer kept in
  preferences or backups; older files that have it still load (ignored).
- [x] Checked the repo and its history for private data: no keys,
  passwords or personal details (the signing key is only in GitHub
  secrets).

### Round 9 — Nikola's notes after using 0.17 (2026-10-11)

Confirmed working on the phone: **fingerprint unlock**.

**A. Quick fixes**
- [x] Menu: *Lock now* becomes an icon button at the top right of the
  menu header (a fixed row of special actions; doesn't scroll).
- [x] Menu: *Themes* above *Backup*.
- [x] Set password: the keyboard's return key moves to the next field.
- [x] Notes: a lock icon next to "Note" in the top bar instead of
  "Locked note".
- [x] Notes: *Edit title* changes the title live while typing, and an
  empty title is allowed there.
- [x] No ✕ in selection mode anywhere (Notes, Shop, …): select all /
  deselect all (and back) already leave it.
- [x] Shop: the select button cycles: select all **in the section** →
  select **everything** (both sections) → deselect all. (Confirmed.)
- [x] Counters: no click sound — find out why (the phone's touch-sound
  setting, or play our own sound).
- [x] Planner: more space between touching blocks (now a thin line).
- [x] Planner: an icon on blocks that have a reminder.
- [x] Planner: selected blocks must be obvious (a clear mark).
- [x] Planner: when an edited time had to be changed to fit (it would
  overlap), say so instead of quietly changing it.

**B. Notes: view mode first**
- [x] A note opens **for viewing**; tapping the text goes into editing
  there.
- [x] Back while editing → view; back in view → as now (save / leave).
- [x] Closing the keyboard (back) while editing → view.
- [x] In view, list items show a real dot (•) instead of `-` (and while
  editing, on every line but the one being edited). The ← arrow always
  leaves; only the system back steps out of editing first.

**C. Planner sheet (add / edit a block)**
- [x] Reach mode in the sheet: pulling down shifts the content into thumb
  reach instead of closing the sheet.
- [x] A close button (the sheet no longer closes by dragging it down).
  Close and Add / Save stay in a fixed row at the bottom; the form
  scrolls above it.
- [x] Closing with changes asks to confirm ("Discard changes?", Cancel /
  Discard). Unlike notes, **back again counts as Discard**; tapping
  outside the dialog does nothing.

**D. Planner: a one-off and a routine at the same time** (one focused
task)
- [x] Replace "the one-off wins": a one-off task and a routine may share
  time — at most **one of each** at any moment. Where they overlap they
  sit side by side (one-off left, routine right); where one goes on
  alone it widens to full width, drawn as the same block continuing
  (blended, no gap). Example: medicine at 11:00 as a routine, whatever
  else is there. Worked out (P12):
  - one-off vs one-off and routine vs routine: still never;
  - free time is time with neither; a task added there may reach over
    routines up to the next task; set to repeat, it keeps clear of
    routines and says so if its times change;
  - tapping a routine offers **Add a task alongside**; it and *Change
    just this day* fit around tasks already there (and say so), and are
    off when tasks fill the routine's time;
  - reminders and ticks: each on its own;
  - very short overlaps: a block's title, time and checkbox go in its
    tallest piece (zoom, E, makes short pieces readable).

**E. Visuals**
- [x] **Timeline zoom** (Nikola's pick for short blocks, which cut off
  the checkbox): one bottom button cycling Normal (30 min = one touch
  target) → Large (15 min) → Extra large (5 min), remembered. No pinch
  (two fingers, against the one-hand rule). Blocks are at least 5 min
  (P13).
- [x] Better icons for the Other tiles (custom SVGs in `assets/icons/`):
  tally marks for Counters, a speech bubble with a question mark for
  Džoni.
- [x] Shop: icons instead of checkboxes (U2): a cart to buy, a tick
  when bought.
- [x] Password reset dialog: no flash when Reset becomes enabled (the
  label faded in from grey over the new red; dialog buttons now change at
  once).

**F. Later**
- [x] **Point items** (Nikola, after E; he meant reminders, not routines):
  something like a one-off reminder or to-do on the timeline — a time but
  **no end**, a small block that "hovers" there as a temporary reminder,
  not a long-running task. Agreed (P14): a short see-through block over
  the timeline; a bell button adds one; notifies at its time only;
  ticking it off deletes it; unticked, it stays on its day.
  - [x] Model, storage (`pins.json` v1), backups (v6, `plannerPins`)
  - [x] Timeline, adding / editing, ticking off, notifications
- [x] Unclear note "(This is just so markdown)": Nikola doesn't recall;
  only the set-password part was meant, and it's done.

### Round 8 — reminders (2026-10-11)

- [x] **Planner reminders** (P10), choices made while Nikola couldn't
  build (adjustable): per block Off / at start / 5–60 min before;
  titles hidden while the Planner is locked; planned two weeks ahead.
  Android build moved to AGP 8.6 / Gradle 8.7 / Java 11 with desugaring
  for flutter_local_notifications.

### Round 7 — after 0.16 (2026-10-10)

- [x] **Menu stays open behind its pages** (G16): back from a page opened
  from the menu returns to the menu; back again closes it.
- [x] **Counters: no ✕ in selection mode** — back already leaves it.
- [x] **Notes: ↶ ↷ keep their order on the left side too** (Nikola);
  only their place (outermost) follows the hand.
- [x] **Planner routines** (P8), designed with Nikola: a routine is its
  own item (not copies), shown on its days; per-day change / skip / tick;
  a Routines screen with a Mon–Sun strip; Repeat + Until in the add sheet;
  the one-off wins a clash; editing a routine changes past days too.
- [x] **Block colours** (P9): six muted fills with a bright stripe, the
  same in every theme; picked in the task / routine sheet.

### Round 6 — after 0.15 (2026-10-10)

- [x] **Markdown: hide the symbols except where you're editing** (N9) —
  Nikola expected the `##` to disappear once formatted. Live preview: the
  line with the cursor shows its symbols; other lines don't.
- [x] **Line numbers in notes** (N12) — Nikola liked the code-editor
  idea; one number per paragraph, switch in Settings.

### Round 5 — after 0.14 (2026-10-10)

- [x] **Notes: edit the title from the bottom** (N11) — Nikola: the title
  is high and hard to reach. A smaller *Edit title* button above the
  editor's buttons (Nikola's choice) opens a sheet at the bottom.
- [x] **Reach mode reaches further** (U4): 28% instead of 20% (about one
  row more), Counters a bit more again.
- [x] **Reach mode snapped back late:** a small scroll the other way only
  snapped back on the next touch (the snap waited for a frame nothing
  asked for); now it snaps as the finger lets go.
- [x] **Note editor without the ⋮ menu** (N10): it held only *Lock note*
  and opening it fought with the keyboard. *Lock note* / *Remove lock*
  is a button; ↶ / ↷ are outermost, under the thumb.
- [x] **Planner: free time as a block** (P7): transparent, dotted border.
- [x] **Džoni: no top bar**; setting the count is a triple tap in the
  top-right corner instead of a long-press on the title.
- [x] **Markdown in notes** (N9) — Nikola: dynamic, basics only, lists
  most important, no checkboxes. Styled live in the editor; symbols stay,
  faint.
- [x] **Fingerprint unlock** (L6) — via `biometric_storage` (Android
  keystore, fingerprint-bound key). Not tried on a phone before release:
  Nikola to check on 0.15.

## Later / ideas

- **Other pages Nikola picked** (Round 11; each starts empty, no
  sample data):
  - **Birthdays & yearly dates**, with a reminder before.
  - **Coin flip**.
  - **Recipes**.
  - **Workout log**.
  - **Days since / until**.
  - **Life percentage**: enter the year born and an expected last year;
    shows how much has passed, visually.
- **More Other pages** (ideas offered in Round 11):
  - **Timer / stopwatch / intervals** (e.g. cooking, workouts, pomodoro),
    big one-handed buttons, ring at the end.
  - **Days since / until**: "days since I started", "days until the
    trip"; tiles with a number.
  - **Habit tracker**: tick a habit per day, streaks and a month grid
    (the medicine tracker could be its first use).
  - **Weight / measurements log**: a number per day with a small chart.
  - **Workout log**: exercises with sets × reps × weight, last time's
    numbers shown.
  - **Quick expense log**: amount + category, a month's total; no bank
    links.
  - **Packing / checklist templates**: reusable lists (trip, gym bag)
    ticked off and reset.
  - **Birthdays & dates**: yearly dates with a reminder a few days
    before.
  - **Decision helper**: pick a random item from a list, or flip a coin /
    roll dice.
  - **Unit / cooking converter**: grams ↔ cups, °C ↔ °F, etc.

- Self-hosted cloud backup, e.g. S3-backed (D5)
- **UI polish (U1)** — once the main features are in: shake on wrong
  password, hero/slide animations, haptics, clicky counter sounds;
  replace the shop checkboxes with nicer icons (U2)

## Decisions

- **L4 — unlock duration:** unlocked until 5 min in the background, app
  closed (removed from recents), or "Lock now". Short app switches don't
  relock.
- **N6 — locked notes:** title stays visible with a small lock icon; only
  the content is encrypted.
- **L5 — whole-section locking** is configured per section in
  Menu → Security, next to the master password.

## Housekeeping

- [x] GitHub Actions Node 20 deprecation: `checkout` and `setup-java` on
  v5; publishing uses the `gh` CLI instead of a third-party action.
- [x] Only the latest release is kept (the release workflow deletes older
  ones; tags stay).

- [ ] The Android toolchain is the one Flutter 3.29 generated (Kotlin
  1.8.22, AGP 8.1, Gradle 8.3). New plugins must be picked at versions that
  build with it — e.g. `package_info_plus` 9 needs Kotlin 2.2, so we use
  8.x. CI's APK job catches mismatches. Upgrade Flutter and the Android
  toolchain together, as one dedicated step, when plugins start requiring it.

- [ ] Two APIs carry `// ignore: deprecated_member_use` because they are only
  deprecated on newer Flutter (`onReorder`, `TickerMode.of`). Switch to
  `onReorderItem` / `TickerMode.valuesOf` when upgrading Flutter.
