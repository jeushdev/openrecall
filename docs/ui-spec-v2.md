# ActiveRecall — UI Revamp Spec (v2)

## 0. Status & relationship to other specs

This is the second UI revamp spec. It builds on:

- `docs/spec.md` — V1 engine (source of truth for everything not changed here).
- `docs/engine-v2-spec.md` — `courses` table, `decks.course_id`,
  `study_sessions.card_scope`, local aggregation layer. **Milestones 15–17 are
  complete.**
- `docs/ui-spec-v1.md` — the first presentation-layer revamp. **Milestones
  U1–U8 are complete** (theme tokens, routing shell, glass nav bar, Decks tab,
  Flip/Cloze/List/Feynman study screens, Mastery tab, Profile & Settings). Its
  **U9 (Course Creator) was left blocked** pending `CourseRepository` write
  methods.

Additionally, a milestone **"U9 — Add Card flow"** shipped (commit `6b04d78`):
the rapid single-card entry screen at `/deck/:deckId/add-card`
(`lib/features/decks/presentation/add_card_screen.dart`), reached after deck
creation and from the study screen's empty-deck dead-ends.

**This doc covers presentation layer + the course/deck write path only.** It
adds no schema, no columns, no tables — the `courses` data model already exists.
It supersedes parts of `docs/ui-spec-v1.md` where noted in §1.

Milestones here are **U10–U15**, executed one per session per `CLAUDE.md`.

---

## 1. What this revamp changes, and what it overrides in ui-spec-v1

| Area | ui-spec-v1 (current) | ui-spec-v2 (this doc) |
|---|---|---|
| Decks tab | Flat 2-column grid, no grouping. Due/All segmented control at top; badge shows `{n} due` or `×{n} cleared` per segment. | **Accordion of collapsible course groups.** No segmented control. Deck tile badge shows **card count only** (`"12 cards"`). |
| Due vs All scope | User picks Due/All on the Decks tab; `scope` query param drives `CardScope`. §6.1 explicitly keeps this control. | **Due view abandoned.** Every session runs `CardScope.all`. The `card_scope` column, `CardScope` enum and `selectSessionCards` argument all stay as plumbing; the UI simply never chooses `due` anymore. The Mastery tab's "deck completions" (`card_scope='all' and status='completed'`) is unaffected. |
| Tapping a deck | Straight to the study mode picker inside `StudySessionScreen`. | Opens a new **Deck detail screen** (`/deck/:deckId`): mode picker + Import action + View cards + edit/delete deck. |
| Center **+** button | Pushes `/deck-creator` directly. | Opens a **bottom sheet**: Create course · Create deck · Import card. |
| Course Creator (v1 §6.6/§7) | Blocked. Speced as name + accent picker + deck multi-select. | **Unblocked** and simplified: **name + accent picker only.** No deck multi-select at creation. Requires the `CourseRepository` write path (U10). |
| Deck edit/delete | Not possible in the app. | `updateDeck` / `deleteDeck` + UI affordances. |
| Card view/edit/delete | Only `add-card` (add-only) is reachable. Legacy card-manager widgets exist but are unrouted. | A card list screen + card edit screen with a delete action, reviving the legacy widgets. |
| Course edit/delete | Not possible. | `updateCourse` / `deleteCourse` + UI affordances. Deleting a course **reassigns its decks to the default course**, then deletes it. |

Everything in `docs/ui-spec-v1.md` §2 (core invariants), §3 (visual identity &
tokens — palette, the 8 accent hexes, geometry, `AppTokens`), §5 (glass nav
bar), and §6.2–6.5 (study screens, Mastery, Profile, Settings) **still holds
unchanged**.

---

## 2. Core invariants (unchanged, binding)

- **Zero-network invariant.** No flip / rate / reveal / type in a study session
  awaits a network call.
- **Authoring is online-only.** Creating or editing a course, deck, or card
  requires connectivity. `CacheFirstDeckRepository` and
  `CacheFirstCourseRepository` already pass authoring calls straight to the
  Supabase repo and throw when offline — new write methods follow that exact
  pattern. **No `is_synced` / dirty-tracking is added for courses or decks**
  (engine-v2-spec §2: "No deck or course rows are ever pushed").
- **No blind color input.** Every accent traces to one of the 8 named
  `accent_color` keys (`slate, red, amber, green, teal, blue, violet, pink`),
  resolved via `AppTokens.accents[key]`. The Course Creator picker offers
  exactly these 8 swatches — never a hex/RGB field.
- **`CardScope.all` is a real study run.** A Mastered card rated below 4 during
  a session regresses — correct, not a bug. No copy may imply studying is
  consequence-free.

---

## 3. Data layer — the write path (milestone U10)

No schema changes. New repository methods + providers only.

### 3.1 `CourseRepository`

Add to `lib/features/courses/domain/course_repository.dart` (+
`SupabaseCourseRepository`, `CacheFirstCourseRepository`, and the test fake):

```dart
Future<Course> createCourse({required String name, required String accentColor});
Future<Course> updateCourse({required String id, String? name, String? accentColor});
Future<void>   deleteCourse(String id);
```

- **`createCourse`** — `insert({'user_id': _userId, 'name': name, 'accent_color': accentColor}).select().single()`. `is_default` defaults to `false`. `accentColor` must be one of the 8 keys (caller-validated; the DB check constraint is the backstop).
- **`updateCourse`** — `update({...})` of only the non-null fields, `.eq('id', id)`. `updated_at` is left to the DB trigger.
- **`deleteCourse`** — two RLS-scoped statements, in order:
  1. `from('decks').update({'course_id': defaultCourseId}).eq('course_id', id)` — reassign this course's decks to the user's default course.
  2. `from('courses').delete().eq('id', id)`.
  `defaultCourseId` = `(await fetchCourses()).firstWhere((c) => c.isDefault).id`. The FK is `NO ACTION`, so step 1 must complete first or the delete fails. **The default course itself is never deletable** — guard in the controller and hide the affordance in the UI.
- `CacheFirstCourseRepository` — all three are straight online-only pass-throughs to `_remote` (like `CacheFirstDeckRepository`'s authoring methods).

### 3.2 `CourseController`

New `lib/features/courses/application/course_providers.dart`:

```dart
final courseControllerProvider =
    AsyncNotifierProvider<CourseController, void>(CourseController.new);
```

Methods `create` / `update` / `delete`, each wrapping the repo call in
`AsyncValue.guard` (mirror `DecksController._run`). On success invalidate
`coursesProvider`, `decksProvider`, and `decksTabViewProvider`. `delete` throws
(or no-ops with an error state) if handed the default course id.

### 3.3 `DeckRepository`

Add to `lib/features/decks/domain/deck_repository.dart` (+ Supabase impl,
cache-first pass-through, fake):

```dart
Future<Deck> updateDeck({required String id, String? name, String? courseId});
Future<void> deleteDeck(String id);
```

- **`updateDeck`** — `update` of the non-null fields, `.eq('id', id).select().single()`. Setting `course_id` to another of the user's courses is allowed by the `decks` RLS `with check` (it verifies course ownership).
- **`deleteDeck`** — `delete().eq('id', id)`. Cards cascade (`cards.deck_id … on delete cascade`).
- Extend `DecksController` with `updateDeck` / `deleteDeck`; invalidate `decksProvider`, `decksTabViewProvider`, and `deckCardsProvider(id)`.

### 3.4 Local mirror

`offline_courses` is a read-only mirror with no `is_synced` — after any course
write, the next read-through refresh re-pulls it. No `app_database.dart` version
bump, no `onUpgrade`. `LocalDeckStore` already threads `course_id`.

---

## 4. Routing

`go_router`, `StatefulShellRoute.indexedStack` for the four tabs; everything
else top-level (outside the shell, no bottom bar).

```
StatefulShellRoute
  /decks     → DecksTabScreen       (accordion — §5)
  /mastery   → MasteryTabScreen     (unchanged)
  /profile   → ProfileTabScreen     (unchanged)
  /settings  → SettingsTabScreen    (unchanged)

Top-level:
  /study/:deckId            → StudySessionScreen        (always CardScope.all)
  /deck-creator             → DeckCreatorScreen         (name + course picker)
  /course-creator           → CourseCreatorScreen       (NEW — §6.2)
  /deck/:deckId             → DeckDetailScreen          (NEW — §6.3)
  /deck/:deckId/import      → ImportCardsScreen         (NEW — §6.4)
  /deck/:deckId/cards       → CardListScreen            (NEW — §6.5)
  /deck/:deckId/add-card    → AddCardScreen             (existing; see §6.4)
```

- **`scope` query param is removed** from `/study/:deckId` call sites. The
  router builds `StudySessionScreen` with `scope: CardScope.all`
  unconditionally. Keep `cardScopeFromDb` and the enum — only the UI stops
  passing `due`.
- New routes carry `parentNavigatorKey: rootNavigatorKey` so the nav bar is
  absent, matching `/study` and `/deck-creator`.
- Card editing is a pushed screen (or full-screen dialog) under
  `/deck/:deckId/cards` — not a separate top-level route with a `cardId` path
  param, since it always opens from the list which already has the `FlashCard`.

---

## 5. Decks tab — course accordion (§6.1 replacement)

`lib/features/decks/presentation/decks_tab_screen.dart`.

- Header "Decks". **No segmented control, no caption.** Remove
  `lib/features/decks/presentation/deck_segment.dart` and
  `widgets/deck_segmented_control.dart` and the `DeckSegment` state.
- **`decksTabViewProvider`** (`application/decks_tab_view.dart`) returns a
  course-grouped model:

  ```dart
  class CourseDeckGroup {
    final Course course;
    final List<DeckTileView> decks;   // this course's decks, created_at DESC
  }
  // Provider now yields AsyncValue<List<CourseDeckGroup>>
  ```

  Ordered by `courses.created_at` ascending, so the default ("Uncategorized")
  course sorts first. **Every course is included, even with zero decks** — a
  course just created from the + menu must be visible immediately.
- Body: a scroll view of accordion sections. Each section:
  - **Header** — a 4px left accent bar (`AppTokens.accents[course.accentColor].fill`),
    course name (`w600`), `"{n} decks"` in `text.secondary`, a trailing chevron
    (rotates on expand). Tapping toggles expansion. A trailing ⋮ (or long-press)
    opens Edit course / Delete course (U15; default course: no delete).
  - **Body** (when expanded) — the course's deck tiles. Reuse `DeckGridTile`
    (2-column grid or a vertical list — pick during build; grid keeps the
    existing tile visual). The trailing `CreateDeckTile` (→ `/deck-creator`)
    stays, ideally inside the default course's body or as a global affordance.
- **Expand/collapse state** is persisted per course id in `SharedPreferences`
  (follow the U8 settings-persistence pattern). Default: all collapsed, or the
  default course expanded — pick during build. Survives app restart.
- **Deck tile badge** → `"{totalCards} cards"` (`DeckSummary.totalCards`),
  `"no cards yet"` when zero. Remove the Due/All badge branching in
  `widgets/deck_badge.dart`.
- **Deck tile tap** → `/deck/:deckId` (deck detail), **not** `/study/:deckId`.
- Deck accent sliver unchanged — still `deck.course.accentColor`.

---

## 6. New screens

### 6.1 Create menu (bottom sheet)

`lib/routing/glass_bottom_nav_bar.dart` `_CreateButton`: replace
`context.push(AppRoutes.deckCreatorPath)` with a `showModalBottomSheet`
(the codebase's first — model the API on `park_prompt_dialog.dart`'s static
`show` helper: `CreateMenuSheet.show(context)`).

Three rows:

| Row | Action |
|---|---|
| **Create course** | push `/course-creator` |
| **Create deck** | push `/deck-creator` |
| **Import card** | pick a deck (`decksProvider` list in the same sheet or a follow-on sheet), then push `/deck/:deckId/import`. If the user has **no decks**, this row routes to `/deck-creator` with a one-line hint ("Create a deck first"). |

Sheet styling: `cardFill` background, `borderRadius: 28` top corners,
`border.hairline`, no shadow.

### 6.2 Course Creator (`/course-creator`)

Top-level route. Model the header (Cancel / Create) and layout on
`lib/routing/placeholders/deck_creator_screen.dart`.

- **Name** — `TextField`, `autofocus`, non-empty to enable Create.
- **Color** — a single-select row/grid of the 8 accent swatches. Each swatch is
  a circle filled with `AppTokens.accents[key].fill`, selected state = a ring in
  `.text`. Default selection: `slate`.
- **Create** → `courseControllerProvider.notifier.create(name:, accentColor:)`;
  on success `pop()` back to the Decks tab (refresh `decksTabViewProvider`). On
  failure, keep the form and show a snackbar (mirror `AddCardScreen._save`).
- No deck multi-select (ui-spec-v1 §7's version is explicitly dropped).

### 6.3 Deck detail (`/deck/:deckId`)

Top-level route. `DeckDetailScreen(deckId)`.

- **App bar** — deck name (looked up from `decksProvider`), a top-right
  **Import** icon action (→ `/deck/:deckId/import`), and a ⋮ overflow →
  **Edit deck** / **Delete deck**.
- **Body**
  - **Study mode picker** — reuse `availableModes()`
    (`lib/features/decks/domain/study_mode.dart`) over
    `deckCardsProvider(deckId)` and the `ModePicker` widget
    (`lib/features/study/presentation/widgets/mode_picker.dart`). Selecting a
    mode pushes `/study/:deckId` (Feynman still routes through the timer picker
    inside `StudySessionScreen`). If the deck has no cards, show a "Add cards"
    CTA → `/deck/:deckId/import`.
  - **"View cards ({n})"** row → `/deck/:deckId/cards`.
- **Edit deck** — a bottom sheet: rename `TextField` + `CourseSelector`
  (`lib/features/decks/presentation/widgets/course_selector.dart`) →
  `DecksController.updateDeck`.
- **Delete deck** — confirm dialog ("Delete deck? This removes it and all its
  cards permanently."; Cancel / Delete) → `DecksController.deleteDeck` →
  `pop()` to the Decks tab.
- **`/deck-creator` success** now routes to `/deck/:deckId` (deck detail)
  instead of chaining into `/deck/:deckId/add-card`.
- `StudySessionScreen` keeps its own mode picker for direct `/study` entry and
  its empty / all-mastered dead-ends — thin it only if it's clearly redundant.

### 6.4 Import cards (`/deck/:deckId/import`)

Top-level route. `ImportCardsScreen(deckId)`. Header = deck name, Cancel/Done.
Two stacked sections:

- **Manual (top)** — the rapid single-card add. Reuse `AddCardScreen`'s field
  set and behavior: Front / Back / Keyword `TextFormField`s, `keywordError`
  validation (`lib/features/decks/domain/keyword_validator.dart`), and on save
  clear + refocus Front + a 1s "Card added" snackbar (do not pop). Calls
  `DecksController.addCard`.
- **Bulk (bottom)** — revive `widgets/bulk_paste_panel.dart`:
  - **"Copy AI prompt"** button → copies `aiIngestionPrompt`
    (`lib/features/decks/domain/ai_prompt.dart`) to the clipboard, confirmation
    snackbar.
  - A multi-line paste `TextField`.
  - **Debounced live preview** (`bulk_paste_parser.dart` → `BulkParseResult`):
    show parsed cards and failed lines with a per-line reason — **never
    silently drop a bad line** (spec §3, "Error states").
  - **"Add {n} cards"** → `DecksController.addCards(deckId, parsed)`.
- **Footer** — **View cards** (→ `/deck/:deckId/cards`) and **Start session**
  (→ `/deck/:deckId`).
- Retire the standalone `/deck/:deckId/add-card` route by repointing its two
  callers (`deck_creator_screen.dart` success — now goes to deck detail per
  §6.3 — and `study_session_screen.dart`'s "Add cards" dead-ends → this import
  route), or keep it as a thin alias of the manual section. Decide during U14.

### 6.5 Card list (`/deck/:deckId/cards`) + card edit

Top-level route. `CardListScreen(deckId)`.

- `deckCardsProvider(deckId)` → a list of `CardListItem`
  (`widgets/card_list_item.dart`) rows showing front / back / keyword preview.
  Empty state → "No cards yet" + a link to `/deck/:deckId/import`.
- **Tap a row** → a card edit screen (push, or a full-screen dialog). Reuse
  `widgets/card_fields.dart` (or `edit_card_dialog.dart`'s `CardFields`):
  Front / Back / Keyword, same validation as add.
  - **Top-right Delete** action → confirm dialog ("Delete card?") →
    `DecksController.deleteCard(id)` → pop back to the list.
  - **Save** → `DecksController.updateCard(id:, front:, back:, keyword:)`.
- The list refreshes via the `deckCardsProvider` invalidation the controller
  already does on card mutations.

---

## 7. Course & deck management affordances (milestone U15)

- **Course header ⋮ / long-press** (Decks tab §5): **Edit course** (name +
  accent picker, reusing the Course Creator's widgets →
  `courseControllerProvider.update`) and **Delete course** (confirm: "Delete
  course? Its decks move to Uncategorized." → `courseControllerProvider.delete`).
- **The default ("Uncategorized") course** — no Delete affordance. Rename /
  recolor is allowed or omitted (decide during build; engine-v2-spec §3.1 notes
  the default is identified by `is_default`, never by name, so renaming it is
  safe).
- **Empty states** — (a) only the default course, no decks; (b) an expanded
  course with no decks; (c) Import card chosen with zero decks anywhere.

---

## 8. Milestones

| # | Scope | Done when |
|---|---|---|
| **U10** | Course & deck **write path** (§3). `CourseRepository` create/update/delete (+ Supabase + cache-first + fake); `CourseController`; `DeckRepository` updateDeck/deleteDeck; `DecksController` extensions. This spec doc + `build-order.md` entries. **No UI.** | `flutter analyze` clean; `flutter test` green incl. delete-course-reassigns-decks and controller-invalidation tests; zero visible app change. |
| **U11** | Create menu bottom sheet (§6.1) + Course Creator (§6.2) + register `/course-creator`. Create deck flow unchanged for now. | `+` opens the 3-option sheet; Course Creator validates (name + one color) and the new course appears on the Decks tab; Create deck still works. |
| **U12** | Decks tab course accordion (§5): grouped provider, collapsible sections, persisted expand state, `"{n} cards"` badge, remove Due/All control. `/study` always `CardScope.all`. | Decks render grouped under collapsible course headers; expand state survives restart; no Due/All control anywhere; every session row records `card_scope='all'`; Mastery "deck completions" still works. |
| **U13** | Deck detail screen (§6.3) + edit/delete deck. Deck tiles route to `/deck/:deckId`. `/deck-creator` success → deck detail. | Tapping a deck opens detail; mode picker starts an `all` session; Edit renames / re-courses a deck (reflected on the tab); Delete removes it after confirmation. |
| **U14** | Import cards screen (§6.4): manual + bulk with Copy-AI-prompt and live preview. Wire the + menu's Import card and deck detail's Import action. Repoint / retire `/deck/:deckId/add-card`. | Manual add and bulk paste both create cards in the right deck; bad bulk lines flagged with a reason, never dropped; View cards / Start session navigate correctly. |
| **U15** | Card list + card edit/delete (§6.5). Course edit/delete from the accordion header (§7). Empty states. Finalize this doc. | Cards can be viewed / edited / deleted; courses renamed / recolored / deleted with decks reassigned to Uncategorized; `flutter analyze` clean, `flutter test` green, manual device pass. |

**Sequencing:** U10 first (unblocks all write paths). Then U11 → U12 → U13 →
U14 → U15. **U12 and U13 may be merged** into one session if context allows —
both rework the tab→deck flow. U14/U15 assume U13's deck detail screen exists as
an entry point (buildable with stub links if reordered).

Each milestone: `flutter analyze` clean + `flutter test` green, then a
conventional commit `feat: <summary> (milestone U##)` on `main`.
