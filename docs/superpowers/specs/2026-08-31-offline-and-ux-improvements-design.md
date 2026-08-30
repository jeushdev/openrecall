# Offline & UX Improvements — Design Spec

**Date:** 2026-08-31
**Status:** Approved for planning. Not yet implemented.
**Scope:** Five loosely-related improvements, delivered as five independent milestones.

## How to use this document

This is a planning spec written before any codebase exploration. Every milestone
below carries a **"Verify first"** list — the assumptions made while reasoning
blind. Future Claude must confirm each of those against the actual code and
against `docs/spec.md` / `docs/spec-v3-card-model.md` / `docs/ui-spec-v2.md`
**before** writing the implementation plan for that milestone.

Each milestone is a separate session and a separate conventional commit
(`feat: <summary> (milestone <id>)`), per the project's one-milestone-per-session
rule. Build them in the order A → B → C → D → E. E (offline) is the largest and
riskiest and is deliberately last, after the smaller UX work has stabilised.

## Decisions already made (do not re-litigate)

- Offline scope: per-deck "make available offline", plus offline creation of
  courses, decks **and cards**, plus the slow-launch fix.
- Offline writes use a **local queue replayed on reconnect** (offline-first),
  not an online-only "pending" indicator.
- Neither decks nor courses are drag-reorderable today; build it for both.
- **Courses are a first-class table** with their own rows. **Every deck belongs
  to a course** (a deck always has a `course_id`). So course ordering is the
  top level and deck ordering is within a course.
- Troublemaker cards are **removed entirely**. In their place, a recent-activity
  feed is added to the **Mastery section** of the app (not the old troublemaker
  location, wherever that was).
- Activity feed contents: deck completions, all session completions, deck
  created, course created.
- Profile metrics to add: current streak, longest streak, and study-volume
  stats (total cards reviewed, sessions completed, total study time) with
  this-week rollups.
- Settings sections become **independent** collapsible toggles that **reset to
  collapsed on every launch** (no persisted expand state).
- Offline launch is **stale-first for downloaded decks only**: cached
  profile/mastery and downloaded decks render immediately; non-downloaded decks
  show a locked/placeholder state while offline.
- Local persistence is **SQLite via the `drift` package** (typed queries +
  versioned migrations). The "no ORM" rule in CLAUDE.md governs the Supabase
  boundary, not the local cache.
- New narrow columns on `study_sessions` (e.g. completion timestamp, deck
  reference, duration) are **acceptable** where Milestones C/D need them —
  `updated_at` stays trigger-managed, RLS unchanged.
- Downloaded decks rarely go stale because cards are only created/edited inside
  the app. Offline-created content auto-syncs on reconnect; server-created
  content must be explicitly downloaded to be usable offline. No download cap,
  no aggressive background polling — refresh opportunistically (see Milestone E).

---

## Milestone A — Collapsible settings sections

### Goal
Make the settings screen scannable by collapsing each section behind a tappable
header.

### Behaviour
- Every settings section renders as a header row (title + chevron) with its
  contents below.
- Sections are **independent**: expanding one does not collapse others.
- **No persisted state.** On every launch/navigation-to-settings, all sections
  start collapsed. (If the screen currently has a single always-visible list,
  "collapsed by default" is acceptable; if the team later decides an
  above-the-fold section should default open, that is a one-line change — do not
  build a persistence layer for it.)
- Expand/collapse is animated consistently with the existing motion work
  (milestones UX3/UX4 introduced flip/slide animations — match their curve and
  duration).

### Data model
None.

### Verify first
- Settings screen file location and route.
- How sections are currently grouped and whether section titles already exist.
- Whether there is an existing collapsible/expansion widget pattern elsewhere in
  the app to reuse (e.g. an `ExpansionTile` wrapper or a custom disclosure
  widget) rather than introducing a new one.
- The shared animation curve/duration constants from the theme layer.

### Testing
- Widget test: tapping a header toggles visibility of that section's children
  and leaves sibling sections unchanged.
- Widget test: re-entering the screen resets all sections to collapsed.

---

## Milestone B — Drag-to-reorder decks and courses

### Goal
Let the user manually order both their course list and their deck list by
dragging, with the order persisted across launches and devices.

### Behaviour
- The **course list** is one reorderable list (top level, ordered per user).
- Each **deck list is reorderable within its course** (ordered per `course_id`).
- Use `ReorderableListView` (or the project's existing list pattern if one
  already supports reordering).
- Drag end: update local/Riverpod state immediately (optimistic), then persist.
- Ordering is **server-backed** so it survives reinstall and syncs across
  devices.
- New decks/courses are appended to the end of their list.
- Deleting an item leaves a gap; gaps are harmless (order is by `position`
  ascending, ties broken by `created_at`). A full renumber on delete is
  optional, not required.

### Data model
- Add `position` (integer, `not null`, default `0`) to the **decks** table and
  the **courses** table.
- Backfill existing rows: `courses.position` = row number ordered by
  `created_at` per `user_id`; `decks.position` = row number ordered by
  `created_at` per `course_id`.
- `updated_at` continues to be set by the existing DB trigger — application code
  must not write it.
- RLS: `position` is just another column on an already user-scoped table
  (`decks` → `decks.user_id`; confirm the courses table's ownership column).
  No policy changes, but **re-read the generated policy SQL** to confirm an
  `UPDATE` of `position` is permitted by the existing policy and is still
  ownership-scoped.

### Persistence strategy
- On reorder, write the new `position` for every affected row. Simplest correct
  approach: send the full ordered list of ids and their new indices in one
  batched update (or a small RPC). Avoid N sequential round-trips on the UI
  thread.
- This write must not block the drag interaction — fire-and-forget with error
  recovery (revert local order + toast on failure).

### Interaction with Milestone E (offline)
If B ships before E (it does, per the build order), a reorder performed offline
simply fails the persist and reverts. Once E lands, reorder writes should go
through the same write-queue mechanism. Note this as a follow-up in E, not a
blocker for B.

### Verify first
- Exact table names and the courses ownership column (assumed `courses.user_id`)
  and deck parent column (assumed `decks.course_id`).
- Whether any `position` / `sort_order` / `order_index` column already exists.
- The existing list widgets for decks and courses and their providers.
- Whether Supabase RPC is already used anywhere (for the batched update) or if
  batched `upsert` is the established pattern.

### Testing
- Widget test: dragging a row changes visual order.
- Unit test: the reorder-to-position mapping produces a contiguous, stable
  ordering.
- Unit test: persist failure reverts local order.

---

## Milestone C — Remove troublemaker cards, add activity feed

### Goal
Remove the "troublemaker cards" surface entirely, and add a **recent-activity
feed** to the **Mastery section** of the app.

### Removal
- Delete the troublemaker cards UI component(s) and their entry point, wherever
  they currently render.
- Delete or neutralise the logic that computes/surfaces troublemaker cards
  **only if that logic exists solely to feed this UI**.
- **Critical constraint:** if any troublemaker-related tracking feeds the
  guaranteed-mastery session loop (the core loop in `docs/spec.md` that
  guarantees every card reaches mastery before a session ends), it must **not**
  be removed. Only the presentation is being removed. Confirm this boundary
  before deleting anything.

### Activity feed

**Source: derived from existing data. Do not create a new activity/event
table** unless verification shows the needed timestamps are not already
recorded.

Feed items, each with a timestamp:
| Item type | Source |
|---|---|
| Session completed | `study_sessions` rows that are finished (completion timestamp / status) |
| Deck completed | Same as above, filtered to single-deck sessions; render with deck name |
| Deck created | `decks.created_at` |
| Course created | `courses.created_at` |

- Merge all sources, sort by timestamp descending, take the most recent ~20.
- Row content: leading icon (per type), a short label
  (e.g. "Completed *Biology · Chapter 3*", "Created deck *Spanish verbs*"),
  and relative time ("2h ago", "yesterday").
- Session/deck completion rows additionally show a compact result summary
  (e.g. cards mastered / total, or the session score as already computed
  elsewhere — reuse the existing session-summary formatting).
- Empty state: a friendly "Your recent study activity will show up here."

### Placement
In the **Mastery section** of the app, as a block below the existing mastery
content. This is a different screen from the old troublemaker location and from
the profile metrics (Milestone D). Verification must confirm exactly what the
"Mastery section" is — a tab, a screen, a card on another screen — and where a
list block fits within it.

### Data model
Ideally none. If `study_sessions` lacks a reliable completion timestamp or a
deck/course reference, the minimal fix is to add those columns to
`study_sessions` (with the DB trigger handling `updated_at`), **not** a new
event-log table.

### Verify first
- Where troublemaker cards are rendered and what computes them.
- What the "Mastery section" is (screen/tab/route) and its current layout.
- Whether troublemaker tracking is coupled to the mastery session loop.
- `study_sessions` schema: is there a `completed_at` / `status` / `ended_at`;
  is there a `deck_id` or a link table for multi-deck sessions; is there a
  stored score/mastery summary.
- `session_cards` RLS is join-scoped through `study_sessions` — confirm any new
  read for the feed stays within the user's own rows.
- Existing relative-time formatting helper (or add one).

### Testing
- Unit test: feed merge produces correct descending order across mixed sources.
- Unit test: feed caps at the configured limit.
- Widget test: each item type renders its icon + label; empty state renders when
  there is no activity.
- Regression: the mastery session loop still behaves identically after
  troublemaker removal (run the existing session-loop tests).

---

## Milestone D — Profile metrics

### Goal
Give the profile screen a fuller picture of study habits.

### Metrics to add
| Metric | Definition |
|---|---|
| Current streak | Consecutive calendar days, in the **device-local timezone**, each having ≥1 completed session. Today counts if there is a completed session today; otherwise the streak is measured up to yesterday and is "at risk". |
| Longest streak | Maximum run of consecutive qualifying days ever. |
| Total cards reviewed | Count of card review events across all history. |
| Sessions completed | Count of finished `study_sessions`. |
| Total study time | Sum of session durations. Requires a start/end or a stored duration on `study_sessions` — see verify. |
| This week | Cards reviewed, sessions completed, and study time for the current week (local timezone, week start per existing app convention or Monday). |

### Presentation
- A metrics block on the **profile screen**. (The activity feed from Milestone C
  lives in the Mastery section, a different screen — no layout coupling between
  C and D, but both read session history; see cross-milestone notes.)
- Reuse the existing stat/tile styling from the profile screen. Do not
  introduce a charting library — these are single-value tiles. Trend lines /
  sparklines are explicitly out of scope for this milestone.

### Computation
- Prefer computing from existing history tables client-side over adding
  denormalised counters, unless the history table is large enough that a
  full scan on profile load would violate the responsiveness requirement in
  `docs/spec.md`. If it would, add a small aggregate query / Postgres view or
  a maintained counter, and note the choice.
- Streak computation: fetch the set of distinct local-date values that have a
  completed session, then walk backwards from today.
- All of this is read-only and must not block navigation to the profile screen
  — load with a spinner/placeholder per tile, consistent with how the profile
  screen already loads mastery.

### Data model
Likely none. Possibly a `duration_seconds` (or `started_at` + `ended_at`) on
`study_sessions` if total study time cannot otherwise be derived.

### Verify first
- Which metrics already exist on the profile screen (streak may already be
  there — dedupe, do not double-render).
- The table(s) recording individual card reviews and session completions.
- Whether session duration is recoverable.
- The app's existing "week start" convention, if any.
- The profile screen's current loading pattern for async stats.

### Testing
- Unit test: streak calculation — no activity, activity today, gap yesterday,
  long unbroken run, activity only in the past.
- Unit test: longest-streak calculation over a fixture history.
- Unit test: this-week rollups respect local-timezone day boundaries.
- Widget test: tiles render values and show placeholders while loading.

---

## Milestone E — Offline overhaul

### Goal
Three outcomes:
1. Launching offline is fast and shows useful content instead of hanging.
2. The user can mark specific decks "available offline" and study them with no
   connection.
3. The user can create courses, decks and cards offline; they sync automatically
   on reconnect.

This is the largest milestone. If, during planning, it proves too big for one
session, decompose it into E1 (local store + slow-launch fix), E2 (per-deck
download + offline study), E3 (offline creation + sync engine) — each its own
session and commit. Prefer this decomposition if there is any doubt.

### E.0 — Local persistence layer

- **SQLite via `drift`**, decided. Typed queries and versioned migrations; the
  "no ORM" rule in CLAUDE.md governs the Supabase boundary, not the local cache.
  This adds `drift` + `sqlite3_flutter_libs` + a `build_runner` code-gen step.
- Tables (names illustrative):
  - `cached_decks` — id, course_id, name, `position`, server `updated_at`,
    `downloaded_at`.
  - `cached_cards` — id, deck_id, `front`, `back`, `keywords` (JSON-encoded
    text array), `is_concept`, server `updated_at`. Mirror exactly the columns
    `availableModes()` needs — front/back/keywords/is_concept — since study
    mode is computed at read time and there is no `type` column.
  - `cached_profile` / `cached_mastery` — a single-row snapshot each, or a
    small key/value blob table, holding the last successfully fetched
    profile and mastery summary.
  - `write_queue` — id (local), op type
    (`create_course` | `create_deck` | `create_card` | …), payload JSON,
    `created_at`, `attempts`, `last_error`, `status`
    (`pending` | `syncing` | `failed`).
  - `id_map` — `temp_id` → `server_id`, for reconciling offline-created rows.
- Migrations: versioned from day one.

### E.1 — Fast offline launch

Current problem: launching offline hangs for a long time; decks never load;
profile/mastery eventually load but slowly.

- On startup, **read from SQLite first** and render:
  - cached profile and cached mastery immediately;
  - downloaded decks immediately;
  - non-downloaded decks as a **locked/placeholder state** (greyed row with a
    "Download to use offline" affordance) while offline.
- Show a persistent but unobtrusive **offline banner**.
- Any network call on the startup path must have a **short timeout** and must
  **not block** first paint. The long hang is almost certainly a synchronous
  `await` on a Supabase call (session refresh, initial decks fetch, or a
  connectivity check) on the critical path — future Claude must locate it and
  move it off the critical path / make it fire-and-forget with a timeout.
- When connectivity returns: run the sync engine (E.3), then silently refresh
  the caches and update the UI.
- Auth: a cached/valid session should let the user in offline. Confirm how
  Supabase auth persistence currently works and that an expired-token refresh
  failure does not lock the user out while offline.

### E.2 — Per-deck "Make available offline"

- Each deck row / deck detail screen gets a toggle or download button.
- Turning it on: fetch the deck + all its cards from Supabase and write them to
  `cached_decks` / `cached_cards`, stamp `downloaded_at`. Show progress for
  large decks.
- Turning it off: delete the deck's rows from the cache (keep nothing but the
  fact that it is not downloaded).
- Downloaded state is shown with a clear indicator (e.g. a filled download
  icon / "Available offline" chip).
- **Staleness:** per the user, drift is rare because cards are only
  created/edited in-app. Handling:
  - When a downloaded deck is opened **while online**, opportunistically
    re-fetch it and update the cache in the background (cheap, no spinner).
  - Provide a manual "Update offline copy" action on the deck.
  - No background polling, no cap on number of downloaded decks, no LRU
    eviction.
- Studying a downloaded deck reads exclusively from SQLite; ratings/flips are
  written to the local review store and queued for sync exactly as the existing
  "study interactions never block on network" constraint already requires.
  Confirm how ratings are currently persisted and whether they already have an
  offline path — if they do, reuse it; if not, that path is part of this
  milestone.

### E.3 — Offline creation and sync engine

- **Offline creation of courses, decks and cards** (all three, decided):
  - The create forms work with no connection.
  - A new row is written to SQLite with a **temp UUID** (client-generated) and
    an entry is added to `write_queue`.
  - A card created offline references its parent deck by that deck's id (a temp
    id if the deck was also created offline); a deck references its course the
    same way.
  - The new course/deck/card appears immediately, flagged with a subtle
    "not synced yet" indicator.
  - A deck created offline should be immediately study-able offline (its cards
    are in SQLite already); treat a freshly-created offline deck as implicitly
    "available offline".
- **Sync engine**, triggered on connectivity regained (and on app resume, and
  after a successful manual retry):
  1. Process `write_queue` in FIFO order (course before deck before card). For
     each op: call Supabase, on success record `temp_id → server_id` in
     `id_map`, rewrite any local references (a queued deck create pointing at a
     not-yet-synced course's temp id; a queued card create pointing at a
     not-yet-synced deck's temp id), mark the op done.
  2. On failure: increment `attempts`, store `last_error`, keep the op
     `pending` (with backoff). Surface a non-blocking "some changes haven't
     synced" affordance with a retry.
  3. After the queue drains, refresh downloaded decks and the profile/mastery
     caches.
- **Conflict policy:** last-write-wins. If the same deck was edited on another
  device, the reconnect refresh overwrites the local copy. The user has
  accepted this as an acceptable rare case. Do not build merge logic.
- `updated_at` is always server-trigger-managed — the sync engine never sends
  it.

### RLS / ownership

- `cards` and `session_cards` have **no owner column**; their RLS is
  join-scoped (`cards` → `decks.user_id`, `session_cards` →
  `study_sessions.user_id`). When the sync engine inserts an offline-created
  course → deck → cards chain, the parents must land first so each child insert
  passes the join-scoped policy. FIFO ordering + the temp-id rewrite handle
  this, but the plan must call it out explicitly and test the full chain.
- Re-read the generated policy SQL for `decks`, `courses`, `cards`,
  `study_sessions`, `session_cards` and confirm INSERT policies actually permit
  the offline-created shapes.

### Verify first

- The exact startup call chain in `main.dart` / `app.dart` and which `await`
  blocks first paint offline.
- How Supabase auth session persistence and refresh currently work offline.
- How card ratings/flips are currently persisted and whether an offline path
  exists.
- Whether a connectivity package is already in the project
  (`connectivity_plus` or similar); if not, it is a new dependency here.
- The current course-create, deck-create and card-create flows and their
  providers (all three need an offline path).
- Whether `cards.keywords` round-trips correctly as JSON in and out of SQLite
  (it is a Postgres `text[]`).
- `docs/spec.md` "Offline/sync design" section and
  "Performance & Responsiveness" — this milestone must conform to whatever is
  already specified there; where this document and `docs/spec.md` disagree,
  **stop and ask**.

### Testing

- Unit: `write_queue` FIFO processing, success path writes `id_map`.
- Unit: queued card-create rewrites its deck temp-id to the real id after the
  deck syncs.
- Unit: failure path increments attempts and retains the op.
- Unit: streak/cache readers tolerate an empty SQLite store (fresh install
  offline — should not crash, should show sensible empty/locked states).
- Widget: offline launch renders cached content + banner within a tight frame
  budget; non-downloaded decks show the locked state.
- Widget: creating a course/deck/card offline shows it immediately with the
  unsynced indicator; a deck created offline is studyable offline right away.
- Integration (fake Supabase / local): go offline → create course + deck +
  card → go online → everything lands server-side with correct parent links and
  passes RLS.

---

## Planning decisions — all resolved

Every open decision from the brainstorming round is settled and folded into the
milestones above:

1. Local store: **`drift`** over SQLite.
2. Offline creation covers **courses, decks and cards**.
3. **Courses are a first-class table**; every deck has a `course_id`.
4. The activity feed lives in the **Mastery section**; profile metrics stay on
   the **profile screen** (separate screens).
5. **New narrow columns on `study_sessions` are pre-approved** where C/D need
   them.

What remains are implementation-time **verifications**, not decisions — each
milestone's "Verify first" list. None of them should require coming back to the
user unless a verification contradicts a decision above (e.g. `docs/spec.md`
already specifies a different offline design), in which case: stop and ask.

## Cross-milestone notes

- Milestone C (activity feed, Mastery section) and Milestone D (metrics, profile
  screen) are on different screens but both read session/completion history —
  build D immediately after C and reuse whatever history-access helper C
  introduces.
- Once Milestone E lands, revisit Milestone B so reorder writes go through the
  write queue rather than failing offline.
- Every milestone: `flutter analyze` clean before commit; add the tests listed;
  conventional commit `feat: <summary> (milestone <id>)` straight to `main`.
