# Changelog

All notable changes to the app. Versions follow `MAJOR.MINOR.PATCH`
(see [docs/RELEASING.md](docs/RELEASING.md)); each version is a GitHub
Release with the installable APK.

## [1.0.0] - unreleased

### Added
- Settings says when the phone blocks the app's notifications, and
  asks to allow them.
- Reminders are planned two weeks ahead: if the app isn't opened for
  that long, a notice the evening before asks to open it, so they keep
  coming.

### Changed
- Doses due at the same time come as **one** notification naming them
  all (Android could hold the second one back for many minutes).
- **The app's own icon**: a little pixel robot in the Clay colours,
  instead of Flutter's logo. On Android 13 and later it follows the
  phone's themed icons too.

## [0.27.0] - 2026-10-13

### Fixed
- Security: the Hub's lock switch could hide under the phone's own
  navigation bar; every list now leaves room for that bar.
- A tapped notification's "go to" is dropped when you go to another tab
  yourself (it went to Medicine later, after a detour).
- Locked notes can no longer be deleted without the master password.
- Importing a backup over locked notes asks for the master password
  first (it replaced them without it).

### Added
- **Weekly backup reminder**: Backup shows when the last backup was.
  A week after it, a red dot on the menu and on Backup, and an evening
  notification (again every 3 days until you export one) that opens
  Backup. It can be turned off on Backup.
- **Lock each Hub page on its own**: in Security, under the Hub, a
  switch per page. A locked page asks for the master password while the
  app is locked (its tile shows a small lock), whether or not the Hub
  itself is locked. Resetting a forgotten password deletes a locked
  page's data, and medicine reminders don't name the medicine while its
  page is locked.
- Medicine histories: a **back to top** button once you've scrolled far
  down.

### Changed
- Notes: **Discard changes** is always there (greyed out until there's
  something to discard), so the buttons don't shift.
- Placard: a longer inflate (about 4 seconds), and a quieter pop.
- Medicine: the total on each card is level with the drag handle.
- Settings: line numbers first.
- Security: resetting a forgotten password is harder to stumble on:
  after typing RESET, **hold** Reset for 10 seconds. A plain tap greys
  the reset out until the next unlock, or for a day.

## [0.26.0] - 2026-10-13

### Added
- **Tapping a notification opens what it's about**: a block, routine or
  reminder opens the Planner on its day, scrolled to it; a medicine opens
  the Medicine page. A locked section still asks first; if it isn't
  unlocked then, it goes there once it is.

### Changed
- Medicine: a medicine's history has a **month calendar** instead of
  the strip: weeks as rows, each day coloured by how it went (with a
  legend). Swipe right or tap ‹ for older months; tap a day to see it in
  the list below.
- Medicine: history and calendar use the same colours in every theme:
  **green** taken, **red** missed, amber not sure.
- Medicine: the **history of all medicines** is new: the medicines on
  top (tap one for its own history), then each day as a small table, a
  row per medicine with a mark per dose. Tapping a row opens that
  medicine's history at that day, where doses can be set. Ready for years
  of history.
- Medicine: unticking a dose asks first (a slip of the finger); each
  card shows how many doses were taken in all.
- Medicine: late doses on the main page are no longer red (that was
  meant for the calendar).
- Placard: the inflating sound is just the rising tone, no static.
- Planner: the hour labels a touch further from the edge.
- Planner: reminder marks a bit bigger, midway between the hour and the
  timeline. Two reminders share a mark only when they'd overlap (about
  12 minutes apart, not 27); close ones each keep their own, and a tap
  goes to the nearer one.
- Counters: the first click after opening is in step with its buzz.

## [0.25.0] - 2026-10-13

### Fixed
- Medicine: the red dot showed after midnight for any dose missed the
  day before; now only for doses at 22:00 or later (until 02:00).
- Pages opened on top (like the Introduction) leave room for the phone's
  own bar too, so their last lines scroll clear of the buttons.

### Changed
- Medicine: **Remind again** is now set for each medicine, in its sheet
  (No, or 1–4 h later), instead of once for the whole page. Its menu
  shows it. (Backups now have format 13.) If you had set it for the
  page, set it again on the medicines that need it.
- The Introduction is no longer in the menu (it lives in Notes); once
  deleted, **Settings → Restore the introduction** puts it back.
- Medicine: a dose whose time has come and isn't taken shows in **red**.
- Medicine: ticking a dose buzzes twice, softly, in step with the gulp.
- Routines screen: reach mode on its timeline, as on the planner.
- Planner: a smaller margin left of the hour labels.
- Placard: the pop no longer shrinks first: it bursts from fully
  inflated, with a ring flying out, and springs back. A rising sound
  while you hold, and a pop.

## [0.24.0] - 2026-10-12

### Fixed
- Notes: the lines level with the buttons at the bottom were hidden
  (e.g. after redo they looked missing), and tapping there jumped the
  text. Now nothing covers the text, taps beside the buttons reach it,
  and the line you're on scrolls up clear of the buttons.
- Planner: the hour labels have their margin from the screen's edge
  back.
- Notes: checkboxes are now drawn by the app, so both look right on
  every phone: an outlined square, or a filled one with a tick, in the
  accent, the same size.

### Added
- An **Introduction** at the top of Notes: how each part of the app
  works, and what's new in this version. It comes back marked *New*
  after each update (Settings can turn that off); delete it from its
  page, and open it any time from the menu.
- Planner and routine sheets: an **End of day** choice for the end time.

### Changed
- Medicine: ticking a dose plays a soft **gulp** instead of the chime.
- Counters: the click is quieter and follows the **media volume**.
- Placard: the hold to count is longer again (about 3 seconds).
- Routines screen: a new routine starts where you tap the free time, as
  on the planner.
- Medicine: "Mark past days taken" is offered only when more than 10
  past doses aren't set.
- No tooltip pops up when holding a button (e.g. − in the shop).
- Notes: no magnifier lens while selecting text.
- Medicine: a dose missed late in the evening keeps the red dot until
  02:00.

## [0.23.0] - 2026-10-12

### Added
- Medicine: **reminders** at each dose time, and if you like a second
  one 1–4 hours later while it's still not taken. A **red dot** on the
  Medicine tile and the Hub tab while one of today's doses is due (shown
  even when the Hub is locked). Both can be turned off or **paused** for
  a day or more in Medicine's new **settings** (the gear in its top bar).
  Medicine reminders have their own channel in Android's notification
  settings.
- Medicine: **history you can read and fix**. Each day has a coloured
  title and a mark per dose; tap one to set it taken, missed or not sure.
  Each medicine has its **own history** (in its menu): the total taken
  so far, a calendar strip of its days (scroll left for older ones) and
  every day below. A medicine can **start in the past**: you're asked
  whether to mark those days taken, and its history has a button for it
  too. (Backups now have format 12.)

### Fixed
- Planner: screen readers can add a task from free time again (it had
  no tap action).
- Planner sheet: ticking a weekday that clashes no longer pushes the
  form down (the chip you tapped stays where it was). The clash line
  looks like the info line, in red, and **Find a free time** is a real
  button.
- Notes: the ticked checkbox showed as a white emoji, and the empty one
  sat higher; both are now drawn the same, in the accent, without a jump
  when ticking.

### Changed
- Medicine: ticking a dose plays a short chime and buzzes (no undo when
  unticking: just tap again). Doses sit two to a row, all the same
  width; a tap anywhere on a card opens it; drag a card's handle to move
  it; the buttons are always on the right; no "for good" written.
- Planner: a new block starts **where you tap** the free time (rounded
  down to :00 or :30), and tapping the **left edge**, by the hour labels,
  adds a reminder there (rounded down to 15 minutes).
- Planner: **reach mode** on the timeline. At 00:00, pull down again and
  the first hours come into thumb reach; push up and it snaps back.
- Placard: the hold to count is longer (about 2½ seconds).
- Counters are more compact and all the same height; − / + are in the
  counter's own colour, vivid (the colour also edges the card), or the
  app's grey without one. No "none" hint in Min / Max.

## [0.22.0] - 2026-10-12

### Changed
- **Other is now called Hub** (a section lock or tile order you had
  carries over).

### Added
- Hub: **Medicine**. Add your medicines with the time of each dose and
  how long you take them; tap a dose when you've taken it (the time is
  kept). Several a day show as 1 of 2. History lists every day. (In
  backups, now format 11.)
- Counters: **options**. A new counter (or Edit, in selection mode) has
  a step (− / + count by it), a colour and optional min and max; the
  buttons stop at the limits. Cards look rounder, with room around them.
  (Backups now have format 10.)
- Hub: **Placard**. A big line of text, sideways and full screen, with
  a count: hold the page and it inflates, shakes and pops to count one
  up. Five taps in the top-right corner set the text and the count. (In
  backups, now format 9.)
- Hub: **hold a tile and drag it** to change the order (kept).
- Settings → Clear data lists the Hub's pages one by one.

## [0.21.0] - 2026-10-12

### Added
- Shop: **amounts**. The new button on an item switches between none, a
  count and a weight; tap the amount for big − / + (weights step through
  common amounts, from 200 g) or to type an exact weight. (Backups now
  have format 8; older ones restore as before.)
- Planner: **reminders are small bell marks** on the timeline's left
  edge instead of boxes over the blocks. Close ones share a mark with a
  number; tap a mark to see them, tick them off or edit them.
- Five more themes, all dark: **Ocean**, **Frost**, **Grape**, **Rose**
  and **Mono**.

### Changed
- Messages at the bottom (like "… deleted · Undo") are a rounded card
  in the theme's colours, floating above the buttons.
- Planner sheet: a time that runs into another block is **no longer
  moved by itself**. It stays, in red, Save is off, and a **Find a free
  time** button moves it if you want.
- **Clay** is first in Themes and the default for a new install. Its
  orange text buttons are a touch lighter, to read better.
- Notes: the Checkbox button is a small one beside *Edit title*, shown
  only while typing. The empty box is bigger, and both boxes are in the
  theme's accent colour.
- Settings → Clear data: confirm by typing DELETE; the Clear button is
  just text.

### Fixed
- Editing a routine: Save sits right at the edge again (since Delete
  moved left it stopped short).

## [0.20.0] - 2026-10-12

### Added
- Notes: **checkboxes**. Type `- [ ] ` (or use the new Checkbox button
  next to ↶) and it shows as a box; tap the box to tick it. Enter starts
  the next one.
- Planner: a **now line** across today's timeline at the current time.
- Settings → **Clear data**: pick Notes, Shop, Planner and/or Other and
  empty them, after typing RESET and entering the master password (if
  one is set). Backups are not touched.

### Changed
- Notes: tapping outside the *Save changes?* dialog only closes it and
  you stay in the note (back on the dialog still saves and leaves).
- Planner sheet: no ✕ (back closes it, asking first if something
  changed); editing a routine has a plain **Delete** on the left.
- Planner: short blocks show a line of their description too, down to
  the smallest.

### Fixed
- Coming back after the auto-lock no longer shows the locked page for
  a moment: the app is covered as it leaves while unlocked.
- No button flashes when it becomes available anymore (it happened on
  the planner's Add): the fix now covers every button in the app.

## [0.19.0] - 2026-10-12

### Added
- Planner: tasks and routines can have a **description**. It shows on
  the block under the time when there's room, and in full when you tap
  the block. (Backups now have format 7; older ones restore as before.)

### Changed
- Planner: tapping a task shows what it is first (time, colour,
  reminder) with Edit and Delete (with Undo), like a routine; editing
  doesn't open the keyboard straight away.
- Planner: Add / Save stay greyed out until there's a title.
- Planner: four more colours (teal, pink, brown, grey); new tasks start
  blue and new routines purple.
- Notes: a note with no title and nothing in it goes away when you
  leave it, also one that was emptied by editing (back still asks first,
  so the change can be discarded).
- Switching tabs ends selection mode, and coming back to the Planner
  shows today (a selection or a picked day used to linger).
- Planner: a short block (say a 5-minute shower) is now drawn full size,
  and its hour on the timeline gets a bit taller to make room, instead
  of the block being squeezed.

### Removed
- The planner's zoom button: short blocks no longer need it.
- The Džoni page in Other. Its count is no longer kept; older backups that
  have it still restore.

## [0.18.0] - 2026-10-11

### Added
- **A task and a routine can share time**: side by side, the task on
  the left and the routine on the right; where one goes on alone it
  takes the full width. Tapping a routine has a new *Add a task
  alongside*. (Before, a task pushed the routine off that day.) Two
  tasks, or two routines, still can't overlap. The quick end in the
  sheet now reads *Until the next task* (or routine, or midnight).
- **Reminders on the planner**: the bell button at the bottom adds a
  reminder: a title and a time, no end. It floats over the timeline as a
  small dashed block without taking up time, notifies at its time, and
  goes away when you tick it off (with undo). Tap it to change or delete
  it. Included in backups.
- **Planner zoom**: a button at the bottom (also on Routines) makes the
  timeline bigger in two steps, so even a 5-minute block can be read and
  ticked, then back to normal. It's remembered. Blocks are now at least
  5 minutes long.

### Changed
- **Notes open for viewing**: tap the text to edit it there. Back (or
  closing the keyboard) while editing goes back to viewing; back again
  leaves. The ← arrow at the top always leaves.
- List bullets show as dots (•), except on the line you're editing.
- Menu: *Lock now* is an icon at the top right (it stays put), and
  *Themes* comes before *Backup*.
- Setting a password: the keyboard's next key goes to the next field.
- A locked note shows a lock icon next to "Note" instead of "Locked
  note".
- *Edit title* changes the title as you type, and it can be left empty.
- Selection mode has no ✕ button anywhere: back, or deselecting all,
  leaves it.
- Other: new icons for the tiles (tally marks for Counters, a speech
  bubble for Džoni).
- Shop: a cart icon marks what's to buy and a tick what's bought,
  instead of checkboxes.
- Shop: the select button first selects the list you started in, then
  both lists, then nothing.
- Planner: more space between blocks that touch (an hour is a bit
  taller, so a 30-minute block is still a full touch target); a bell on
  blocks with a reminder; when a picked time had to change to fit, the
  sheet says why.
- Selected items have a much clearer outline everywhere.
- Planner sheet: it no longer closes when dragged down; pulling down
  brings the form into thumb reach. A ✕ at the bottom closes it, and if
  something changed it asks first (back on that question discards).

### Fixed
- Planner notifications show a proper bell icon instead of a grey blob.
- Planner: ticking another weekday (or changing the end date) in a
  routine's sheet now moves its times clear of other routines on those
  days and says so. Before, the clash only showed after saving, and the
  changes were lost.
- If the phone can't save (e.g. its storage is full), removing, changing
  or resetting the master password now stops and says so, instead of
  going ahead with data that wasn't saved.
- Data that can't be read at startup is still kept aside (never
  overwritten), and now the app says which.
- Resetting a forgotten password with the Planner locked also deletes its
  reminders.
- Planner: left open overnight, it still showed yesterday as today until
  something changed. It now catches up when the app comes back.
- Notes: pressing Enter at the very start of a note works again.
- Notes: if the app locked while *Save changes?* was open (with Notes
  locked), it could end on a black screen. It now saves and goes back to
  the lock screen.
- Notes: only moving the cursor no longer rewrites the notes file.
- Planner notifications: two quick changes could leave a notification
  for something already ticked off or deleted. They're now planned one
  at a time.
- Planner: adding a task in the last minutes before another one no
  longer makes a block shorter than 5 minutes, and an old short block
  can be edited without its times getting stuck.
- Planner: a reminder can be at any minute, up to 23:59.
- Planner: while selecting, checkboxes don't tick anything.
- The Reset button in *Forgot password* no longer flashes when it
  becomes available.
- Planner: a long-pressed block now shows as selected (it was selected,
  but didn't look it until something else redrew the day).
- **Counters click again**: the app plays its own click; Android's touch
  sound (which it used before) is off on most phones.

## [0.17.0] - 2026-10-11

### Added
- **Planner routines**: blocks that repeat every day, on weekdays or on
  chosen days, for good or until a date. Set Repeat when adding a task,
  or use the new **Routines** screen (button at the bottom of the
  planner; a Mon–Sun strip picks the weekday). On a day, tap a routine's
  block to change it just there, skip that day, or edit the routine;
  ticking it off counts for that day only. A one-off task already in its
  way wins that day.
- **Planner reminders**: in the task or routine sheet, *Remind* at the
  start or 5–60 minutes before. A notification with the title and time
  (only "Planner" and the time while the Planner section is locked).
  Notifications permission is asked the first time.
- **Block colours** in the planner: pick one of six colours (or none) in
  the task or routine sheet; the block gets a tinted background and a
  coloured stripe.

### Changed
- **The menu stays open** when you come back from one of its pages; back
  again closes it.
- Counters: selection mode has no ✕ button any more (back leaves it).
- Notes: ↶ Undo and ↷ Redo stay in that order when the buttons are on
  the left.
- Planner: an hour is a little taller, so even a 30-minute block (and
  its checkbox) is a full touch target; the task sheet's times are
  outlined buttons, readable in every theme.

## [0.16.0] - 2026-10-10

### Added
- **Line numbers in notes**, like a code editor (one per paragraph). Turn
  them off in Settings.

### Changed
- **Markdown symbols hide** once formatted: `##`, `**` and the rest only
  show on the line you're editing.

## [0.15.0] - 2026-10-10

### Added
- **Markdown in notes, styled as you type**: `- ` and `1. ` lists (Enter
  continues them, Enter on an empty item ends the list), `#`–`###`
  headings, `**bold**`, `*italic*`, `~~strike~~`. Notes stay plain text.
- **Unlock with fingerprint** (Security): instead of typing the master
  password, wherever the app asks for it. Kept on this phone only, in
  Android's keystore; turns itself off when the master password changes.
  The app now needs Android 6 or newer.
- **Edit title** button in the note editor: a smaller button above the
  others opens the title in a sheet at the bottom, within thumb reach.
- Džoni: the page has no top bar; a triple tap in the top-right corner
  sets or resets the count.

### Changed
- **Note editor buttons**: Lock note (or Remove lock) is a button of its
  own instead of a ⋮ menu, and ↶ Undo / ↷ Redo sit outermost, under the
  thumb. Tapping them no longer closes the keyboard.
- **Planner free time is a block too**: see-through, with a dotted
  border, lined up with the task blocks.
- **Reach mode reaches further** (about one row more; Counters a bit
  more again).
- **Shop scrolls to each new item** as you add it, so you see it land in
  the list above the add sheet.

### Fixed
- **Reach mode snaps back as soon as you let go**: a small scroll the
  other way used to coast, and only snapped back on your next touch.

## [0.14.0] - 2026-10-10

### Added
- **Undo / redo in notes**: ↶ and ↷ buttons in the editor go back and
  forward step by step (a burst of typing, or a paste, is one step).
  Discard changes can be undone too.
- **Forgot master password?** on the Security page: resets it by deleting
  what it locks (locked notes, and everything in locked sections).
  Everything else stays. The confirmation lists what goes and asks you to
  type RESET.
- **Edit planner tasks**: tap a block to change its title or times (up to
  the tasks around it).

### Changed
- On today, a new planner task starts at the next full hour instead of
  at the start of the free time.
- The planner's 00:00 label is no longer cut off at the top of the day.
- Changing the theme no longer flashes the old one for a moment.
- **Reach mode in the menu and on every list page** (Security, Backup,
  Themes, Settings): pull down at the top to bring the first items
  within reach.
- **Swipe right along the bottom bar** to open the menu.
- **Clay** looks more like the Claude app: near-black background and
  Claude's deeper orange.
- **Planner day strip previews live**: while you swipe, the day in the
  middle (now framed) is shown at once, not only when you let go.
- **Reach mode replaces the pull-down space**: pull a list down when it's
  already at the top to shift it down (by less than before) so the first
  rows are in thumb reach; any scroll the other way snaps it back.
  Scrolling up from further down just stops at the top.

## [0.13.0] - 2026-10-10

### Added
- **Planner time blocks**: each day is a timeline from 00:00 to 24:00.
  Tap free time to add a task there — it starts where the free time
  starts and lasts an hour, or pick 15 / 30 min, 1 / 2 h, *until free
  time ends*, or a time. Tasks never overlap; tick them off with the
  checkbox in the block's corner. (There's no + button anymore.)
- **Themes** (Menu → Themes): Green (the original look), Black (true
  black for OLED screens) and Clay (warm greys with a clay-orange accent).
- **Settings** (Menu → Settings): switch the counters' click and
  vibration on or off.
- **Counters click and vibrate** on − and +.
- **Džoni** in Other: a sideways page with a big question and a count —
  hold anywhere to count one up.

### Changed
- **Actions sit at the bottom, on your hand's side.** Selection mode and
  the note editor show their buttons at the bottom right — or bottom left
  if you tapped on the left half of the screen to bring them up. Top bars
  keep only ☰ (or ←). Selection's ✕ is now the outermost bottom button.
- In the note editor, *Discard changes* has a new icon and only appears
  once there's something to discard; ⋮ is at the bottom too, and the text
  ends above the buttons.
- **Other** shows its tools as icon tiles, starting in the bottom right.
- Backups also keep the Džoni count (backup format 4; older backups
  still restore).
- **Planner**: a fast swipe on the day strip travels many days; the past
  is greyed out (only back to the oldest unfinished task); no Today
  button.
- Lists settle at the top when you scroll back up close to it, and going
  to a section puts its list back at the top.
- The drag handle area is a little smaller.
- **No touch ripples** anymore.

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
