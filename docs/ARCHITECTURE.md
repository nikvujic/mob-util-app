# Architecture

The code in `lib/` is split into layers. Each layer may only depend on the
layers listed for it, so UI never leaks into data code, features stay
independent, and shared pieces stay reusable.
`test/architecture_test.dart` enforces these rules on every test run (and so
in CI) — a change that breaks them fails the build.

```
main.dart ──► app/ ──► pages/<feature>/ ──► widgets/
                │            │
                │            ▼
                └──────► providers/ ──► data/ ──► models/
                                                     ▲
                core/  (used by every layer except models)
```

| Layer | What lives there | May import |
|-------|------------------|------------|
| `main.dart` | Startup: load storage and app info, then run the app with them. | `app`, `core`, `data` |
| `app/` | The app shell: `MyApp`, home screen, bottom navigation, the menu. | `core`, `models`, `providers`, `pages`, `widgets` |
| `pages/<feature>/` | One folder per feature (notes, shop, planner, other, security). A feature never imports another feature — shared UI goes to `widgets/`. | `core`, `models`, `providers`, `widgets` |
| `widgets/` | Reusable, feature-agnostic UI: dialogs, selection mode, empty state, app bars, input sheet. | `core` |
| `providers/` | App state (Riverpod notifiers): the rules for changing notes, shop items, … Every change is saved through `data/`. | `core`, `data`, `models` |
| `data/` | Storage: reading and writing files. The only place that touches `dart:io`. | `core`, `models` |
| `models/` | Plain immutable value classes with JSON conversion. No Flutter, no imports at all. | — |
| `core/` | App-wide basics: theme (the only file allowed to define colors), ids, app info, encryption (`crypto.dart`). | — |

## Other rules (also enforced)

- Imports are always `package:the_app/...`, never relative.
- Colors come from `AppColors` in `core/theme.dart`; no `Colors.*` (except
  `Colors.transparent`) or `Color(0x…)` anywhere else.
- No `print()`; use `debugPrint`.
- Platform plugins are confined: `path_provider` and `file_picker` to
  `data/` (behind small interfaces like `BackupFiles`, so tests can fake
  them), `package_info_plus` to `main.dart`, `cryptography` to
  `core/crypto.dart` (the app's only encryption code).

## Design checks

`test/design_test.dart` checks every screen against Android's
accessibility guidelines — tap targets of at least 48×48 dp, every tap
target labelled for screen readers, text contrast — and pins what the
requirements ask of the layout (e.g. shop rows are exactly one tap target
high and ≥20% smaller than note rows). Conventions it relies on:

- List rows are one screen-reader element: the content is the label, state
  (checked, selected) is a semantic flag. Drag handles and selection ticks
  are decorative (`ExcludeSemantics`); reordering is offered to screen
  readers as the list's "Move up/down" actions.
- Highlights (selection) never change a row's size.
- Layouts must survive a 2× system font size without overflowing.

## Back button

The home screen owns the only back handler for the main sections (Flutter
calls every back callback on a screen, so several would all fire). It
closes an open menu first, then offers back to `BackHandlers` registered by
pages (selection mode uses `SelectionPopScope`), and only then runs the
"press back again to exit" logic.

## State and persistence

- Each feature has one `StateNotifier` holding an immutable list; pages read
  it with `ref.watch` and change it only through the notifier's methods.
- Notifiers save every new state through `AppStorage` (one JSON file per
  feature, crash-safe writes). Storage is loaded once in `main()` and
  injected with a provider override; tests inject in-memory storage.
- Slow work (key derivation) runs in a background isolate. Widget tests
  run it for real with `tester.runAsync`, via the `settleBusy` helper.
