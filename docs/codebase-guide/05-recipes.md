# 05 — Recipes: "I want to X"

Each recipe is an ordered list of files, with a one-line reason for each, and
the verification step. Start here when you're not sure where to go.

**Every recipe ends the same way:**

```bash
flutter analyze          # must be clean
flutter test             # must be green (606 tests as of this writing)
flutter run              # then press 'r', look at it on the device
git add -A && git commit -m "…"   # conventional commit; work goes straight to main
```

---

## Recipe 1 — Change a colour, spacing, or corner radius app-wide

| Want | File | How |
|---|---|---|
| Any colour (background, text, card fill, borders) | `lib/theme/app_tokens.dart` | Edit the hex in `AppTokens.light` and/or `AppTokens.dark`. That's it — every screen resolves through these. |
| A course accent colour | `lib/theme/app_tokens.dart` | Edit the relevant `AccentPair` in the `accents:` map (both light and dark). |
| A corner radius | `lib/theme/app_geometry.dart` | `AppRadii.card` (28), `.gridTile` (16), `.input` (12). |
| Border thickness | `lib/theme/app_geometry.dart` | `AppBorders.hairline` (0.5). |
| Expand/collapse animation speed | `lib/theme/app_motion.dart` | `AppMotion.expandDuration`. |

**Do not** add a raw `Color(0xFF…)` in a screen file — `app_tokens.dart` is the
only place hexes are allowed. There is a token test
(`test/theme/app_tokens_test.dart`, `app_theme_dark_test.dart`) that may need
updating if you add/rename a token.

Spacing that's local to one screen (a `SizedBox(height: 20)`) is edited in that
screen's file — see Recipe 2.

---

## Recipe 2 — Change one screen's layout or wording

1. **`docs/codebase-guide/02-screen-map.md`** → find the screen, get its file.
2. Open the file. Find the `build()` method (or `_SomethingState.build()` for a
   stateful screen).
3. The UI is the widget tree it returns. To change text, edit the string in a
   `Text(...)`. To reorder/add/remove, edit the `children:` list of a `Column` /
   `ListView`. To change spacing, edit a `SizedBox` height or an `EdgeInsets`.
4. If the screen has file-private `_Sub` widgets, they're lower in the same
   file.
5. `flutter run` + hot reload (`r`) — layout changes show instantly.

If the test for that screen asserts on the exact text you changed, update the
test (`test/` mirrors `lib/`).

---

## Recipe 3 — Add a field to a card, deck, or course

This is a **chain of ~7 files plus a database migration**. Do it in this order;
the compiler will flag anything you miss.

Example: adding a `notes` string to `FlashCard`.

1. **Supabase** — add the column in the dashboard (SQL editor:
   `alter table cards add column notes text;`). *(Out of this guide's scope, but
   the app won't read a column that doesn't exist.)* Mirror the change into
   `supabase/schema.sql` so it's not lost.
2. **`lib/features/decks/domain/card.dart`** — add the field to `FlashCard`, its
   constructor, `fromJson`, `toJson`/`copyWith` if present, `==`/`hashCode`.
3. **`lib/features/decks/domain/deck_repository.dart`** — if the field is
   settable, add it to the relevant method signature (`addCard`, `updateCard`).
4. **`lib/features/decks/data/supabase_deck_repository.dart`** — include the
   column in the `.select(...)` string and in insert/update payloads.
5. **`lib/features/decks/data/local_deck_store.dart`** — add the column to the
   local `offline_cards` handling (the row ↔ model maps).
6. **`lib/core/local_db/app_database.dart`** — the SQLite migration:
   - add the column to the `CREATE TABLE offline_cards` in `schemaStatements`,
   - bump `static const _version = 6` → `7`,
   - add `static const List<String> upgradeToV7Statements = ['ALTER TABLE offline_cards ADD COLUMN notes TEXT'];`
   - add `if (oldVersion < 7) { for (final s in upgradeToV7Statements) await db.execute(s); }` to `_onUpgrade`.
7. **`lib/features/decks/data/cache_first_deck_repository.dart`** — usually no
   change (it delegates), but check if it constructs `FlashCard`s directly.
8. **`test/support/fake_deck_repository.dart`** — update the fake to carry the
   field.
9. **UI** — `card_fields.dart` / `edit_card_dialog.dart` / `import_cards_screen.dart`
   to let the user enter it; the card list / study card to display it.

**Verification:** `flutter test` — the **schema-parity test**
(`test/core/local_db/schema_parity_test.dart`) specifically checks that a fresh
v7 DB and a v6-upgraded-to-v7 DB are identical. If it fails, your
`schemaStatements` and `upgradeToV7Statements` disagree.

For **deck** fields: `deck.dart`, `deck_repository.dart` (`createDeck` /
`updateDeck`), the three deck data files, the migration, the fake.
For **course** fields: `course.dart`, `course_repository.dart`, the three course
data files, the migration, `fake_course_repository.dart`.

---

## Recipe 4 — Add or remove a Settings toggle

The pattern, end to end (all persist to `SharedPreferences`, none touch the
server). Copy an existing one — e.g. the theme toggle.

1. **`lib/features/settings/data/<name>_preference.dart`** — a small class with
   `Future<T> read()` / `Future<void> write(T)` over `SharedPreferences`. Copy
   `theme_mode_preference.dart`.
2. **`lib/features/settings/application/settings_providers.dart`** — add a
   provider. For a simple value use a `FutureProvider`; for one the user
   changes, an `AsyncNotifierProvider` with a controller exposing a setter
   (optimistic write with rollback — copy `themeModeProvider` /
   `ThemeModeController`).
3. **`lib/ui/settings/settings_tab_screen.dart`** — add a row inside a
   `CollapsibleSettingsSection`. Use `SettingsSegmentedControl<T>` for a small
   choice, a `Switch` for on/off. Wire `onChanged:` to the controller's setter.
4. If it needs a stable section id, add a `const _kMyThing = 'my_thing';` at the
   top and pass it to `settingsSectionsExpansionProvider`.
5. **`test/features/settings/`** and **`test/ui/settings/settings_tab_screen_test.dart`**
   — add coverage.

To **remove** one: delete the row from `settings_tab_screen.dart`, then the
provider, then the preference class, then the tests. `flutter analyze` will
flag anything still referencing them.

If the new setting affects **study**, read it in the study screen the way
`cardFontSize` is read: `ref.watch(studyAppearanceProvider).asData?.value?.X ?? default`.

---

## Recipe 5 — Change study behaviour

See `04-study-engine.md` first. Common changes:

| Want | File | What |
|---|---|---|
| The park threshold (3 consecutive fails) | `lib/features/study/domain/study_session_state.dart` | `static const int _parkThreshold = 3` (near line 240). |
| Where a failed card requeues ("3 ahead") | `lib/features/study/domain/requeue.dart` | `requeuePosition(...)` — the whole function. |
| What each rating button means / is worth | `lib/features/study/domain/flip_rating.dart` | The `label` and `level` switch expressions. Mind the deliberate gap at level 2. |
| Cloze outcome → mastery level | `lib/features/study/domain/cloze_outcome.dart` | The `masteryLevel` switch. |
| Cloze fuzzy-match tolerance | `lib/features/study/domain/levenshtein.dart` + its caller in `cloze_type_card.dart` | The distance threshold. |
| Deck mastery % formula | `lib/features/decks/domain/card.dart` | `masteryPercentFromLevels` / `masteryPercentFromLevelSum`. |
| Session-length presets (10/20/30/All) | `lib/features/study/domain/session_length.dart` | `sessionCapPresets`. |
| Queue eligibility / ordering | `lib/features/study/domain/session_queue_selection.dart` | `selectSessionCards` / `cardsSupportingMode`. |

Each of these has a dedicated pure-logic test in `test/features/study/` — run
it, expect to update it.

---

## Recipe 6 — Add a new screen

1. **`lib/routing/app_routes.dart`** — add `static const String fooPath = '/foo';`
   and `static const String fooName = 'foo';`.
2. **Create the screen widget** — `lib/features/<feature>/presentation/foo_screen.dart`
   (or `lib/ui/<area>/`). Start from an existing `ConsumerWidget` screen as a
   template — `Scaffold` + token background + `SafeArea`.
3. **`lib/routing/app_router.dart`** — add a `GoRoute`. If it should have **no
   bottom nav bar** (most non-tab screens), add it as a top-level route with
   `parentNavigatorKey: rootNavigatorKey` (copy the `deckDetailPath` entry). If
   it's a new tab, that's a new `StatefulShellBranch` (rare — the shell is
   designed for exactly 4).
4. **Navigate to it** — from wherever:
   `context.pushNamed(AppRoutes.fooName)` (with `pathParameters:` if the path
   has a `:param`).
5. **`test/routing/app_router_test.dart`** — add a case; write a widget test for
   the screen.

---

## Recipe 7 — Remove a feature safely

1. Find its **route** in `app_routes.dart` + `app_router.dart` — remove both.
2. Find its **screen file(s)** via `02-screen-map.md` — delete.
3. Find every **navigation** into it: `grep -rn "AppRoutes.thatName" lib/`.
   Remove the buttons/tiles that pushed it.
4. Find its **providers** (`lib/features/<feature>/application/`) — delete the
   ones nothing else uses. `flutter analyze` flags leftovers.
5. Find its **repository methods** — if a method is now unused, remove it from
   the `domain/` interface, all three `data/` implementations, and the fake.
6. Delete its **tests** (`test/` mirror path).
7. **What to leave alone:** shared widgets (`rating_row.dart`,
   `mastery_bar.dart`, `settings_segmented_control.dart` …), theme tokens, and
   anything under `lib/core/`. Deleting a DB column is usually not worth it —
   leaving an unused column is harmless; a migration to drop it is risk for no
   gain.

`flutter analyze` + `flutter test` will tell you if you cut too much.

---

## Recipe 8 — Change what the Mastery or Profile tab shows

Neither tab writes a query — they compose **aggregation providers**.

- **Mastery tab** screen: `lib/features/stats/presentation/mastery_tab_screen.dart`;
  sections in `lib/ui/mastery/`; providers in
  `lib/features/stats/application/stats_providers.dart`
  (`overallMasteryProvider`, `courseSummariesProvider`, `deckRunThroughsProvider`,
  `recentActivityProvider`).
- **Profile tab** screen: `lib/ui/profile/profile_tab_screen.dart`; sections in
  `lib/ui/profile/`; providers in
  `lib/features/profile/application/profile_providers.dart` (`currentStreakProvider`,
  `userIdentityProvider`) and `stats_providers.dart` (`studyMetricsProvider`).
- The **pure derivation logic** is in `lib/features/stats/domain/`
  (`overall_mastery.dart`, `course_summary.dart`, `streak.dart`,
  `study_metrics.dart`, `activity_feed.dart`) — with matching tests. Change the
  maths there.
- To add a new tile: add a pure function + test in `domain/`, a `FutureProvider`
  in the providers file, and a widget in `lib/ui/<tab>/`.

---

## Recipe 9 — Change offline behaviour or the sync order

- **What's stored offline** — `lib/core/local_db/app_database.dart`
  (`schemaStatements`). Adding a table = new migration (Recipe 3's DB steps).
- **When the local fallback kicks in** — the `catch` blocks in each
  `lib/features/*/data/cache_first_*_repository.dart`, and `staleFirst` in
  `lib/core/cache/stale_first.dart`.
- **The read timeout** (how long before falling back to cache) —
  `decksLoadTimeoutProvider` (`decks_tab_view.dart`), `statsLoadTimeoutProvider`
  (`stats_providers.dart`), `kRevalidateTimeout` (`stale_first.dart`).
- **The push order on reconnect** — `lib/core/sync/sync_service.dart`. It's
  strict FK order (courses → decks → cards → study). Don't reorder without
  understanding the FK constraints.
- **The offline UI** — `lib/core/ui/offline_banner.dart`,
  `lib/features/decks/presentation/widgets/sync_status_chip.dart`,
  `offline_toggle.dart`.
- **Tests** — `test/core/sync/`, `test/core/local_db/`,
  `test/features/decks/offline_*_test.dart`.

---

## Recipe 10 — "Where does this number/label on screen come from?"

1. Note the exact text or a nearby label.
2. `grep -rn "the label text" lib/` → finds the widget that renders it.
3. In that widget, see which `ref.watch(xProvider)` supplies the value.
4. `grep -rn "xProvider" lib/` → find where it's declared
   (`application/*_providers.dart`).
5. The provider body either derives it (follow the pure function it calls in
   `domain/`) or reads a repository (`domain/*_repository.dart` interface →
   `data/supabase_*` for the real query).
6. For a formatted string (times, percentages, deltas), check `lib/core/format/`
   (`relative_time.dart`, `study_duration.dart`, `mastery_delta_label.dart`).

---

## Appendix — the fastest orientation commands

```bash
# every screen file
find lib -path '*presentation*' -name '*_screen.dart'

# every provider declaration
grep -rn "^final .*Provider = " lib/

# every route
cat lib/routing/app_routes.dart

# which test covers a file
grep -rl "SymbolYouChanged" test/

# every place a screen is navigated to
grep -rn "AppRoutes\." lib/
```
