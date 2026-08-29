# ActiveRecall — Engine V2 Spec

## 0. Status & relationship to `docs/spec.md`

This is a north-star spec for a small multi-milestone change (milestones 15–17). It is not
a replacement for `docs/spec.md`, which stays the source of truth for everything Engine V2
does not explicitly change.

Engine V2 is **data layer + one queue-scope option + a local aggregation layer**. Every
piece of UI it implies — course pickers, per-course colour theming, a stats / "Mastery"
screen, a navigation shell — is deferred to a later "UI revamp" phase and is explicitly
out of scope here. The work in these milestones is the plumbing that revamp will sit on.

This spec was reconciled from an earlier draft ("Engine V2 Overhaul Specification") that
assumed an architecture the app does not have. §1 records what changed and why, so the
history stays legible.

---

## 1. Codebase reconciliation

The original draft was written against an assumed SM-2 spaced-repetition engine with a
separate isolated "Cram mode". This codebase has neither. The reconciliation:

| Original draft | Reality in this codebase | Reconciled decision |
|---|---|---|
| Study Mode = "the existing SM-2 flow, untouched" | There is no SM-2 — no `ease_factor`, `interval_days`, or `next_review_date` anywhere. Study Mode is a mastery grind: it requeues every card rated below Mastered until the queue clears, parks a card after 3 consecutive fails, and ends when every card is Mastered-or-parked. `cards.mastery_level` (0–4) is the only progress signal. | Study Mode is that grind, unchanged. |
| Cram Mode = a new isolated session-scoped queue: loads every card, card leaves the queue at rating ≥ 2, no park, never writes `mastery_level` | The existing loop already *is* a session-scoped queue that loops failed cards until empty. The only genuinely new behaviour wanted is the ability to drill cards that are *already Mastered*. | No separate mode, no `session_type`, no separate transition. Add **one option** to the existing loop: include already-Mastered cards in the queue ("all cards") instead of only due ones ("due only"). Everything else — `mastery_level` writes, park-after-3, `last_studied_at` — behaves exactly as a normal session. |
| New `lapses` integer on `cards`, incremented on ratings 0–1, powering a "Troublemaker" query | `cards.fail_count` already exists as a lifetime counter, already incremented on every sub-Mastered rating, and already powers the Deck Overview "Troublemaker cards" list (§4 of `docs/spec.md`). | No new column. Reuse `fail_count`. |
| Stored `mastery_count` integer on `decks`, synced last-write-wins | A client-side read-modify-write counter is racy (a lost increment under last-write-wins), and it would be the first *content* write in a sync surface that is otherwise "study results only". | Do not store it. "Times this deck was fully cleared" is **derived** from a count of completed whole-deck sessions — rows that already sync and are conflict-free. |
| "Mastery Tab" with client-side aggregations | The app has flat `go_router` navigation — no tabs, no bottom nav, no stats screen. | Ship the aggregation logic as tested providers + repository methods. The screen that renders them is part of the later UI revamp. |
| `accent_color` on a Course, decks inherit it, selected from a curated palette | No colour column exists anywhere; the app is a single seed-colour Material 3 theme. | Add `courses.accent_color` as a **named-key enum** (not a hex string). Decks read it through `course_id`. No colour-selection UI yet. |
| "Mid-session Cram state" carried in the sync payload for app-kill recovery / resume | No session-resume-from-DB has ever existed — a killed session is abandoned and rebuilt on next start. With no separate mode there is nothing mode-specific to recover. | Out of scope. Resume-from-DB is a future milestone in its own right. No `session_cards.resolved` column, no session-conflict rework. |

---

## 2. Core invariants (retained from V1)

- **Zero-network invariant.** The study loop and every aggregation run against local state
  or the local SQLite mirror. No study interaction — flip, rate, type an answer — blocks
  on a network call. This is already true in V1 and Engine V2 must not regress it.
- **Sync gate.** The batch `SyncService.syncPending()` runs only *between* sessions
  (connectivity returning, app resume, session exit/finish). Live per-row background
  upserts of `session_cards` during a session continue exactly as in V1. Engine V2 adds no
  new sync trigger.
- **Sync surface stays the same shape.** Still `cards → study_sessions → session_cards`,
  in that dependency order; `cards` via the `updated_at` compare-and-set (never a blind
  update); session tables single-writer, batched upsert. **No deck or course rows are ever
  pushed** — course assignment is online-only for now, and "times cleared" is derived from
  session rows that already sync.

---

## 3. Data layer & models

### 3.1 New table: `courses`

```sql
create table courses (
  id           uuid primary key default gen_random_uuid(),
  user_id      uuid not null references profiles(id) on delete cascade,
  name         text not null,
  accent_color text not null,
  is_default   boolean not null default false,
  created_at   timestamptz not null default now(),
  updated_at   timestamptz not null default now()
);
```

- **`updated_at` trigger** reuses `public.set_updated_at()` (same as `decks` / `cards`).
- **RLS:** one `for all to authenticated` policy `courses_owner` with
  `user_id = (select auth.uid())` in both `using` and `with check` — the same direct-owner
  pattern as `decks`.
- **Indexes:** `create index on courses (user_id);` plus a partial unique index so a user
  has exactly one default course:
  `create unique index courses_one_default_per_user on courses (user_id) where is_default;`
- **`accent_color`** is constrained by a *named* check constraint so a future palette
  change is a clean `drop constraint` / `add constraint`:

  ```sql
  constraint courses_accent_color_check
    check (accent_color in ('slate','red','amber','green','teal','blue','violet','pink'))
  ```

  These are **named keys**, mapped to actual hex values in the Flutter theme layer during
  the UI revamp — not arbitrary hex, so contrast stays controlled. The list above is
  **provisional** and will be finalised with the revamp. The neutral default key is
  `slate`, and it must always be a member of the allowed set.
- **The default course is identified by `is_default = true`, never by its name.** The UI
  revamp will let users rename it, so name-matching `'Uncategorized'` is not safe to build
  on.

### 3.2 `decks` changes

```sql
alter table decks
  add column course_id uuid not null references courses(id);   -- FK action: NO ACTION (the default)
create index on decks (course_id);
```

- **The FK action stays `NO ACTION` (the default) — do not change it to `RESTRICT`.**
  Deleting a `profiles` row cascades to *both* `decks` and `courses` at once. `NO ACTION`
  defers the FK check to the end of the statement, so the simultaneous cascade succeeds.
  `ON DELETE RESTRICT` checks immediately and can spuriously fail account deletion — which
  the `delete-account` Edge Function depends on cascading cleanly.
- **Server-side default via a `before insert` trigger on `decks`:** when a row is inserted
  with `course_id` null, the trigger fills it from the inserting user's `is_default`
  course. This keeps the column `not null` with zero client changes and covers every
  insert path — manual create, bulk paste, tests, any future import.
- **The `decks` RLS `with check` gains a course-ownership clause.** The FK only proves the
  course *exists*, not that the user owns it, so a client could otherwise attach its deck
  to someone else's `course_id`. Add:
  `and exists (select 1 from courses c where c.id = decks.course_id and c.user_id = (select auth.uid()))`

### 3.3 `study_sessions` changes

```sql
alter table study_sessions
  add column card_scope text not null default 'due'
    check (card_scope in ('due','all'));
```

- This is queue-selection **metadata**, not a mode. It records whether the session drilled
  only due cards (`'due'`, the V1 behaviour) or the whole deck including Mastered cards
  (`'all'`).
- It is what makes "times fully cleared" derivable:
  `card_scope = 'all' and status = 'completed'`.
- `not null default 'due'` keeps every existing insert path working untouched.
- **No `session_type` column. No `resolved` column on `session_cards`.**

### 3.4 Schema application

The live Supabase project holds test accounts only — there is no production data to
migrate. So milestone 15 **rewrites `supabase/schema.sql`** to include all of the above
and re-applies it to a fresh project. There is no `supabase/migrations/` directory and no
incremental patch script.

`public.handle_new_user()` is extended so a new signup gets both a `profiles` row *and*
one `courses` row in the same trigger:

```sql
insert into public.courses (user_id, name, accent_color, is_default)
values (new.id, 'Uncategorized', 'slate', true);
```

The course insert comes *after* the `public.profiles` insert (FK order), and both tables
are fully qualified (`security definer` with `set search_path = ''`).

### 3.5 Dart models

- **New `Course` domain model** + **`CourseRepository`** (Supabase implementation + a
  cache-first wrapper), following the structure of the `decks` feature. Only the read path
  (list the user's courses) is wired now; create / update / delete are speced but not
  exposed until the UI revamp.
- **`Deck` / `DeckSummary`** (`lib/features/decks/domain/deck.dart`): add `courseId`.
  Update the nested selects in `supabase_deck_repository.dart` (`fetchDecks`, `fetchDeck`)
  to pull `course_id`. `fromJson` already ignores unknown keys so this is additive, but
  the field must be threaded through the DTOs so the revamp can group by course without
  rebuilding the plumbing.
- **`StudySession`** (`lib/features/study/domain/study_session.dart`): add `cardScope`, a
  new `enum CardScope { due, all }` whose `.db` maps to `'due'` / `'all'`.
- **`StudySessionArgs`** (`lib/features/study/presentation/study_session_args.dart`): add
  `cardScope`, defaulting to `CardScope.due`. No current screen sets it to `all`.
- **`FlashCard`**: no change — `failCount` is already present.

---

## 4. The session engine

### 4.1 Study loop — essentially unchanged

The V1 mastery loop is untouched: `StudySessionState.applyResult` retires a card at
rating ≥ 4, requeues anything lower via `requeuePosition`, prompts a park on the third
consecutive fail; the controller does the guarded `cards` writes and the `mastery_delta`
write on completion, and `_seedSession` still calls `markDeckStudied`.

### 4.2 The one new behaviour: "study all cards"

- `selectSessionCards` (`lib/features/study/domain/session_queue_selection.dart`) gains a
  `CardScope` argument. For `CardScope.all` it **skips the `c.isDue` filter** — every card
  that structurally supports the chosen mode enters the queue, already-Mastered ones
  included. The mode filter and the optional length cap still apply, unchanged.
- `SessionController.start` threads `cardScope` from `StudySessionArgs` into
  `selectSessionCards` and records it on the `study_sessions` row in `_seedSession`.
- A Mastered card rated below 4 during an "all" run requeues and its `mastery_level` drops
  — exactly like any other card. A "mastered" card the user has genuinely forgotten
  regressing is the correct outcome, not a bug.
- **There is no entry-point widget for this in Engine V2.** The plumbing defaults to
  `due`; the toggle that lets a user pick "all cards" is part of the UI revamp. Milestone
  16 covers the engine path with tests only — `session_queue_selection`,
  `session_controller`, and `study_session_state` all have existing suites to extend.

### 4.3 "Times fully cleared" — derived, never stored

```sql
select count(*) from study_sessions
where deck_id = :deckId and card_scope = 'all' and status = 'completed';
```

There is no stored counter. This value is surfaced only through the aggregation layer
(§6); nothing writes it anywhere.

---

## 5. Sync & offline mirror

The changes here are deliberately minimal.

- **`SyncService`** is unchanged in shape. The only edit is that the `study_sessions` push
  value map now includes `card_scope`.
- **`lib/core/local_db/app_database.dart`**: bump `_version` from 1 to 2 and add an
  `onUpgrade` that applies the same column deltas. All new columns have constant defaults,
  which SQLite's `alter table add column` requires.
  - **New `offline_courses`** table: `id`, `name`, `accent_color`, `is_default`. A
    read-only mirror — **no `is_synced`** — pulled during the read-through refresh
    alongside `offline_decks`.
  - **`offline_decks`** gains `course_id text` (nullable in the mirror is fine). **No
    `is_synced` on this table** — decks are still never edited offline; course assignment
    is online-only and "times cleared" is derived, so there is nothing to push.
  - **`offline_study_sessions`** gains `card_scope text not null default 'due'`.
  - **`offline_session_cards`**: no change.
- **`LocalStudyStore`** value maps updated for `card_scope`: `insertSession` and
  `unsyncedSessions`. **`LocalDeckStore`** carries `course_id` through `downloadDeck`,
  `refreshDeckMeta`, and `cachedDeckSummaries` — read-through only, no dirty-tracking.
- **Add a schema-parity test**: open a fresh v2 database and a v1 database upgraded to v2,
  and assert the resulting schema is identical. This guards `_createSchema` and
  `onUpgrade` against drifting apart.
- **Offline "study all cards" needs no extra plumbing.** A downloaded deck already mirrors
  every one of its cards; skipping the due filter is a pure in-memory change.

---

## 6. Local aggregation layer

Providers and repository methods only — **no widgets**. Each is unit-tested. These are the
APIs the UI revamp consumes. Where possible they derive from the deck list the app has
already fetched rather than adding new queries.

- **Overall mastery %.** A pure function over every card's `mastery_level`, flattened from
  the nested `cards(mastery_level)` that `fetchDecks` already returns. It is
  **card-weighted** — a large deck dominates — and reuses `masteryPercentFromLevels`. It
  mirrors the `DeckOverviewStats.fromCards` pattern: pure, no DB dependency, degrades
  cleanly when `appDatabaseProvider` is null. New `overallMasteryProvider`.
- **App-wide Troublemakers.** A *separate, targeted* query —
  `cards` selecting `id, deck_id, front, back, keyword, fail_count`,
  `order by fail_count desc limit N`, RLS-scoped — **not** an expansion of the
  library-screen deck select (which must stay lean). Offline results are partial:
  `offline_cards` only holds downloaded decks. An optional
  `create index on cards (fail_count desc)` gives headroom at scale.
- **Per-deck run-throughs.** The derived "times fully cleared" count from §4.3, as one
  query grouped by `deck_id`. New provider + repository method.
- **Per-course rollups.** A new `CourseSummary` (`id`, `name`, `accentColor`, `deckCount`,
  `totalCards`, `masteryPercent`), derived from the deck list joined by `course_id`.
  Courses are the headline change in Engine V2; the aggregation layer must expose
  course-level stats or the revamp will end up rebuilding both the widgets and the data
  behind them.
- **Speced but deferred** — named here so the revamp knows they are expected, even though
  Engine V2 does not implement them:
  - Activity over time — sessions per day, from `study_sessions.started_at`.
  - Mastery gained over time — a running sum of `study_sessions.mastery_delta`
    (already written on every completed session).
  - Lifetime totals — sessions completed, approximate study time from
    `completed_at - started_at`.

---

## 7. Milestones

Three sessions, in dependency order. See `docs/build-order.md` for the one-line entries.

### 15 — Engine V2 data layer

Everything schema-shaped, no behaviour change to studying, no UI.

- `courses` table: RLS, `updated_at` trigger, `user_id` index, `is_default`
  partial-unique index, named `accent_color` check constraint.
- `decks.course_id` (`NO ACTION` FK) + index; the `before insert` default-course trigger;
  the course-ownership clause added to the `decks` RLS `with check`.
- `study_sessions.card_scope`.
- `public.handle_new_user()` extended to create the default course.
- Rewrite `supabase/schema.sql` and **re-apply it to the live (test-only) project**.
- `Course` model + `CourseRepository` (read path); `Deck` / `DeckSummary` /
  `StudySession` / `StudySessionArgs` field additions; `fetchDecks` / `fetchDeck` select
  updates.
- SQLite `_version` → 2 + `onUpgrade`; `offline_courses`; `offline_decks.course_id`;
  `offline_study_sessions.card_scope`; `LocalStudyStore` / `LocalDeckStore` map updates;
  courses pulled in the read-through refresh; the fresh-vs-upgrade schema-parity test.
- **Done when:** the schema re-applies cleanly to a fresh project, a new signup
  auto-creates a `profiles` row *and* a default `courses` row, every existing deck ends up
  attached to its owner's default course, `flutter analyze` is clean, and `flutter test`
  is green including the schema-parity test — with zero visible change to the app.

### 16 — "Study all cards" queue option

- `selectSessionCards` gains its `CardScope` argument and skips `isDue` for
  `CardScope.all`.
- `SessionController.start` threads `cardScope` from args → `selectSessionCards` →
  `_seedSession`'s `card_scope` write.
- Extend the `session_queue_selection`, `session_controller`, and `study_session_state`
  test suites.
- Plumbing defaults to `due`; no toggle widget (the revamp adds it).
- **Done when:** a test session seeded with `CardScope.all` on a fully-mastered deck
  builds a non-empty queue containing the Mastered cards, its `study_sessions` row records
  `card_scope = 'all'`, and a `due` session behaves exactly as before.

### 17 — Local aggregation layer

- `overallMasteryProvider` (card-weighted, pure).
- App-wide Troublemakers: repository method + provider, via the targeted query.
- Per-deck run-through count, derived from `study_sessions`.
- `CourseSummary` per-course rollups.
- Providers + repository methods + tests. No widgets.
- **Done when:** each provider returns correct values against a fixture dataset, the pure
  functions have no DB dependency, and `flutter test` is green.

Milestones 16 and 17 are both light and can be merged into one session if preferred; 15 is
the substantial one and stands alone.
