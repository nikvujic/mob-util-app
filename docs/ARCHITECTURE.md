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
| `core/` | App-wide basics: theme (the only file allowed to define colors), ids, app info. | — |

## Other rules (also enforced)

- Imports are always `package:the_app/...`, never relative.
- Colors come from `AppColors` in `core/theme.dart`; no `Colors.*` (except
  `Colors.transparent`) or `Color(0x…)` anywhere else.
- No `print()`; use `debugPrint`.
- Platform plugins are confined: `path_provider` to `data/`,
  `package_info_plus` to `main.dart`.

## State and persistence

- Each feature has one `StateNotifier` holding an immutable list; pages read
  it with `ref.watch` and change it only through the notifier's methods.
- Notifiers save every new state through `AppStorage` (one JSON file per
  feature, crash-safe writes). Storage is loaded once in `main()` and
  injected with a provider override; tests inject in-memory storage.
