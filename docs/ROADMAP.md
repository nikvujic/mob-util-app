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
- Commits are authored by the owner, unsigned, pushed to `main`.
- Every step that changes the app ends with a release: version bump,
  `CHANGELOG.md` entry, then the Release workflow → GitHub Release with
  the APK ([RELEASING.md](RELEASING.md)).
- Release signing key is set up (2026-10-08); v0.10.0 is the first
  release, installed and working on the phone.
- **Releases are started by the user** (Actions → Release → Run workflow).
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

- [x] ~~After 12e: **explain to the user in plain terms** how locked notes~~
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
    the bottom (the user's shape); included in backups (backup format 3).
15. [x] **Other → Counters (O1, O2).** Included in backups (format 3).

### Round 3 — feedback from using 0.12 (2026-10-09)

the notes, grouped. Proposed order: small fixes first, then the
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
  No light theme.

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
  of the screen height). (after using 0.13: the old snap felt
  odd, sometimes didn't snap, and sometimes snapped instead of
  scrolling.)
- [x] **Planner day strip: live preview** — the day in the middle is
  selected while swiping (header and timeline follow), not only on
  letting go; a fixed frame marks the middle slot ("fast and
  dynamic", smoother like before).
- [x] **Planner: 00:00 label cut off** — small inset above the timeline.
- [x] **Theme switch flashed the old theme** on the next page: the theme
  change was animated (200 ms) and the palette switched half-way; now it
  switches at once.
- [x] **Clay closer to the Claude app** (too light, orange off):
  Anthropic's brand colours — background #141413, accent #C96442, text
  #FAF9F5 / #B0AEA5. Tune with a screenshot if still off.
- [x] **Reach mode everywhere it makes sense** (G14): the menu, Security,
  Backup, Themes, Settings; an architecture rule flags plain scrolling
  lists in pages, with a short list of explained exceptions.
- [x] **Swipe right along the bottom bar opens the menu** (G15).
- [x] **Forgot master password → reset** (L7): deletes locked notes and
  the content of locked sections (the user chose this, so a section lock
  can't be bypassed by resetting); everything else stays.
- [x] **Notes: undo / redo while typing** (N8): ↶ / ↷ in the editor;
  typing bursts and pastes are steps; Discard can be undone too.
- [x] **Shop: scroll to an item as it's added** (S6).
- [x] **Džoni: hidden reset / set of the count** — long-press the page
  title.

### Goal: v1.0.0 — the version the user starts using for real (2026-10-12)

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
   missing; a short phone test list for review.
3. [x] **The app's own icon**: an 8-bit pixel character of our own,
   replacing Flutter's logo (launcher icon and the notification icon's
   look checked).
4. [x] **Last pass before v1**: a read through everything that saves
   (D6's remaining part: updates, crashes while saving, a full disk),
   the Introduction checked against the app, the docs tidied.
5. [x] **Release v1.0.0.** (13 Oct 2026) Then the user clears the test data (Settings →
   Clear data) and starts using it.

**After v1** (v1.x / v2, roughly by size):
- **Notifications page** in the menu (E3, Round 23): recent ones (today
  and yesterday) that open their page, a clear button, and the
  notification settings: sounds per kind, picked in the app (E2;
  Android's own per-channel settings work meanwhile).
- More Markdown and a formatting bar (N17, Round 20).
- **Automatic backup** to a folder the user picks (D8, second part), then
  a self-hosted cloud backup (D5).
- [x] **Food tracker** (O14): built in Round 46 (1.13.0).
- **Bills** (Round 45): what he pays every month. The next new
  Hub page after the food tracker.
- **Page organizer** (O10): a quick-access menu from the right side
  with pages picked for it, maybe sections in the Hub, later pages for
  The user's servers and connectors to his projects. Built on O9, so it
  adds places to put pages, not a rework.
- New Hub pages (see *Later / ideas*), **Recipes first** (Round 27): birthdays & yearly dates, days
  since / until, coin flip / decision helper, life percentage, recipes,
  workout log, timer, habits, weight log, expenses, packing lists, a
  converter.
- UI polish (U1): animations, shake on a wrong password, transitions.

### Round 130 — fix: no way in during quest work (2026-10-30, 2.1.2)

- [x] Pip Home opened in quest hours played his way in (from the sky)
  before his work, which only starts once he's free. Now, as on his
  adventure, no way in: he's simply at his work. Test in
  `pip_room_quest_test.dart`.

### Round 129 — fix: the menu's room picking up a stale doing (2026-10-30, 2.1.1)

- [x] A battery given in the menu, then quest hours' work started from
  Pip Home before it was done: back in the menu he finished the battery,
  then snapped to his work. A room opened again on him left mid-doing
  now finishes it first (as a still room does), so he's straight at his
  work. Test in `pip_room_quest_test.dart`.

### Round 128 — Pip's quests: his house his home (2026-10-30, 2.1.0)

- [x] Once the house is built (`PipLifeNotifier.houseBuilt`) he lives
  in it but for his field's times (`PipQuest.fieldTimes`, 11:30–12:00
  and 18:00–19:00), his adventure, a ski trip and quest work
  (`PipLink.homeNow`, checked by his room every second).
- [x] `PipBrain.home`: in or out when he's free; on the floor between
  the walls (`homeLeft`/`homeRight`); his own events there (a dance, a
  window, the fire); his field's things held off (`fieldOnly`, Pip Home
  says *Not in his house*); in up through the floor; his station by a
  wall; no tent, umbrella or puddles. The room draws his own things on
  the floor and the weather outside the house's outline; windows dark at
  night.
- [x] Docs, intro, full suite, release 2.1.0. Decisions and
  simplifications in `docs/QUESTS_SPEC.md` section 15.

### Round 127 — Pip's quests: the scenes and quest hours' rules (2026-10-30, 2.1.0)

- [x] `core/pip_quest_scene.dart`: `QuestView.of` — where he is and what
  he's doing from the step and the seconds into it (walking out and
  home across the field, felling, breaking stone, digging, building
  with materials flying in and dust, the scaffold, smelting).
- [x] `PipActivity.questing` (only sleep or running out start during
  it), `PipLink.questNow`, `widgets/pip_quest_paint.dart` (the house
  area, forest, mine and beach; a lantern after dark; the fireplace's
  glow); the menu's narrow room follows him across the house area.
- [x] Quest hours' rules: no station, no events, the medicine pill
  while he works, a **rain hat** in the wet, no umbrella, tent,
  puddles or snowman; Pip Home says *He's at work*.

### Round 126 — Pip's quests: Pip Home (2026-10-30, 2.1.0)

- [x] The Quests row and card (Start in quest hours, the bar, what he's
  doing, done about, the finished quests with the framed picture), the
  inventory card between the status and the settings; Pip Home opens on
  the quest card while he works.
- [x] `core/pip_house.dart` and `widgets/pip_house_art.dart`: the house
  drawn piece by piece from the script's progress (nothing floats), its
  tall tree by season, the places he gathers in.

### Round 125 — Pip's quests: the rules (2026-10-30, 2.1.0)

- [x] `core/pip_quest.dart`: quest hours (10:00–11:30, 19:00–20:30),
  the windows between two moments, the finish estimate; the **house's
  script**: 25 pieces in the decided order, each gathered for first
  (trips: out, gather up to a load, back), glass smelted in the
  fireplace before the windows; about 61 days of quest hours (a test
  holds it to 55–65); where it is after some work minutes (step,
  minutes into it, inventory, what's built, the card's line).
- [x] `PipLife` v4 (`quest`, `questsDone`), `pip.json` v4, backup v33,
  fixtures `v33`.
- [x] `PipLifeNotifier`: offered, started in quest hours only (not away),
  work minutes counted from the clock (powered down and away left out;
  settled before any energy change, as adventures are), finished with
  the moment of its last minute; `questAt` and `questWorkingAt` for the
  UI rounds. Charging keeps its energy rule; only his trip to the
  station is left out in quest hours (the scenes round).
- [x] Pip Home and the scenes: Rounds 126–128.

### Round 121 — Pip's quests: the spec (2026-10-30)

- [x] The user's notes on quests turned into `docs/QUESTS_SPEC.md`
  (Build a house: quest hours 10:00–11:30 and 19:00–20:30, a script
  worked out from the clock, materials, the house piece by piece,
  weather and seasons, the finished house as his home) and drafts
  (`docs/pip_house_drafts.png`). Answers: no charging in quest hours;
  a lantern at night; a rain hat in rain, snow and storms; a drawn
  framed picture; the charging station where he is.
- [x] Round 122: nothing floats (built bottom-up, each block on one
  below); the house redrawn, Terraria-like and detailed; adventures as
  they are (the house only when he doesn't go).
- [x] Round 123: no outside stone or furnace: a fireplace inside smelts
  the glass, its flue through the roof; a larger porch (deck, roof,
  bench); the house area's tree is his field's own; wood from a forest,
  stone from a mine, sand from a beach.
- [x] Round 124: the house area's own tall tree, by season; wooden
  stairs and porch posts (no stone slab); a denser forest; the mine in
  a mountain on the right.
- [x] The spec and drafts approved (Round 124).

### Round 120 — v2.0.0 (2026-10-29, 2.0.0)

- [x] Round 116's notes: Delete on a date a full button; Pip Home without
  the how-to hints (tap the field, tap him three times).
- [x] The v2 list checked: all in, the page organizer moved to later;
  older open items that were done since ticked off. **2.0.0** released.
  Next: Pip's quests, specced with the user first.

### Round 119 — converter feedback (2026-10-28, 1.46.1)

- [x] Units always shown (a label, not a suffix that only shows while
  typing), with their names; groups ordered temperature, length,
  weight, volume, speed, cooking.

### Round 118 — the unit converter (2026-10-28, 1.46.0)

- [x] Picked from the leftover ideas (the rest deferred: days since /
  until, timer, workout log, weight log, expenses, decision helper, life
  percentage; no habits; UI polish and cloud backup later). A Hub page
  of unit pairs, two boxes each, either filling the other; nothing
  stored. `core/units.dart`, `pages/hub/converter.dart`.

### Round 116 — notes from using the patches (2026-10-28, noted)

- [x] Delete on a date (the Dates page) as a full button, like Delete
  person, not a text button.
- [x] Pip Home: drop the hint text about three taps waking him and
  tapping the screen to feed him.

### Round 115 — People: one line between siblings (2026-10-28, 1.45.1)

- [x] `PeopleBook.drawsSiblingBar`: no sibling bar when they share a
  parent (the parents' line already joins them).

### Round 114 — People: drag alone, relations follow (2026-10-28, 1.45.0)

- [x] A drag moves only the one dragged (`familyPull` removed).
- [x] `relate` adds what follows: a parent for a child's siblings, a
  new sibling's parents; refused ones skipped; `lastAlso` for the toast.

### Round 113 — People project birthdays into Dates (2026-10-28, 1.44.0)

- [x] *From Dates* copies the day only, the original left (it was taken
  over and renamed); `Person.inDates` (on by default, stored only when
  off): off removes the projected date, on makes it again.

### Round 112 — People: whole names zoomed out, double tap to zoom (2026-10-28, 1.43.4)

- [x] Names on two lines again at every zoom; a font shrunk until the
  longest word fits the box (`_fitWords`), so names break between words.
- [x] Double tap, hold and move to zoom (down in, up out, about the
  tapped spot); the second tap within 300 ms and 40 px of a quick first.

### Round 111 — People: face size zoomed out, star on the corner (2026-10-28, 1.43.3)

- [x] Zoomed out the text grows up to 1.6× (was 2.2×), the name on one
  line past 1.3×, and the face stays 78 unless room runs short; the
  main person's star on the box's top-right corner.

### Round 110 — People: zoom handle, soft movement (2026-10-27, 1.43.2)

- [x] A zoom handle in the board's corner (down out, up in, tap 100%).
- [x] People on damped springs (one soft overshoot) with a squash along
  their speed; a dropped person held where left until the book catches
  up. The note stays out of Edit (view only), as built in Round 109.

### Round 109 — People, first fixes (2026-10-27, 1.43.1)

- [x] Board: one box size for all; text grows and faces shrink zoomed
  out; cake spacing; the pinch-then-one-finger jump (a gesture only
  starts a drag from a fresh single finger, else pans from where it is);
  a main person (star, opened on) and a family highlight; the options
  menu (center on main, highlight family, Tidy); no toast after Tidy.
- [x] Panel: the new edit layout; Discard (snapshots of People and
  Dates at Edit; back asks, Done doesn't); asking before a birthday is
  removed; the Dates birthdays list scrolls; the note at the end, as
  Markdown, written on `pages/hub/person_note_page.dart`; swipe down to
  close; no Undo toast after Delete.
- [x] Settings: Hide People notes (the password to show them). Dates:
  Year known locked for a People birthday; default reminders on one
  made in People.

### Round 108 — People built (2026-10-27, 1.43.0)

- [x] Avatar drafts approved; the page built from `docs/PEOPLE_SPEC.md`:
  `models/people.dart` (people, relations, `whyNot`, `familyOf`),
  `models/people_layout.dart` (`tidyLayout`, `generations`,
  `familyPull`), `providers/people_provider.dart` (saved as changed;
  the birthday kept in step with its date in Dates; `takeBirthday`;
  relate, the picked one brought near; remove with Undo; Tidy),
  `pages/hub/people_board.dart` (pan, pinch zoom, tap to centre, drag
  with the family's pull from where the finger went down, glide, lines
  drawing in), `pages/hub/people_panel.dart` (info, edit, relation and
  person pickers), `widgets/people_sprites.dart` / `people_avatar.dart`
  (the 14 faces). Dates: a linked birthday marked, its title, day, year
  and type locked, no Delete. people.json v1, backup v32, fixtures. The
  shared choices sheet now sizes to its choices (six overflowed a short
  screen).

### Round 107 — the People spec and avatar drafts (2026-10-27)

- [x] `docs/PEOPLE_SPEC.md` written, questions answered; faces drafted
  (`docs/people_avatar_drafts.png`) and approved.

### Round 106 — the rain radar (2026-10-27, 1.42.0)

- [x] a key option in Internet Access with a note ("for more
  advanced weather use your own"); no direct links, a copy icon; the
  key in encrypted backups only (settings turned out not to be in
  backups at all: it never leaves the phone); no test week. Tomorrow.io
  realtime (`TomorrowIoApi`), checked once on paste; its rain or snow
  wins, dry keeps Open-Meteo's sky, failing falls back with the reason
  shown; fetched every 15 minutes with a key.
- [ ] Watch it in the next rain.

### Round 105 — feedback on 1.41.0 (2026-10-27, patch 1.41.1)

- [x] "Export for agents", not ChatGPT; a better icon for the Import /
  export button (`Icons.sync_alt`, ⇄; it was `import_export`).
- [x] Weather (v2 item 3), proposed to the user (built in Round 106): no free API is
  station-only; the rain-now fix is a radar nowcast. Proposal: a
  provider seam in `data/weather_api.dart`; Open-Meteo stays for
  temperature, wind and the day's codes, and "raining now" comes from
  a radar-based nowcast (Tomorrow.io or Rainbow.ai, free key, his key
  typed in Internet Access); first a week's side-by-side log in debug
  to pick the one that matches Belgrade. Waiting on his answer.

### Round 104 — recipe import / export (2026-10-26, 1.41.0)

- [x] "export for import and export for agent"; text only
  (import is paste, export is copy); an extra button on the Recipes
  page; import makes a new recipe, export picks one from a list.
  `providers/recipe_transfer.dart`: `exportRecipe` (JSON:
  `format` "the-app/recipe", `version` 1, the recipe with each
  ingredient's section), `exportForAgent` (what to answer, the rules,
  his ingredients by section, the example), `parseRecipe` (the JSON from
  the first `{` to the last `}`, so an agent's words and fences don't
  matter; the recipe alone too; a newer version refused), and
  `importRecipe` (`IngredientsNotifier.ensure`: an ingredient there by
  name, or added to its section, made if new). A confirm lists what's
  new to the ingredients first. `pages/hub/recipe_transfer_sheet.dart`.

### Round 103 — feedback on 1.40.5 (2026-10-26, patch 1.40.6)

- [x] Packing, an item's options: Count first, then Rename.

### Round 101 — the road to v2, then Pip's quests (2026-10-26)

**v2.0.0** — productivity and the tasks left open, before anything
big for Pip:

1. [x] Recipe edit keeps its scroll (Round 100; 1.40.5, Round 102:
   the view's offset opens edit there, edit's comes back).
2. [x] Recipes: export / import as text (Round 104; 1.41.0).
3. [x] A better weather API (Round 99): the rain radar, Round 106 (1.42.0).
4. [x] People: an index of people, notes, a family tree (Round 100;
   planned with the user first). Spec: `docs/PEOPLE_SPEC.md` (Round 107),
   waiting on his answers.
5. [-] Page organizer (O10): not in v2 (Round 117). The right-side
   panel isn't wanted; it comes back once the user's own services are
   linked, as the place for their special pages.
6. [x] Other productivity ideas the user brings: the unit converter
   (Round 118); the rest of the ideas list deferred (Round 118).

Released as **2.0.0** once these are in: **released 2026-10-29
(Round 120).**

**After v2: Pip's quests** (a plan, to be specced with the user before
building; big). Open questions: what a quest is (given by the app,
found by him, tied to what the user does in the app?), how long, what it
gives (XP, items, hats), how it's shown (Pip Home card, a log), and how
it fits his adventures and the old Godville-style items and events log
ideas (Rounds 26 and 30).

### Round 100 — the notes (2026-10-26)

- [x] **Recipe edit keeps its scroll**: starting and ending edit on a
  recipe jumps back to the top; it should stay where it was.
- [x] **People** (new Hub page, to plan with the user first; built in
  Round 108): a big index
  of people he knows, notes on each, and a **family tree** with a good
  visual overview.

### Round 99 — feedback on 1.40.4 (2026-10-21, noted)

- [x] **Rain heard, Pip dry** (W1/O36; the rain radar, Round 106): Belgrade raining, the app said
  cloudy. The user's own Open-Meteo check (01:30): `weather_code` 3,
  `precipitation` 0, `rain` 0: its model saw no rain at all, so reading
  precipitation won't help. **Switch to a better weather API** (one
  that uses station / radar observations for "now", not only a model):
  compare candidates (free tier, key or not, Serbia coverage, terms)
  and propose before building; keep `WeatherReport` and the Internet
  Access page as they are, only `data/weather_api.dart` changes.

### Round 98 — feedback on 1.40.3 (2026-10-21, patch 1.40.4)

- [x] **Buzzes through Pip's animations** (O42): "make us use vibration
  often, everywhere where it makes sense (like battery drop)". The brain
  queues a `PipBuzz` as an animation's clock passes a mark
  (`_passed`, `_buzzOn`): light for hops landing, small hits and steps,
  medium for thuds (the battery drop, the old one landing, falling over,
  plugging in and out, the snowball), heavy for the new battery clicking
  in. The room buzzes for each segment charged, watched. The ball buzzes
  only on bounces faster than `ballBuzzSpeed`.

### Round 97 — feedback on 1.40.2 (2026-10-21, patch 1.40.3)

- [x] **Changing his battery, livelier** (O24): the new battery bounces
  on landing (`bounceHeight`) and glints while it waits
  (`batteryGlint`); he stands `batteryGap` off it, so the old one pulled
  out isn't over it; the old one (no red bit: `batteryEmpty`) is thrown
  over his head to his other side (`_oldBatteryLands`), lands with a
  puff of dust (`batteryDust`), lies, fades; a crackle of sparks at the
  slot as the new one clicks in; a shake, then a hop with sparkles
  (`shakeEnd`, `pickEnd` 3.45). "the batteries overlapping"
  (old over new) gone. The Animations entry was there already (plays
  when full, no energy): a test now says so.

### Round 96 — feedback on 1.40.1 (2026-10-21, patch 1.40.2)

- [x] **Packing's edit mode**: sections dragged by the right of their
  heading, as Ingredients' (a line where it'd go, the list scrolled at
  its edges; `PackingList.sectionMovedTo`); no Move up / down. **Add
  section** a button by Done. **+ Add** the whole width. "Its 1 item
  goes with it". An item let go between "+ Add" and the next heading
  settled there, then snapped into the section above: the first heading
  is above the reorderable rows, the last "+ Add" under them, and each
  other "+ Add" shares a row with the next heading, so every gap is
  where it lands.

### Round 95 — feedback on 1.40.0 (2026-10-21, patch 1.40.1)

- [x] **Packing, his changes** (O41): each list has its **own sections**
  (`PackingList.sections`, packing.json v2, backup v31; Round 94's lists
  get the shared ones), edited in its edit mode (a heading's tap:
  Rename, Move up/down, Delete with its things, asked; Add section at
  the end; at least one; Other is a normal one). The Sections page is
  **Default sections**, what a new list starts with. **+ Add** under each
  section. A new list is **New list**, kept once something's in it, and
  Done goes back to the lists. Back asks **Save or Discard**. No Undo /
  Redo / Discard button: held things are selected and deleted. View rows
  a normal size, every section shown, Reset asked (no toast). Copy list
  back to the lists. Typing the name bounced the page (asked room above
  it at the list's top, as a recipe's in Round 64): `scrollPadding` top 0.

### Round 94 — feedback on 1.39.0 (2026-10-21, 1.40.0)

- [x] **Packing lists** (O41): a Hub page (`HubTool.packing`, lockable,
  Clear data) of lists (`models/packing.dart`, `packing.json` v1, backup
  v30, partial restore). the answers: several lists as cards;
  sections shared by every list, starting as Documents, Clothes,
  Toiletries, Electronics, Medicine and Other (always last), editable on
  their own page; a count only (×2); ticked ones don't move; **Copy
  list** asks the name and which sections to take. View mode: a big box
  per row, a tap anywhere ticks, Reset (Undo), progress. Edit mode like a
  recipe's (saved as made, Undo, Discard changes, Done): a section's +
  adds several in a row, a tap renames / counts / deletes, the handle
  drags into another section too. Not tied to Dates.
- [x] **Spotify**: its page drops "may not start if Spotify was closed"
  (the user tried it: it starts).
- [x] Next: the recipe import/export (done in Round 104).

### Round 93 — feedback on 1.38.2 (2026-10-20, 1.39.0)

- [x] **Spotify in the morning** (O40): a Hub page (`HubTool.spotify`,
  no lock, nothing to clear) with on/off, time, days and volume, kept in
  `Preferences.morningMusic`; `morningMusicSyncProvider` sends them to
  Android (`the_app/morning_music`) at start and on each change;
  `MorningMusic.kt` keeps them, sets an exact alarm for the next time,
  and on it sets the music volume, presses play (`KEYCODE_MEDIA_PLAY`)
  and sets the next; `BOOT_COMPLETED` / `MY_PACKAGE_REPLACED` set it
  again. No play button.
- [x] Next: Packing lists came first (Round 94); then the recipe
  import/export.

### Round 91 — feedback on 1.38.0 (2026-10-20, patch 1.38.1)

- [x] **Save or Discard** on back, as a note's, for the pages saved as
  typed: Subscription, Date, Meal (`widgets/discard_scope.dart`: changed
  since it opened, Back asks; Discard restores it, or deletes a new one;
  a tap outside stays; a meal's open food list closes first). Medicine's
  sheet and a recipe's edit mode had their own already.
- [x] **Calendars**: open on the day set, today when none (Round 87
  went too far: all on today). A new subscription's default day (a month
  on) counts as not set until picked; the month picker on its year.
- [x] **Pip's station**: a segment every **8 s** watched.

### Round 90 — feedback on 1.38.0 (2026-10-20): notes, plan (waiting for a go)

Fixes (a patch):
- [x] **Medicine, hold to take** (1.38.2): once the hold has started (and once
  it's filled) the dialog can't be closed (no tap outside, no Back, no
  Cancel), and the take registers the moment it's full (a case where it
  filled and the take was lost).
- [x] **Ingredients: no two of the same** (1.38.2) (name, case and spaces
  ignored), when adding or renaming; says where it already is.
- [x] **Ingredients' sections** (1.38.2: a `Draggable` on the right
  edge; rows found by the finger's height, a line between sections)
  dragged only from the right edge, where
  a handle would be; the drop no longer dips and snaps back.
- [x] (1.38.2: `widgets/low_handles.dart`, on every field, checked by
  the architecture test) **The lowered selection-handle grab area** (Round 74, Notes and
  the recipe method only so far) on every text field in the app.

Features:
- [x] **Recipes: export / import** (Round 104) as JSON (to have ChatGPT write new
  ones in the same shape): the recipe (name, prep minutes, type, method
  in Markdown, ingredients with quantity and section) plus every
  ingredient name by section, so a new recipe can use the names there
  are; pasted in when adding a recipe, it fills everything, and
  ingredients not there yet are added to their section (a new section
  if needed), after a summary to confirm.
- [x] **Packing lists** (Round 57's order had it second, after Dates;
  missed when asked "what's next"): built in Round 94 (1.40.0).

Question: Spotify in the morning (answered: an alarm can send a play
key to Android's media session; or the Clock app's Spotify alarm).

 (2026-10-20, 1.38.0)

- [x] **Subscriptions' cards held and dragged** to a new place, as the
  Hub's tiles (`LongPressDraggable` / `DragTarget`, taking the place of
  the card under the finger at once; Move earlier / later for screen
  readers). The page shows the list in its own order (`moveTo`; a new
  one last); the by-state order is gone (the user's were already in his
  note's order).

### Round 88 — feedback on 1.37.4 (2026-10-20, patch 1.37.5)

- [x] **Pip's station**: a segment every **15 s** watched
  (`PipBrain.chargeEvery`, was 30).
- [x] **Tap outside a field** lets it go, app-wide: a translucent
  `GestureDetector` at the app's root (`MaterialApp.builder`, out of
  semantics) unfocuses on a tap nothing else takes (fields, buttons and
  rows keep theirs).
- [x] A subscription added after another: its calendar opened on next
  month (its default day) — fixed by 1.37.4's today-first calendars.
- [x] **Subscriptions' cards moved** by holding and dragging (Round 89,
  1.38.0).

### Round 87 — feedback on 1.37.3 (2026-10-20, patch 1.37.4)

- [x] **Calendars open on today** (they seemed to carry on where
  one was last, for other things): every date picker goes through
  `widgets/date_pick.dart`'s `pickDate`: today's month (or the nearest
  allowed), today marked, the set day picked only if in that month; the
  month picker opens on this year, the set month marked in its own.

### Round 86 — feedback on 1.37.2 (2026-10-20, patch 1.37.3)

- [x] **Month picker** squished (four chips across): three across, four
  rows, 44-high buttons 8 apart (the picked one washed and edged in the
  accent); checked narrow with large text.

### Round 85 — feedback on 1.37.1 (2026-10-20, patch 1.37.2)

- [x] **Subscriptions' card lines**: icons centred on their text's first
  line (they sat high), at any text size.
- [x] **Card expiry: a month**, no day: `showMonthPicker` (a year with
  ‹ ›, twelve months), "expires 10/26" kept on one line, good through
  the month's last day (stored as it; an older day reads as its month).

### Round 84 — feedback on 1.37.0 (2026-10-20, patch 1.37.1)

- [x] **Subscriptions**: a card's expiry on the card is **orange** a week
  or less ahead (the day itself included) and **red** once gone by
  (`Subscription.cardExpiryOn`, `cardExpiryLabel`); checked in the themes.
  A notification for it was planned, then dropped.
- [x] Not wanted for now: missed blocks' prompt, Shop's un-tick place,
  Pip's inventory, his events log. Cloud save: a project of its own.
- [x] Stale boxes ticked: the angry animation's hand (Round 79), Skiing
  holidays (Round 72).

### Round 83 — feedback on 1.36.3 (2026-10-20, 1.37.0)

- [x] **Tavern**: Pip sits on the bench (his body on its top, his feet
  over its front; `seatHeight` 2, was 3: standing on it), centred under
  him (`benchLeft`, drawn off the grid as he is).
- [x] **Planner**: new blocks and routines remind **at their start** by
  default (the add sheets' `remind: 0`).
- [x] **Planner: Move to another day** in a block's menu (P28): a date
  picker (next day first; tomorrow for a missed one), its time kept if
  free, else the nearest free time as long (`fitTime`) after a *That time
  is taken* dialog saying to what; Undo moves it back
  (`PlannerNotifier.moveTask`).
- [x] **To-do**: un-ticked, a thing goes back to its place (waiting
  again if it was) unless the things to do changed meanwhile (added,
  moved, done, set waiting); else the end, as before.

### Round 82 — feedback on 1.36.2 (2026-10-20, patch 1.36.3)

- [x] Notifications are private only when set Private, not because the
  page is locked (the planner's "on now" said "A block is on").
- [x] The planner's "on now" notification can be swiped away: since
  Android 14 an ongoing notification can be dismissed (only a foreground
  service's can't); it comes back when the app opens. Kept so (a
  foreground service for it isn't worth it, nor allowed for this).

### Round 81 — feedback on 1.36.1 (2026-10-19, patch 1.36.2)

- [x] A field being typed in lets go when a date or time picker opens
  (Subscriptions, Dates, the planner's sheet, Medicine, Food): the
  keyboard used to come back once the picker closed.
- [x] Chips: no tick (poor contrast, worst on the state's dot); the
  picked one is a wash of the accent with an accent edge (`chipTheme`,
  checked in all eight themes).

### Round 80 — feedback on 1.36.0 (2026-10-19, patch 1.36.1)

- [x] **Subscriptions**: the card that pays it: its name stays, and its
  **expiry date** (`cardExpires`, optional in subscriptions.json v1);
  shown on the card, "Card expires before it renews" in red when it runs
  out before the next renewal (`cardRunsOutOn`).
- [x] **Cards**: normal ones (rounded, a light tint, a thin outline, the
  state a pill): no thick left edge.
- [x] **Weather off**: the trees stand still (`PipWind.of`: not known is
  calm).
- [x] **Patches** keep their minor version's changes in What's new (as
  since Rounds 48/70); written into `docs/RELEASING.md`.

### Round 79 — the notes (2026-10-19)

- [x] **Pip's trees**: sway only in the wind. Open-Meteo's wind (km/h at
  10 m, `wind_speed_10m`) comes with the weather: under 12 still, 12–30
  a light sway, 30 and over (or a storm) hard (`PipWind`). With the
  weather off (the wind not known), a light sway as before (Round 80:
  still).
- [x] **Angry**: his fist went too far from his body (over his head,
  shaken out sideways): now beside his head, a pixel off his casing,
  shaken up and down.
- [x] **Subscriptions** (the note): a Hub page
  (`docs/SUBSCRIPTIONS_SPEC.md`): two-column cards tinted by state
  (active, to cancel, cancelled, inactive), price (~), card, note, a
  reminder before shown on the card; notifications on its day at 09:00
  and before; a month's total; a red dot when one's to be cancelled soon.

### Round 78 — feedback on the planner (2026-10-19, 1.35.0)

- [x] **Routines**: no confirm/check any more (no box, no Done on their
  notification); they're just there, and not shown on past days.
- [x] **Blocks**: a ticked-off block on a past day is deleted
  automatically (on opening or coming back to the app; at once if
  ticked on a past day, with Undo).

### Round 77 — the wake-ups (2026-10-19, 1.35.0)

- [x] **Night wake-up** (Round 62): three taps on him asleep (each
  within 0.8 s of the last) wake him for **15 minutes**, once a night
  (`PipEnergy.mayWakeAt`, `nightKey`; `PipLife.wokenAt`, optional in
  pip.json v3); one eye opens first (`PipActivity.stirring`, face
  `peek`), then the usual wake; drowsy (face and pace as at one segment)
  till he falls asleep again. Batteries and his station work while up.
- [x] **Early wake-up** (from 07:00): three taps then wake him
  for the day (not drowsy). His energy goes as asleep either way.

### Round 76 — feedback on 1.34.0 (2026-10-19, patch 1.34.1)

- [x] Out, knocked over: the trees stand with the ground (they kept
  going by his time out); they catch up as he runs on (up to half as
  fast again, or put in place if 20 s off), so every room still agrees.
- [x] His sword flying off: an arc, two turns and a quarter, landing flat
  and never into the ground (`PipRun.swordBelow`).

### Round 75 — feedback on 1.33.0 (2026-10-19, 1.34.0)

- [x] **Trees**: the pine (green all year) rare, about 5%, but 60% in
  winter; both trees the same kind but now and then (10%); the same
  when the field moves out on his adventure.
- [x] **Weather idling** (`core/pip_weather.dart`, one table of what each
  weather does in each thing he's doing): a **storm**, his tent (over
  sleep or being off too; events wait; batteries fly into it); **rain**,
  his umbrella, puddle jumps, a twirl; **drizzle**, a hand out; **snow**,
  a snowman (stays, melts after), flakes, a snowball splatting on the
  glass; **fog**, slow, lost. The weather comes in and he looks up.
- [x] **On his adventure**: a storm's tent by the path; snowmen in the
  snow; slower in fog, foes looming; splashes in the rain.
- [x] All in Pip Home's **Animations** (each trying its weather on).

### Round 74 — feedback on 1.32.0 (2026-10-19, 1.33.0)

- [x] **Handles** (notes): the grab area from the icon outwards; on the
  text's side of it a sliver (2 px).
- [x] More than one look for **trees**: oak, birch, pine (random per spot
  per app open).
- [x] The **tavern break**: he eats (bite by bite, a hand to his mouth;
  sips at the hut), sits still (no "squats"); a nicer tavern, table and
  bench.
- [x] The menu's Pip and Pip Home's **out of step** at the break (trees
  elsewhere): the trees go by his time out, from his life.

### Round 73 — feedback on adventures (2026-10-19, 1.32.0)

- [x] Watched, his **XP goes up as he strikes bugs** (each collects
  what's gained since; "+N XP" rises). XP is now ten a minute, so most
  bugs bring one or two.
- [x] Pip Home's **adventure view**: a switch on the first card; opens
  on it while he's out; his adventure card alone (no Animations card);
  later more adventure cards (the inventory).
- [x] **Foes**: beetles (2 strikes), spiders (3); a **boss** (6) once a
  day out if he's watched, worth 50 XP; a Boss preview.

### Round 72 — feedback on 1.28.1 (2026-10-19)

Now: the planner's notification that stays (done), small fixes (Dates'
sections and bell). Pip (done in 1.31.0):
- [x] **Bus**: the window isn't his whole face; a **bigger bus**, him
  seen in a window; the roadside trees not on the road.
- [x] **Skiing** (seen in Pip Home's previews): he should ski **down**,
  not walk left and right on a layer of ground; the trees should come
  up from the bottom of the screen and go up till they vanish at the
  horizon.
- [x] **Adventure** (previews): the bugs seem to **teleport**.
- [x] A better **ski beanie**.
- [x] **Trees**: a lot bigger, more detailed, in a random spot each time
  the app opens (not always one in view and one peeking in).
- [x] **Rain**: a better effect (slanted streaks in two layers,
  splashes).
- [x] **Christmas**: not 20 Dec–7 Jan; just **New Year's Eve** (all
  31 December, to 02:00), and the **Orthodox Christmas (7 January)**
  with its own look: a badnjak in straw, a lit candle. (The Santa hat,
  25 Dec–2 Jan, is a hat of the year's, not the background's: kept.)
- His question: the longer wake-up (yawn and stretch) was done in
  1.18.0; still open: **Night wake-up** (three taps at night wake
  him for 15 minutes) and **Early wake-up** (from 08:00).

### Round 71 — feedback on 1.28 (2026-10-19, patch 1.29.1)

- [x] **Shop search** button beside **+** (G11), not in the top bar; it
  filters **only the bought list** (as asked in Round 64); its icon and
  text aligned. The user asked whether this was sloppy: it was, both rules
  were written down (G11, and the ask itself). The architecture test now
  fails on any top-bar action, so it can't slip through again.
- [x] **Notes, Select all**: the copy/paste menu didn't come back in a
  long note (left at its start, scrolled away).

### Round 65 — feedback on 1.25.0 (2026-10-18)

- [x] **Batteries while he's out**: a tap gives one; it flies to him and
  he catches it running. Registering fills his energy (as built).
- [x] **Skiing**: spec in `docs/ADVENTURES_SPEC.md` section 8; built
  in Round 67.

### Round 67 — the answers on skiing (2026-10-18)

- [x] Skiing as in `docs/ADVENTURES_SPEC.md` section 8: slope B; travel
  hours and leaving times in Dates (there 06:00 on the first day, back
  11:00 the day after the last); no skiing on a day the bus is on the
  road in 12:00–18:00 (XP still); batteries pile up on the trip; his
  gear always shown on ski days.
- [x] Pip Home: an **ADVENTURES** previews list (Adventure, Skiing, Bus
  trip), no XP, stops when swiped back.

### Round 66 — feedback on the skiing spec (2026-10-18)

- [x] **Break only on a fresh look**: not while he's watched (setting
  off, or back on with a battery); after five minutes unseen.
- [x] Pip Home: "Not an adventurer yet" and "Come back between..." ran
  off the card on a narrow phone: they wrap.
- [x] Skiing answers in the spec: snow all ski day, ski beanie
  (birthdays win), flags and bumps at random, falls every 40–90 s, no
  skiing unless registered; his **gear** in the field, picked up first;
  a **bus trip** there and back (travel time in Dates), the slope to
  pick from drafts (`docs/pip_ski_slope_drafts.png`).

### Round 64 — the notes from using the app (2026-10-18)

Noted; adventures first (go given), the rest after.

- [x] **Medicine history** (Round 62, not done yet): changing a take
  time rewrites the history's times.
  Not a bug (Round 68): the time shown is the dose's daily slot.
- [x] **Adventure break** (`docs/ADVENTURES_SPEC.md`): half an hour off
  during the adventure, only for looks (XP goes on). If the app is
  opened between 14:00 and 16:00 and he hasn't had it, it starts then,
  so it's seen. He comes to a **tavern** (the background shifts, he
  stays centred), sits at a table, a **plate of food** pops out of the
  window onto it and he eats. Skiing: a **hot chocolate**. More break
  events later.
- [x] **Note selection handles**: the left one's grab area reaches too
  high and catches touches by accident; lower it.
- [x] (Round 79) **Subscriptions**: a new Hub page (to spec).
- [x] **Shop search**: a search button opens a field above the keyboard;
  typing filters the bought items; the list still scrolls with the
  keyboard open; closing the keyboard keeps the field (and filter), with
  a cancel button beside it.
- [x] **Shop sort**: a toggle on the bought list: alphabetical, drag
  handles hidden; again for the normal order. Items added while sorted
  still go on top of the normal order.
- [x] **Recipes**: typing the title makes the page bounce at every key.
- [x] **Recipes**: the markdown format bar for its text; and a free
  **text quantity** ("1-2") beside the pickers, which Shop takes too
  (ingredients go to Shop). Round 70: a **Text** choice in both amount
  sheets.
- [x] **Planner reminders button**: a list of all scheduled reminders,
  next first with their times, with checkboxes to delete several.
- [ ] **Hub pages ideas** (to talk through).
- [x] **Pip**: the charging station seemed to flash when the app opened
  with no charger in.

### Round 63 — Pip's adventures, the spec (2026-10-17)

- [x] Spec written: `docs/ADVENTURES_SPEC.md` (the notes: the
  Adventures button and card, register 13:00–15:00 with a sword-up
  fanfare, adventuring **12:00–18:00** as a daily activity, running and
  fighting bugs, XP from time, ~90 at a year, 160, 230, 280, then 50 a
  year; titles every 10 levels to 80; skiing later).
- [x] His answers are in the spec: register 13:00–17:00; XP bar; a hat
  box beside weapon and off-hand; no XP while powered off; he can't
  power down mid-adventure (does it after 18:00); level-up flash and
  vibration, no sound; no notifications; the register fanfare is the
  only sound (media volume), the rest is vibration; taps and random
  events off while out; he keeps his hat; bugs sometimes knock him back
  and his sword flies off, so he fetches it; skiing: snow and sliding
  down, falling now and then and fetching a lost ski.
- [x] Built (v1.25.0), with the break (Round 64). Skiing next.

### Round 62 — the notes after 1.24.0 (2026-10-17)

Noted only; not started (out of tokens).

Medicine:
- [x] **Bug**: changing a medicine's take time also changes the times
  already in its history. History must keep the time it was taken at.
  Not a bug (Round 68): the time shown is the dose's daily slot.

Pip:
- [x] (Round 77) **Night wake-up**: tapping Pip three times at night wakes him for
  **15 minutes**, once per night (so he can be charged). Special wake-up
  animation: he looks with one eye open first. During the 15 minutes he
  looks tired, like at 1 battery tick, then goes back to sleep.
- [x] (Round 77; from 07:00) **Early wake-up**: from 08:00 on, waking him before his usual time
  is allowed.
- [x] **Angry animation** (Round 79): his hand goes too far from his body; keep it
  closer.
- [x] **Backgrounds** (Round 70: seasons, trees, Halloween, Christmas,
  New Year's Eve, Easter, the weather; previews in Pip Home): trees,
  seasons, event backgrounds (Halloween, New Year…), weather (rain,
  snow, clouds); moving parts (trees swaying, leaves falling, snoring
  Zs, clouds drifting). No location permission.
  Answer given: real weather needs a network weather API plus a
  location; without location permission the only options are a city
  The user types once (geocoded, then a free no-key API such as
  Open-Meteo, needs INTERNET permission) or no real weather at all.
  Seasons, events, day/night and all the animation need nothing.

Internet Access (a page in the menu, second to last):
- [x] Says plainly the app uses **no internet** unless a section below
  is turned on. The release APK has no INTERNET permission today and no
  analytics or network packages; adding the permission comes with this
  page (check the merged manifest of the built APK).
- [x] One **section per service**, each with a toggle, what it is, and
  what it's used for. Turning one on opens the section.
- [x] **Weather** (Open-Meteo, no key): add a city by search, pick from
  the matches (name, region, country), saved with coordinates; several
  cities, to switch fast; "No place found" saves nothing. Fetched by
  coordinates every hour or two while the app is open; off → seasonal
  sky only. No IP location (wrong on mobile data).
- [ ] Later: **my backup server** section (API key field, Test
  connection; on success the server backup appears in Settings).
- Order: **adventures first**, then this and the backgrounds.

Dates:
- [x] **No "Year known"** for Holiday and Event (they already carry
  their year). (Done in Round 61's forms.)
- [x] **Sections**: **Today** (dates happening now, including a
  multi-day one in progress) above **Upcoming**, and **Past** at the
  end for one-off dates (anything but Birthday and Anniversary), kept
  so the date isn't lost.
- [x] **Cards**: a small bell icon next to the reminders text.
### Round 61 — the notes on 1.21.0 (2026-10-16)

Pip:
- [x] **Hats**: everyday hats at random: some days he wears one, a
  random one, all day, about **6–7 hat days a month**; mostly none.
  **Event hats**: a **Santa hat** from a week before New Year to 2
  January; more of that kind (ideas: a pumpkin/witch hat around 31
  Oct, a bunny-ears or flower crown at Easter (moves each year), a
  party hat at New Year's Eve, a heart on 14 Feb). Birthdays stay the
  party hat. An event hat wins over a random one.
- [x] The **moon**'s dark circle round it looks like an error: drop
  (or rework) the night halo. (It's a disc a little lighter than the
  sky, which reads as a dark ring next to the bright moon.)
- [x] **Hatched**: he starts with **2 segments** and **a battery** in
  hand (now: full, none).
- [x] At 2 segments he **flashes smiles** while idling. Found: a blink
  draws the eyes shut with the *normal* smile, whatever his face, so a
  tired Pip smiles for each blink. A blink should keep his mouth.

Dates:
- [x] **Holiday kinds** (Round 72), starting with **Skiing**: during its days Pip
  is on a **snowy mountain** (snowing all the time), dressed as a skier
  in his usual events, with ski events of his own (the coming
  *adventures* could be him skiing).
- [x] **Default reminders** for every date: **1 day before and 7 days
  before**.
- [x] Cards show **everything**: the date it's on (not "the year of the
  next one" for a birthday with a year, and nothing for one without:
  just its day), how soon, the age / which anniversary / how many
  years, how long it lasts, its kind (skiing...), the birth year if
  known, and its **reminders** when set. Not "every year" or "year
  known" as such.
- [x] **Each type its own form and defaults**: Birthday and
  Anniversary: every year, year known on (Birthday: "Year known — for
  the age"; Anniversary: "— for which anniversary"). Holiday and Event:
  no Every year / Year known (a date with a year; Holiday has its kind
  and length). Notes and wording per type.
- [x] Event kinds, e.g. **Wedding**: its own default reminders (a week
  and a month before), set only if the reminders weren't touched.

App:
- [x] **Notifications** vanish from the tray when the app opens.
  Found: every replan (each app start, any change) calls the plugin's
  `cancelAll`, which also clears notifications already shown. Should
  cancel only what's planned (ids apart from shown ones), so a shown
  one goes only when its page is opened (or swiped away).
- [x] **To-do** (locked) doesn't ask for the **fingerprint** at once
  when opened (the password prompt comes first; the fingerprint is
  its alternative), unlike locked pages.
- [x] **Notes**: in a long note, selecting from the end and dragging
  the start handle up to the first line: it can't reach it, it jumps
  about (the text doesn't scroll along smoothly).
- [x] Check the **introduction** is still up to date and relevant.
- [x] Question: is the app safe for **passwords in locked notes**?
  Answered in chat: Argon2id (OWASP setting) + AES-256-GCM, the
  password never stored, the fingerprint key in Android's keystore,
  auto-lock after 5 min away, backups encrypted the same way; as safe
  as the master password is strong; not audited; not a password
  manager (no autofill, no breach checks).

Batch 1 done (1.22.0). Also found and fixed: Dates had no notification
channel, so its reminders (and every reminder after the first one) were
never scheduled. Tray: reminders get ids from what they are, a replan
cancels only planned ones no longer wanted, and each page clears its
kind's shown ones when opened (`ClearsShown`, the Planner tab, Backup;
"open the app" notices on start). Selection: `GentleRevealController`
(reveal jumps at most 12 px while a range is selected) and
`HandleEdgeScroll` (a finger held past the edge scrolls on, the
selection's end following). Locked pages: `LockedScreen(askAtOnce)`,
not when locked while open (its page closes). What's new:
`Preferences.introFrom`, `changesSince`.

Batch 2 done (1.23.0): `DateKind` (skiing, beach, trip; wedding) in
dates.json v3 / backup v25 (fixtures v25); `DateType.choosesYearly`
(Other only); per-type *Year known* wording and note hints; a kind's own
reminders (`DateKind.reminders`: a wedding a week and a month before)
replacing the usual only if untouched; cards: `whenLabel` without the
year for every-year dates, `dateDetails` (kind, days, born/since,
reminders). Holiday kinds are in; Pip skiing on a ski holiday is batch 4.

Batch 3 done (1.24.0): `core/pip_hats.dart`: `pipHatOn(day, seed)` (a
day of the year's from `seasonalHatOn`: Santa 25 Dec–2 Jan, witch 31
Oct, bunny ears Orthodox Easter Sun–Mon (`orthodoxEaster`), heart 14
Feb; else a steady per-day hash, chance 6.5/30.44, an everyday hat),
seeded with his birthday so each Pip has his own days. `PipLink.hatToday`
→ `PipBrain.dayHat`; the party hat (birthday) wins, a tried-on one over
both. New sprites: santa, witch, bunny, heart (centred, antenna covered).

### Round 60 — the user (2026-10-15)

- [x] Dates: a day's dates shown **around the date** (its circle in
  their colours, like Food's rated days) instead of dots under it;
  colours that meet split it in sections; the same colour, a border.

Done (1.21.0): `DateMarkPainter` (one colour a filled circle, several
in slices from the top, several of one colour a border, the picked day
ringed outside).

### Round 59 — the notes on 1.19.0 (2026-10-15)

- [x] Dates: a **Holiday** (and an **Event**) has a **length**: pick how
  many days it lasts.
- [x] Dates: the **+** button is on the left; it belongs on the right.
- [x] Pip keeps **charging once full**: he should stop.
- [x] 18:27, practically night outside, and Pip's sky shows the **sun**:
  it should be evening for him.
- [x] Food: **Delete meal** asks first.

Done (1.20.0). Lasting: `DateEntry.days` (holiday and event only,
`span`; 1–31), dates.json v2, backup v24; on each day, from its first
(`startCovering`; into the new year too), upcoming while it's on, its
reminders before its first day. The + was on the hand's side, taken
from the Hub tile's tap: pinned right, as Medicine's. Charging: full,
he unplugs (the station stays while plugged in). The sky: `sunTimesOn`
(NOAA's approximations at 45°N on the time zone's meridian, an hour
later in summer time); dawn 45 min before sunrise to 20 after, dusk
20 before sunset to 35 after.

### Round 58 — the notes on 1.18.0 (2026-10-15)

- [x] Pip's **hats** sit on one side of his head: centre them, as hats
  are (they were kept right of his antenna; the angry #! moves aside
  instead). The **party hat** better, a bit bigger.
- [x] Settings: the **To-do** and **Introduction** switches swap places.
- [x] Shop: adding an item that's there already **moves** it (no
  copy); with one item selected, **Rename** (between Delete and Select
  all); the add field offers **existing items** as you type.
- [x] Food, the index: the field **let go** (keyboard down) closes it;
  **back** first closes it (the field let go), a second back leaves.
- [x] Dates: **Delete** asks first.
- [x] Pip's **energy** goes far too slowly (17:00 the next day, one
  battery given, still full): a bug, or too slow. He drains a lot
  faster, a little slower than batteries can keep up with. Offset by the
  **station**: while he's looked at (the menu or Pip Home) with the
  phone charging, he gains a segment every 30 s. **Off** when the
  phone's plugged in: the station sends out a **drone** that charges
  him one segment; then he walks to the station as usual.

Done (1.19.0). The hats weren't kept aside for the angry animation:
they were put right of his antenna so as not to cover it; now they
cover it, centred (even widths, about his head's middle), and his
cross words move out past the hat. The "still full" was a bug: plugged
in, his icon kept the segments he had when the app saw the plug go in,
and after a restart that came from the saved "plugged" setting, so with
the phone charging when looked at he could look full for days. His icon
now shows what he has. Energy: 1/4 a segment an hour awake, 1/18 asleep
(about 4.25 a day against the batteries' 4.8). Also found: opened while
off and plugged in, he went straight to charging (empty, he now
doesn't; the drone comes).

### Round 57 — the next pages (2026-10-15)

Bills not now. The order: **Birthdays & dates**, **Packing lists**,
**Days since / until**, **Life percentage**, **Coin flip**, then the
**planner notification that stays**. (2026-10-16, **Life
percentage**, **Coin flip** and **Days since / until** are scrapped.)

- [x] **Birthdays & dates** (spec `docs/DATES_SPEC.md`): a calendar of
  important dates; a date has a title, a note, a type, and up to 3
  reminders (days before, time); the usual patterns (Notifications page
  settings, lock, backup, Clear data). Pip wears a **party hat** on a
  birthday. the answers: named **Dates**; a new date reminds **1
  day before**; a **green dot** on birthdays, gone once the page is
  opened; the hat on **Pip's own birthday** too (not the day he
  hatched); asleep, the hat **beside him**; and a **Hats** list on Pip
  Home to try hats on (not kept once you leave it).
- [x] Go. Pip Home's **Animations, Backgrounds and Hats** are
  all previews that combine (a hat and a background, an animation in
  them); swiping back to his info card or leaving Pip Home resets them.
- [x] Pip: **waking up** is still too quick when you happen to see it:
  longer, with a **yawn** and a **stretch**.
- [x] Pip: what's on his screen gets **mirrored** in a few cases (HI
  reads IH, the lightning bolt faces the wrong way): find them all and
  fix them.

### Round 56 — the index's scroll on (2026-10-15; patch 1.17.2)

- [x] Food, the index under the field: scrolled to its end, a drag kept
  trying to scroll it (it stretched) instead of the page. Now the drag
  goes on as the page's own (a flick flings the page on), and the index
  doesn't stretch.

### Round 55 — the notes on 1.17.0 (2026-10-15; patch 1.17.1)

- [x] Pip's **medicine reminder stays** as long as the red dot is on:
  whenever he's up and about it's the first thing he does, before
  going to charge or picking up a battery, and he keeps at it (the pill
  on his screen, a hop now and then) until the dose is marked. Not
  asleep (and later, not on an adventure).
- [x] The Medicine page's **notifications button** (top corner) goes.

### Round 54 — the notes on 1.16.0 (2026-10-15; 1.17.0)

- [x] Pip's **battery**, done by hand: he walks up beside it, a hand
  pulls his old battery out of his side and throws it away, picks the
  new one up and pushes it in. In Pip Home's Animations too, as a
  preview only (no battery used, no energy).
- [x] His **hands** a bit closer to his body (charging, the sword, and
  any other); only the hand he uses shows (charging had both).
- [x] Food, the index under the field: picking a recipe and closing it
  with the keyboard down no longer brings the keyboard up (only a tap
  on the field does).
- [x] The index scrolled to its end, scrolling on scrolls the page.
- [x] The meal page's **Same as** section goes.

### Round 53 — the notes on 1.15.0 (2026-10-15; patch 1.15.1, then 1.16.0)

**Patch (1.15.1)**
- [x] Food, the index under the field: an **X** in the field closes it;
  the index at most so tall, scrolling inside when longer.
- [x] Pip's **waking up** after sleep a bit longer.
- [x] His **sword** better looking, held pointing up and away from him
  (not angled into his body); **bugs** bigger and better.
- [x] No more pictures on his screen for fun (the ?, HI, star eyes with
  their flashing red, the heart, loading, the wink): that kind of event
  goes. His screen still shows notifications.
- [x] Words on his screen never mirrored (they were, facing left).
- [x] The **#!** when angry a bit lower.
- [x] Holding the flower: its stem in his hand, not floating above it.
- [x] Picking something up (a flower, a battery) and landing: he
  crouches, feet on the ground (the legs floated for a frame).
- [x] **Buzzes** at moments: the ball kicked, a bug struck, landing from
  the sky or a throw.

**New (1.16.0)**
- [x] **Medicine reminder**: while the medicine red dot is on, he
  reminds now and then (a pill on his screen, a hop).
- [x] **Eating**: after a recipe was open 5 minutes or more, the next
  time he's seen within the hour he's eating (a plate in his hands,
  bites, crumbs).

### Round 52 — Pip: entrances, random events, richer skies (2026-10-15, 1.15.0)

The user, going to sleep: "start pip work without waiting for me … make
it a bigger change". Decisions Claude's.

**Entrances** (all three)
- [x] **From the side, only in the side menu**: thrown in by the menu's
  swing, he tumbles in, lands, and is **angry** for a bit (a scowl,
  shaking a fist with his floating hands).
- [x] **From the sky**: he drops in, lands with a squash and a little
  dust.
- [x] **Coming back after a while** away (the app opened again): one of
  the entrances, not always the ground.

**Random events**
- [x] **Bugs**: little computer bugs crawl into his field; he pops out a
  **sword** and fights them off (the sword is for the adventures later).
- [x] **His screen** shows things now and then: when a notification
  comes, a few kinds (an envelope, a bell, a "!" blinking); and random
  ones (a heart, a note, a question mark, a loading bar…).
- [x] **Little things in his field**: a **flower** he walks to and
  picks (and holds for a while), and more of the kind (a butterfly he
  watches, a ball he kicks…).
- [x] All of them in Pip Home's Animations list, and in the `mayStart`
  table so nothing clashes (no bug fight while charging or asleep).

**More of the kind** (Claude's, as asked)
- [x] A **little dance** (hops to a beat, turning, music on his screen).
- [x] At dusk or night, a **shooting star** he looks up at.

Pictures: `docs/pip_round52_events.png`, `…_screens.png`,
`…_skies.png`.

**Backgrounds** (the note)
- [x] Richer skies: more colours in the bands (the evening's tinted
  lines, but with more hues), more detail on **clouds**, the **sun** and
  the **moon**. The ground stays as it is.

### Round 51 — the food tracker's calendar and legend (2026-10-15, patch 1.14.4)

- [x] The calendar's days as small as the week line's were (the month
  grid stays).
- [x] The legend under the bars: a mini coloured bar "With it", a grey
  one "Without", a divider, then "with · without" for the counts.
- [x] "Bad or awful: x% with it, y% without" as a statistic: two
  labelled bars, not a line of text.

### Round 50 — a sweep of the food tracker (2026-10-15, patch 1.14.3)

the page was someone's request; sweep it so it holds up for
whoever needs it, decisions Claude's. His question: ingredients have no
tags. (They needn't: an ingredient added to a meal becomes a food, in
Foods, and is tagged there.)

- [x] Foods: renaming one to another food's name **merges** them (asked
  first): its meals become the other's, tags joined. So "Egg" and "Eggs"
  typed apart can become one, and the statistics count them together.
- [x] Foods: a line saying tags give the statistics by kind, while some
  foods have none.
- [x] A meal's **day** can be changed too, not only its time.
- [x] Statistics: how many meals aren't rated yet (they don't count).

**Later, much later**: partial restore for Food. Proposal in
Round 49's answer: pick the backup's days; each meal brings the foods
the list is missing, existing ones untouched, meals already there
skipped. The user mentioned notes as what he needs partial restore for.

### Round 49 — Questions on the food tracker (2026-10-15, patch 1.14.2)

- [x] Statistics: a row's verdict ("Not enough data yet" and the rest)
  centred on its food's lines, not at their top.
- [x] Statistics: a food without a verdict says what's missing (rated
  meals with it, or without it), so "5 rated meals" and "not enough
  data" don't look like a contradiction.
- [x] Foods: a food deleted and later added again by the same name gets
  its meals back (it takes the old id), instead of showing twice in the
  statistics.
- Questions answered (tags, rename and delete, foods vs ingredients,
  partial restore for Food: a proposal, not built).

### Round 48 — symptoms, the Hub's order, recipes in the food index (2026-10-14, patch 1.14.1)

- [x] Statistics **by symptom**: for each symptom logged, the foods it
  follows clearly more often than without them (the same fair
  comparison and minimums as the verdicts). Symptoms stay **separate**
  from the verdicts: those still come from the faces alone.
- [x] The Hub's **default order**: Counters, Medicine, Placard, Pip,
  Recipes, Food (the user wrote "ingredients" for the last: the Food
  page). An order already arranged by hand stays.
- [x] The food index gets a **Recipes** section: a tap on a recipe opens
  its ingredients, ticked, to choose which to add (each becomes a food,
  the same name reused).
- [x] A patch, 1.14.1: the Introduction's *What's new* shows 1.14.0 and
  1.14.1 (a patch shows its whole minor version's changes).

### Round 47 — the notes on the food tracker (1.13.0, 2026-10-14)

- [x] Adding a food that's already in the meal: its chip **flashes**
  (it's there already).
- [x] The five faces the other way round: from bad to good.
- [x] A meal's **Delete** not in the top bar and not a round button: a
  button at the end of the page.
- [x] The week strip becomes a **month calendar** like Medicine's
  history (bigger), still circles coloured by the day's worst meal.
- [x] Adding foods: an **index** under the field, in sections, *Foods*
  (ones already used) and *Ingredients* (from Recipes' list, not foods
  yet), narrowed as you type; so the same names get reused and the
  statistics track them. No separate *From ingredients* button.
- [x] **Statistics, more of it** (the user wants it extensive): a tap on a
  food (or kind) opens its page: the verdict and numbers, how its meals
  were rated (a bar per face), with it vs without it, the symptoms after
  it, and **its meals' history** with dates, the other foods eaten with
  it and the rating; a tap opens the meal.

### Round 46 — the food tracker, built from the proposal (2026-10-14)

The user, busy: "whip out the page without my input" from the Round 15
proposal (O14); 1.12.0 checked and fine. His two answers: foods can be
**added from the ingredients list**; **no reminders, no notifications**.
The rest are Claude's calls, to change after he's tried it.

- [x] A Hub page, **Food**: a day at a time (‹ date ›, a week strip
  coloured by each day's worst rating, a tap picks a day), its meals in
  order.
- [x] **+** logs a meal: breakfast / lunch / dinner / snack (guessed from
  the time) and a time, the foods as chips (most used first), typing a
  new name adds a food, **From ingredients** picks from the recipes'
  ingredients list (a food of the same name is reused), and the last
  meals can be repeated with one tap.
- [x] A tap on a meal **rates** it: five faces (Great, Good, OK, Bad,
  Awful), symptoms (bloating, heartburn, cramps, nausea, tiredness,
  headache, other) and a note; also edit its foods and time, or delete
  it (Undo). Per meal, not per food. No reminder to rate.
- [x] **Foods**: rename, tags (dairy, gluten, spicy, fried, sugar,
  alcohol, caffeine, meat, fish), delete (meals keep its name).
- [x] **Statistics**: per food and per tag, how rated meals with it went
  against meals without it: *likely trouble* (5+ rated meals, bad or
  awful clearly more often than without it), *seems fine*, *not enough
  data yet*, with the numbers ("7 meals, 5 bad; without it 1 in 5") and
  the symptom that most often followed.
- [x] `food.json` v1, backup v22 (`food`), fixtures; lockable, in Clear
  data. Not in partial restore yet (a backup restores it whole).
- Later: a whole-day "how I felt", a month calendar, partial restore.

### Round 45 — the notes on 1.10.1 and the charging station (2026-10-14)

Built after the user tried 1.11.0 ("do it, except the segment drop time").

**Charging station, changes**
- [x] No lit antenna while charging.
- [x] Of the charging screens, drop the **percentage**; keep the rest.

**Patches**
- [x] Notes: scrolled down, hold and Select all: the selection's handle
  (the arrow at its start) shows way up, over the app bar. Hide a
  handle whose end of the selection is out of view.
- [x] Ingredients list: sections' handles **invisible**; touching a
  section's name and moving drags it; a tap opens its menu.

**To-do note**
- [x] A button beside Add with the list's options: a **Waiting**
  section on or off, and **Lock** the to-do list.
- [x] **Waiting**: the "to do" part split in two, *To do* and *Waiting*:
  things dragged between them; a tap still moves one to *Completed*.
  Off, waiting things show with the rest (kept marked, back when it's
  on again).
- [x] **Lock**: just a password: the list closed behind the
  master password while the app is locked, like a locked Hub page (not
  encrypted).
- [x] The to-do note's switch in Settings only shows or hides its card:
  the list, its Waiting and its lock stay as they are.

**Pip's batteries and energy, a better system** (no batteries
all day, no drain seen, with the app in his recent apps)
- [x] A battery every **5 hours on the clock** (no random spread),
  piling up while he's away, up to 3: time away counts, open or not.
- [x] He uses a segment every **8 hours awake** (was 10).
- [x] Plugged in: he uses energy as ever, but his battery icon keeps its
  segments until unplugged (so it doesn't drop while he charges), and he
  can't run out. For fun more than to save him.
- [x] Not done: a "a segment less in X h" line in his Status.

**Pip patches**
- [x] Pip Home's *Charging* said "busy" when he wasn't: it refused
  whenever the phone was plugged in (e.g. he's full and ignores the
  station). Play it then too; if he's at the station already, say
  "HE'S CHARGING".

**Idea: Pip's entrances** (later)
- [x] (Round 52) Flying in from the side, only in the side menu: as if the menu's
  swing threw him in. Then he's **angry** for a bit, shaking a hand.

### Round 44 — the notes on 1.10.0; Pip's charging station (2026-10-14)

**Patches**
- [x] Recipes list: a card's prep time and type as **chips**.
- [x] Ingredients list: a section's handle level with its name (the
  touch area as big as now).
- [x] The add-a-section button looked like "new folder": another icon.

**Pip's charging station** (next; drafts first)
- [x] While the phone charges, a **charging station** stands in his
  field and he's plugged in. Opened while charging: he's simply there,
  charging. Plugged in or out while watching: the animation (the
  station appears, he walks over, plugs in; or unplugs, the station
  goes).
- [x] It doesn't fill his battery (just for looks).
- [x] Busy (asleep, adventuring, off…): the station appears, but he
  doesn't use it.
- [x] Order: **hands** first (specs and sprites, he grabs a cable), then
  the station, then the animation; the user sees drafts at each step.
- [x] Hands (picked, drafts `docs/pip_hands_drafts.png`):
  **floating mitts**, no arms. He has none until he needs them; then
  they **pop in** (and pop away after), so his other animations stay as
  they are. Later used for adventuring too.
- [x] The station (drafts `docs/pip_charging_drafts.png`): it rises out
  of the ground, he **hurries** over, stops, his hands pop in, he takes
  the plug and plugs it into his side, the hands pop away. Unplugged:
  the same backwards, the station sinks.
- [x] While charging his screen changes now and then, at random:
  happy ^-^, a battery filling up, static.
- [x] **Ignores the station when his energy is full.** It's only for
  looks: it doesn't fill his battery (else he'd always be full,
  and running out would hardly ever be seen).
- [x] While plugged in he **can't lose power** (his energy stays).
- [x] The station looks like a **power station**, bigger, more detail
  (drafts v2: `docs/pip_station_drafts.png`); it never appears on top
  of him (it rises where he isn't).
- [x] Charging: his **antenna's tip lights up**, brighter at night.
- [x] All the charging screens now: ^-^, a battery filling, static, a
  bolt, eyes shut and content, a percentage counting up, sparks at the
  plug, humming (notes float up), blinking with the station's light.
- [x] He **hurries** to the station, and to batteries too (now his
  pace follows his energy, so a tired Pip walks slowly to them).
- Detecting it: Android says if the phone is plugged in (no permission);
  the app listens while it's open (MainActivity). Plugged in, not
  "charging": at 100% the phone stops charging but the cable's still in.
- Ideas for later, while charging: a bolt on his screen; eyes shut,
  content; a little percentage counting up; sparks at the plug; he
  hums (notes floating up); he reads the station's light and blinks
  with it.

**Later**
- Recipes extras (type filters, search by ingredient): much later, after
  the new Hub pages, maybe never.
- **AI help** (much later, after the backend service): e.g. on a
  recipe, a Complete button sends the draft to an agent, which returns
  it filled in, in a form the app turns into the recipe.

### Round 43 — the notes on 1.9.0 (2026-10-14)

**Recipes patches**
- [x] Editing jumps: after changing the type, a quantity, or closing a
  sheet, the page jumped down to where the method was last edited. The
  method should work like a note: a tap puts the cursor there, nothing
  else moves.
- [x] Closing the keyboard (back) ends editing the method (the cursor
  goes), as in notes.
- [x] Ingredients list: the first section ("Ingredients", the default)
  stays at the top; new sections go under it; sections can be dragged.
- [x] View mode: no To Shop button of its own; the top bar's menu
  (out of reach) becomes a bottom button with its options.
- [x] Edit mode: ingredients show no quantity button; a tap gives
  options, **Quantity** then **Delete**; holding selects (to delete
  several), no hold-to-delete.
- [x] Quantity: pickers like Shop's (count, weight), plus **teaspoon**
  and **tablespoon** (small and big spoons).

**Idea: Pip's adventures** (later)
- [ ] Two modes: **normal** (the pet, as now) and **adventure**. From
  Pip Home's first card (under his info): first time, a **Register as
  adventurer** button, only between **13:00 and 15:00** (so it isn't
  skipped); registering fills his batteries.
- [ ] In adventure mode the first card shows his **level** and main
  **inventory**; swiping shows the inventory (instead of animations and
  settings). He carries a **sword**.
- [ ] He adventures **12:00–16:00** each day, slowly gaining **XP** on
  his own (an idle RPG). It fits the energy system: batteries still fly
  to him, and he can power down.

### Round 42 — the notes on 1.8.0, and Recipes (2026-10-14)

**Patches**
- [x] Code blocks: the room above and below the text don't match.
- [x] Code blocks while editing: the ``` fences are hidden, so a block
  emptied of its text stays as an empty panel with nothing to delete.
  Show the fences (faint), like `###` on a heading.
- [x] Pip's batteries are **blue**, not green.

**Recipes** (`docs/RECIPES_SPEC.md`)
- [x] Decided: a recipe's ingredients are **one flat list** (no groups).
- [x] Build it (the spec's five chunks), then release (v1.9.0).
  Later: type filters on the list, search by ingredient.

**Idea: a planner notification that stays** (later)
- [x] While a planner **block** or **routine** is on, a notification
  that can't be swiped away shows what it is ("what I should be doing
  now"). It goes when the task is ticked, perhaps with a **Done** button
  on the notification itself. Planner blocks and routines only.

### Round 41 — the notes on 1.7.0, and his answers on Recipes (2026-10-14)

**Patches**
- [x] Medicine: the hold-to-take button's circle doesn't fill to 100%
  before its finishing animation.
- [x] The menu: a small gap between Pip's name/age/battery line and his
  room (half a pixel if a whole one is too much).
- [x] The Introduction: check it's still right.
- [x] Code blocks in notes look better: rounded corners, room on the
  left, maybe a different (monospace) font, bundled with the app (no
  fetching: it works offline).
- [x] Notifications are loud: a **volume** for each one (Loud, Medium,
  Quiet: quieter copies of the app's sounds; the phone's own sound can't
  be turned down by the app).

**Recipes, the answers** (the spec updated)
- No servings, no ticking ingredients, no timer.
- Duplicate yes; share = **copy to the clipboard** only.
- Search by ingredient: later.
- To Shop: an item with the same name but another quantity is added as
  a copy; everything goes to the to-buy list (he moves what he has).
- Prep time: a picker. Type: a fixed list. Ingredients deleted: recipes
  keep theirs; renamed: recipes follow.

### Round 40 — Medicine weekdays, a tidy roadmap, Recipes spec (2026-10-14)

- [x] **Medicine: pick weekdays** (supplements taken some days only).
- [x] **Tidy the ROADMAP**: done items still marked open.
- [x] **Recipes: a spec for review** (no building yet; `docs/RECIPES_SPEC.md`,
  drafts `docs/recipes_drafts.png`), from his notes:
  - The page lists recipes as items that can be **reordered**: name and
    prep time. An **Ingredients** button opens the ingredients list.
  - A recipe opens in **view mode**, which keeps the screen on (set the
    phone aside while cooking): its name, a small **prep time** field
    and a **type** (breakfast, snack, cake...) beside it, then its
    **ingredients** with their quantities (no handles, no adding), then
    a **description** area that works like a note (Markdown; only to
    look at in view mode). A **Send to shop** button adds its
    ingredients to Shop with their quantities (an item already there
    with the same name and quantity is just put back on the to-buy
    list).
  - An **Edit** button: everything becomes editable. The ingredients
    look simple: a box of text items (no background), name and quantity
    as plain text, a grab handle on the right (only in edit) to drag;
    quantity adjustable; hold to remove; an **add** button opens the
    ingredients list to pick from. The description works like a note:
    view, and a tap to edit (Markdown). Pull down to reach (reach mode)
    only in edit.
  - **Ingredients list** (not in the Hub; opened from Recipes, or from a
    recipe to pick): a simple list like the to-do, in **sections**; an
    Edit button lets you add sections and drag items between them; add
    is a simple sheet like the to-do's, new items (and sections) going
    to the top of the first section. Two modes: **pick** (checkboxes,
    like selection, and a button to accept; Edit is a button there too,
    and back returns to picking) and **edit** (the default when opened
    from Recipes' button).
  - The user asked what's missing for a page like this.

### Round 39 — the night shift (2026-10-14, for v1.7.0)

the notes from earlier rounds, done overnight while he sleeps; not
released (v1.7.0 waits for the morning).

- [x] **8-bit notification sounds**: Chime, Bell and Soft go; several
  hacky 8-bit ones instead, to try (Round 33).
- [x] **Consistency sweep**: buttons and toasts on every page against
  the UI conventions (e.g. Medicine's grey +) (Round 33).
- [x] **Multi-line code blocks** in notes with their own button on the
  format bar; strikethrough's button goes to make room (Round 32).
- [x] **Automatic backup** to a folder the user picks (Round 33, D8's
  second part).

### Round 38 — a quick run before Round 37 (2026-10-14)

- [x] **The night sky**: fewer stars, none touching the moon; the moon
  looks like the moon, not the sun.
- [x] **The moon's real phase** (worked out from the date): none, thin,
  half, full.
- [x] Pip Home: Pip **the same size as in the menu** (not zoomed in); a
  bigger field around him instead.

### Round 37 — Pip's energy, batteries and sleep (2026-10-14)

Plan proposed to the user first; then Pip, then the small notes (8-bit
sounds, the consistency sweep, multi-line code blocks).

- [x] **Energy indicator**: a battery with **three segments**: 3 green,
  2 orange, 1 red, 0 empty.
- [x] **His face by energy**: 3 as now, 2 tired, 1 very tired; at 0 he's
  **empty**: he falls down and his screen goes off.
- [x] **Batteries**: one comes every few hours (with a random offset);
  the time of the next is set, and it's collected when the app is opened
  after it, so they can't stack while away. At most **3** held. He
  loses energy a bit slower than batteries come, on average.
- [x] He **moves slower** the lower his energy.
- [x] **Running out while away**: the next time he's seen (menu or Hub),
  instead of coming out of the ground he turns off and falls down; if he
  was already seen off, he's simply lying there off.
- [x] **Sleep**: 23:00–8:00, losing energy much slower. Seen between
  23:00 and 0:00 he plays falling asleep; seen after 0:00 he's simply
  asleep. Waking the same: seen 8:00–9:00 he plays waking up, after
  9:00 he's simply awake. Running out while away at night: **power off
  wins** (seen at night, he plays turning off, unless already seen off).
- [x] Powered off, he can't get up: a dropped battery **flies to him**.
- [x] Everything about him (energy, batteries, times, what was seen) is
  in **backups**, and a restore carries on from there.

### Round 36 — Review of Pip Home (1.5.0, 2026-10-14)

- [x] Pip Home's scene takes **half the screen**.
- [x] **Background is a choice, not on/off**: a list of backgrounds to
  pick from (one for now, Field); day and night are the same background.
- [x] The menu's room **at least twice as high** (there's room on
  The user's phone; on smaller ones the menu items scroll above it).
- The Android home-screen widget: dropped from the plan (after
  hearing it can't animate smoothly).

### Round 33 — Review of 1.4.0 (2026-10-13)

Then the patch release, then Pip's first round (hatching), with drafts
first.

- [x] To-do: the round red **Delete completed** was ugly: now a quiet
  *Delete all* on the Completed header.
- [x] To-do: **+** in the add-button look of other pages.
- [x] To-do: deleting completed ones said "cannot be undone" and then
  offered Undo: no Undo now.
- [x] To-do: done ones can't be edited by holding them.
- [x] Why it happened (the user asked): the page wasn't checked against
  others, and the rules weren't written down. Now they are
  (ARCHITECTURE, "UI conventions").
- [x] Later (done in Round 39): a **consistency sweep** across pages: buttons (e.g. Medicine's
  grey +), toasts (when, and with Undo or not), against the conventions.
- [x] (Round 39) **new notification sounds**: the current three (Chime,
  Bell, Soft) go; instead **hacky 8-bit sounds**, several to try, then
  The user picks which stay.
- [x] (Round 39) Automatic backup to a folder: not simple (Android needs a folder
  picked with lasting permission, written through native code, and
  something to run it): later.

### Round 32 — Review of 1.3.1 (2026-10-13)

**1. Formats**
- [x] Bold, italic and strikethrough **toggle**: pressing one again on
  formatted text takes it off, instead of stacking more symbols.
- [x] (Round 39) **proper code blocks**, multi-line, with a
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

### Pip, a virtual pet (the user's plan, Round 32) — bit by bit, between other features

The user wants more say on sprites and visuals: show him drafts first.

**Phase 1: hatching, name, age, his home**

pickeds (Round 34):
- The **spotted egg**. 7 taps: the first starts the crack, 2 more widen
  it, 2 more again, and 2 pop him out. A light buzz on each tap, a
  slightly longer one for the pop.
- **Text**: the app's own 3 x 5 pixel letters (A–Z, 0–9, a few signs;
  no č, ć...): drawn on his pixel grid, so they stay crisp (a font file
  blurs at that size), and any name he's given can be shown. Name then
  age on one line, on the left (the right is for his battery and the
  battery stock later).
- **Age** in days: "1 DAY", "2 DAYS"... (the day he hatched is day 1).
- Hatched: he's alive, his page appears in the Hub. His data (name,
  birthday, later his inventory) is in backups; his **age** comes from
  his birthday, so restored from a backup he's as old as he really is.
- **Pip Home** isn't another plain page: more like a game. Its look
  drafted first, for review to pick.

- [x] Until he's hatched, the menu's room shows an **egg**; a few taps
  crack it, and Pip jumps out. His **birthday** is that moment.
- [x] Above the room, his **name and age** in tiny pixel text.
- [x] **Pip Home, picked (Round 35)**: draft B. A big animated
  scene on top (a tall version of his field's background; the menu's
  room gets the short version, both following the time of day), and
  under it a **card that swipes**:
  - *Status* (now): his icon, name, age, birthday. Later: batteries and
    energy, then inventory, his adventures...
  - *Settings*: **Rename** (in the card itself, no phone keyboard: the
    app's own pixel keyboard; names up to **6** letters, so nothing
    overflows), **Animations** (play each one on the scene), and
    **Background** (one for now, day and night being the same one: a
    toggle). Each opens in the card, with a back button.
- [x] **One system for what's shown and what he does** (so nothing
  clashes): backgrounds and their decorations say where (menu room /
  Pip Home) and when (time of day, season, dates, weather later) they
  apply, and one place works out what's showing now; his behaviour is a
  table of what he's doing and what may interrupt it (a battery during a
  fight: not allowed, or later). Both tested as tables.
- Later: weather (snow when it snows), seasons, a Santa hat in the last
  week of the year.
- [x] **Pip Home** (a Hub page; only once he's hatched, then opened;
  special, so it can't be locked): his avatar, name (changeable), age,
  birthday, and the same room as the menu's.
- [x] The field's **background follows the time of day**.

**Phase 2: energy and batteries**
- [x] A tiny **energy bar** above the room (Round 37: beside his name).
- [x] (Round 37) **Batteries**: about 3 a day, earned by visiting the app; tap the
  room to drop one, he runs over and picks it up to fill his energy.
- [x] While the phone **charges** (if the app can tell): a charging
  station, he runs to it and plugs in. (Round 44: done.)

**Later: more life**
- [x] Entrances: from the ground (now; also when the app is opened again
  after a while), falling from the sky, from the sides. (Round 52.)
- [x] Random events: **bugs** (computer bugs) appear and he draws a sword
  to fight them; moments where he **shows something on his screen**
  (also when a notification comes). (Round 52.)
- [x] **Sleeping** at night (Round 37: 23:00–8:00; he's seen falling
  asleep and waking, not woken by the app).
- [x] (Round 35/37: the `mayStart` table) Careful **flow control**, so things can't clash (no battery during
  a fight, etc.).
- [x] On Pip Home: a **background** pick for the room, and an **info
  page** playing every animation he has (Rounds 35–36: Settings,
  Background and Animations).
- [ ] Much later: Godville-style items and phrases made to fit him,
  items and levelling up.

### Round 30 — Review of 1.3.0 (2026-10-13)

Then the notifications page (Round 28, part 3).

- [x] To-do: **under** the Introduction (the Introduction stays on top).
- [x] To-do: its buttons follow the **hand-side rule** like every page.
- [x] To-do: **two lists**: done things go down to a *Completed* list;
  tapping toggles them back; a **Delete completed** button.
- [x] Restore part: the **Restore** button is broken (text and icon in
  one line, over the round button's sides).
- [x] Restored copies get **(Copy)** in their titles.

### Round 29 — the notes on 1.2.0 and 1.2.1 (2026-10-13)

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

The user, after 1.2.1: the to-do note and partial restore now; the
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

The user is importing his notes: the extra formats and their buttons now
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

**4. Pip's head** (concepts, the user choosing)
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
  and the user likes it), not a centred face.

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

### Round 25 — the notes on 0.28.0, then v1 (2026-10-13)

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
- Then release v1.0.0 (yes, after these).

### Round 24 — the notes before v1 (2026-10-13)

The user meant the notification tests and a final review to come before
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
- [x] Medicine: pick weekdays (supplements taken some days only; Round 40).

**5. Install problem** — solved: a bad download (the user installed it).

**8. Pip, a virtual pet** (idea; the user decides after seeing the cost)
- [x] Before v1 maybe: a small **room** at the bottom of the menu (a
  field); the first time the menu opens, Pip pops out of the ground,
  then stands and walks about. Drawn at a finer pixel scale than the
  icon so walking and squash/stretch look right.
- [x] (Round 35: Pip Home) Later: his own Hub page (tamagotchi-like); doing things by
  himself: sleeping at night, something on his screen, waking up after
  the app was away.
- [x] (Round 35) On his page, a section that **plays each of his animations** on
  demand (pop out, hop, walk, blink, …) (Round 26).
- [ ] On his page, besides the pet side: **Godville-style random
  events** (Round 26): little things happening to him by
  themselves, told as a log.

**7. Order to v1** — 0.28.0 is a test build of all this; the user tests,
  sends small fixes and his icon pick; then v1.0.0.

**6. The icon** — [x] **Pip** (picked, a 16 × 16 grid) drawn by
  `tool/make_icon.py`. (Prompt given in chat, Round 24:) a prompt for review to ask Claude for icon ideas
  (from the theme and what the app is), and how to send the chosen one
  back (a screenshot, a file, or instructions to draw the same).

### Round 23 — order to v1 (2026-10-13)

the backup reminder, then release (0.27.0); then the icon, the
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

**Phone test list (E1)** — for review, on 1.0.0:
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
- [x] (Round 31) **Notifications page** (menu → Notifications; E3): a **history**
  of recent notifications — today and yesterday — because ones cleared
  from the phone's drawer (e.g. by opening the app instead of tapping
  them) are otherwise gone unseen. Tapping one goes to its page / item
  (like tapping the notification), and a button clears the list. The
  same page holds the notification settings planned with E2 (sounds per
  kind).

### Round 22 — towards v1 (2026-10-13)

Round 20's extra Markdown and the formatting bar wait (v2
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

### Round 20 — Review of 0.26.0 (2026-10-13)

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

### Round 19 — the notes before the night (2026-10-13)

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

### Round 18 — Review of 0.25.0 (2026-10-13)

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

### Round 17 — Review of 0.24.0 (2026-10-13)

**1. Quick fixes**
- [x] Medicine dot: at 00:50 it showed for yesterday's 11:00–22:00
  doses. Only yesterday's doses at **22:00 or later** (the user changed it from 23:00) keep it until
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

### Round 16 — Review of 0.23.0 (2026-10-12)

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

### Round 15 — the notes on 0.23.0 (2026-10-12)

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
- [x] A Hub page for what was eaten each day and how well it agreed
  (asked for by someone; details left to Claude): a list of foods,
  each day's meals from it with a rating, a day view, and **statistics
  that point out what tends to cause trouble** (and what's fine).
  Design to propose first. (Built in Round 46 without his review, at
  his ask: see there for what changed from this.)

  **Proposal:**
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

### Round 14 — the notes on 0.21–0.22 (2026-10-12)

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
- [x] ~~(the user's note on tapping a stacked reminder was cut off: ask.)~~
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

### Round 13 — the notes on 0.20.0 (2026-10-12)

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

### Round 12 — the notes on 0.19.0 (2026-10-12)
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
- [x] (Rounds 31, 39: per page) Later (with E2): **default notification sounds** for tasks,
  routines and reminders separately, and for medicine (Round
  17: a sound per kind, picked in the app; each kind already has its own
  Android channel, so Android's per-channel sound works meanwhile).
- [x] (Round 39: automatic backup to a folder) Later (with D6): **what if the app is deleted?** Uninstalling
  deletes the app's files; ways to survive it: Android's backup (on, see
  ARCHITECTURE), exports, an automatic export to a folder the user picks
  (outside the app, so it stays), cloud save (D5).

### Round 11 — the notes, evening of 2026-10-11

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

**A2. Planner: descriptions** ✅ (after chunk 2) — tasks and
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
- [x] (E1, before v1) **Make them solid** (P17): they must arrive with the app open, in
  the background, swiped away, the screen off and the phone locked, and
  after a restart. Check: exact alarms (and the permission on Android
  12+), Doze, battery optimisation (ask to be exempt if needed), boot
  rescheduling, notifications while the app is in front, and what the
  phone maker's battery savers do. Test each state on the phone.
- [x] (Round 31: on the Notifications page) **Notification settings** in Settings (P18): sound (Android lets a
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
  (default **"Add text here!"**, the user sets his own on the phone) and
  the count.
- [x] **Better count animation**: while holding (a bit longer than now)
  the page **inflates and shakes**, then **pops** when it counts.
- [x] **Hide the status bar** while it's open.
- [x] Fix: on back the page **disappears before the screen turns back
  upright**; turn first, then close.

**L. New page: medicine tracker** (O6) ✅ — the user takes a pill every
  morning and notes it in a sheet; make that one tap. Agreed shape (all
  of it combined):
  - Add medicines, each with **how many** (doses a day), **when** (times),
    from a date **until a date or forever**.
  - A clear **"taken today"** view: one tap per dose, with medicines taken
    more than once a day showing each dose (e.g. 1 of 2).
  - **History**: each day, and the time each dose was marked taken.

**M. Later**
- [x] (before v1) **Data-safety sweep** (D6): everything that could lose data
  (storage, updates, restore, locks, crashes, phone changes), how safe
  export is, and when cloud saving should come in.
- [ ] **Cloud save** (D5): the server is **typed in** (connection
  details entered in the app), never hard-coded.

**N. Ideas for more Other pages** — listed under *Later / ideas*.

**Process**
- [x] After a release the user confirmed, Claude runs it and gives a
  **checklist of what to test** (docs/RELEASING.md).

**Chunks** (small, one at a time; each can be released on its own):
1. [x] G + H — switching tabs clears state; empty notes go away.
2. [x] A + B — the planner sheet and tapping a task; colours.
3. [x] D — the "now" line.
4. [x] C — reminders as marks on the timeline.
5. [x] E1 — notifications: check every state, fix what's missing; a
   phone test list.
6. [x] E2 — notification settings (sound, colour).
7. [x] F — toasts.
8. [x] I — shop quantities.
9. [x] J — counters options and style.
10. [x] K — Džoni back, configurable (as Placard).
11. [x] L — medicine tracker (model and storage, then the page).
12. [ ] New Other pages, one per chunk (see *Later / ideas*).
M (data-safety sweep, cloud) later.

### Round 10 — the notes on 0.18.0 (2026-10-11)
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

### Round 9 — the notes after using 0.17 (2026-10-11)

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
- [x] **Timeline zoom** (picked for short blocks, which cut off
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
- [x] **Point items** (after E; he meant reminders, not routines):
  something like a one-off reminder or to-do on the timeline — a time but
  **no end**, a small block that "hovers" there as a temporary reminder,
  not a long-running task. Agreed (P14): a short see-through block over
  the timeline; a bell button adds one; notifies at its time only;
  ticking it off deletes it; unticked, it stays on its day.
  - [x] Model, storage (`pins.json` v1), backups (v6, `plannerPins`)
  - [x] Timeline, adding / editing, ticking off, notifications
- [x] Unclear note "(This is just so markdown)": the user doesn't recall;
  only the set-password part was meant, and it's done.

### Round 8 — reminders (2026-10-11)

- [x] **Planner reminders** (P10), choices made while the user couldn't
  build (adjustable): per block Off / at start / 5–60 min before;
  titles hidden while the Planner is locked; planned two weeks ahead.
  Android build moved to AGP 8.6 / Gradle 8.7 / Java 11 with desugaring
  for flutter_local_notifications.

### Round 7 — after 0.16 (2026-10-10)

- [x] **Menu stays open behind its pages** (G16): back from a page opened
  from the menu returns to the menu; back again closes it.
- [x] **Counters: no ✕ in selection mode** — back already leaves it.
- [x] **Notes: ↶ ↷ keep their order on the left side too**;
  only their place (outermost) follows the hand.
- [x] **Planner routines** (P8), designed with a routine is its
  own item (not copies), shown on its days; per-day change / skip / tick;
  a Routines screen with a Mon–Sun strip; Repeat + Until in the add sheet;
  the one-off wins a clash; editing a routine changes past days too.
- [x] **Block colours** (P9): six muted fills with a bright stripe, the
  same in every theme; picked in the task / routine sheet.

### Round 6 — after 0.15 (2026-10-10)

- [x] **Markdown: hide the symbols except where you're editing** (N9) —
  The user expected the `##` to disappear once formatted. Live preview: the
  line with the cursor shows its symbols; other lines don't.
- [x] **Line numbers in notes** (N12) — the user liked the code-editor
  idea; one number per paragraph, switch in Settings.

### Round 5 — after 0.14 (2026-10-10)

- [x] **Notes: edit the title from the bottom** (N11) — the title
  is high and hard to reach. A smaller *Edit title* button above the
  editor's buttons (the user's choice) opens a sheet at the bottom.
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
- [x] **Markdown in notes** (N9) — dynamic, basics only, lists
  most important, no checkboxes. Styled live in the editor; symbols stay,
  faint.
- [x] **Fingerprint unlock** (L6) — via `biometric_storage` (Android
  keystore, fingerprint-bound key). Not tried on a phone before release:
  The user to check on 0.15.

## Later / ideas

- **Other pages the user picked** (Round 11; each starts empty, no
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
