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

### Round 7 — after 0.16 (2026-10-10)

- [x] **Menu stays open behind its pages** (G16): back from a page opened
  from the menu returns to the menu; back again closes it.
- [x] **Counters: no ✕ in selection mode** — back already leaves it.
- [x] **Notes: ↶ ↷ keep their order on the left side too** (Nikola);
  only their place (outermost) follows the hand.
- [ ] **Planner routines** (P8), designed with Nikola: a routine is its
  own item (not copies), shown on its days; per-day change / skip / tick;
  a Routines screen with a Mon–Sun strip; Repeat + Until in the add sheet;
  the one-off wins a clash; editing a routine changes past days too.
- [ ] **Block colours** (P9).

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
