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
| G4 | **Selection mode** behaves the same on every list: long-press selects, tap toggles, the top bar shows the count; the actions (select all, delete, and e.g. lock for notes) are round buttons in the lower right, in thumb reach; back, or deselecting everything, exits (no ✕ — Nikola). | ✅ |
| G5 | Deleting always asks for confirmation through the shared dialog. | ✅ |
| G6 | All data persists locally and is saved on every change; edits in progress are autosaved while typing and when the app goes to the background. | ✅ |
| G7 | **Navigation stack.** Each main section is the bottom of the stack: system back on a main section closes the app — after a confirming second press: the first shows *Press back again to exit*, a second within 2 s exits. Back first closes an open menu or leaves selection mode. Anything opened from a section (a note, a menu page, a sub-page under Other) is pushed on top, and back returns exactly to where the user was. | ✅ covered by `test/navigation_test.dart` |
| G8 | **Menu** (hamburger, top-left on every main section): **Security** page (master password, section locks), later **Backup** (export/import) and other app-wide options. The app version is shown at the bottom of the menu. | ✅ |
| G17 | **Menu header:** *Lock now* is an icon button at the top right of the menu, in a fixed header row (special actions; doesn't scroll with the list). Items: Security, Themes, Backup, Settings. | ✅ |
| G18 | **Leaving a page clears its state**: switching tabs ends selection mode and takes the planner back to today. | ✅ |
| G9 | Android only. No web/desktop targets or code paths. | ✅ |
| G11 | **Actions at the bottom, on the hand's side.** Top bars carry no action buttons except the menu (☰) — page actions are round buttons at the bottom, like selection mode. They sit on the side of the hand in use: bottom right after tapping the right half of the screen (e.g. opening a note from the right side), bottom left after the left half. Content can always scroll clear of them. Selection mode follows the same rule (side of the long-press), with ✕ as its last button; switching sides mirrors side and order. | ✅ ← back stays at the top |
| G12 | **Themes:** Menu → **Themes** page to switch the app's look. The app must first get its colours from a theme instead of fixed constants. | ✅ Clay (first, the default), Green, Black, Ocean, Frost, Grape, Rose, Mono — all dark, no light mode |
| G13 | **Back to a section = back to its top:** going to a section (tapping it in the bottom bar) clears any pulled-down space, so the list sits at its normal top. | ✅ |
| G14 | **Reach mode everywhere it helps:** every scrolling list (sections, the menu, Security, Backup, Themes, Settings, …) supports reach mode (U4). Exceptions only where pulling down brings nothing into reach (forms, bottom sheets, the routines timeline, bottom-up tiles; the planner and routines timelines have it since Rounds 14 and 17); enforced by `test/architecture_test.dart`. | ✅ |
| G15 | **Swipe right along the bottom bar opens the menu** (easier for the right thumb than the left screen edge). | ✅ |
| G16 | **The menu stays open behind its pages:** a page opened from the menu returns to the open menu on back; a second back closes the menu. | ✅ |
| G10 | **Accessible**: every screen meets Android's accessibility guidelines (48 dp touch targets, labelled controls for TalkBack, text contrast) and copes with large system font sizes. Checked by `test/design_test.dart`. | ✅ |

## D — Data safety: export / import

| # | Requirement | Status |
|---|-------------|--------|
| D1 | **Export** all data (notes, shop, planner, counters, settings needed to read locked data) to one JSON file the user saves anywhere (Downloads, Drive, …) via the Android file picker / share sheet. File name includes the date. | ✅ notes, shop, planner, counters, and the key of locked notes |
| D2 | **Import** a previously exported file: validated first (format, version), shows what it contains, and asks for confirmation before **replacing** current data. Invalid files are rejected without touching current data. | ✅ with Undo right after restoring |
| D2a | **Encrypted backups.** Export first asks **Plain** (readable JSON) or **Encrypted**. Encrypted uses the **master password** and is only offered once one is set; the file can't be read without it. Importing an encrypted file asks for the master password it was made with. | ✅ |
| D3 | Locked content stays encrypted inside the export; after import it opens with the same master password. | ✅ the backup carries the key, encrypted with the password; restoring adopts the backup's master password, or re-locks the notes under this phone's |
| D4 | Export files carry a format version; newer app versions can always import older exports. | ✅ newer ones are rejected with a clear message; app data and backups of every version (v1–v13) are read in tests from frozen samples |
| D5 | Cloud backup to a self-hosted service (e.g. S3-backed). The server is **typed in** (connection details entered in the app), never hard-coded. | 💭 not now |
| D6 | **Data-safety sweep**: everything that could lose data (storage, updates, restore, locks, crashes, phone changes), how safe export is, and when cloud saving should come. | ✅ v1 pass (Round 23): saves are atomic (temp file, then rename), a file that can't be read is set aside and said, newer formats are never misread, every format has frozen fixtures; a save that fails (a full phone) is said once, kept, retried on the next change or on coming back, and "Saved again" once it works; Round 21 closed the password-less ways to destroy protected data. Cloud saving: D5 after v1 |
| D7 | **Clear data per section** (Settings): pick Notes, Shop, Planner and/or Other and clear everything in them, after typing DELETE and, with a master password set, entering it. The Clear button is text only. | ✅ |
| D8 | **Surviving an uninstall**: data outside the app (automatic export to a folder the user picks, or cloud) so deleting the app doesn't lose it. | 🟡 the weekly reminder (D9) is in; automatic export after v1 |
| D9 | **Weekly backup reminder** (Round 23): Backup shows when the last export was ("8 days ago"; in red once due). A week after it (or after the first start, with none yet), a red dot on the menu button and on Backup, and a notification in the evening (19:00), again every 3 days until a backup is exported; tapping it opens Backup. A switch on Backup turns it off. Restoring doesn't count; a cancelled export doesn't either. | ✅ |

## N — Notes

| # | Requirement | Status |
|---|-------------|--------|
| N1 | List shows title and last-modified date/time, in a custom order (drag handle on the right). | ✅ |
| N2 | Tapping + creates "New Note" at the top and opens it; an untouched new note is removed on leaving. | ✅ |
| N3 | Title and body are directly editable; leaving saves; empty title becomes "Untitled". | ✅ |
| N4 | Long-press → select → delete with confirmation. | ✅ |
| N5 | **Save or discard on back.** Back after changing something asks *Save changes?* (*Save new note?* for a new one) with **Discard** (left) and **Save** (right) buttons and a line saying notes are saved automatically. Save — or back on the dialog — saves and leaves; tapping outside the dialog only closes it, staying in the note; Discard restores the note to how it was when opened, or deletes a new note. Back without changes leaves without asking. Closing or killing the app never asks: edits are always autosaved. | ✅ |
| N5a | **↶ Discard changes** (existing notes only): restores the note to how it was when opened, without leaving the editor. Asks for confirmation. | ✅ |
| N6 | **Lock a note** (from the editor menu or selection mode). A locked note's content is stored encrypted with the master password. Its **title stays visible** in the list, with a small lock icon. Opening it requires unlocking (see L). If no master password exists yet, locking first routes to password setup, then returns. | ✅ an open locked note closes (saved) when the app locks |
| N7 | Unlock a note permanently (remove the lock) — requires the app to be unlocked. | ✅ **Remove lock** in the editor menu and selection mode, with confirmation |
| N8 | **Undo / redo while typing** (e.g. undo a paste), step by step: ↶ and ↷ bottom buttons in the editor, always there and greyed out when there's nothing to undo / redo. A step is a burst of typing up to a 1 s pause, or one big change (a paste, a cut, Discard changes) on its own; title and text share one history. Undone changes are saved like any edit; the history lasts while the note is open. | ✅ |
| N10 | **Editor actions at the bottom (G11):** a row of round buttons on the hand's side: *Lock note* (or *Remove lock*), *Discard changes* (once something changed; not ↶), and ↶ *Undo* / ↷ *Redo* outermost, under the thumb — always in that order, ↶ left of ↷, on either side (the rest of the row mirrors). No ⋮ menu (it had one entry, and opening it fought with the keyboard). The text area scrolls clear of the buttons. | ✅ |
| N11 | **Edit the title from the bottom:** the title field is at the top, out of thumb reach, so a smaller *Edit title* button sits above the row of editor buttons, on the hand's side; it opens the title in a sheet at the bottom, above the keyboard. The title changes **live** as it's typed there, and may be left empty (saved as "Untitled" on leaving). Part of undo. | ✅ |
| N12 | **Line numbers in notes**, like a code editor: a thin, faint margin left of the text with one number per paragraph (a line between two Enters; a wrapped paragraph keeps one number), level with its first row, scrolling with the text. On by default; Settings has a switch. | ✅ |
| N13 | **View first, then edit:** an existing note opens for viewing (no keyboard, Markdown symbols hidden, list items shown with a dot •). Tapping the text (or title) edits right there. While editing, the phone's **back** — or closing the keyboard — goes back to viewing; back while viewing leaves as before (asking to save if changed). The ← arrow in the top bar always leaves. A new note opens ready to type. | ✅ |
| N14 | **Empty notes go away**: no title ("Untitled") and no content (only spaces / new lines) → removed on leaving, even after editing. If something changed, back still asks first, so changes can be discarded. | ✅ |
| N15 | **Checkboxes in notes**: `- [ ] ` / `- [x] ` items show as a box drawn by the app over a square space in the text (an outlined square / a filled one with a tick, in the accent, the same size, a bit bigger than the letters; Round 16: the phone's ☐ / ☑ glyphs ignored size and colour); the ticked item's text struck through and muted); tapping the box ticks it without starting to edit (saved, part of undo); tapping the words edits as usual. Enter after one continues with an empty box; Enter on an empty one ends the list. A small **Checkbox** button beside *Edit title*, shown only while typing the text (keyboard up), makes the current line a checkbox or a plain line again. | ✅ |
| N16 | **Introduction note**: a read-only note at the top of Notes (apart from the notes: not selectable or movable), drawn as Markdown: a guide to every part of the app for any user (`assets/introduction.md`), then **What's new** in this version (its CHANGELOG section). Marked *New* on a fresh install and after each update, until opened; an update brings it back if deleted, unless Settings → *Introduction after updates* is off. Deleted from its page (asks, with undo); while deleted, Settings offers *Restore the introduction* (not in the menu: it lives in Notes). Kept in preferences, not in backups. | ✅ |
| N9 | **Markdown, live while typing** (basics only; always on): the note stays plain text, the editor styles it as you type. **Lists** matter most: `- ` bullets and `1. ` numbered lists; Enter continues the list (next number), Enter on an empty item ends it. Also `#`/`##`/`###` headings, `**bold**`, `*italic*`, `~~strike~~`. Formatting symbols (`##`, `**`, `*`, `~~`) are **hidden except on the line being edited** (live preview, like Obsidian), shown muted there; when not typing, all are hidden. List markers stay visible, in the accent colour. Checkboxes: see N15. | ✅ |

## L — Security: master password & locking

| # | Requirement | Status |
|---|-------------|--------|
| L1 | Menu → **Security**: set, change (requires current), remove (requires current; decrypts locked items) the master password. | ✅ minimum 8 characters |
| L2 | The password itself is never stored. A key is derived from it with a slow KDF (Argon2id/PBKDF2 + random salt); only the salt, KDF parameters and a verifier are stored. | ✅ Argon2id (verified against OpenSSL); only a verifier is stored |
| L3 | Locked data is encrypted with an authenticated cipher (AES-GCM). Without the password it cannot be read, also not from an export. Forgotten password = locked data is unrecoverable (it can only be deleted, L7); the setup screen says so clearly. | ✅ encrypted backups and locked notes |
| L4 | **Convenient unlock:** entering the password once unlocks everything (locked notes and locked sections). It stays unlocked while the app is in use and while it is briefly in the background (e.g. switching away to copy something). It locks again when the app has been in the background for **5 minutes**, when the app is closed (removed from recent apps), or when "Lock now" is used. | ✅ Lock now in the menu and on Security; encrypted export uses the open session |
| L5 | **Section locks** on the Security page: per main section (Notes, Shop, Planner, Other) a switch to lock the whole section. Opening a locked section requires unlocking (L4). Only available once a master password is set. | ✅ hides the section (no encryption — locked notes are the encrypted option); turning a lock off needs the app unlocked; backups need unlocking while a section is locked |
| L7 | **Forgot master password → reset** (Security page). Removes the master password without knowing it, by deleting what it protects: every **locked note**, and **everything in a locked section** (all notes, shop items, planner tasks or counters), so a section lock can't be bypassed by resetting. Everything else stays. The confirmation lists exactly what will be deleted and, when anything will, needs typing RESET and then **holding Reset for 10 seconds** (hidden in plain sight, Round 21); a plain tap greys the reset out until the next unlock or a full day. Encrypted backups made with the old password still need it. The data is deleted (and on disk) before the password goes. | ✅ |
| L6 | **Unlock with fingerprint** as an alternative to typing the password. Turned on in Security (needs the app unlocked, and a fingerprint to confirm). Wherever the app asks for the master password to unlock, the fingerprint prompt comes up first; cancelling it leaves the password field, with a button to try the fingerprint again. The key derived from the password is kept in Android's keystore, released only by a fingerprint (strong biometrics only, invalidated when a new fingerprint is enrolled); the password itself is never stored. It's on this phone only (not in backups), and turns itself off when the master password is changed, removed or reset. | ✅ needs Android 6+ |
| L8 | **Nothing protected on leaving**: when the app starts leaving while unlocked, it is covered at once (background and a lock), so the frame Android keeps (recent apps, and the moment of coming back) shows nothing protected. Coming back after the auto-lock shows the locked page straight away, never a flash of the unlocked one; coming back sooner uncovers it. | ✅ |
| L9 | **Nothing protected is destroyed without the password** (Round 21): deleting locked notes, Clear data, and importing a backup over locked notes all ask for the master password while the app is locked. | ✅ |

## S — Shop

| # | Requirement | Status |
|---|-------------|--------|
| S1 | Two lists: **To buy** above **Items** (catalog of things bought before). Tapping an item moves it to the other list: to the top of *Items*, or to the end of *To buy* (S5). | ✅ |
| S2 | Items are only a name. + adds to To buy (at the end, S5); the input stays open for adding several in a row. | ✅ |
| S3 | Drag handle on the right reorders within a list. Long-press → select → delete. | ✅ |
| S4 | **Compact rows** — noticeably smaller than note rows (one 48 dp touch target high, ≥20% smaller, tighter gaps), so more items fit on screen without becoming harder to tap. | ✅ |
| S5 | New items, and items moved back from *Items*, go to the **end** of *To buy*, so it keeps the order things were added in (Nikola's request). Bought items still go to the top of *Items*. | ✅ |
| S6 | **A new item scrolls into view** as it's added: the list moves just enough to show it above the add sheet (from anywhere in the list), and not at all if it's already in view. | ✅ |
| S7 | **Quantities**: a small button on each item (to buy) toggles none → count → weight; the amount shows beside it ("×2", "200 g", "1.5 kg"). Tapping the amount opens a sheet at the bottom with the kind (None / Count / Weight) and big − / +: count by 1 (from 1, default 1); weight through common amounts (default 200 g), and tapping the weight types an exact one (any number above 0, below 1 g too; a comma works). Changes apply at once. Each kind keeps its value. In the bought list the amount shows but doesn't change, and touches there act on the row. | ✅ − / + live in the sheet: inline in the one-touch-target row they'd leave no room for names |

## P — Planner (currently the "To Do" tab)

| # | Requirement | Status |
|---|-------------|--------|
| P1 | Tab renamed to **Planner**. | ✅ |
| P2 | v1 (Nikola's shape): a **to-do list per day**. A scrollable day strip at the bottom picks the day (swipe or tap; today marked, days with tasks dotted); the list above shows that day's tasks; + adds tasks to that day. Tapping a task marks it done (struck through); long-press selects to delete; drag handle reorders. Later: descriptions, editing, moving to another day. | ✅ v1, replaced by time blocks (P7) |
| P3 | Can be locked as a whole section (L5). | ✅ |
| P5 | **No Today button** (not needed). | ✅ |
| P6 | **Day strip shows little of the past:** past days are greyed out and can't be selected; at most the last 3 show, as filler. If an unfinished task is in the past, the strip reaches back to that day (selectable), plus 3 greyed days before it. Future days as now. | ✅ |
| P7 | **Time blocks** (towards P4, like TimeTune): each day is a timeline; tasks are blocks with a start and an end time, not a checkbox list. A day without tasks shows one big *free time* area. Free time is drawn as a block too: transparent, with a dotted border. Adding a task starts it at the beginning of free time and ends it 1 hour later; the end can be picked, with quick options 15 / 30 / 60 / 120 min and *end of free time*. The timeline is the whole day (00:00–24:00); there's no + button: a new day is one free slot, tapping a free slot adds a task in it (start = slot start, end = 1 h later, a quick option, or the slot's end), splitting it into free / task / free. Blocks never overlap. Later: colours, notifications, repeating daily. | ✅ blocks have a checkbox in the top-right corner; old tasks without times are shown marked, to delete |
| P8 | **Routines** (repeating blocks). A routine is its own item — title, start and end time, the weekdays it runs on, from a date, until a date or forever — not copies on days: each day shows its one-off tasks plus the routines that fall on it (marked ↻). Tapping a routine's block on a day: *Change just this day* (it becomes a one-off task there; the routine skips that day), *Skip this day*, or *Edit routine*. Ticking it off counts for that day only. A **Routines** screen (from the planner) has the same timeline with a **Mon–Sun strip** instead of dates: tapping free time adds a routine on that weekday (more days can be ticked), tapping a routine edits or deletes it everywhere. The add sheet has **Repeat**: doesn't repeat / every day / weekdays / chosen days, **until** forever or a date. Rules: routines never overlap each other on a shared weekday; a one-off and a routine may share time (P12). Editing a routine changes every day it's on, past ones too (ticks and skips stay with their days). Missed routine blocks don't pull the day strip back (P6), and routines don't dot the day strip. | ✅ |
| P9 | **Block colours:** tasks and routines can have one of a few colours from a small palette that suits each theme. | ✅ |
| P10 | **Reminders:** a task or routine can remind: Off (default), at its start, or 5 / 10 / 15 / 30 min or 1 h before. A notification with its title and time; tapping it opens the app. None for blocks ticked off or routine days skipped. If the Planner section is locked, the notification leaves the title out. Reminders are planned two weeks ahead, again on every change and whenever the app opens (so routines keep reminding); they survive a restart of the phone. Notifications permission is asked the first time a reminder is set; exact timing uses Android's exact alarms (the app isn't on the Play Store, so it can declare them). | ✅ not yet tried on a phone |
| P11 | **The add / edit sheet** follows reach mode (pulling down shifts the form towards the thumb, never closes it) and can't be dragged closed. A fixed row at the bottom holds **Close** (✕) and Add / Save. Closing with changes asks *Discard changes?* (Cancel / Discard); system back on that question counts as Discard. | ✅ |
| P12 | **A one-off and a routine at the same time** (replaces "the one-off wins"). Tasks never overlap tasks and routines never overlap routines, but a task and a routine may: at most one of each at any moment. Where they share time they sit **side by side, task left, routine right**; where one goes on alone it takes the full width, drawn as the same block continuing (one shape, no gap). Each ticks off and reminds on its own. Free time is time with neither. Adding from free time, a task may reach over routines up to the next task ("Until the next task"); set to repeat, it stays clear of routines instead, and the sheet says so if its times had to change. Tapping a routine also offers **Add a task alongside**; it and *Change just this day* use the routine's time, fitted around tasks already there (said under the times), and are off when tasks fill it. | ✅ |
| P13 | ~~Timeline zoom~~ (removed, Round 10). **Short blocks stretch the timeline:** every block is at least one touch target high (like a 30-minute block); where a shorter one is, the timeline is taller there (that hour takes more room than others), so nothing is squeezed. A block is **at least 5 minutes**; the sheet says so if a picked time had to change for it. | ✅ |
| P14 | **Reminders** (Nikola: like a one-off reminder or to-do): a title at a **time with no end**, on one day. Shown as a **mark on the timeline's left edge** (a bell, by the hour labels) at its time, so nothing covers the blocks; it takes no time. Reminders whose marks would overlap (Round 19: about 12 minutes apart) **share one mark** showing how many; closer marks than a touch target each keep theirs, a tap going to the nearer one. **Tapping a mark** opens a menu at the bottom listing its reminders (title, time, a box to tick); ticking one off deletes it (with undo), tapping one edits it (Delete is there). Added with a **bell button** at the bottom of the planner (title and time). Notifies **at its time**. Unticked, it stays on its day, and the day strip reaches back to it like an unfinished task. In backups. | ✅ marks since Round 11 (the menu comes up from the bottom rather than a bubble by the mark: actions at the bottom, G11) |
| P15 | **Tapping a task shows it first** (like a routine): title, time, colour, reminder and options; Edit opens the sheet. Editing doesn't focus the title (no keyboard just to look). Add / Save stay greyed out until the title is valid. | ✅ |
| P16 | **A "now" line** across today's timeline at the current time, moving with the clock. | 💭 Round 11 |
| P17 | **Notifications always arrive**: app open, in the background, swiped away, screen off, phone locked, after a restart (exact alarms, Doze, battery optimisation, boot). | 💭 Round 11 |
| P18 | **Notification settings** (in Settings): the sound, and the colour (the block's colour, or set per reminder). | 💭 Round 11 |
| P19 | **More block colours**; new tasks default to blue, routines to purple. | ✅ |
| P20 | **Descriptions**: tasks and routines have an optional description, typed in the sheet under the title; shown on the block below the time when there's room (as many lines as fit), and in full in the block's menu. | ✅ |
| P21 | **Now line**: on today, a line with a dot marks the time now across the timeline (following stretched hours); it moves on each minute and goes when the day is over. | ✅ |
| P22 | **Clashes are shown, never fixed by themselves**: in the add / edit sheet, times that run into another block (a picked start or end, or weekdays / an end date that bring in another routine) stay as they are; the times turn red, a red line (with its icon, like the info line) says what's there, and Save / Add is off. **Find a free time** (a button under it, at the form's left) moves them into the nearest free time and says where. When the line appears or goes because of the days picked below it, the form scrolls by as much, so the chip just tapped stays under the finger. Only the shortest length (5 min) and the day's end still correct a time directly. | ✅ |
| P23 | **Where you tap counts**: tapping free time starts the new block near the tap, rounded down to :00 or :30 (never before the free time starts); tapping the timeline's left edge, by the hour labels, adds a reminder there, rounded down to 15 minutes (the marks on that edge still open theirs). A screen reader's tap (no point) keeps the old rules: free time's start, or today the next full hour. | ✅ |
| P24 | **Tapping a notification opens what it's about** (Round 19): a block, routine or reminder opens the Planner on its day, scrolled to it; a medicine opens the Medicine page. From anywhere in the app (pages on top close). Locks stay as they are: a locked section shows its lock screen, and the "go to" waits there until it's unlocked, also on a later visit. | ✅ |
| P4 | Scheduler in the style of *TimeTune* (time blocks across the day, routines). | ✅ via P7–P9 |

## E — Notifications

| # | Requirement | Status |
|---|-------------|--------|
| E1 | **Reliable reminders**: planned two weeks ahead, again on every start, change and return to the app; kept across phone restarts and app updates; exact where Android allows (USE_EXACT_ALARM). Doses due at the same minute come as **one** notification (Android holds back alarms close together while idle). When reminders would run past what's planned, a notice the evening before asks to open the app. Settings says so when the phone blocks notifications, and asks to allow them. | ✅ Round 23 |
| E2 | Notification sounds per kind, picked in the app (each kind has its own Android channel meanwhile: planner, medicine, backup, notices). | 💭 after v1 |
| E3 | **Notifications page** (menu): recent ones (today and yesterday) that open their page, a button to clear them, and E2's settings. | 💭 after v1 |

## U — UI polish ("fun but practical")

| # | Requirement | Status |
|---|-------------|--------|
| U1 | Small touches that make the app satisfying without getting in the way: shake on a wrong password, meaningful animations (e.g. hero transitions into a note, items sliding between shop lists), haptic feedback, clicky sounds for counters and similar. Each one optional where it could annoy. | 💭 after the main features |
| U4 | **Reach mode** (replaces "snap back"): pulling a list that's already at its top, with a new gesture, shifts it down by 28% of the list's height (about one row more than the first 20%; a bit more on Counters, whose rows are bigger) so its first rows are within thumb reach; it stays there. Any scroll the other way leaves the mode and snaps fully back to the top **as soon as the finger lets go** (not on the next touch). Scrolling towards the top from further down stops at the normal top (doesn't enter). A small pull springs back. | ✅ |
| U5 | **Drag handle area a little smaller** than the current 80 dp (Notes, Shop). | ✅ |
| U6 | **Counters: vibration and a click sound** on − / +, with an on/off switch in Menu → Settings. | ✅ the app's own click sound (Android's touch sound is often switched off, so it was silent — Nikola); follows the media volume, quieter than full (Round 16) |
| U7 | **Toasts** (messages at the bottom, with Undo) styled to match the app: a rounded card in the theme's colours with a thin edge, floating above the bottom buttons, the action in the accent. Set once in the theme, so every message gets it. | ✅ |
| U8 | **No button flashes** when it turns on (label and fill change together), for every button in the app, enforced in the theme. | ✅ in the theme; test/core/theme_test.dart |
| U2 | Shop: replace the checkboxes with simple, nicer icons (from the phone test): a cart (accent) while an item is to buy, a quiet tick once bought. Still announced as checked / not checked. | ✅ |
| U3 | **One-handed use:** selection actions (select all, delete) as buttons in the lower right; lists can be pulled down past the top so top items come within thumb reach (springing back); bigger drag-handle grab areas; consistent ripples. From the second phone test. | ✅ pull-down is a first version, to tune on the phone |

## O — Other (shown as **Hub** since Round 13)

| # | Requirement | Status |
|---|-------------|--------|
| O1 | **Other** tab lists additional tools; each opens as a page on top (back returns to the list). | ✅ Counters is the first tool |
| O11 | **Renamed to Hub** (Nikola's pick): the tab and its page say *Hub*, and so does the code and what's saved (`AppSection.hub`, `HubTool`, `pages/hub/`, `layout.json`'s `hub`). The old id `other` is still read (a section lock or layout saved before), so nothing is lost. | ✅ |
| O12 | **Hub page settings**: a page that has settings shows a settings button in its top bar (not at the bottom; Counters and Placard have none). Medicine: reminders on/off, the red dot on/off, and pausing reminders and the dot through today, tomorrow, 3 days or a week. Kept on the phone, not in backups. | ✅ |
| O13 | **Medicine, round 2**: buttons always on the right; a sound and vibration on ticking; dose boxes two per row, same width; medicines reordered by drag handles; a tap anywhere on a card opens it; no "for good" text. History of all: the medicines on top (each opens its own history), then each day as a small table, a row per medicine with a mark per dose; a row opens that medicine's history at that day, where each dose can be set (taken / missed / not sure); built as it scrolls, ready for years of marks; a medicine's own history with a month calendar (weeks as rows, Monday first, each day coloured by how it went, with a legend; older months to the left by swiping or ‹ / ›; a day's tap shows that day in the list below, changing nothing; Round 18) and a lifetime total; the states in fixed colours whatever the theme (green taken, red missed, amber not sure); unticking a taken dose asks first; each card shows its total taken; start in the past and mark the past days taken. Notifications at dose times for doses not marked, and, set per medicine in its sheet (Round 16), a second one 1–4 h later if still not marked (own Android channel; no name while the Hub is locked); a red dot on the tile and the Hub tab while one of today's doses is due and not marked (yesterday's from 22:00 too, until 02:00) (marking it missed or not sure clears it too), seen even when the Hub is locked. | ✅ |
| O3 | **Tools as tiles:** Other shows its tools as square tiles with only an icon (no title; still labelled for screen readers), laid out from the bottom right (thumb reach). | ✅ |
| O4 | **Placard** (was the Džoni page): sideways, full screen (no status bar), a big line of text with a count under it. **Holding** the page inflates it, shaking harder as it fills, then it **pops and counts** one up (a burst from fully inflated, with a ring flying out, then a spring back; a rising sound while held and a pop; a hold of about 3 seconds; one count per hold; letting go early lets it down; a tap does nothing). **Five taps in the top-right corner** open its settings: the text (default "Add text here!"; blank goes back to it) and the count (default 1; Reset fills in 0, Save applies). On back it turns upright first, then closes. Kept in `placard.json` and in backups. | ✅ |
| O2 | **Counters**: named counters with big − / + buttons and the current value; add, rename, reset, delete; reorder. | ✅ values may go below 0; reset and rename via selection mode; selection mode without ✕ (back leaves it) |
| O5 | **Counters, expanded**: adding opens a sheet with the name and options — **step** (how much − / + count, at least 1), **colour**, **min** and **max** (empty: no limit); editing (selection mode → Edit) opens the same sheet. The buttons read −5 / +5 for a step above 1 and turn off at a limit; the limits show under the value ("0–10"). It starts and resets at 0, or the nearest limit if 0 is outside. Cards have room around them and rounder corners; compact and all one height (limits sit beside the name); − / + are in the counter's vivid colour (which also edges the card), or the app's grey without one. | ✅ |
| O6 | **Medicine tracker** (Hub → Medicine): medicines with the time of each dose (how many a day = how many times, up to 8), from a day until a day or for good. **Today**: a card per medicine with a big button per dose; one tap marks it taken with the time ("Taken 08:03"), a second tap unmarks it (with undo); several a day show "1 of 2"; the top line says how many of today's doses are taken. Medicines not on today are listed apart. Tapping a medicine's name edits or deletes it (its history goes too, with undo). **History**: every day back to the first start, newest first, each dose with the time it was taken or "not taken". Kept in `medicine.json` and in backups. | ✅ |
| O7 | **Lock each Hub page on its own** (like section locks): a switch per page under the Hub on Security. Independent of the Hub's own lock (a locked Hub with free pages, or a free Hub with locked pages); a locked page shows a lock screen while the app is locked, and its tile a small lock. A reset deletes a locked page's data; medicine reminders leave names out while Medicine is locked. | ✅ Round 21 |
| O8 | **Arrange Other**: hold a tile and drag it to change the order (it takes a tile's place as soon as it's over it); kept across restarts. Screen readers get *Move earlier* / *Move later*. | ✅ (to try once Other has a second page) |
| O9 | **Pages as a system** (architecture, before v1): every page is registered once (id, name, icon, page, its data, lockable); Other, Clear data, page locks, backups and later the quick-access menu all read from that list, and the arrangement is stored as page ids, so new pages and new places to put them need no rework. | ✅ see ARCHITECTURE "Pages as a system" |
| O14 | **Food tracker** (Hub page, first of the new ones): foods eaten each day with how well they agreed, a day view, and statistics that point out which foods tend to cause trouble. Design to propose. | 💭 Round 15 |
| O10 | **Page organizer** (v2): a quick-access menu opened from the right side, with the pages picked for it; maybe sections in Other; maybe rename Other; later pages to control Nikola's servers and connectors to his projects. | 💭 v2 |

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
