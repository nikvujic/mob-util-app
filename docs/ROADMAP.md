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

- [ ] After 12e: **explain to Nikola in plain terms** how locked notes
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
- [ ] **U4 Snap back to the top** when scrolling up leaves only a little
  pulled-down space (all pull-down lists: Notes, Shop, …).
- [ ] **U5 Drag area a little smaller** (Notes, Shop).
- [ ] **G13 Going to a section resets its pulled-down space.**
- [ ] **P5 Remove the planner's Today button.**
- [ ] **Planner day strip: fast swipes travel far** (it now moves about
  one day per swipe); needed once there's no Today button, to swing back
  to the start. Together with **P6** (greyed past, starting at the oldest
  unfinished task), since that defines where "the start" is.

**B. Actions at the bottom, on the hand's side (G11)**
- [ ] Shared bottom action buttons that sit bottom-right or bottom-left
  depending on which half of the screen was tapped; no action buttons in
  top bars except ☰.
- [ ] **N10 Note editor:** Discard (new icon, not ↶) and ⋮ move to the
  bottom; the text scrolls clear of them.
- [ ] Apply the side rule to the selection actions too: their side
  follows the side of the long-press. Selection's ✕ moves down too, as
  the last button. Switching sides mirrors both the side and the order
  of the buttons.

**C. Themes (G12)**
- [ ] Colours come from the theme (not fixed constants); design checks
  run on every theme.
- [ ] Menu → **Themes** page.

**D. Other: tiles, sounds, a new tool**
- [ ] **O3** Tools as icon tiles from the bottom right.
- [ ] **U6** Counters: vibration + click sound on − / +.
- [ ] **O4** "Džoni što ćutiš?" page (landscape, big text, hold to
  count with shake + pop).

**E. Planner: time blocks**
- [ ] **P7** Time blocks (details settled, see answers below).

**Answers so far (2026-10-09):**
- G11: yes, the side rule also applies to selection actions, and ✕ is
  added to them as the last action. Switching sides mirrors side and
  order.
- O4: one count per hold; the count is saved for good. Later: a hidden
  way to reset or set the count.
- P7: the timeline covers the whole day, 00:00–24:00. **No + button:**
  a new day is one big free slot; tapping a free slot adds a task in it
  (start = start of that slot, end = 1 h later or a quick option, up to
  the end of the slot). Adding 08:00–09:00 to an empty day leaves three
  blocks: free, the task, free; the next task goes into one of the free
  slots. **Blocks never overlap.**

**Still open:**
- G11: does the ← (back) on pages like the editor stay at the top?
- P7: can a block be ticked off as done (like the current checkbox), or
  is a block just a time slot? What happens to today's v1 tasks (no
  times) — become blocks at the start of free time?
- U6: always on, or a switch (sound/vibration) somewhere?
- G12: which themes to start with (e.g. the current dark green, a pure
  black/AMOLED one, a light one)?

## Later / ideas

- Undo / redo while typing in a note, e.g. undo a paste (N8)
- **Markdown in notes** (N9) — Nikola's idea; ask about the details
  (editing vs. viewing, which syntax, toggle per note?) before planning
- Fingerprint unlock (L6)
- TimeTune-style scheduler in Planner (P4)
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
