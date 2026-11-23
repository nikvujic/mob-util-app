# Documents — spec

A Hub page for documents kept on the phone: identity documents, receipts
(with their warranties), barcodes of loyalty and membership cards, and
tickets. Each item holds one or more pictures, a few fields and a note.
Pictures only for now; other files (PDFs and the like) later, on the same
storage and backup format.

Status: **being built.** Steps 1–3 are done (2.6.0): the plugin check,
the storage, the zip backups and Android's backup exclusion.

## Types

New items start by choosing a type.

| Type | Creating | Its fields |
|---|---|---|
| **Document** (passport, ID, licence) | The form opens. | Name, pictures, note, **expiry date** (optional) with a reminder before it. |
| **Receipt** | The camera opens (camera permission asked the first time). The photo becomes the first picture; the form follows. | Name, pictures, note, **shop** and **price** (optional), **warranty** (a checkbox): start (*Today*, ticked by default, or a date), end, with quick buttons (**1 year**, **2 years**) and a reminder before the end. |
| **Barcode** (loyalty or membership card) | The camera opens; after the photo, the **crop step** frames the barcode. | Name, pictures, note, **one barcode** (a crop of one of its pictures). Several codes on one card: the other sides as pictures. |
| **Ticket** (boarding pass, event, train) | As Barcode. | Name, pictures, note, **date** (no time), the barcode as for Barcode (optional), a reminder on the day. |

Closing the camera without a photo leaves the form open, empty, the type
kept. Every type can add pictures from the **camera** or the **gallery**
at any time; a Barcode or Ticket can set or change its barcode from any of
its pictures (**Set barcode**: pick a picture, crop).

## The form and the item page

- The same editing rules as the app's other pages: saved as it changes,
  saved when the app goes to the background, **Save / Discard** on back
  after changes, a new empty item discarded; the pull-down reach space at
  the top; actions at the bottom on the hand's side.
- **Pictures** in a row of thumbnails: a tap opens the picture full screen
  (pinch to zoom, swipe between pictures); holding one offers *Rotate*,
  *Download* and *Delete*; the handle reorders them.
- **Download** saves a copy of the picture to the phone's gallery (a copy
  outside the app's protection, by choice).
- **Show barcode** (Barcode, Ticket): the cropped barcode full screen,
  brightness raised to the maximum and the screen kept on while it shows;
  the brightness goes back when it closes.
- **Delete** asks, with Undo; the pictures are deleted once Undo has gone.

## The list

- Cards in the user's order (the handle moves them), each with a
  thumbnail, the name, the type's icon and its date line: *Expires
  3 Mar 2031*, *Warranty until 12 Nov 2028*, *Warranty ended*, *Tomorrow*
  (a ticket).
- Dates coloured as in Subscriptions: ending within the reminder period
  orange, gone by red, a past ticket greyed.
- Search (by name, shop and note) and a filter by type.

## Reminders

- Expiry and warranty end: a reminder before (none, a week, a month,
  three months, six months), at 09:00. A ticket: on its day at 09:00.
- Its own notification channel and settings on the Notifications page
  (on, pause, private, colour, sound), as other pages. Names are shown
  unless the channel is private, or the page is locked (then generic:
  *A warranty ends in a week*).
- Rescheduled on every start, as other reminders; the dates they need
  are kept in a small index without names, readable while the page is
  locked.

## Locking and encryption

- **Unlocked (the default):** like any page, no password needed. The data
  is in the app's private storage (encrypted by Android on the device).
- **Locked:** Documents appears in page locks like any page and needs a
  master password like any lock. Unlike other page locks, which hide a
  page, locking Documents **encrypts** it: every picture and the list
  (names, fields, notes), with the master password's data key (the one
  locked notes use; fingerprint unlock opens it too).
- Opening the locked page asks for the password (or fingerprint) once per
  unlocked session, as locked notes: the session ends when the app closes
  or after five minutes in the background, and decrypted pictures are
  dropped from memory with it. Nothing decrypted is ever written to disk
  (Download excepted, by choice).
- Turning the lock on or off encrypts or decrypts everything once. A
  progress indicator (pictures done of all) shows only if it takes longer
  than a second. Crash-safe: each file is written to a new name and
  swapped in when complete; an interrupted run resumes on the next start.
- Changing the master password re-wraps the data key only (nothing is
  re-encrypted). A forgotten password makes a locked page unrecoverable,
  as locked notes; the lock switch says so.
- Removing the master password follows what locked notes do: the page is
  decrypted first (or the removal refused until it's unlocked), whichever
  the existing flow does.

## Storage

- `documents.json` (version 1): the items, in order, with their fields and
  their pictures' ids; sealed with the data key while locked.
- Pictures as files in the app's private folder (`documents/`), one per
  picture, resized on saving (2000 px on the long side, JPEG), sealed while
  locked. The barcode crop is a picture of its own.
- Camera photos and gallery picks are copied to a staging folder, saved,
  and the staging copy deleted. The gallery's original is never touched.
  Staging leftovers (a crash mid-way) are deleted on start.
- Files no item refers to (a crash mid-delete) are deleted on start.

## Backups

- **One file, a zip:** the backup document (as today) and the pictures.
  Backup version 34. Every older backup (plain JSON, plain or encrypted)
  still restores; the app tells the formats apart by their contents.
- Pictures are always included. Locked, they go in sealed, as locked notes
  do, with the master password record; restoring asks for that backup's
  password.
- An **encrypted backup** seals the whole zip's contents.
- **Partial restore** offers Documents as a kind. Locked with another
  password than this app's: each picture is decrypted with the backup's
  key and sealed again with this app's.
- **Clear data** deletes the pictures as well.
- **Automatic backups** (to a folder, daily):
  - On the Backup page, a chip: *5 backups · 23 pictures · 120 MB*.
  - A tap opens an overview: each backup with its date and size, and how
    many to keep (1–14, 7 by default).
  - Written under a temporary name and renamed when complete; the last
    backup's time is updated only then. A backup interrupted by the app
    closing is cleaned up on the next start and simply runs again.
- **Android's automatic backup** (to the Google account, used when setting
  up a new phone or reinstalling) leaves Documents out, data and pictures:
  it's limited to 25 MB in all, and over that it backs up nothing. The
  Backup page says that Documents move to a new phone only with a backup
  file.

## Permissions and dependencies

- Camera: asked the first time a camera opens; refused, the gallery and
  the form still work, and the camera button explains how to allow it.
- Gallery saving (Download): as Android requires for the version.
- New plugins (camera/gallery picking, cropping, screen brightness, saving
  to the gallery) must build with the app's Android toolchain (Kotlin
  1.8.22, AGP 8.1). If the needed versions don't, upgrading Flutter and the
  toolchain comes first, as its own change.

## Later

- Reading a barcode from its picture (a pure-Dart scanner) and drawing it
  sharp, its number shown for checking.
- Files other than pictures (PDFs).

## Build order

Each step complete and released on its own, with tests:

1. The plugin and toolchain check (a throwaway build with the plugins).
2. Storage: items, pictures, staging, orphan cleanup; Clear data.
3. Backups: the zip format (version 34), full and partial restore of every
   older version, automatic backups (temporary names, the overview and
   the keep setting).
4. The page, the types and the form; pictures (camera, gallery, rotate,
   reorder, download, delete).
5. Barcode: the crop step, Show barcode (brightness).
6. Dates and reminders: expiry, warranty with quick buttons, ticket date;
   the notification channel.
7. Locking: encryption on and off with progress, sealed backups, partial
   restore across passwords, Android's backup exclusion.

## Tests that must exist

- Round trips with real files: save, lock, unlock, back up (plain,
  encrypted, locked), restore full and partial, under the same and a
  different master password; every older backup version restores.
- Interruptions: a lock, a backup and a save each stopped mid-way, then
  started again: nothing lost, nothing half-encrypted, no leftovers.
- No decrypted data on disk while locked (the folder's files all sealed).
- The camera refused, cancelled and accepted; the gallery picked and
  cancelled.
