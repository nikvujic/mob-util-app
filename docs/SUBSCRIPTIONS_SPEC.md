# Subscriptions — spec (Round 79)

From the user's note (a list of his subscriptions with their state), turned
into a Hub page that keeps track of what's paid, when, and what's to be
done about it.

## A subscription

| Field | Notes |
|---|---|
| **Name** | "Claude", "Grok". |
| **Price** | An amount (e.g. 20) with its currency (€ by default, any text), and **about** (a ~ before it: AWS's ~5€). Optional (none: just not shown). |
| **Every** | Month (default) or year: how often it renews. |
| **State** | One of four, below. |
| **Date** | What it means goes with the state (below). A day, no time. |
| **Card** | The (virtual) card it's paid with, any text: "Revolut 4421". Empty: **card unknown** (Grok: "didn't set a name"). |
| **Card expires** | Round 80: the day that card expires (virtual cards run out). On the card: "· expires 10 Nov" (or "expired"); expiring before the next renewal, "Card expires before it renews" in red. Round 85: a **month and year** (cards have no day), picked from a year's months, shown "expires 10/26", good through the month's last day (kept as that day; one kept with a day reads as its month). Round 84: the expiry itself orange when it's a week or less away (the day included), red once gone by; no notification. |
| **Note** | Anything: "real ~30€", "payment failed". |
| **Reminder** | Besides the one on its date at 09:00 (always, while it's one with a date): **none** (default), or **1, 2, 3 days or a week before**, at 09:00. Shown on the card. |

### States

| State | Date is | Colour | Notifications (09:00) |
|---|---|---|---|
| **Active** | the next payment; once gone by it moves on by a month (or year) | green | "Claude renews today · 20€" (and before, if set: "Claude renews in 2 days · 20€") |
| **To cancel** — running, renewing, but you mean to cancel it before then (Grok) | the renewal: cancel before it | orange | "Cancel Grok: it renews today" / "Cancel Grok: it renews in 2 days" (a reminder before is set by default here: 2 days) |
| **Cancelled** — still on until a day (ChatGPT) | the last day | blue | "ChatGPT ends today" |
| **Inactive** — not running: lapsed, card ran out, payment failed (Spotify) | none | grey | none |

A **cancelled** one whose day has gone by shows as **Ended** (grey, like
inactive); it stays until deleted or set going again. A **to cancel** one
whose day goes by (not cancelled in time) renewed: its date moves on, as
an active one's, still marked to cancel.

## The page (Hub → Subscriptions)

- At the top, **per month**: what the running ones come to (active and to
  cancel; a year's price ÷ 12; ~ if any is about), e.g. **~61€ a month**.
  By currency if they differ (€ and $ each their own).
- **Cards, two columns**, in the user's order (Round 89): as added, a new
  one last; **held and dragged** to a new place, as the Hub's tiles
  (screen readers: Move earlier / Move later). (Rounds 79–88: to cancel,
  active, cancelled, then inactive and ended, by date then name.)
  Each card, rounded, lightly tinted with a thin outline in its state's
  colour (Round 80: no thick edge), its state a pill:
  - the name (bold), the price ("~16€ / month");
  - the state and date: *Renews 3 Nov* · *Cancel by 17 Nov* · *Active
    until 13 Nov* · *Ended 13 Nov* · *Inactive*;
  - the card and its expiry (a card icon; *Card unknown* in italics);
    a warning if it expires before it renews;
  - the reminder (a bell): *2 days before* (none set: nothing);
  - the note, a line or two.
- Tap a card: its **sheet** to edit everything (name, price, about,
  currency, every, state, date, card, note, reminder), with Delete (Undo).
- **+** (bottom right, as Dates): a new one, active, renewing a month from
  today.
- Empty: a hint ("Add your subscriptions to keep track of what's paid and
  when").

## Elsewhere, as the other pages

- `subscriptions.json` (version 1), in **backups** (v29) and partial
  restore, Clear data, a lock of its own, the Notifications page (its
  own on/off, pause, private, colour; "Claude renews today" privately:
  "A subscription renews today"), tapping a notification opens the page.
- No Pip tie-in for now.
