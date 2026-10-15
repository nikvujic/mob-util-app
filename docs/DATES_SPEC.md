# Birthdays & dates — spec (Round 57)

From Nikola's notes (ROADMAP, Round 57): a calendar of important dates,
each with a title, a note, a type and up to three reminders; Pip in a
party hat on a birthday. Built from the app's usual patterns. Marked
**Q** where Nikola decides; everything else is a proposal to build as
written.

## 1. The page (a Hub page, "Dates")

- Q: its name in the Hub: **Dates** (short, fits the tile), or
  *Birthdays*, or *Birthdays & dates*.
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
  **Birthday**, **Anniversary**, **Holiday**, **Event**, **Other**.
  Q: the list (e.g. add *Name day*, *Memorial*).
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
  one: **on the day, 09:00**. Q: that default, or *1 day before*.
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
- Planned ahead like the others, but further: the app plans its
  reminders 14 days ahead (re-planned whenever it's opened); a date's
  reminder can be 30 days before, so dates are planned **45 days**
  ahead (a few each; well under Android's alarm limit).
- Locked page: notifications still come, without the title ("A
  birthday tomorrow"), as the Planner does when locked.
- **29 February** in a year without it: on 28 February.
- Q: a **red dot** on the Dates tile (and the Hub tab) on a day with a
  date, gone once the page is opened that day. Proposed: no (the
  notification is enough), or yes for birthdays only.

## 4. Pip's party hat

- On a day with a **Birthday** (any of them), Pip wears a **party hat**
  all day: a small striped cone with a pompom, on his head beside the
  antenna.
- Q: also on **his own birthday** (the day he hatched, each year).
  Proposed: yes, and maybe a few confetti specks now and then.

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
- **Asleep** (his body tucked lower): the hat follows the head down, or
  is put beside him while he sleeps. Proposed: it stays on.
- Off (**lying on his side**): it tilts with him.
- Thrown in **tumbling**: it spins with him (or flies off and lands
  next to him: more fun, a bit more work; proposed: spins with him).
- His **charging** and **screen** frames are his body too: no change.

Tests check the hat sits on his head's top row in every frame kind
(standing, walking, tucked, falling over, charging, each screen), so a
new animation that moves the head without the frame grid would fail
and be caught.

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
   notification to open it.
4. Pip's party hat.
5. Introduction, docs, full suite, release.

## Q — for Nikola

1. The page's name: **Dates**?
2. The types: Birthday, Anniversary, Holiday, Event, Other — more?
3. A new date's reminder: **on the day at 09:00**, or 1 day before?
4. A red dot on the tile on the day: no / birthdays only / every date?
5. The hat on **Pip's own birthday** too?
6. The hat while asleep: on, or beside him?
