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
| G1 | Bottom navigation with the main sections: **Notes** (default on launch), **Shop**, **Planner**, **Other**. Each keeps its state (scroll position, selection) when switching. | ✅ |
| G2 | One visual language (dark theme, green accent) defined in `lib/core/theme.dart`; pages don't hard-code colors. | ✅ |
| G3 | Shared building blocks instead of per-page copies (confirm dialog, selection mode, list rows, empty state, input sheet, …). | ✅ |
| G4 | **Selection mode** behaves the same on every list: long-press selects, tap toggles, the top bar shows the count and ✕; the actions (select all, delete, and e.g. lock for notes) are round buttons in the lower right, in thumb reach; back or ✕ exits. | ✅ |
| G5 | Deleting always asks for confirmation through the shared dialog. | ✅ |
| G6 | All data persists locally and is saved on every change; edits in progress are autosaved while typing and when the app goes to the background. | ✅ |
| G7 | **Navigation stack.** Each main section is the bottom of the stack: system back on a main section closes the app — after a confirming second press: the first shows *Press back again to exit*, a second within 2 s exits. Back first closes an open menu or leaves selection mode. Anything opened from a section (a note, a menu page, a sub-page under Other) is pushed on top, and back returns exactly to where the user was. | ✅ covered by `test/navigation_test.dart` |
| G8 | **Menu** (hamburger, top-left on every main section): **Security** page (master password, section locks), later **Backup** (export/import) and other app-wide options. The app version is shown at the bottom of the menu. | ✅ |
| G9 | Android only. No web/desktop targets or code paths. | ✅ |
| G11 | **Actions at the bottom, on the hand's side.** Top bars carry no action buttons except the menu (☰) — page actions are round buttons at the bottom, like selection mode. They sit on the side of the hand in use: bottom right after tapping the right half of the screen (e.g. opening a note from the right side), bottom left after the left half. Content can always scroll clear of them. Selection mode follows the same rule (side of the long-press), with ✕ as its last button; switching sides mirrors side and order. | ✅ ← back stays at the top |
| G12 | **Themes:** Menu → **Themes** page to switch the app's look. The app must first get its colours from a theme instead of fixed constants. | ✅ Green, Black, Clay |
| G13 | **Back to a section = back to its top:** going to a section (tapping it in the bottom bar) clears any pulled-down space, so the list sits at its normal top. | ✅ |
| G14 | **Reach mode everywhere it helps:** every scrolling list (sections, the menu, Security, Backup, Themes, Settings, …) supports reach mode (U4). Exceptions only where pulling down brings nothing into reach (forms, the planner timeline, bottom-up tiles); enforced by `test/architecture_test.dart`. | ✅ |
| G15 | **Swipe right along the bottom bar opens the menu** (easier for the right thumb than the left screen edge). | ✅ |
| G10 | **Accessible**: every screen meets Android's accessibility guidelines (48 dp touch targets, labelled controls for TalkBack, text contrast) and copes with large system font sizes. Checked by `test/design_test.dart`. | ✅ |

## D — Data safety: export / import

| # | Requirement | Status |
|---|-------------|--------|
| D1 | **Export** all data (notes, shop, planner, counters, settings needed to read locked data) to one JSON file the user saves anywhere (Downloads, Drive, …) via the Android file picker / share sheet. File name includes the date. | ✅ notes, shop, planner, counters, and the key of locked notes |
| D2 | **Import** a previously exported file: validated first (format, version), shows what it contains, and asks for confirmation before **replacing** current data. Invalid files are rejected without touching current data. | ✅ with Undo right after restoring |
| D2a | **Encrypted backups.** Export first asks **Plain** (readable JSON) or **Encrypted**. Encrypted uses the **master password** and is only offered once one is set; the file can't be read without it. Importing an encrypted file asks for the master password it was made with. | ✅ |
| D3 | Locked content stays encrypted inside the export; after import it opens with the same master password. | ✅ the backup carries the key, encrypted with the password; restoring adopts the backup's master password, or re-locks the notes under this phone's |
| D4 | Export files carry a format version; newer app versions can always import older exports. | ✅ newer ones are rejected with a clear message; app data and backups of every version (v1–v3) are read in tests from frozen samples |
| D5 | Cloud backup to a self-hosted service (e.g. S3-backed). | 💭 not now |

## N — Notes

| # | Requirement | Status |
|---|-------------|--------|
| N1 | List shows title and last-modified date/time, in a custom order (drag handle on the right). | ✅ |
| N2 | Tapping + creates "New Note" at the top and opens it; an untouched new note is removed on leaving. | ✅ |
| N3 | Title and body are directly editable; leaving saves; empty title becomes "Untitled". | ✅ |
| N4 | Long-press → select → delete with confirmation. | ✅ |
| N5 | **Save or discard on back.** Back after changing something asks *Save changes?* (*Save new note?* for a new one) with **Discard** (left) and **Save** (right) buttons and a line saying notes are saved automatically. Save — or tapping outside / back on the dialog — saves; Discard restores the note to how it was when opened, or deletes a new note. Back without changes leaves without asking. Closing or killing the app never asks: edits are always autosaved. | ✅ |
| N5a | **↶ Discard changes** (existing notes only): restores the note to how it was when opened, without leaving the editor. Asks for confirmation. | ✅ |
| N6 | **Lock a note** (from the editor menu or selection mode). A locked note's content is stored encrypted with the master password. Its **title stays visible** in the list, with a small lock icon. Opening it requires unlocking (see L). If no master password exists yet, locking first routes to password setup, then returns. | ✅ an open locked note closes (saved) when the app locks |
| N7 | Unlock a note permanently (remove the lock) — requires the app to be unlocked. | ✅ **Remove lock** in the editor menu and selection mode, with confirmation |
| N8 | **Undo / redo while typing** (e.g. undo a paste), step by step: ↶ and ↷ bottom buttons in the editor, always there and greyed out when there's nothing to undo / redo. A step is a burst of typing up to a 1 s pause, or one big change (a paste, a cut, Discard changes) on its own; title and text share one history. Undone changes are saved like any edit; the history lasts while the note is open. | ✅ |
| N10 | **Editor actions at the bottom (G11):** a row of round buttons on the hand's side: *Lock note* (or *Remove lock*), *Discard changes* (once something changed; not ↶), and ↶ *Undo* / ↷ *Redo* outermost, under the thumb. No ⋮ menu (it had one entry, and opening it fought with the keyboard). The text area scrolls clear of the buttons. | ✅ |
| N11 | **Edit the title from the bottom:** the title field is at the top, out of thumb reach, so a smaller *Edit title* button sits above the row of editor buttons, on the hand's side; it opens the title in a sheet at the bottom, above the keyboard. Like typing in the title (part of undo, saved the same way). | ✅ |
| N9 | **Markdown** formatting in notes. Details to be decided with Nikola. | 💭 later |

## L — Security: master password & locking

| # | Requirement | Status |
|---|-------------|--------|
| L1 | Menu → **Security**: set, change (requires current), remove (requires current; decrypts locked items) the master password. | ✅ minimum 8 characters |
| L2 | The password itself is never stored. A key is derived from it with a slow KDF (Argon2id/PBKDF2 + random salt); only the salt, KDF parameters and a verifier are stored. | ✅ Argon2id (verified against OpenSSL); only a verifier is stored |
| L3 | Locked data is encrypted with an authenticated cipher (AES-GCM). Without the password it cannot be read, also not from an export. Forgotten password = locked data is unrecoverable (it can only be deleted, L7); the setup screen says so clearly. | ✅ encrypted backups and locked notes |
| L4 | **Convenient unlock:** entering the password once unlocks everything (locked notes and locked sections). It stays unlocked while the app is in use and while it is briefly in the background (e.g. switching away to copy something). It locks again when the app has been in the background for **5 minutes**, when the app is closed (removed from recent apps), or when "Lock now" is used. | ✅ Lock now in the menu and on Security; encrypted export uses the open session |
| L5 | **Section locks** on the Security page: per main section (Notes, Shop, Planner, Other) a switch to lock the whole section. Opening a locked section requires unlocking (L4). Only available once a master password is set. | ✅ hides the section (no encryption — locked notes are the encrypted option); turning a lock off needs the app unlocked; backups need unlocking while a section is locked |
| L7 | **Forgot master password → reset** (Security page). Removes the master password without knowing it, by deleting what it protects: every **locked note**, and **everything in a locked section** (all notes, shop items, planner tasks or counters), so a section lock can't be bypassed by resetting. Everything else stays. The confirmation lists exactly what will be deleted and, when anything will, needs typing RESET. Encrypted backups made with the old password still need it. The data is deleted (and on disk) before the password goes. | ✅ |
| L6 | Unlock with fingerprint as an alternative to typing the password. | 💭 later |

## S — Shop

| # | Requirement | Status |
|---|-------------|--------|
| S1 | Two lists: **To buy** above **Items** (catalog of things bought before). Tapping an item moves it to the other list: to the top of *Items*, or to the end of *To buy* (S5). | ✅ |
| S2 | Items are only a name. + adds to To buy (at the end, S5); the input stays open for adding several in a row. | ✅ |
| S3 | Drag handle on the right reorders within a list. Long-press → select → delete. | ✅ |
| S4 | **Compact rows** — noticeably smaller than note rows (one 48 dp touch target high, ≥20% smaller, tighter gaps), so more items fit on screen without becoming harder to tap. | ✅ |
| S5 | New items, and items moved back from *Items*, go to the **end** of *To buy*, so it keeps the order things were added in (Nikola's request). Bought items still go to the top of *Items*. | ✅ |
| S6 | **A new item scrolls into view** as it's added: the list moves just enough to show it above the add sheet (from anywhere in the list), and not at all if it's already in view. | ✅ |

## P — Planner (currently the "To Do" tab)

| # | Requirement | Status |
|---|-------------|--------|
| P1 | Tab renamed to **Planner**. | ✅ |
| P2 | v1 (Nikola's shape): a **to-do list per day**. A scrollable day strip at the bottom picks the day (swipe or tap; today marked, days with tasks dotted); the list above shows that day's tasks; + adds tasks to that day. Tapping a task marks it done (struck through); long-press selects to delete; drag handle reorders. Later: descriptions, editing, moving to another day. | ✅ v1, replaced by time blocks (P7) |
| P3 | Can be locked as a whole section (L5). | ✅ |
| P5 | **No Today button** (not needed). | ✅ |
| P6 | **Day strip shows little of the past:** past days are greyed out and can't be selected; at most the last 3 show, as filler. If an unfinished task is in the past, the strip reaches back to that day (selectable), plus 3 greyed days before it. Future days as now. | ✅ |
| P7 | **Time blocks** (towards P4, like TimeTune): each day is a timeline; tasks are blocks with a start and an end time, not a checkbox list. A day without tasks shows one big *free time* area. Free time is drawn as a block too: transparent, with a dotted border. Adding a task starts it at the beginning of free time and ends it 1 hour later; the end can be picked, with quick options 15 / 30 / 60 / 120 min and *end of free time*. The timeline is the whole day (00:00–24:00); there's no + button: a new day is one free slot, tapping a free slot adds a task in it (start = slot start, end = 1 h later, a quick option, or the slot's end), splitting it into free / task / free. Blocks never overlap. Later: colours, notifications, repeating daily. | ✅ blocks have a checkbox in the top-right corner; old tasks without times are shown marked, to delete |
| P4 | Scheduler in the style of *TimeTune* (time blocks across the day, routines). | 💭 later |

## U — UI polish ("fun but practical")

| # | Requirement | Status |
|---|-------------|--------|
| U1 | Small touches that make the app satisfying without getting in the way: shake on a wrong password, meaningful animations (e.g. hero transitions into a note, items sliding between shop lists), haptic feedback, clicky sounds for counters and similar. Each one optional where it could annoy. | 💭 after the main features |
| U4 | **Reach mode** (replaces "snap back"): pulling a list that's already at its top, with a new gesture, shifts it down by 28% of the list's height (about one row more than the first 20%; a bit more on Counters, whose rows are bigger) so its first rows are within thumb reach; it stays there. Any scroll the other way leaves the mode and snaps fully back to the top **as soon as the finger lets go** (not on the next touch). Scrolling towards the top from further down stops at the normal top (doesn't enter). A small pull springs back. | ✅ |
| U5 | **Drag handle area a little smaller** than the current 80 dp (Notes, Shop). | ✅ |
| U6 | **Counters: vibration and a click sound** on − / +, with an on/off switch in Menu → Settings. | ✅ the click follows the phone's touch sounds setting |
| U2 | Shop: replace the checkboxes with simple, nicer icons (from the phone test). | 💭 with the design pass |
| U3 | **One-handed use:** selection actions (select all, delete) as buttons in the lower right; lists can be pulled down past the top so top items come within thumb reach (springing back); bigger drag-handle grab areas; consistent ripples. From the second phone test. | ✅ pull-down is a first version, to tune on the phone |

## O — Other

| # | Requirement | Status |
|---|-------------|--------|
| O1 | **Other** tab lists additional tools; each opens as a page on top (back returns to the list). | ✅ Counters is the first tool |
| O3 | **Tools as tiles:** Other shows its tools as square tiles with only an icon (no title; still labelled for screen readers), laid out from the bottom right (thumb reach). | ✅ |
| O4 | **"Džoni što ćutiš?"** tool: turns the screen sideways (landscape), shows that text big with a counter under it; holding anywhere on the screen makes it shake and pop and counts up by one; the count is saved for good; long-pressing the page title opens a dialog to set it (or reset it to 0); back leaves (and restores the orientation). | ✅ |
| O2 | **Counters**: named counters with big − / + buttons and the current value; add, rename, reset, delete; reorder. | ✅ values may go below 0; reset and rename via selection mode |

---

## Technical notes

Code structure and its enforced rules: [ARCHITECTURE.md](ARCHITECTURE.md).

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
