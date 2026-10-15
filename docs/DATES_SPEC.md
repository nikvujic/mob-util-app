# Birthdays & dates — spec (Round 57)

Built in Round 57 (v1.18.0).

From Nikola's notes (ROADMAP, Round 57): a calendar of important dates,
each with a title, a note, a type and up to three reminders; Pip in a
party hat on a birthday. Built from the app's usual patterns. Nikola's
answers are in (Round 57); **Decided** marks them.

## 1. The page (a Hub page, "Dates")

- Its name in the Hub: **Dates** (decided).
- **A month calendar** on top, the same kind as Food's (weeks as rows,
  Monday first, swipe or ‹ › for other months; this month first). A day
  with a date on it shows a **small dot in its type's colour** (two or
  more: up to three dots); today is ringed. Unlike Food it goes forward
  too (months to come), a year each way.
- **A tap on a day** shows that day's dates under the calendar (title,
  type, "turns 31"), and **+** then adds one on that day.
- With no day picked: **UPCOMING**, the next dates in order for the
  coming year: each a card with its type's icon and colour, the title,
  the date ("Sat 24 Oct") and how far off ("in 9 days", "tomorrow",
  "today"); a birthday with a year also says the age ("turns 31"), an
  anniversary the count ("10 years").
- **+** (the app's add button, bottom, on the hand's side) adds a date.
  A tap on a card opens it.
- Empty: the usual empty state ("No dates").
- Like other Hub pages: **lockable**, in **Clear data**, in backups and
  in *Restore part of a backup*; reach mode on the list (pull-down).

## 2. A date (its page)

Opened from a card or **+**; saved as you go, like a meal or a recipe
(nothing to confirm; a new one left without a title is dropped).

- **Title** (needed): "Ana", "Mum & Dad", "Exam".
- **Type**, a picker from a fixed list, each with an icon and a colour:
  **Birthday**, **Anniversary**, **Holiday**, **Event**, **Other**
  (more can be added later).
- **Date**: day and month, and the **year** if known (a birthday
  without a year still works; it just doesn't say the age).
- **Every year** (a switch): on by default for Birthday, Anniversary
  and Holiday; off for Event and Other (a one-off on that year's date,
  so its year is needed then).
- **Note**: plain text, a few lines ("gift ideas: …").
- **Reminders**: up to **3**, each a row "**3 days before · 09:00**";
  a tap changes it (a sheet: how many days before, picked from *on the
  day, 1, 2, 3, 5, 7, 14, 30 days*, and the time); a row's ✕ removes
  it; **Add a reminder** while fewer than 3. A new date starts with
  one: **1 day before, 09:00** (decided).
- **Delete** at the end of the page (like a meal's), with Undo.

## 3. Notifications

- At each reminder's time: **"Ana's birthday tomorrow"** /
  "… today" / "… in 3 days", with "turns 31" when the year is known,
  and the date's type icon colour as the tint. Tapping opens the page
  on that date.
- One notification per reminder (two dates on the same day and time
  come as one: "Ana's birthday, Mum & Dad's anniversary", like
  Medicine's doses).
- On the **Notifications page**: a **Dates** entry with the usual
  settings: on/off, sound, volume, pause, and the log.
- Planned like the others: the app plans what's due in the next 14
  days (again whenever it's opened), by when each reminder comes; a
  reminder 30 days before a date is planned once its time is within
  those 14 days.
- Locked page: notifications still come, without the title ("A
  birthday tomorrow"), as the Planner does when locked.
- **29 February** in a year without it: on 28 February.
- **A green dot** on the Dates tile on a day with a **birthday**, gone
  once the Dates page is opened that day (decided: green, not red: red
  is for something to do, like a dose or a backup). The Hub tab shows
  it too, unless a red dot is there (red wins).

## 4. Pip's party hat

- On a day with a **Birthday** (any of them), Pip wears a **party hat**
  all day: a small striped cone with a pompom, on his head beside the
  antenna.
- Also on **his own birthday**: the day he hatched, each year after,
  not the day he hatched itself (decided).

### Is it hard to keep consistent? No.

Every animation draws Pip's body from the same frame grid (20 × 19,
head on top), in one place in the painter, with the same moves applied:
mirrored when facing left, stretched and squashed, lifted for hops,
tilted when he falls over, spun when he's thrown, sunk while he comes
up. The hat is drawn **right after the body, inside those same moves**,
pinned to his head's top row (where the frame's first non-empty row
is), so it follows every animation there is, and every one to come
that uses his body frames, with nothing to redo.

What needs a thought, once each (done in this change):
- Not on the **egg** or while hatching (he isn't out yet).
- **Asleep**: the hat **sits beside him** on the ground while he sleeps
  (decided), and goes back on when he wakes.
- Off (**lying on his side**): it tilts with him.
- Thrown in **tumbling**: it spins with him (or flies off and lands
  next to him: more fun, a bit more work; proposed: spins with him).
- His **charging** and **screen** frames are his body too: no change.

Tests check the hat sits on his head's top row in every frame kind
(standing, walking, tucked, falling over, charging, each screen), so a
new animation that moves the head without the frame grid would fail
and be caught.

### Hats on Pip Home (decided, Round 57)

- Pip Home's settings card gets **Hats** (beside Rename, Animations,
  Backgrounds): a list of hats to try on him: **party hat**, **crown**,
  **top hat**, **wizard hat**, **cap**, **beanie** (a few to start; more
  later). A tap puts it on him; the hat he has on is ticked; **None**
  takes it off.
- Only for trying on: he **doesn't keep it**. Back to the settings
  menu, a swipe back to his info card, or leaving Pip Home, and it's
  gone. The menu's Pip never wears it (Pip Home has its own Pip).
- On a birthday he's in the party hat anyway; trying another swaps it
  while on Hats, and the party hat comes back after.
- Every hat is drawn the same way as the party hat (one sprite on his
  head's top row, inside his moves), so the same tests cover them all.

## 5. Stored

- A new `dates.json`: a list of dates (id, title, type, day, month,
  year or none, every year, note, reminders [days before, minutes into
  the day]). Kept on the phone like the other pages.
- Backups **v23** with `dates`; the frozen fixtures and their hashes
  (as for every stored change); restoring an older backup leaves dates
  empty.

## 6. The order of work (one release, 1.18.0)

1. Data: the model, storage, backup v23, fixtures.
2. The page: the calendar, upcoming, the date's page, the type picker.
3. Reminders: planning, the Notifications page entry, tapping a
   notification to open it; the green dot.
4. Pip's hats: the party hat on birthdays (and his own), beside him
   asleep; the Hats list on Pip Home.
5. Introduction, docs, full suite, release.
