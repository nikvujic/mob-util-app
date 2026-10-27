# Recipes — spec (Round 40; settled in Rounds 41–42)

Built in Round 42 (v1.9.0); type filters and search are for later. From the notes (ROADMAP, Round 40); the drafts are
in `docs/recipes_drafts.png`. Marked **Q** where the user decides.

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
- No pull-down reach mode here: only in edit mode.
- Bottom buttons: **Edit** (outermost) and **To Shop**.

### To Shop

- Puts the recipe's ingredients on the Shop list, with their quantities.
- All of them go on the **to-buy** list (the user moves what he has).
- An item already in Shop with the same name (ignoring case) and the
  same quantity is just put back on the to-buy list; with another
  quantity, a **copy** is added (two items, two quantities: easier than
  changing one each time).
- Quantities are free text in a recipe (below); Shop's are a count or
  a weight. Read when possible: "200 g", "1.5 kg" → a weight; "2",
  "3 pcs" → a count; anything else ("1 tbsp", "a pinch") → no quantity
  in Shop, just the name.
- A toast says what happened ("4 added to Shop, 1 put back on the
  list"), with Undo.

## 3. A recipe, edit mode

- Everything becomes editable: the **name**, the **prep time** (a
  **picker**, shown as "25 min" / "1 h 30"; decided), the **type** (a
  dropdown from a **fixed list**: Breakfast, Lunch, Dinner, Snack, Cake,
  Drink, Other; decided).
- **Ingredients**: a plain box of rows, no background on the rows:
  name, quantity, and a **grab handle** on the right to drag. Tap a
  quantity to change it (a small text sheet: "200 g", "2", "a pinch").
  **Hold a row to remove it** (with Undo). **+ Add** opens the
  ingredients list in **pick mode**; the picked ones come in at the end,
  with no quantity yet (tap to set).
- **Method**: works like a note: it shows as text, a tap puts the cursor
  there and the keyboard up, with the format bar (Markdown). (So edit
  mode has its own view/edit for this text, as the user said.)
- Pull down for reach (reach mode) here, as on other editing pages.
- Saving like a note: as you go (autosave); bottom buttons **Done**
  (outermost; back to view mode), **Undo**, **Discard changes** (back to
  how it was when Edit was pressed).
- A new recipe left with no name and nothing in it is dropped (like an
  empty note).
- A menu (top bar ⋮) in view mode: **Duplicate** (a copy named
  "… (Copy)", opened in edit mode), **Copy to clipboard** (the name,
  time, type, ingredients with quantities and the method, as plain
  text), **Delete** (with Undo). Decided: share is the clipboard only.

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
- An ingredient used by recipes and deleted here: recipes keep it
  (their own copy of the name). Decided.

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
  ingredient renames it in recipes that link to it (decided).
- Both in backups (backup version +1, new `recipes` and `ingredients`),
  with frozen fixtures; partial restore lists recipes (each brings its
  ingredients that aren't in the list yet).

## 6. Decided (Round 41)

- No servings, no ticking off ingredients, no timer, no photos.
- Duplicate and copy to the clipboard: yes (the recipe's menu).
- Search by ingredient ("what can I make with eggs?"): later.
- Ingredient groups (a cake's "Dough" and "Filling"): **no**, one flat
  list per recipe (Round 42).

**Quantities, explained**: a recipe's quantity is any text ("200 g",
"2", "1 tbsp", "a pinch"). Shop only knows a count (×2) or a weight
(grams). So for *To Shop*, "200 g" and "1.5 kg" become a Shop weight,
"2" or "2 pcs" a Shop count; "1 tbsp" or "a pinch" can't, so that item
goes to Shop with its name only (no quantity).

## 7. Build in chunks

1. Data: recipes and ingredients (models, storage, backups, fixtures).
2. Ingredients page: sections, edit mode, pick mode.
3. Recipes page and a recipe's view mode (screen kept on).
4. Edit mode (fields, ingredient rows, the method as a note).
5. To Shop; Clear data, locks, partial restore; docs and Introduction.
