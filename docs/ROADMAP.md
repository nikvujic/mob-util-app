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
- **Waiting on the signing key** (Nikola, one-time; see below). Once the
  secrets are in: tag the latest version so it becomes the first GitHub
  Release, then ask whether CI should also keep the APK of every run as a
  downloadable artifact (handy for quick looks, but debug-signed — can't be
  updated by real releases).
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
10. [ ] **Import (D2, D2a)** — validate, preview counts, confirm, replace;
    asks for the master password for encrypted files. Invalid files never
    touch current data.

### Locking

11. [ ] **Session unlock (L4)** — unlock once; stays unlocked through short
    trips to other apps; locks after 5 min in the background, on app close,
    or "Lock now". Encrypted export then needs no typing while unlocked.
12. [ ] **Lock notes (N6, N7, D3)** — lock/unlock a note, encrypted at rest,
    lock icon in the list, route to password setup if none exists. Export
    already carries the stored (encrypted) form, so D3 is verified here.

### New sections

13. [ ] **Section locks (L5)** — Security switches to lock whole sections.
14. [ ] **Planner v1 (P1, P2)** — tasks with title + description; add, edit,
    delete.
15. [ ] **Other → Counters (O1, O2).**

## Later / ideas

- Undo / redo while typing in a note, e.g. undo a paste (N8)
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
  Menu → Security, next to the master password.

## Housekeeping

- [ ] The Android toolchain is the one Flutter 3.29 generated (Kotlin
  1.8.22, AGP 8.1, Gradle 8.3). New plugins must be picked at versions that
  build with it — e.g. `package_info_plus` 9 needs Kotlin 2.2, so we use
  8.x. CI's APK job catches mismatches. Upgrade Flutter and the Android
  toolchain together, as one dedicated step, when plugins start requiring it.

- [ ] Two APIs carry `// ignore: deprecated_member_use` because they are only
  deprecated on newer Flutter (`onReorder`, `TickerMode.of`). Switch to
  `onReorderItem` / `TickerMode.valuesOf` when upgrading Flutter.
