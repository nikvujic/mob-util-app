# Changelog

All notable changes to the app. Versions follow `MAJOR.MINOR.PATCH`
(see [docs/RELEASING.md](docs/RELEASING.md)); each version is a GitHub
Release with the installable APK.

## [0.8.0] - 2026-10-08

### Added
- **Master password** (Menu → Security): set, change and remove it.
  It's never stored — only a check value derived from it with Argon2id —
  so a forgotten password can't be recovered. It will protect locked
  notes and encrypted backups.

## [0.7.0] - 2026-10-08

### Added
- **Backup → Export all data** in the menu: saves your notes and shopping
  list to one file (e.g. `the-app-backup-2026-10-08-0930.json`) wherever
  you choose — Downloads, Google Drive, … Importing it back comes next.

## [0.6.0] - 2026-10-08

### Changed
- **Compact shop rows**: about 20% more items fit on screen, while every
  row stays a full-size touch target.

### Fixed
- Screen readers (TalkBack) now announce shop items with their name and
  checked state, and announce selected rows in selection mode; drag
  handles are no longer read out as "Reorder".
- Selecting a row no longer makes it 2 px taller.

## [0.5.0] - 2026-10-08

### Changed
- **Back from a note asks "Save changes?"** when something was changed
  (*Save new note?* for a new one). **Yes** — or tapping outside the dialog
  — keeps the changes; **No** puts the note back as it was, or deletes the
  new note. Back without changes leaves straight away. Closing the app
  still saves everything, without asking.
- **↶** now only appears on existing notes and keeps you in the note after
  undoing your changes.

## [0.4.0] - 2026-10-08

### Added
- **Discard changes** (↶ in a note's top bar): undoes everything done since
  the note was opened, even after it was autosaved, and closes the note.
  A note created in that session is deleted instead. Asks first.

## [0.3.1] - 2026-10-08

### Fixed
- Android build failed in 0.3.0: the version-info plugin needed a newer
  Kotlin than the project uses; now uses a compatible plugin version.

## [0.3.0] - 2026-10-08

### Changed
- The gear icon and Settings page are replaced by a **menu** (☰, top
  left on every section) with a **Security** page — master password and
  section locks arrive in upcoming versions.
- The app version is shown at the bottom of the menu.

## [0.2.0] - 2026-10-08

### Added
- Settings page, opened from the gear icon on every section (Security and
  Backup are listed and arrive in upcoming versions).
- **Other** section, where extra tools such as Counters will live.

### Changed
- The To Do section is now called **Planner**.
- The unfinished Export/Import menu on Notes is gone; backup will live in
  Settings.
- Back on any main section closes the app; back from Settings or a note
  returns to where you were.

## [0.1.0] - 2026-10-07

First tracked release.

### Added
- Notes: create, edit title and body, custom order with drag handles,
  long-press selection with confirmed delete. New notes start as
  "New Note" and are removed again if left untouched.
- Shop: "To buy" and "Items" lists; tap moves an item between them; add
  several items in a row; drag to reorder; selection with confirmed delete.
- To Do tab placeholder.
- All data is saved on the phone after every change; note edits are
  autosaved while typing and when the app goes to the background.
