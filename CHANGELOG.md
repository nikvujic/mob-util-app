# Changelog

All notable changes to the app. Versions follow `MAJOR.MINOR.PATCH`
(see [docs/RELEASING.md](docs/RELEASING.md)); each version is a GitHub
Release with the installable APK.

## [0.12.0] - 2026-10-09

### Added
- **Planner**: a to-do list per day. Swipe or tap the day strip at the
  bottom to pick a day (today is outlined, days with tasks have a dot);
  + adds tasks to that day; tap a task to tick it off. Long-press to
  select and delete; drag to reorder. Included in backups.
- **Counters** (Other → Counters): named counters with big − and + buttons.
  Long-press to rename, reset or delete; drag to reorder. Included in
  backups.
- **Section locks** (Menu → Security): switch on a lock for Notes, Shop,
  Planner or Other. While the app is locked, a locked section shows a lock
  screen instead of its content; enter the master password to open it.
  Turning a lock off needs the password too. A section lock hides the
  section — to encrypt content, lock notes.

### Changed
- **Easier one-handed use**:
  - The drag handle reacts on the whole area around it (full row height,
    wider to the left), not only on the icon.
  - In selection mode, *Select all*, *Delete* (and *Lock* for notes) are
    round buttons in the lower right instead of the top bar.
  - Lists can be pulled down past their top, so the first rows come
    within thumb reach; scroll back up to return.
- **Shop order**: new items, and items moved back from *Items*, now go to
  the end of *To buy*, so the list keeps the order you added things in.
  Bought items still go to the top of *Items*.
- **Touch feedback**: rows and buttons all show the same plain ripple.
  Tapping a shop item's checkbox now ripples the whole row, like tapping
  the item.

## [0.11.0] - 2026-10-09

### Added
- **Locked notes**: lock a note from its ⋮ menu (or several in selection
  mode). Its content is stored encrypted with your master password; the
  title stays visible in the list with a lock icon. Opening it asks for
  the master password if the app is locked. **Remove lock** turns it back
  into a normal note. Without a master password, locking first helps you
  set one.
- **Backups keep locked notes locked**: they stay encrypted inside every
  backup file. Restoring on a phone without a master password takes over
  the backup's; otherwise the backup's password is asked once (not at all
  for a backup from this phone) and the notes then open with yours.
- **Unlock once**: after entering the master password, the app stays
  unlocked while you use it and during short trips to other apps. It locks
  again after 5 minutes in the background, when the app is closed, or with
  **Lock now** (in the menu and on the Security page).
- Encrypted export no longer asks for the password while unlocked.

- **Press back twice to exit**: on a main section, the first back shows
  "Press back again to exit"; back still closes the menu or leaves
  selection mode first.

### Changed
- Removing the master password unlocks all locked notes first (the form
  says how many), so none are ever left without a password.
- Setting a master password also unlocks the app.
- **Dialogs redesigned**: clearer title, message and buttons, with squarer
  corners. Leaving a note now asks with **Discard** and **Save** buttons
  and says that notes are saved automatically.
- Data files from a newer app version (only possible after installing an
  older version) are set aside untouched instead of being read.

### Fixed
- Creating a note no longer makes the notes list jump while the editor
  opens.
- Closing the keyboard while adding shop items now closes the add field
  too, instead of leaving it over a dimmed page.

## [0.10.0] - 2026-10-08

### Added
- **Import from file** (Menu → Backup): pick a backup, enter its master
  password if it's encrypted, see what it holds (date, number of notes and
  shop items) and confirm to restore it. Files that aren't backups, are
  damaged, or come from a newer app version are refused with a clear
  message, and nothing changes. **Undo** right after restoring puts your
  previous data back.

## [0.9.0] - 2026-10-08

### Added
- **Encrypted backups**: Export now asks *Plain file* or *Encrypted file*.
  An encrypted backup can only be read with your master password (you
  confirm it when exporting) and is named `…-encrypted.json`. Needs a
  master password; without one the option points you to Security.

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
