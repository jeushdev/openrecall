# ActiveRecall — Offline-First Authoring Spec (v4)

## 0. Status & relationship to other specs

This spec makes the app usable with no connectivity. Today (spec.md §10) the
app is study-only offline, and only for decks the user explicitly toggled
"Available offline"; browsing the deck list, opening a deck, importing cards,
viewing profile/mastery, and creating a course or deck all fail offline.

It builds on:

- `docs/spec.md` — V1 engine and the original offline/sync design (§10,
  "Performance & Responsiveness"). **This doc supersedes §10 and the
  "authoring requires connectivity" clauses in §2, §3.**
- `docs/engine-v2-spec.md` §5 — the local mirror (`offline_courses`,
  `offline_decks.course_id`) and `SyncService`. **This doc extends both.**
- `docs/ui-spec-v2.md` §2 — states course/deck authoring is online-only.
  **Superseded here.**

Milestones are **O1–O4**, executed one per session per `CLAUDE.md`.

- **O1 — schema v4 + local stores.** SQLite `_version` 3 → 4; dirty-flag
  columns on `offline_courses` / `offline_decks`; `content_dirty` on
  `offline_cards`; `offline_deletions` tombstone table; the full local-store
  method surface (offline create / update / delete + sync-support reads).
  Schema-parity test extended. No behaviour change yet. **Complete.**
- **O2 — cache-first authoring falls back to a local queue.** Every authoring
  method on `CacheFirstDeckRepository` / `CacheFirstCourseRepository` tries
  Supabase, then writes the local mirror (client-generated UUID, `is_synced =
  0`) on failure. Read paths mirror all rows, not just pinned decks.
- **O3 — `SyncService` pushes content + deletions.** Grows to push courses →
  decks → card content → card mastery → sessions → session_cards, then replays
  tombstones in reverse FK order.
- **O4 — offline / pending-sync chip + copy + toggle semantics.** A small
  `☁ offline · N` indicator; reword the "check your connection" copy; the
  "Available offline" toggle becomes a pin (`is_pinned`), since a deck is
  cached the moment it is opened online.

---

## 1. Decisions

| Question | Decision | Why |
|---|---|---|
| How far does offline go? | **Full offline-first authoring.** Create / edit / import / delete courses, decks and cards offline; queued locally, pushed on reconnect. | The offline use case is no longer "study on the bus" only — the user wants to work on their material anywhere. |
| Which content is editable offline? | **Any deck opened while online** (auto-cached), plus anything created offline. A deck never opened online is unavailable offline (unchanged). | The auto-cache already holds the card set once a deck is opened, so editing it offline costs nothing extra. |
| What caches automatically? | Course list, deck list, profile, mastery — always. A deck's **card set** caches when the deck is opened online, or proactively when pinned. | Navigation must never look broken offline. Card sets are the only heavy payload, so they stay demand-loaded. |
| The "Available offline" toggle | Becomes a **pin** (`offline_decks.is_pinned`): fetch the deck without opening it and never auto-evict it. Row existence alone just means "cached". | Two concepts (cached vs. pinned) previously shared `offline_decks` membership. |
| Multi-device? | **No.** Single-device beta. Last-write-wins by `updated_at`, no merge UI. | Matches spec.md §10 ("Not building: multi-device conflict resolution"). |
| Sync mechanism | **Extend the existing `is_synced` dirty-flag pattern** + a tombstone table. No separate mutation/outbox log. | Single-device + LWW make "current row state + tombstones" sufficient, and it keeps one sync mechanism instead of two. `create → edit → delete` offline before a sync collapses to nothing automatically. |
| Deletes offline | **Allowed**, recorded as tombstones and replayed on reconnect. A row deleted offline that changed remotely is still deleted (LWW). | Consistent with the single-device assumption. |
| IDs for offline-created rows | **Client-generated UUIDs** from creation (`lib/core/ids.dart` `newUuid()`). Supabase `id` columns only *default* to `gen_random_uuid()`, so an explicit UUID upserts fine. | No "swap the temporary id" step once synced — same rule spec.md §10 already states for offline sessions. |
| Sync-status UI | **Minimal**: a `☁ offline` chip with a pending-change count, plus the existing sign-out "unsynced progress" warning. No per-row badges, no sync screen. | Enough for the user to know a write hasn't landed yet, without new surface area. |

---

## 2. Local schema (v4)

`lib/core/local_db/app_database.dart`, `_version` 3 → 4, `upgradeToV4Statements`
added, `schemaStatements` kept in parity (the schema-parity test enforces this;
`_v3Schema` is the frozen snapshot).

**`offline_decks`** gains:

| Column | Meaning |
|---|---|
| `created_at`, `updated_at`, `base_updated_at` (TEXT, nullable) | Timestamps for offline-authored rows; `base_updated_at` is the last Supabase `updated_at` seen (null ⇒ never synced). |
| `is_synced` (INTEGER NOT NULL DEFAULT 1) | Flips to 0 on a local create / rename / re-course. Walked by `SyncService`. |
| `is_pinned` (INTEGER NOT NULL DEFAULT 0) | The device-local "keep available offline" toggle. |
| `mastery_level_sum`, `total_cards` (INTEGER NOT NULL DEFAULT 0) | Let the Library render counts for a deck listed online but never opened, without mirroring its cards. |

**`offline_courses`** gains `user_id`, `created_at`, `updated_at`,
`base_updated_at` (TEXT, nullable) and `is_synced` (INTEGER NOT NULL DEFAULT 1)
— the same dirty-flag shape.

**`offline_cards`** gains `content_dirty` (INTEGER NOT NULL DEFAULT 0). A content
edit (front / back / keywords / is_concept) or an offline insert sets it to 1,
so the sync pass pushes a **full upsert**, distinct from the mastery-only
compare-and-set (`is_synced = 0 AND content_dirty = 0`).

**`offline_deletions`** (new):

```sql
CREATE TABLE offline_deletions (
  entity_type     TEXT NOT NULL,          -- 'course' | 'deck' | 'card'
  entity_id       TEXT NOT NULL,
  deck_id         TEXT,                   -- for a 'card' tombstone, to order the push
  created_locally INTEGER NOT NULL DEFAULT 0,  -- 1 ⇒ never reached Supabase, skip the remote delete
  created_at      TEXT NOT NULL
);
CREATE UNIQUE INDEX idx_offline_deletions_entity
  ON offline_deletions(entity_type, entity_id);
```

`LocalDeletion` (`lib/core/local_db/local_deletion.dart`) is the shared DTO.

---

## 3. Local stores (O1)

### `LocalCourseStore`

- `refreshCourses` — was a blind `DELETE + reinsert`; now a **dirty-preserving
  merge**: rows with `is_synced = 0` are untouched, synced rows absent from the
  remote list are dropped.
- `createCourse` / `updateCourse` / `deleteCourse` — write the row (or
  tombstone) with `is_synced = 0`. `deleteCourse` re-homes the course's local
  decks to the default course (and marks them unsynced), matching the remote
  two-statement delete.
- `defaultCourseId()` — resolves a null `course_id` on an offline deck create,
  matching the server `decks_fill_default_course` trigger.
- Sync support: `unsyncedCourses()`, `markCourseSynced(id, remoteUpdatedAt)`,
  `courseDeletions()`, `clearCourseDeletion(id)`.

### `LocalDeckStore`

- `refreshDeckMeta` — was downloaded-decks-only; now **upserts every deck** in
  the online list (name, course, last-studied, `mastery_level_sum`,
  `total_cards`), skipping `is_synced = 0` rows. This is what makes the whole
  Library browsable offline.
- `mirrorCards` — also ensures the `offline_decks` row exists, so opening any
  deck online auto-caches it (unpinned).
- `cachedDeckSummaries` — returns every cached deck; counts come from the
  mirrored cards when present, otherwise from the stamped
  `mastery_level_sum` / `total_cards`.
- `downloadDeck` / `removeDeck` — set / clear `is_pinned`. `removeDeck` keeps
  the row (just unpins) when the deck still holds unsynced work.
- Offline content writes: `createDeck`, `updateDeck`, `deleteDeck` (tombstone +
  cascade local cards/sessions), `insertCards` (client UUIDs, `is_synced = 0`,
  `content_dirty = 1`), `updateCardContent`, `deleteCard` (tombstone).
- Sync support: `unsyncedDecks()`, `contentDirtyCards()`, `markDeckSynced`,
  `markCardContentSynced`, `deckDeletions()` / `cardDeletions()` /
  `clearDeckDeletion` / `clearCardDeletion`. `unsyncedCards()` (the existing
  mastery push) now excludes `content_dirty` rows.

Testing follows the project convention (`local_stats_store_test.dart`): the
schema-parity test plus the no-database no-op contract. Real read/write/queue
behaviour is verified by the manual airplane-mode walkthrough (§6).

---

## 4. Cache-first repositories (O2)

Every authoring method follows the pattern already used by
`CacheFirstStudyRepository.createSession`: try `_remote`; on success mirror
locally as synced; on failure, if a local DB exists, write the local store
(client UUID, `is_synced = 0`) and return the local object; otherwise rethrow.

- `CacheFirstDeckRepository`: `createDeck`, `addCard`, `addCards`, `updateDeck`,
  `deleteDeck`, `updateCard`, `deleteCard`. `resetDeckMastery` stays online-only
  (bulk op, rare).
- `CacheFirstCourseRepository`: `createCourse`, `updateCourse`, `deleteCourse`.
- Reads already fall back; the only change is that the mirror-refresh side now
  covers all rows (§3).

An offline `createDeck` with a null course resolves to
`LocalCourseStore.defaultCourseId()`.

---

## 5. `SyncService` (O3)

Grows from `cards(mastery) → study_sessions → session_cards` to:

1. **Push courses** — upsert `unsyncedCourses()` (with `user_id`),
   `markCourseSynced` with the returned `updated_at`.
2. **Push decks** — upsert `unsyncedDecks()` (with `user_id`, resolved
   `course_id`), `markDeckSynced`.
3. **Push card content** — upsert `contentDirtyCards()` full rows,
   `markCardContentSynced`.
4. **Push card mastery** — existing guarded compare-and-set, unchanged.
5. **Push sessions / session_cards** — unchanged.
6. **Process deletions** — reverse FK order (card, deck, course). Skip the
   remote call when `created_locally = 1`; `clearDeletion` on success.

Keeps the existing best-effort / swallow-errors / `_running`-guard contract and
trigger set (`syncCoordinatorProvider` on reconnect, `SessionController` on
session end). `pendingSyncProvider` is extended to consult the new dirty rows
and tombstones; a `pendingSyncCountProvider` feeds the O4 chip.

**Auth / offline launch:** `SupabaseAuthRepository.isSignedIn` reads
`currentSession != null`, which `supabase_flutter` restores from local storage
on launch, so an offline cold start should still resolve `/` to `/decks`. This
is verified in §6; a guard is added only if the walkthrough shows a gap.

---

## 6. Manual verification (airplane-mode walkthrough)

1. Sign in online, browse several decks (don't open all), open two, view Mastery
   and Profile.
2. Airplane mode on. Confirm: the deck list still shows every deck; a
   previously-opened deck opens and runs a full session; Mastery and Profile
   render; a deck never opened online shows "unavailable offline".
3. Offline: create a course, create a deck in it, bulk-import ~10 cards, edit a
   card, delete a card, rename the deck. Chip shows `☁ offline · N`.
4. Kill and relaunch offline — app opens to `/decks`, all queued content
   present.
5. Airplane mode off. Chip clears within a few seconds. In the Supabase
   dashboard, the new course/deck/cards exist with the same UUIDs, and the
   edit / delete / rename landed.
6. `flutter build apk --debug` succeeds.
