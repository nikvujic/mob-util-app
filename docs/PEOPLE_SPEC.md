# People — spec (Round 107)

Not built yet. From Nikola's notes (Round 107, v2 item 4): the people he
knows as **floating boxes on a zoomable board**, with **relations** that
make a **family tree**, laid out like Pip Home (the picture on top, the
controls below). **Nikola** marks what he asked for; **Proposed** marks
what I filled in; the open questions are in section 9.

## 1. The page (a Hub page, "People")

- **Nikola:** like Pip Home: the **board** fills the top half of the
  screen, the **panel** sits below it.
- **Nikola:** with nobody selected, the panel is hidden but for **a small
  bar with Add**. Selecting a person opens the panel with their info.
- **Proposed:** the bar shows how many people there are ("23 people") and,
  beside Add, **Find** (a search by name that centres on the match) and
  **Tidy** (section 5.4). The panel slides up and down (animated), and the
  board grows into the space it leaves.
- **Proposed:** like the other Hub pages: **lockable**, in **Clear data**,
  in backups and in *Restore part of a backup*; stored in `people.json`.
- Empty: the board shows the usual empty state ("No people yet") above the
  Add bar.

## 2. A person

| Field | Notes |
|---|---|
| **Name** (needed) | **Nikola:** the full name. |
| **Birthday** | **Nikola:** day, month, and the year if known. Tied to Dates (section 6). |
| **Gender** | **Nikola:** shown as blue or pink. **Proposed:** male, female, or not set (grey). |
| **Deceased** | **Nikola:** a person can be marked deceased. **Proposed:** an optional date of death too; the age then stops there ("lived to 84"). |
| **Highlighted** | **Nikola:** important people stand out (section 4.2). |
| **Note** | **Nikola:** free text; shown in the panel, never on the board. |
| **Relations** | **Nikola:** to other people (section 5). |
| **Position** | **Nikola:** where the box sits on the board, remembered. |

- **Proposed:** a new person is placed at the middle of what the board
  shows, nudged so it doesn't cover anyone.

## 3. The panel (below the board)

- **Nikola:** selecting a person shows their **info**: name, birthday and
  age, gender, deceased, highlighted, relations, note.
- **Nikola:** an **Edit** button turns it into fields to change them.
- **Proposed:** in view, each relation is a row ("Mother: Ana Petrović");
  tapping it selects and centres that person. **Edit** shows the fields,
  **Add relation**, each relation with × to remove it, and **Delete
  person** at the end (it asks first; the person's linked birthday is
  removed from Dates with them, section 6). Changes save as you go, like
  a recipe, with **Done** to leave edit mode.
- **Proposed:** a tap on the empty board deselects (the panel goes down),
  as does Back.

## 4. The board

### 4.1 Moving around

- **Nikola:** **zoomable**: pinch to zoom, drag the empty board to pan.
- **Nikola:** **touch and drag a person** to move them; the new position is
  remembered.
- **Nikola:** **tapping a person centres on them** (animated) and opens the
  panel.
- **Nikola:** **animated**: people glide to their new places when rearranged,
  and a new relation's line draws itself in.
- **Proposed:** zoom from about a quarter of the size to twice the size;
  the view (where you were and how close) is remembered between visits.

### 4.2 A person's box

- **Nikola:** an **avatar by age** (worked out from the birthday, so it
  changes by itself):

  | Avatar | Age |
  |---|---|
  | Baby | 0–2 |
  | Kid | 3–12 |
  | Teen | 13–19 |
  | Adult | 20–39 |
  | Older adult | 40–59 |
  | Older | 60–79 |
  | Old | 80+ |

  **Proposed:** pixel-art faces in Pip's style, one per age and gender (7 ×
  2, plus a plain one for gender not set); no birth year: the adult face.
  Drafts first, for Nikola to pick from, as with Pip.
- **Nikola:** the box shows the person's info **except the note**.
  **Proposed:** the name, and under it the age or "b. 1958", plus a small
  cake on their birthday.
- **Nikola:** **gender as blue or pink** (proposed: the border and the
  avatar's backdrop; grey when not set).
- **Nikola:** **highlighted** people stand out; the others have a plain
  greyish border and muted text. **Proposed:** highlighted people get a
  thicker border in their colour, full-strength text and a slightly bigger
  box.
- **Proposed:** **deceased** people are shown greyed, with a small cross
  (✝) by the name and their years ("1931–2015").
- **Proposed:** the selected person has the accent ring.

## 5. Relations and the family tree

### 5.1 Adding one

- **Nikola:** **Add relation**, then **pick another person**; the two get
  connected on the board, with the line drawing in.
- **Proposed:** the picker is a searchable list of the others, then the
  kind:
  - **Parent** / **Child** (one relation, seen from either side);
  - **Partner** (married or not; **proposed:** with "former" as an option,
    drawn dashed);
  - **Sibling** (only needed when no parents are entered; siblings who
    share a parent are worked out from that);
  - **Other** (friend, colleague...: a thin plain line with an optional
    word on it, e.g. "Godfather").
- **Proposed:** a relation that makes no sense is refused with a reason
  (someone their own parent, more than two parents, a loop of parents).

### 5.2 How lines are drawn (Nikola: one line for both parents)

- **Partners**: a short horizontal line between them, side by side.
- **Children of a couple**: **one** line drops from the middle of the
  partners' line to a horizontal bar, and each child hangs from that bar,
  instead of a line from each parent to each child.
- **Children of one parent** (the other not entered): the line drops from
  that parent.
- **Siblings** without parents entered: a bar over them, with no line up.
- **Other** relations: a thin straight line, with its word in the middle.
- **Proposed:** lines are drawn at right angles (down, across, down), so a
  family reads like a classic tree.

### 5.3 Sticking together (Nikola: "when moved they stick together")

- **Proposed:** **partners move as a pair**: dragging one brings the other
  along, side by side. A **parent drags their descendants** with them,
  keeping their places relative to the parent. Children can still be
  dragged on their own, and only their own descendants follow. Other
  relations never pull anyone.
- **Proposed:** while you drag, the lines follow live, so you can see the
  tree hold together.

### 5.4 Keeping it readable (Nikola: "stable", "a good overview")

- **Proposed:** a **Tidy** button lays the family out as a tree:
  generations in rows (parents above children), partners side by side,
  children in birth order under their parents' line, spaced so no lines
  cross where that can be helped. Everyone glides to their new place
  (animated), and Tidy can be undone (a toast with Undo).
- **Proposed:** nothing moves by itself except during Tidy or a drag;
  people you placed stay where you put them. When a relation is added,
  only the newly linked person is moved next to the other, if they're far
  apart.

## 6. Birthdays and Dates

- **Nikola:** when **creating** a person, a button lets you **pick a birthday
  from the Dates page**: the person takes it over, so the original date
  isn't left as a separate entry ("we kill the original").
- **Nikola:** a birthday typed in **by hand is added to Dates** as a birthday.
- **Nikola:** in Dates, **those dates show a small icon** saying they come
  from People; **they can be edited there but not deleted** (they go when
  the person is deleted, or when their birthday is cleared).
- **Proposed:** the linked date's **title follows the person's name**, and a
  change to the day in Dates changes the person's birthday too: one
  birthday, two ways in. Its reminders, note and type stay Dates' own.
- **Proposed:** a deceased person's birthday stays in Dates (renamed
  nothing; the person's icon greyed), unless it's removed from the person.

## 7. Data

- **Proposed:** `people.json` (version 1): each person
  `{id, name, birthday: {day, month, year?}, gender, deceased, diedOn?,
  highlighted, note, x, y, dateId?}`, the relations as their own list
  `{id, kind, from, to, former?, label?}` (one entry per relation, never
  doubled), and the board's last view `{x, y, zoom}`.
- **Proposed:** Dates entries get an optional `personId`: the People icon,
  and the reason they can't be deleted.
- **Proposed:** a backup version bump with frozen fixtures, as for every new
  store; a backup from before People leaves them be.

## 8. Not in the first version (proposed)

- Photos as avatars.
- More than one family tree view (e.g. a list view); Find covers looking
  people up.
- Pip on the board.

## 9. Open questions for Nikola

1. **Relation kinds:** are Parent, Child, Partner (with "former"), Sibling
   and Other the right set? Should Other have a free word on its line?
2. **Sticking together:** is "partners move together, parents bring their
   descendants" right, or should dragging anyone move their whole family?
3. **Tidy:** do you want the Tidy button (auto-arrange the tree), or only
   your own placing?
4. **"Like with notifications":** which existing items did you mean,
   ones that can be edited but not deleted? I've assumed the linked
   birthday is edited in Dates but only removed from People.
5. **Deceased:** just a mark, or a date of death too (so the age stops
   there)?
6. **Gender:** male, female and "not set": anything else?
7. **Avatars:** pixel art like Pip, with drafts first?
8. **The Hub's name:** "People", or something else ("Family", "Contacts")?
