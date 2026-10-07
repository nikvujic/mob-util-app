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
  `CHANGELOG.md` entry, `vX.Y.Z` tag → GitHub Release with the APK
  ([RELEASING.md](RELEASING.md)).
- **Before the first phone test: set up the release signing key**
  ([RELEASING.md](RELEASING.md#signing-key-one-time-setup)) so the APK you
  install can be updated by later releases without losing data. Until then,
  versions are bumped and logged but not tagged.
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
   Other tab (empty), add a Settings page opened from the app bar. Widget
   tests pin down back-button behavior: back on a main section exits; back
   from Settings / a note returns to where we were.

### Notes & Shop polish

4. [ ] **Discard changes in a note (N5)** — snapshot when the editor opens,
   undo action restores it (or removes a just-created note), with confirm.
5. [ ] **Compact shop rows (S4).**

### Backup (failsafe) — device checkpoint after this group

6. [ ] **Export (D1, D4)** — one versioned JSON file with all data, saved via
   the Android file picker / share sheet.
7. [ ] **Import (D2)** — validate, preview counts, confirm, replace. Invalid
   files never touch current data.

### Privacy — device checkpoint after this group

8. [ ] **Crypto service + master password (L1–L3)** — key derivation,
   AES-GCM encrypt/decrypt, verifier; Settings → Security page to set /
   change / remove the password. Pure-logic first, heavily unit-tested.
9. [ ] **Session unlock (L4)** — unlock once; stays unlocked through short
   trips to other apps; locks after 5 min in the background, on app close,
   or "Lock now".
10. [ ] **Lock notes (N6, N7, D3)** — lock/unlock a note, encrypted at rest,
    lock icon in the list, route to password setup if none exists. Export
    already carries the stored (encrypted) form, so D3 is verified here.

### New sections

11. [ ] **Section locks (L5)** — Security switches to lock whole sections.
12. [ ] **Planner v1 (P1, P2)** — tasks with title + description; add, edit,
    delete.
13. [ ] **Other → Counters (O1, O2).**

## Later / ideas

- Fingerprint unlock (L6)
- TimeTune-style scheduler in Planner (P4)
- Self-hosted cloud backup, e.g. S3-backed (D5)
- **UI polish (U1)** — once the main features are in: shake on wrong
  password, hero/slide animations, haptics, clicky counter sounds

## Decisions

- **L4 — unlock duration:** unlocked until 5 min in the background, app
  closed (removed from recents), or "Lock now". Short app switches don't
  relock.
- **N6 — locked notes:** title stays visible with a small lock icon; only
  the content is encrypted.
- **L5 — whole-section locking** is configured per section in
  Settings → Security, next to the master password.

## Housekeeping

- [ ] Two APIs carry `// ignore: deprecated_member_use` because they are only
  deprecated on newer Flutter (`onReorder`, `TickerMode.of`). Switch to
  `onReorderItem` / `TickerMode.valuesOf` when upgrading Flutter.
