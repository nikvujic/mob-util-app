# Recipes — spec (Round 40, draft for Nikola)

Not built yet. From Nikola's notes (ROADMAP, Round 40); the drafts are
in `docs/recipes_drafts.png`. Marked **Q** where Nikola decides.

## 1. The Recipes page (a Hub page)

- A list of recipes as cards: **name**, and under it **prep time · type**
  ("25 min · Breakfast"). Nothing more.
- **Reordered** by holding a card's handle and dragging (like Shop and
  the to-do). Holding a card elsewhere selects it (selection mode, like
  Notes: delete several, asked first, no Undo after).
- A tap opens the recipe in **view mode**.
- Bottom buttons (on the hand's side): **+** (the app's add button) makes
  a new recipe and opens it straight in **edit mode** with the name
  focused; an **Ingredients** button opens the ingredients list (in its
  edit mode).
- Q: a row of **type filters** above the list (All · Breakfast · Cake …)
  once there are many recipes; and a **search**. Proposed: filters yes
  (cheap), search later.
- Like other Hub pages: lockable (its own lock), in Clear data, in
  backups and in *Restore part of a backup*.

## 2. A recipe, view mode (what opens first)

- **Keeps the screen on** while it's open (cooking with the phone set
  aside); off again when leaving it or when the app goes to the
  background.
- From the top: the **name** (in the top bar); a small **prep time** box
  and the **type** beside it (both read only here); **INGREDIENTS · N**:
  each ingredient's name on the left and its quantity on the right, no
  handles, no adding; then the **method**, the recipe's text shown as a
  note shows it (Markdown rendered, nothing editable).
- Proposed extra: **tap an ingredient to tick it off** while cooking
  (struck through; not saved, gone when leaving). Q.
- No pull-down reach mode here (Nikola): only in edit mode.
- Bottom buttons: **Edit** (outermost) and **To Shop**.

### To Shop

- Puts the recipe's ingredients on the Shop list, with their quantities.
- Proposed: it first shows the recipe's ingredients **all ticked**;
  untick what's already at home, then *Add N to Shop*. Q.
- An item already in Shop with the same name (ignoring case) and the
  same quantity is just put back on the to-buy list (Nikola's rule);
  otherwise a new item is added. Q: same name but another quantity:
  a new item (as said), or update that one's quantity and put it on the
  to-buy list? Proposed: update it (no near-duplicates in Shop).
- Quantities are free text in a recipe (below); Shop's are a count or
  a weight. Read when possible: "200 g", "1.5 kg" → a weight; "2",
  "3 pcs" → a count; anything else ("1 tbsp", "a pinch") → no quantity
  in Shop, just the name.
- A toast says what happened ("4 added to Shop, 1 put back on the
  list"), with Undo.

## 3. A recipe, edit mode

- Everything becomes editable: the **name**, the **prep time** (Q: free
  text like "25 min", or a minutes picker shown as "25 min" / "1 h 30";
  proposed: the picker, so recipes can later be sorted or filtered by
  time), the **type** (a dropdown; Q: a fixed list — Breakfast, Lunch,
  Dinner, Snack, Cake, Drink, Other — or one you can add to; proposed:
  fixed to start).
- **Ingredients**: a plain box of rows, no background on the rows:
  name, quantity, and a **grab handle** on the right to drag. Tap a
  quantity to change it (a small text sheet: "200 g", "2", "a pinch").
  **Hold a row to remove it** (with Undo). **+ Add** opens the
  ingredients list in **pick mode**; the picked ones come in at the end,
  with no quantity yet (tap to set).
- **Method**: works like a note: it shows as text, a tap puts the cursor
  there and the keyboard up, with the format bar (Markdown). (So edit
  mode has its own view/edit for this text, as Nikola said.)
- Pull down for reach (reach mode) here, as on other editing pages.
- Saving like a note: as you go (autosave); bottom buttons **Done**
  (outermost; back to view mode), **Undo**, **Discard changes** (back to
  how it was when Edit was pressed).
- A new recipe left with no name and nothing in it is dropped (like an
  empty note).
- Q: one recipe deleted from its own page: a **Delete** in a menu (top
  bar ⋮) with Undo. Proposed.

## 4. Ingredients (not in the Hub)

One list of ingredients, in **sections** (Baking, Dairy, Vegetables…),
so picking is quick. Opened from Recipes (to manage it) or from a recipe
(to pick from it).

### Edit mode (the default from Recipes' button)

- Like the to-do: rows of text, a handle on the right; sections as
  headers.
- **+** adds ingredients with the to-do's quick sheet (it stays open for
  the next); new ones go to the **top of the first section**.
- **Section** button adds a section (to the top); hold a section header
  to rename or delete it (its items move to the section above; Q).
- Drag rows within and **between sections**; hold a row to rename or
  delete it.
- Q: an ingredient used by recipes and deleted here: recipes keep it
  (their own copy of the name), proposed. See *Data* below.

### Pick mode (from a recipe's + Add)

- The same sections with **checkboxes** (like selection mode); ones
  already in the recipe are ticked and greyed.
- A wide **Add N** button at the bottom accepts; back cancels.
- An **Edit** button switches to edit mode (to add a missing one);
  back returns to picking for the recipe that asked.

## 5. Data

- `recipes.json` (new, version 1): recipes in their order; each: id,
  name, prep minutes (or null), type (or null), ingredients (each: an
  ingredient id, its name as it was, quantity text, in order), method
  text (Markdown), created/modified times.
- `ingredients.json` (new, version 1): sections in order, each with its
  ingredients (id, name) in order.
- A recipe's ingredient keeps the **name too**, so a recipe stays whole
  if an ingredient is deleted or the list isn't restored; renaming an
  ingredient renames it in recipes that link to it (Q).
- Both in backups (backup version +1, new `recipes` and `ingredients`),
  with frozen fixtures; partial restore lists recipes (each brings its
  ingredients that aren't in the list yet).

## 6. What may be missing (Nikola's question)

1. **Servings** ("serves 4"), and maybe scaling the quantities (×2) —
   only possible for quantities that are numbers. Proposed: a servings
   field now, scaling later if wanted.
2. **Two groups of ingredients** in one recipe (dough / filling).
   Proposed: later; for now one list (the same ingredient can be added
   twice).
3. **Ticking off ingredients and steps while cooking** (view mode).
4. **A timer** from the prep time or from a step ("10 minutes") — maybe
   with the Hub's timer page, later.
5. **Photos** of the dish: not now (storage, backups grow).
6. **Duplicate a recipe** (to make a variant): small, could go in v1 of
   the page.
7. **Searching** recipes by name or ingredient ("what can I make with
   eggs?"): later.
8. **Sharing** a recipe as text (to send to someone): small (the
   phone's share sheet), could go in.

## 7. Build in chunks

1. Data: recipes and ingredients (models, storage, backups, fixtures).
2. Ingredients page: sections, edit mode, pick mode.
3. Recipes page and a recipe's view mode (screen kept on).
4. Edit mode (fields, ingredient rows, the method as a note).
5. To Shop; Clear data, locks, partial restore; docs and Introduction.
