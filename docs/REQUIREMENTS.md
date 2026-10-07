# Requirements

A personal, offline utility app for **Android only**. It replaces several
store apps (notes, shopping list, planner, counters) that come with ads,
accounts or registration. Guiding principles:

- **Simple.** Creating and finding things takes as few taps as possible.
- **Never lose data.** Everything is saved immediately and survives the app
  being closed, killed, or left with the back button. Export/import is the
  failsafe for a lost or new phone.
- **Private.** No accounts, no network. Sensitive notes and sections can be
  locked behind a master password.

How we work, step by step, is in [ROADMAP.md](ROADMAP.md).

Status: ✅ done · 🚧 in progress · ⏳ planned · 💭 later / idea

---

## G — General

| # | Requirement | Status |
|---|-------------|--------|
| G1 | Bottom navigation with the main sections: **Notes** (default on launch), **Shop**, **Planner**, **Other**. Each keeps its state (scroll position, selection) when switching. | 🚧 Notes, Shop, To Do exist; rename to Planner and add Other |
| G2 | One visual language (dark theme, green accent) defined in `lib/core/theme.dart`; pages don't hard-code colors. | ✅ |
| G3 | Shared building blocks instead of per-page copies (confirm dialog, selection mode, list rows, empty state, input sheet, …). | ✅ |
| G4 | **Selection mode** behaves the same on every list: long-press selects, tap toggles, top bar shows count / select all / delete, back or ✕ exits. | ✅ |
| G5 | Deleting always asks for confirmation through the shared dialog. | ✅ |
| G6 | All data persists locally and is saved on every change; edits in progress are autosaved while typing and when the app goes to the background. | ✅ |
| G7 | **Navigation stack.** Each main section is the bottom of the stack: system back on a main section closes the app. Anything opened from a section (a note, settings, a sub-page under Other) is pushed on top, and back returns exactly to where the user was. | 🚧 holds today; must be kept as pages are added, with tests |
| G8 | **Settings** page, opened from the app bar of any main section. Holds **Security** (master password, section locks), export/import, and future options. | ⏳ |
| G9 | Android only. No web/desktop targets or code paths. | ⏳ |

## D — Data safety: export / import

| # | Requirement | Status |
|---|-------------|--------|
| D1 | **Export** all data (notes, shop, planner, counters, settings needed to read locked data) to one JSON file the user saves anywhere (Downloads, Drive, …) via the Android file picker / share sheet. File name includes the date. | ⏳ |
| D2 | **Import** a previously exported file: validated first (format, version), shows what it contains, and asks for confirmation before **replacing** current data. Invalid files are rejected without touching current data. | ⏳ |
| D3 | Locked content stays encrypted inside the export; after import it opens with the same master password. | ⏳ |
| D4 | Export files carry a format version; newer app versions can always import older exports. | ⏳ |
| D5 | Cloud backup to a self-hosted service (e.g. S3-backed). | 💭 not now |

## N — Notes

| # | Requirement | Status |
|---|-------------|--------|
| N1 | List shows title and last-modified date/time, in a custom order (drag handle on the right). | ✅ |
| N2 | Tapping + creates "New Note" at the top and opens it; an untouched new note is removed on leaving. | ✅ |
| N3 | Title and body are directly editable; leaving saves; empty title becomes "Untitled". | ✅ |
| N4 | Long-press → select → delete with confirmation. | ✅ |
| N5 | **Discard changes.** While editing, changes keep being saved (back, closing the app — nothing is lost), but an *undo* action in the editor restores the note to exactly how it was when it was opened and leaves the editor. For a note created in this session, discarding removes it. Asks for confirmation. | ⏳ |
| N6 | **Lock a note** (from the editor menu or selection mode). A locked note's content is stored encrypted with the master password. Its **title stays visible** in the list, with a small lock icon. Opening it requires unlocking (see L). If no master password exists yet, locking first routes to password setup, then returns. | ⏳ |
| N7 | Unlock a note permanently (remove the lock) — requires the app to be unlocked. | ⏳ |

## L — Security: master password & locking

| # | Requirement | Status |
|---|-------------|--------|
| L1 | Settings → **Security**: set, change (requires current), remove (requires current; decrypts locked items) the master password. | ⏳ |
| L2 | The password itself is never stored. A key is derived from it with a slow KDF (Argon2id/PBKDF2 + random salt); only the salt, KDF parameters and a verifier are stored. | ⏳ |
| L3 | Locked data is encrypted with an authenticated cipher (AES-GCM). Without the password it cannot be read, also not from an export. Forgotten password = locked data is unrecoverable; the setup screen says so clearly. | ⏳ |
| L4 | **Convenient unlock:** entering the password once unlocks everything (locked notes and locked sections). It stays unlocked while the app is in use and while it is briefly in the background (e.g. switching away to copy something). It locks again when the app has been in the background for **5 minutes**, when the app is closed (removed from recent apps), or when "Lock now" is used. | ⏳ |
| L5 | **Section locks** in Security: per main section (Notes, Shop, Planner, Other) a switch to lock the whole section. Opening a locked section requires unlocking (L4). Only available once a master password is set. | ⏳ |
| L6 | Unlock with fingerprint as an alternative to typing the password. | 💭 later |

## S — Shop

| # | Requirement | Status |
|---|-------------|--------|
| S1 | Two lists: **To buy** above **Items** (catalog of things bought before). Tapping an item moves it to the other list, to the top. | ✅ |
| S2 | Items are only a name. + adds to the top of To buy; the input stays open for adding several in a row. | ✅ |
| S3 | Drag handle on the right reorders within a list. Long-press → select → delete. | ✅ |
| S4 | **Compact rows** — noticeably smaller than note rows, so more items fit on screen. | ⏳ |

## P — Planner (currently the "To Do" tab)

| # | Requirement | Status |
|---|-------------|--------|
| P1 | Tab renamed to **Planner**. | ⏳ |
| P2 | v1: a list of tasks, each with a title and an optional description. Add, open/edit, delete (select mode, as elsewhere). Deleting is how a task is "done". | ⏳ |
| P3 | Can be locked as a whole section (L5). | ⏳ |
| P4 | Scheduler in the style of *TimeTune* (time blocks across the day, routines). | 💭 later |

## U — UI polish ("fun but practical")

| # | Requirement | Status |
|---|-------------|--------|
| U1 | Small touches that make the app satisfying without getting in the way: shake on a wrong password, meaningful animations (e.g. hero transitions into a note, items sliding between shop lists), haptic feedback, clicky sounds for counters and similar. Each one optional where it could annoy. | 💭 after the main features |

## O — Other

| # | Requirement | Status |
|---|-------------|--------|
| O1 | **Other** tab lists additional tools; each opens as a page on top (back returns to the list). | ⏳ |
| O2 | **Counters**: named counters with big − / + buttons and the current value; add, rename, reset, delete; reorder. | ⏳ |

---

## Technical notes

- Flutter 3.29.x (as on the dev machine; `pubspec.lock` is generated with it).
- State: Riverpod `StateNotifierProvider`, one provider per feature in
  `lib/providers/`. Models are immutable value classes in `lib/models/`.
- Storage: one JSON file per feature in the app documents folder
  (`data/notes.json`, `data/shop.json`, …), with a `version` field. Writes go
  to a temp file that is renamed over the real one (never half-written).
  Unreadable files are moved aside (`*.corrupt-<time>`), never overwritten.
- Reusable widgets in `lib/widgets/`, feature pages in `lib/pages/<feature>/`.
- Every change ships with tests (provider/unit + widget tests for the main
  interactions) and passes `flutter analyze`.
