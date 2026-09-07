# Native offline data audit and implementation plan

Audited: 2026-09-07. Scope: native first; web remains online-only.

## Milestone status

- **Milestone 1 — Storage contracts and account isolation:** implemented; validation recorded below.
- **Milestone 2 — Immediate application reads:** implemented; validation recorded below.
- **Milestone 3 — Durable Dashboard, History, and metrics:** implemented; validation recorded below.
- **Milestone 4 — Reliable deck packages:** implemented; validation recorded below.
- **Milestone 5 — Local study writes and clear status:** implemented; validation recorded below.

The native offline-data plan is complete across milestones 1–5. Web and native
database-open failures intentionally remain online-only.

## Audit: current data flow

These findings describe the code before this work, based on static inspection.
They are not measurements of native cold-start performance.

| Area | Direct Supabase source | Existing local behavior |
| --- | --- | --- |
| Dashboard/Home | Active `study_sessions`, queue/mastery joins through `session_cards` and `cards`, completed-session counts, decks, courses, profile | Remote-first providers joined in `home_providers.dart`; loading/errors hide the affected sections, while greeting and shell render. |
| Profile/More | `profiles(id, email, username)`; completed sessions for metrics; deck summaries for mastery | No persisted profile row. Identity falls back immediately; metrics use placeholders. |
| History | Recent completed sessions (20), completed-session metrics (1,000), decks/courses for labels | Local fallback covers sessions mirrored on this device, not account history fetched elsewhere. Calendar and log show independent loading/error states. |
| Decks/courses | Deck metadata with nested `cards(mastery_level)`; course rows | Listed metadata is mirrored. Decks tab alone has an immediate cached-deck path; course enrichment still waits. |
| Cards | Full deck card queries, download counts/pages, individual mastery state | Card content is opportunistically mirrored when a deck header exists. Card List, Deck Detail, and Deck Overview await remote-first card providers. |
| Study sessions | Abandon/create session, create/update queue rows, guarded mastery writes, completion, last-studied update | Session/queue tables exist, but operations generally try Supabase before falling back locally. |

### Existing persistence

- SQLite through `sqflite`, `open_recall.db`, previously schema v6.
- Existing tables: `offline_courses`, `offline_decks`, `offline_cards`,
  `offline_study_sessions`, `offline_session_cards`, `offline_deletions`, `offline_meta`.
- DAOs already support dirty flags, content edits, baseline timestamps,
  client-generated UUIDs, and deletion tombstones.
- `SyncService` pushes courses, decks, card content/mastery, sessions, queue rows,
  then deletions. Retry/backoff and manual retry already exist.
- SharedPreferences persists theme, study appearance, notification preferences,
  and expanded course sections. It is for device preferences, not another data cache.
- Supabase restores its authentication session, but does not cache the separate
  `profiles` row. Riverpod values are in-memory, not durable persistence.
- `main()` skips SQLite on web and continues online-only if native database open
  fails. Existing account isolation uses a `last_user_id` marker and mirror wipe.

### Username fallback

`profileRepositoryProvider` uses `SupabaseProfileRepository` directly.
`profileProvider` catches failures and returns null. Home and More call
`displayNameOr(username, email)` with the email from the restored auth session.
There is no saved username to restore, and fallback also happens during loading.
Comments claiming no display-name field exists are outdated.

### History and Dashboard failures

`CacheFirstStatsRepository` is remote-first: fallback runs only after the remote
future throws. Stats providers wrap that whole call in a six-second timeout.
A stalled request can therefore exhaust the timeout before SQLite is reached.
History shows errors; Dashboard hides failed sections via `maybeWhen`.

Successful stats responses are not persisted. The shared `decksProvider` has no
explicit timeout or immediate cached emission, and dependent joins wait on it.
History Retry invalidates derived providers instead of explicitly refreshing failed
sources. Session completion directly invalidates cards/decks, but not all session
metrics. Without SQLite, no durable fallback exists.

### Slow offline loading

Most reads and writes wait for Supabase failure before trying SQLite. Some paths
have six-second bounds; others have no application-level timeout. Sequential
dependencies can accumulate waits. Study startup awaits remote-first abandonment,
session creation, and queue creation. Ratings use asynchronous write chains, but
draining those chains can delay finish or another session's start.
`connectivity_plus` detects network interfaces, not server reachability.
The existing `staleFirst` helper is not wired into these application reads.

### Download and readiness gaps

`isDownloaded()` means a deck header exists. `loadStudyDeckCards()` trusts it and
can return an empty list for a nonempty metadata-only deck, even online. Offline
tile eligibility means at least one local card exists, not that every card exists.
Downloads fetch cards without explicitly ensuring deck/course metadata or existing
session state. Pinning and card replacement are separate operations; an empty page
can prematurely terminate fetching. Unpinning clean decks deletes metadata and
history along with cards; unsynced work is retained despite outdated comments.

### Two offline indicators

- `OfflineBanner` in `ScaffoldWithNavBar`: “You're offline.”
- `SyncStatusChip` in Decks tab actions: “offline,” optionally with a pending count.

Both use `onlineStatusProvider`. The chip also reads pending counts and sync
outcomes. They are two presentations of the same connectivity hint.

## Target architecture

Extend SQLite, existing DAOs, Riverpod, and SyncService. Do not introduce another
database or general-purpose cache framework.

### Automatically cached application data

Cache profile, course/deck metadata and aggregates, ordering, session metadata for
History/calendar/metrics, and active-session progress summaries independently of
deck downloads. Record fetch time and partial/complete coverage, including empty
successful responses. Merge normalized session IDs with pending local sessions;
explicitly page metadata and keep the current UI limits of 20/1,000.

### Explicit offline deck packages

A complete package needs deck/course metadata, every card's ID/text/keywords/concept
flag/mastery/fail count/timestamps/sync baseline, completeness and download time,
pin preference, and stable local account identity. Study creates durable session
and queue records locally. Keep opportunistically fetched cards in the same tables;
pinning guarantees retention, while verified unpinned sets may be used if retained.
A partial card set plus an offline-authored card is not a complete download.

Preserve current resume behavior: restart/requeue remaining cards. Exact queue or
timer restoration and downloading another device's running session are separate
features, not requirements for creating a new complete offline session.

### Network-only data and operations

Authentication server operations, password recovery, account deletion, username
edits, download/update requests, and bulk mastery reset remain network-only.
Cache successful username edits. Retain existing offline course/deck/card authoring.

### Shared behavior

Render local data first, refresh in the background, skip definitively offline
requests, and bound requests when connectivity is uncertain. Keep cached data on
refresh errors. Distinguish missing, empty, partial, and unavailable storage.
Merge dirty rows/tombstones before presentation. Invalidate dependent providers
after local commits and refreshes. Revoke old-account work before switching data.

## Separately implementable milestones

### 1. Storage contracts and account isolation

- Migrate v6 to v7: profile table, cache metadata/coverage, cached active progress,
  card-set completeness and download timestamp. Reuse existing session metadata
  columns rather than adding a parallel session store.
- Preserve UUIDs, dirty rows, pins, and tombstones. Legacy card sets start
  unverified; migration neither deletes their content nor asserts completeness.
- Serialize ownership changes and atomically clear data/change the owner marker.
  Gate native consumers and sync on this local initialization barrier, revoke old
  DAO handles, and invalidate account-bound provider state.
- Expose unavailable local storage as a capability, not a completed cache.
- Verify real SQLite migration parity/data preservation, missing/empty/partial
  cache states, same-owner retention, stale handles, and overlapping switches.

This milestone adds contracts only: existing card-readiness and screen-read
behavior is intentionally left for later milestones. Existing installs with no
owner marker are adopted by the first restored account, matching prior behavior.

### 2. Immediate profile, deck, course, and card reads

- Use shared local-first observable reads with bounded background refresh;
  replace the Decks-tab-specific workaround.
- Persist/restore username and cache successful edits without fallback flicker.
- Serve complete cards immediately; fetch metadata-only decks online or show
  unavailable offline. Never present an incomplete deck as empty.
- Refresh metadata after authoring without clobbering dirty rows/tombstones.
- Acceptance: cached content renders with unresolved remote futures.

Implemented in `Add immediate local-first application reads`:

- `staleFirst` is the shared observable read primitive for profile, deck,
  course, and per-deck card providers. It emits a usable SQLite value first,
  bounds only the background remote leg to six seconds, replaces the value on
  success, and retains it on refresh failure. The Decks tab now consumes the
  app-wide deck provider rather than maintaining a tab-only cached fallback.
- Successful empty deck/course list responses are distinguished from missing
  caches through `application_cache`. Profile rows use `cached_profile`; Home
  and More suppress the email-derived fallback while native profile restoration
  is pending. Successful username edits update the cached row before the
  profile provider is refreshed.
- A local card list is eligible for immediate use only when
  `offline_decks.cards_complete = 1`. Successful full card mirrors set that bit,
  including for a zero-card response. Migrated legacy rows and metadata-only
  rows remain unverified, so a failed bounded online fetch produces the existing
  unavailable-offline/error state instead of an empty-deck view.
- Remote list/card merges are presentation-authoritative only after SQLite has
  preserved dirty rows and filtered deck/course/card tombstones. Metadata
  refresh also retains parent rows needed by unsynced cards, sessions, or decks.
  Successful online course/deck create and edit responses are written into the
  existing metadata mirror immediately.
- A null SQLite capability still produces no local emission or write and uses
  the repository's online result. Web therefore remains online-only. No session
  persistence, download transaction, study write-ordering, or indicator changes
  are included in this milestone.

### 3. Durable Dashboard, History, and profile metrics

- Persist paginated account session metadata and active progress; merge by ID.
- Derive existing views from the persisted data and expose incomplete coverage.
- Refresh session-dependent providers after local study and sync; retry sources.
- Keep cached Dashboard sections visible and distinguish uncached offline states.
- Acceptance: online history survives offline restart; local completions appear
  immediately and exactly once after sync.

Implemented in `Add durable dashboard, history, and profile metrics`:

- Successful recent-session (20) and completed-session metrics (1,000) reads
  page through Supabase and persist full session metadata into the existing
  `offline_study_sessions` mirror. Active-session metadata uses that same table,
  while `cached_active_progress` stores its compact mastered/total projection.
  No schema or storage package was added.
- Remote and pending local sessions merge on the normalized session UUID. A
  remote cache write cannot replace an `is_synced = 0` row, so a locally
  completed session remains immediately visible and becomes the same row after
  sync rather than a duplicate.
- Dashboard, History, and study-metrics sources are SQLite-first async
  notifiers with bounded background refresh. A failed refresh leaves cached
  data in `AsyncData`; an uncached failure remains an error. Cache metadata
  records complete versus capped/partial coverage, and History displays a
  saved-data notice that explicitly says when older activity may be missing.
- History Retry invalidates the recent-session and completed-session sources,
  plus their deck/course label sources. Study start/completion/exit and both
  manual and reconnect sync invalidate active progress, recent history,
  completed metrics, and deck session counts.
- A null SQLite capability performs no cache reads or writes and preserves the
  online-only path used by web and database-open failures. Deck packages,
  study commit ordering, and the existing banner/chip behavior are unchanged.

### 4. Reliable deck packages

- Replace header/nonempty-card checks with completeness checks everywhere.
- Validate full pagination, count, unique IDs, and required metadata; commit cards,
  completeness, and pin atomically. Keep the old package on failed update.
- Preserve dirty cards/tombstones. Unpin without deleting application history;
  retain cards needed by pending work or active sessions. Support empty packages.
- Acceptance: interrupted downloads never report ready; unpin loses no history.

Implemented in `Add reliable offline deck package validation`:

- Deck readiness, pinned-package membership, study fallback, and offline tile
  eligibility now all require `cards_complete = 1`; a metadata header or a
  nonempty local card list is never enough. Verified zero-card packages remain
  complete and pinnable.
- Production card reads and explicit downloads page to the exact count, reject
  short pages, duplicate IDs, wrong-deck rows, invalid card state, and count
  changes during the fetch. A package also requires usable deck metadata and,
  when assigned, cached course metadata.
- `LocalDeckStore.commitDeckPackage` validates first, then replaces clean cards,
  stamps completeness/download time, and changes pin state in one SQLite
  transaction. Fetch or validation failures happen before that transaction;
  transaction failures roll back, so a previously complete package stays intact.
- Package replacement overlays dirty cards and card tombstones and retains cards
  referenced by active sessions or unsynced session/queue work. Unpinning clears
  package readiness and deletes only discardable clean cards; it never deletes
  deck metadata, sessions, queue rows, history, or metrics inputs.
- Cached card data remains visible when a background refresh or local package
  commit fails. With no SQLite capability, online card reads remain authoritative
  and the offline-package control is hidden. Web remains online-only.
- Study write ordering and both existing offline indicators are unchanged;
  milestone 5 was not started.

### 5. Local study writes and clear status

- Commit local session start, queue, mastery, completion, and last-studied data
  before background sync for complete local decks.
- Preserve conflict handling and dependency ordering; acknowledgments must match
  the sent local revision so newer edits cannot be marked synced accidentally.
- Keep the global banner; make the chip pending/failure-only and disable retry
  when definitively offline.
- Acceptance: all study modes finish with stalled remote calls; reconnect is
  idempotent and preserves newer local edits.

Implemented in `Add local-first study writes and accurate sync status`:

- For a verified complete deck package, abandonment, client-UUID session
  creation, queue creation and mutation, card mastery/fail changes, completion,
  and the deck's last-studied timestamp commit to the existing SQLite v7 mirror
  without awaiting Supabase. Incomplete packages, web, and native runs without
  SQLite retain the online-only repository path.
- The session controller serializes queue-position/fail/park writes and drains
  them together with guarded mastery writes before committing completion. It
  refreshes pending-sync, history, active-progress, session-count, card, and deck
  providers after local commits without replacing usable cached values on a
  refresh or sync failure.
- Sync retains its parent-first dependency order. For affected decks it applies
  the existing remote active-session conflict rule before replaying session
  rows, then upserts queue rows. Deck replay now carries the locally committed
  `last_studied_at` value.
- Every sync acknowledgment is conditional on the exact local revision sent:
  timestamped card/content rows also compare their sent values, deck/course
  acknowledgments compare all locally mutable fields, and session/queue rows
  compare their complete payload because those server tables have no
  `updated_at`. A later local edit therefore remains dirty for the next
  idempotent pass instead of being cleared by a late response.
- `SyncStatusChip` renders only when work is pending, uses the existing failure
  outcome to distinguish a stalled online push, and never renders a synced or
  up-to-date state. Retry remains enabled after an online failure and is disabled
  only when connectivity is definitively offline. The global `OfflineBanner`
  implementation and behavior are unchanged.

Overall completion: milestones 1–5 now provide account-scoped SQLite v7 storage,
immediate local-first reads, durable Dashboard/History/metrics, atomic verified
deck packages, and local-first study writes with revision-safe sync status. No
additional database or cache package was introduced.

## Validation

Milestone 1: 44 tests passed with
`flutter test --no-pub test/core/local_db test/core/sync test/features/decks/offline_launch_test.dart`.
Coverage includes actual v6-to-v7 migration, fresh/upgraded schema parity,
pending-row preservation, cache coverage states, account-bound provider invalidation,
overlapping switches, stale DAO rejection, late sync-response rejection, and existing
offline launch behavior. `flutter analyze --no-pub` reports only three pre-existing
warnings in `home_tab_screen.dart` (unused `style`, `_CardSkeleton`, `_SectionError`).

Milestone 2: 368 tests passed with
`flutter test --no-pub test/core/cache test/core/local_db test/features/profile test/features/decks test/features/courses test/features/home/home_tab_screen_test.dart test/features/home/home_providers_test.dart test/features/settings/more_tab_screen_test.dart test/features/stats/stats_providers_test.dart test/features/study/pre_session_cards_provider_test.dart`.
Coverage includes unresolved-remote cached emissions for profile/decks/courses/
complete cards, username restoration without an email-fallback flash, verified
empty card sets, metadata-only and legacy-unverified unavailability, background
refresh replacement/error retention, dirty-row and tombstone preservation,
authoring metadata refresh, and no-SQLite online-only behavior.
`flutter analyze --no-pub` reports only the same three pre-existing warnings in
`home_tab_screen.dart` (unused `style`, `_CardSkeleton`, `_SectionError`).

Milestone 3: 195 focused and regression tests passed with
`flutter test --no-pub test/core/cache test/core/local_db test/core/sync test/features/stats test/features/home test/features/settings/more_tab_screen_test.dart test/features/study/session_controller_test.dart`.
Coverage includes persisted history after a real SQLite close/reopen while the
remote future remains unresolved, ID-based remote/local session merging without
duplicates, active-progress restoration, cached Dashboard retention after a
background failure, explicit partial/complete coverage, History Retry reaching
the failed source, study/sync regression coverage, and null-SQLite online-only
behavior. `flutter analyze --no-pub` reports only the same three
pre-existing warnings in `home_tab_screen.dart` (unused `style`,
`_CardSkeleton`, `_SectionError`).

Milestone 4: 297 focused and regression tests passed with
`flutter test --no-pub test/core/cache test/core/local_db test/features/decks test/features/study/pre_session_cards_provider_test.dart test/features/study/session_controller_test.dart`.
Coverage includes partial/interrupted and duplicate-ID downloads, atomic pin and
package replacement, verified empty packages, failed-update rollback behavior,
dirty-card and tombstone preservation, active/pending-work retention after unpin,
history/queue preservation, cached-data retention on package errors, and
no-SQLite online-only behavior. `flutter analyze --no-pub` reports only the same
three pre-existing warnings in `home_tab_screen.dart` (unused `style`,
`_CardSkeleton`, `_SectionError`).

Milestone 5: 588 focused and regression tests passed with
`flutter test --no-pub test/core/cache test/core/local_db test/core/sync test/core/ui/offline_banner_test.dart test/features/decks test/features/study test/features/stats test/features/home test/features/settings/more_tab_screen_test.dart`.
Coverage includes Flip, Cloze, and Feynman sessions starting and completing from
SQLite while every remote study write remains unresolved; local session, queue,
mastery, completion, and last-studied commits; parent-first idempotent reconnect
replay; exact-revision late-ack protection for session, queue, mastery, content,
deck, and course writes; pending/failure-only chip states; retry disabled only
while definitively offline; unchanged banner behavior; cached session data
retained through refresh failures; no-SQLite online-only operation; cross-DAO
revision checks; and queue-before-completion ordering.
`flutter analyze --no-pub` reports only the same three pre-existing warnings in
`home_tab_screen.dart` (unused `style`, `_CardSkeleton`, `_SectionError`).

All five implementation milestones are complete. Native startup timing remains
a separate on-device measurement; it is not established by static inspection or
the automated test suite.
