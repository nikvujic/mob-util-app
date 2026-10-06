# Requirements

A personal utility app with three sections, switched from the bottom
navigation bar: **Notes**, **Shop** and **To Do**.

Status legend: ✅ done · 🚧 in progress · ⏳ planned

## General / cross-cutting

| # | Requirement | Status |
|---|-------------|--------|
| G1 | Bottom navigation with three tabs: Notes, Shop, To Do. Each tab keeps its state (scroll position, selection) when switching tabs. | ✅ |
| G2 | Shared visual language (dark theme, green accent) defined once in `lib/core/theme.dart`; pages do not hard-code colors. | ✅ |
| G3 | Reusable UI building blocks instead of per-page copies: confirmation dialog, selection-mode app bar, selectable list tile, empty-state placeholder, text-input sheet. | ✅ |
| G4 | **Selection mode** works the same way on every list: long-press an item to enter selection mode with that item selected; tap toggles items; the app bar shows the count, *select all*, and *delete*; system back / ✕ exits selection mode; deselecting the last item exits it too. | ✅ |
| G5 | Deleting is never instant: it always goes through the reusable confirmation dialog, which names how many items will be deleted. | ✅ |
| G6 | Data survives an app restart (local persistence). | ⏳ not started — data is currently in-memory only (see [BACKLOG.md](BACKLOG.md)) |

## Notes

| # | Requirement | Status |
|---|-------------|--------|
| N1 | List of notes showing title and last-modified date/time. | ✅ |
| N2 | Tap a note to open it. | ✅ |
| N3 | Note title is editable (tap it and type) and uses a smaller font than before. Body is editable the same way. | ✅ |
| N4 | Leaving the note (back arrow or system back) saves it. An empty title is saved as "Untitled". | ✅ |
| N5 | Tapping + creates a note titled "New Note" at the **top** of the list right away and opens it. If it is left untouched (title still "New Note" or blank, and no content), it is deleted again on leaving. | ✅ |
| N6 | **Custom order:** each row has a drag handle on the right; grabbing it lets the user move the note up/down. The order persists (it is no longer sorted by modified date). | ✅ |
| N7 | Long-press → selection mode → delete selected, with confirmation (see G4, G5). Long-press no longer deletes. | ✅ |
| N8 | Export / import as a failsafe for losing the app or moving devices (menu entries exist, not implemented). | ⏳ |

## Shop (shopping list)

| # | Requirement | Status |
|---|-------------|--------|
| S1 | Items have only a name — no title, dates, or body. | ✅ |
| S2 | Two sections: **To buy** on top, **Items** below, each with a header and item count. *Items* is the catalog of things bought before, so they can be put back on the list later. | ✅ |
| S3 | Each item has a checkbox on the left. Tapping the item (or its checkbox) moves it from *To buy* to *Items*, or from *Items* back to *To buy*. A moved item lands at the top of its new section. | ✅ |
| S4 | Add button creates a new item at the top of *To buy*. The input stays open after adding so several items can be entered in a row. Blank names are ignored. | ✅ |
| S5 | Each item has a drag handle on the right for reordering within its section. | ✅ |
| S6 | Long-press → selection mode → delete selected, with confirmation (see G4, G5). Selection may span both sections. No rename — delete and re-add instead. | ✅ |

## To Do

| # | Requirement | Status |
|---|-------------|--------|
| T1 | Tab and page exist, showing an empty "coming soon" state. | ✅ |
| T2 | Full to-do list functionality. | ⏳ to be specified |

## Technical notes

- State management: Riverpod (`StateNotifierProvider`), one provider per feature
  in `lib/providers/`.
- Models are immutable value classes in `lib/models/`.
- Reusable widgets live in `lib/widgets/`; feature pages in `lib/pages/<feature>/`.
- Every feature ships with provider unit tests and widget tests for its main
  interactions (`test/`).
