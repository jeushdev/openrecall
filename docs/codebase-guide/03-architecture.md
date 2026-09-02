# 03 — Architecture

How the code is organised, so you know *which kind of file* to open before you
go looking for the specific one.

---

## 1. The four layers

Every feature folder (`lib/features/<feature>/`) has up to four sub-folders.
They form a one-way dependency chain: **presentation → application → domain**,
and **data → domain**. A layer never imports "upward."

| Layer | Folder | Contains | May import | The rule |
|---|---|---|---|---|
| **Presentation** | `presentation/` (or `lib/ui/<tab>/`) | Widgets. Screens and their sub-widgets. | application, domain, theme | **A widget never queries Supabase or SQLite. It `ref.watch`es a provider.** |
| **Application** | `application/` | Riverpod providers and controllers. The glue: it reads repositories and exposes their data/actions to widgets. | data, domain | This is where "when the user taps X, call repository method Y, then invalidate provider Z" lives. |
| **Domain** | `domain/` | Plain Dart: model classes (`FlashCard`, `Deck`, `Course`), pure functions (`availableModes`, `masteryPercentFromLevels`, `requeuePosition`), and **repository *interfaces*** (`abstract class DeckRepository`). | nothing app-specific | No Flutter, no Supabase, no I/O. Pure and unit-testable. |
| **Data** | `data/` | The actual implementations: `Supabase*Repository`, `Local*Store` (SQLite), and the `CacheFirst*Repository` that combines them. | domain | The only layer that knows Supabase / sqflite / SharedPreferences exist. |

**Cross-cutting code** that isn't tied to one feature lives in `lib/core/`
(local DB, sync, connectivity, caching helpers, formatting, shared UI chrome),
`lib/routing/`, and `lib/theme/`.

### Why there's both `lib/features/` and `lib/ui/`

The app was built feature-first (`lib/features/decks/…`, `lib/features/study/…`).
Later, the presentation-layer revamp (ui-spec-v2) and the Mastery/Profile/
Settings tab rebuilds put their **new screen widgets** under `lib/ui/<tab>/`
(`lib/ui/mastery/`, `lib/ui/profile/`, `lib/ui/settings/`) — but left the
**providers** for those screens under `lib/features/<feature>/application/`
(`lib/features/stats/…`, `lib/features/profile/…`, `lib/features/settings/…`).

So: **screen widget in `lib/ui/`, its data in `lib/features/`.** When hunting,
check both. `02-screen-map.md` disambiguates per screen.

---

## 2. The repository sandwich (the most important idea here)

Every feature that touches server data has **the same three-part stack**, wired
together in its `application/*_providers.dart` file:

```
        <feature>RepositoryProvider
                    │
                    ▼
      CacheFirst<Feature>Repository        ← the strategy: try remote, fall back to local,
        ├── Supabase<Feature>Repository       queue local writes as "unsynced"
        └── Local<Feature>Store  (SQLite)
```

All three implement the same `abstract class <Feature>Repository` interface from
`domain/`. That's why:

- **Tests** can swap in a `Fake<Feature>Repository` (in `test/support/`) and
  nothing else changes.
- The rest of the app **only ever sees the interface** — no screen or provider
  imports `Supabase` directly.

### The four sandwiches

| Feature | Interface (`domain/`) | Remote (`data/`) | Local store (`data/`) | Combiner (`data/`) | Wired in |
|---|---|---|---|---|---|
| Decks & cards | `deck_repository.dart` | `supabase_deck_repository.dart` | `local_deck_store.dart` | `cache_first_deck_repository.dart` | `application/deck_providers.dart` |
| Courses | `course_repository.dart` | `supabase_course_repository.dart` | `local_course_store.dart` | `cache_first_course_repository.dart` | `application/course_providers.dart` |
| Study | `study_repository.dart` | `supabase_study_repository.dart` | `local_study_store.dart` | `cache_first_study_repository.dart` | `application/session_controller.dart` |
| Stats | `stats_repository.dart` | `supabase_stats_repository.dart` | `local_stats_store.dart` | `cache_first_stats_repository.dart` | `application/stats_providers.dart` |

**To change what data an action reads or writes**, you usually change the
**interface** (`domain/*_repository.dart`) plus **all three** implementations,
plus the fake in `test/support/`. The compiler will list every place you missed.

### Read strategy: `staleFirst`

`lib/core/cache/stale_first.dart` — a helper that yields the **cached value
first**, then replaces it with a freshly-fetched one, with a timeout (default
6s) bounding *only* the remote call. This is why the Decks tab paints instantly
offline instead of spinning behind a doomed network request. The
`decksLoadTimeoutProvider` / `statsLoadTimeoutProvider` set the bounds
(overridden short in tests).

### Write strategy: `is_synced = 0`

When a write can't reach Supabase, the `CacheFirst*Repository` writes it to the
local SQLite store with a client-generated UUID and `is_synced = 0`. See §4.

---

## 3. Theme & design tokens — read this before any visual change

**`lib/theme/app_tokens.dart` is the only file in the app where a raw colour hex
is allowed.** Everything else resolves colour through the theme.

### How a widget gets a colour

```dart
final tokens = Theme.of(context).extension<AppTokens>()!;
// ...
color: tokens.textPrimary,          // headings
color: tokens.textSecondary,        // captions
color: tokens.background,           // screen background
color: tokens.cardFill,             // card / tile fill
color: tokens.mutedFill,            // stat blocks, inactive segmented track
color: tokens.borderHairline,       // 0.5px borders
```

### The token set (`AppTokens`)

Seven surface/text colours + an `accents` map. `AppTokens.light` and
`AppTokens.dark` are both defined as `static const` in `app_tokens.dart`, each
with its full palette. The dark palette is a documented inversion — the
reasoning (with WCAG AA contrast math) is in `docs/spec-v5-dark-mode.md`.

- **To retint the whole app** (light or dark), edit the hex values in
  `AppTokens.light` / `AppTokens.dark`. Nothing else.
- **Course accents**: eight named keys (`slate, red, amber, green, teal, blue,
  violet, pink`), each an `AccentPair(fill, text)` — `fill` used at low opacity
  for the "stacked deck" accent, `text` full-strength for labels. Resolve with
  `tokens.accent('blue')`. Unknown keys fall back to `slate`.

### Geometry & motion

| Constant file | Holds |
|---|---|
| `lib/theme/app_geometry.dart` | `AppRadii` (card = 28, gridTile = 16, input = 12) and `AppBorders.hairline` (0.5). **No shadow constant — `BoxShadow` is banned**; depth is faked with solid offset `Container`s. |
| `lib/theme/app_motion.dart` | `AppMotion.expandDuration` (240ms) / `expandCurve` — the shared expand/collapse timing. |
| `lib/theme/app_theme.dart` | Assembles `ThemeData` (`AppTheme.light` / `AppTheme.dark`) from the tokens, and holds the system status-bar / nav-bar overlay styles (`lightOverlay` / `darkOverlay`). |

Which theme is active: `themeModeProvider` (System/Light/Dark, persisted to
`SharedPreferences`) → `MaterialApp.themeMode` in `lib/app.dart`.

---

## 4. Offline & sync

### The local database — `lib/core/local_db/app_database.dart`

A device-local SQLite file (`open_recall.db`), opened at startup. Current
**schema version is 6** (`_version = 6`). It mirrors:

- `offline_courses`, `offline_decks` — so the Decks tab renders offline.
- `offline_cards`, `offline_study_sessions`, `offline_session_cards` — so a
  downloaded deck can run a full study session with no connectivity.
- `offline_deletions` — **tombstones**: rows deleted while offline, so the
  delete can be replayed to Supabase on reconnect.
- `offline_meta` — a one-row-per-key scratch table (`local_meta_store.dart`).

**The `is_synced` convention:** every mirrored table has one column Supabase
doesn't — `is_synced`. It's `1` when the row came *from* Supabase, and flips to
`0` the moment a local write touches it. `SyncService` walks the `0` rows on
reconnect.

**Changing the schema** means: edit `schemaStatements`, bump `_version`, add a
matching migration step to `_onUpgrade`. The **schema-parity test**
(`test/core/local_db/schema_parity_test.dart`) fails if a fresh install and an
upgraded old install don't end up identical. See `05-recipes.md`.

### The sync engine — `lib/core/sync/sync_service.dart`

On reconnect (driven by `lib/core/connectivity/connectivity_service.dart`), it
pushes everything marked `is_synced = 0` (and every tombstone) up to Supabase
**in strict foreign-key order** — courses, then decks, then cards, then
study data — so a fully-offline authoring session never references a parent
Supabase hasn't seen. Deck/course *positions* (after an offline drag-reorder)
push via dedicated RPCs (`set_deck_positions` / `set_course_positions`).

`SyncOutcome` / `SyncOutcomeKind` track what the last pass did; that drives the
retry affordance on `SyncStatusChip` (top-right of the Decks tab) and the
`OfflineBanner`.

Wired app-wide by `ref.watch(syncCoordinatorProvider)` in `lib/app.dart`.

### Account-switch safety — `mirror_scope_guard.dart`

If the signed-in user id changes, `mirrorScopeGuardProvider` (also watched in
`app.dart`) **drops the entire local mirror**, so one account never sees
another's cached data.

### Per-device preferences (not synced)

Theme, study-appearance toggles, notification on/off, which Decks-tab sections
are expanded, the last-used Feynman timer — all `SharedPreferences`, via small
store classes in `lib/features/settings/data/` and
`lib/features/*/data/*_preference*.dart`. These never touch Supabase or SQLite.

---

## 5. Routing & auth gating

| File | Role |
|---|---|
| `lib/routing/app_routes.dart` | Every route path + name, as constants. Also `unauthenticatedPaths`. |
| `lib/routing/app_router.dart` | The `GoRouter`: the `StatefulShellRoute` (4 tabs) + the top-level routes. Wires the redirect and the refresh stream. |
| `lib/routing/auth_redirect.dart` | The pure gating rule (signed-out → only auth routes; signed-in → bounce off splash/auth to `/decks`). Unit-tested. |
| `lib/routing/go_router_refresh_stream.dart` | Re-runs the redirect whenever the Supabase session appears/clears. |
| `lib/routing/scaffold_with_nav_bar.dart` | The shell chrome: the 4 branches in a `Stack`, the slide transition, the `OfflineBanner`. |
| `lib/routing/glass_bottom_nav_bar.dart` | The floating nav pill + centre **+** button. |

---

## 6. Startup — `lib/main.dart`

In order, before `runApp`:

1. `dotenv.load('.env')` — reads `SUPABASE_URL` / `SUPABASE_ANON_KEY`. **Not
   guarded** — the app genuinely can't run without it.
2. `Supabase.initialize(...)` — restores the persisted session (local only; the
   network `recoverSession` is fire-and-forget inside the package). **Not
   guarded.**
3. `NotificationService().init()` — **guarded** in `try/catch`; reminders are a
   nice-to-have.
4. Eagerly read the saved `ThemeMode` — **guarded**; so the first frame paints
   in the right theme with no flash.
5. `AppDatabase.open()` — **guarded**; if it fails the app runs online-only.

Then `runApp(ProviderScope(overrides: [...], child: OpenRecallApp()))` — the
overrides inject the constructed notification service, theme seed, and database
handle into their providers.

Everything after step 2 **degrades instead of blocking** — that's the
"fast offline launch" contract (design spec §E.1).

---

## 7. Testing conventions

- **`test/` mirrors `lib/`.** `lib/features/study/domain/requeue.dart` →
  `test/features/study/requeue_test.dart`.
- **Pure domain logic** has plain unit tests — fast, no Flutter. These are the
  bulk of the suite and the easiest to read for "what is the intended
  behaviour."
- **Widget tests** use `test/support/pump_app.dart` — `pumpApp(tester,
  signedIn: true, decks: FakeDeckRepository()...)` boots the whole app with
  in-memory fakes, no `Supabase.initialize()` needed.
- **Fakes** live in `test/support/` — `fake_deck_repository.dart`,
  `fake_study_repository.dart`, `fake_course_repository.dart`,
  `fake_stats_repository.dart`, `fake_auth_repository.dart`. If you add a method
  to a repository interface, you add it to the fake too (the compiler tells
  you).
- **Local-DB tests** use `test/support/local_db_harness.dart` (opens an
  in-memory sqflite via `sqflite_common_ffi`).

**To find the test for a file you're changing:** same path under `test/`, or
`grep -rl "the_thing_you_changed" test/`. Run `flutter test` before and after
every change.
