# Phase 2 — Explicit Offline Deck Support

## Objective

Make deliberate deck downloads reachable and reliable in the current Android UI: download a deck, restart without internet, open its cards, and start and complete a study session. Removing the offline copy must leave cloud data and pending local work intact.

Planning only. Audited on 2026-09-08 against HEAD `d816855`. No application source changes or feature implementation are part of this document. Findings below come from static source inspection; prior validation reports are not newly executed tests or Android verification.

## Scope

- Native SQLite capability, with Android as the acceptance target.
- Current Decks tab → Deck Detail → View cards / study routes.
- Explicit download, durable availability, safe removal, bounded automatic refresh, and failure recovery.
- Reuse the existing automatic cache, local study writes, account isolation, and reconnect synchronization.
- Preserve existing access to complete opportunistic caches. Explicit download adds guaranteed retention and a visible promise; it does not disable previously working cached study.

## Non-goals

No dashboard offline improvements, username/profile caching, history offline feature work, loading-screen redesign, Cloze hints, returning-card indicators, sounds, completion-screen redesign, onboarding/tutorial, AI, spaced repetition, general UI redesign, or unrelated Supabase refactors. No web offline support, background OS download service, new offline management screen, cross-device download preferences, or new sync engine. Existing history/session records are protected as a data-safety requirement only.

## Current Architecture Findings

Paths in this document are repository-relative. The current code supersedes older architectural descriptions, including the online-only authoring and opt-in-only caching text in `docs/spec.md`. Root `AGENTS.md` is empty. `README.md` and `CLAUDE.md` also contain older List-mode descriptions; the current unified card model and engine are authoritative.

### What Phase 1 actually delivered

The preceding five commits correspond to the completed work recorded in `docs/offline-data-audit-and-plan.md`:

| Commit | Infrastructure verified in source |
| --- | --- |
| `b5d74c2` | SQLite v7 cache coverage/readiness fields and coordinated account isolation. |
| `e31678e` | Local-first observable deck/course/card reads with bounded remote revalidation. |
| `c80115e` | Durable application session metadata and metrics infrastructure; reuse without extending scope. |
| `dc3a4aa` | Validated paged card downloads, atomic package commit, completeness-based eligibility, and protective removal. |
| `d816855` | Local-first study writes, serialized queue/mastery writes, revision-checked sync acknowledgments, and pending/failure sync status. |

Phase 2 is therefore a completion and hardening phase, not implementation of a new offline subsystem. Some download controller/UI code predates these commits.

### Storage, ownership, and persistence

- `lib/main.dart` opens `AppDatabase` on native platforms and injects it through Riverpod. Web and a failed database open use null/no-op stores and remain online-only.
- `lib/core/local_db/app_database.dart`: `sqflite`, durable `open_recall.db`, schema v7. Tables include `offline_courses`, `offline_decks`, `offline_cards`, `offline_study_sessions`, `offline_session_cards`, `offline_deletions`, `offline_meta`, `application_cache`, `cached_profile`, and `cached_active_progress`.
- `offline_decks.is_pinned`, `cards_complete`, and `downloaded_at` already persist explicit retention and verified card coverage. Header existence is not availability. Empty complete decks are supported.
- `AppDatabase.scopeAccount`, `LocalMetaStore`, `MirrorScopeGuard`, and scoped DAO handles coordinate owner changes. Old handles reject access after generation changes. Preserve this barrier and capture operation ownership before asynchronous fetches.
- SharedPreferences holds device preferences, including course expansion, study appearance, and Feynman timer choices. It is not the deck database. Supabase restores authentication separately. Same-account app restarts retain SQLite data; sign-out/account switching and app-data clearing are different cases.
- SQLite tables shown here do not declare cascading foreign keys between deck/card/session rows. Enabling `PRAGMA foreign_keys` does not supply missing relationships: cleanup must be explicit.

### Deck, card, and course reads

| Consumer/path | Current behavior |
| --- | --- |
| `deck_providers.dart`: `decksProvider` | `staleFirst` emits `LocalDeckStore.cachedDeckSummaries()` then calls `CacheFirstDeckRepository.fetchDecks()`. |
| `SupabaseDeckRepository.fetchDecks` | One unpaged deck-list query, with nested card mastery aggregates; not a complete package metadata contract. |
| `deckCardsProvider(deckId)` | Emits local cards only if `isCardSetComplete`; otherwise fetches. Repository fetch mirrors through `commitDeckPackage`. Opening online can create a complete **unpinned** cache. |
| `SupabaseDeckRepository.fetchCards` | Exact count, pages of 1,000 ordered by `created_at, id`, length/identity checks, final count check. |
| `course_providers.dart`: `coursesProvider` | Local-first `LocalCourseStore` plus `CacheFirstCourseRepository` / `SupabaseCourseRepository`. |
| `decks_tab_view.dart` | Joins local-first deck/course data; synthetic group if courses are unavailable. Uses `studiableOfflineDeckIdsProvider` to lock unavailable tiles offline. |
| Deck Detail and Card List | Watch `deckCardsProvider`; Deck Detail resolves its title from `decksProvider`. Detail currently uses a generic card-load error. |

`staleFirst` bounds revalidation to six seconds, but always invokes the remote closure. A Dart Future timeout does not cancel its underlying work or prevent a late repository cache write. Connectivity is not currently a skip condition in these reads.

### Existing downloads and actual UI reachability

- `offline_providers.dart`: `OfflineController.download`, `updateOfflineCopy`, `remove`; injectable `OfflineDownloadSource`; 100-card pages; global operation/progress providers.
- Download validates page lengths, unique IDs, deck IDs, and counts before calling `LocalDeckStore.commitDeckPackage`. The local transaction merges dirty cards/tombstones, replaces discardable cards, and sets completeness/time/pin together.
- However, explicit download fetches **cards only**. It accepts a presentation-supplied name and relies on an already-cached parent course/header. A missing header can be synthesized with no course; missing course metadata can instead cause commit failure. This is not a self-contained package download.
- `OfflineToggle` offers “Keep available offline,” progress, and removal confirmation. `DeckOverviewScreen` offers “Update offline copy.” **Neither is the current entry point:** `app_routes.dart` explicitly records that the old overview route is unregistered. `app_router.dart` routes tiles to `DeckDetailScreen`, whose overflow contains only Edit/Delete.
- Current `DeckGridTile` displays a lock message for unavailable decks, but `DeckTileView` has no explicit-download badge field. The old `DeckTile` indicator does not solve current grid discoverability.

### Study data and sync

- `pre_session_cards_provider.dart`: `loadStudyDeckCards` reads a complete local card set directly; otherwise invokes the repository with a six-second bound.
- `SessionController` uses that loader for start/resume, existing domain mode/queue selection, and `CacheFirstStudyRepository`. Modes are Flip, Cloze, Feynman, derived from content/keywords/`isConcept`; no separate offline card type or downloaded engine configuration is needed.
- Complete local decks create UUID sessions and queue rows locally. Ratings persist mastery/fail state; queue operations drain before completion and last-studied commits. `LocalStudyStore` already persists session configuration and progress.
- `SyncService` pushes existing dirty data in dependency order and handles tombstones, retry/backoff, and revision-safe acknowledgments. This phase needs regression tests, not a new result outbox.
- Study write routing tests `cards_complete` on each operation. Clearing it during a live session would route subsequent writes back to Supabase, even if protected cards were retained. Removal must guard active sessions at the service/storage boundary.
- Restart/resume follows the existing restart/requeue behavior; exact restoration of timer and in-memory queue is not promised here.

### Content, ordering, timestamps, and media

- `FlashCard` contains ID, deck ID, front/back text, keyword list, concept flag, mastery level, fail count, created/updated timestamps. There is no card media/file field. Inspection of deck/study renderers found no network image/audio/video/storage download path. Bundled fonts/icons and local timer settings need no per-deck download.
- Deck metadata includes name, parent course, ordering position, creation/update time, and last-studied time. Course name/accent/default/position support grouping and labels.
- Server `supabase/schema.sql` gives courses/decks/cards row-level `updated_at` triggers. A card edit does **not** bump its deck's timestamp. Session/queue tables lack `updated_at`. `DeckSummary` discards the deck update timestamp, and `refreshDeckMeta` omits several full `Deck` fields, including position/creation/update baselines.
- Local `cards()` sorts only by `created_at`, unlike remote pagination's `created_at, id`. Add the ID tie-breaker.
- Count checks detect many interruptions and cardinality changes, but do not prove a single server snapshot when same-count edits happen during pagination. Do not claim that they do.

### Additional gaps to address narrowly

1. Global download state has no deck identity, overlap guard, deadline, or stale-operation cancellation contract.
2. `remove` invalidates card/deck providers; their online refresh can immediately recreate the removed cache. Already-running refreshes can also commit after removal.
3. `refreshDeckMeta` prunes clean absent deck headers even when pinned; list omission can be pagination, not confirmed deletion. Course pruning can remove pinned-package labels. Orphan cards can remain because there is no SQL cascade.
4. Package replacement retains cards needed for old sessions. `cards()` returns all retained rows, so a remotely deleted but protected clean card can leak into the next study deck. Package membership must be distinguishable from retention for pending/session work.
5. Availability providers are not uniformly invalidated after automatic package commits. Membership loading currently defaults to empty, risking transient lock/badge errors.

## Existing Phase 1 Infrastructure We Can Reuse

Keep the existing database, DAOs, `Deck`/`Course`/`FlashCard` models, repository interfaces, Riverpod providers, local transaction merge rules, account generation barrier, study engine, and `SyncService`. Extend `OfflineDownloadSource` for targeted metadata reads instead of fetching an account-wide list or accessing Supabase in widgets. Keep `OfflineController` as the presentation adapter; place fetch/commit coordination in a small testable `OfflineDeckService` shared by explicit and automatic package refresh.

## Proposed Architecture

Current UI → `OfflineController` → `OfflineDeckService` → existing remote source + scoped SQLite package transaction.

Current read providers → local usable package immediately → bounded refresh through the same service when eligible. Existing web/no-storage reads continue through the remote repository.

The service owns a per-deck operation generation and one in-flight fetch per deck; the controller may serialize explicit downloads globally to preserve the current one-progress-bar convention. State carries the deck ID, operation kind, progress, and error. Refresh/removal share that gate. Capture the account-scoped stores before fetching and recheck account and operation generations inside the commit boundary, including after awaiting a queued transaction. Timed-out, superseded, disposed, or removed operations cannot mutate storage later.

Study startup must also acquire a short per-deck lease spanning local card loading through session/queue creation. Removal and refresh cannot pass the gate while startup holds it; after creation, the persisted active-session predicate protects the session. Release the lease on success or failure. This closes the race where removal occurs after cards load but before the active session is inserted, without holding a database transaction across network calls or changing the study algorithm.

Do not put a network await inside a SQLite transaction. Download into a temporary in-memory list, validate, then perform one short atomic install. Keep bounded 100-card fetches and measure memory for large decks before considering a disk staging subsystem.

## Offline Deck Data Model

### Existing authoritative state

| Persistent state | Interpretation |
| --- | --- |
| `is_pinned=0, cards_complete=0` | Metadata-only, partial legacy data, or removed copy; not usable as a full deck offline. |
| `is_pinned=0, cards_complete=1` | Complete opportunistic cache; usable while retained, without an explicit retention promise. |
| `is_pinned=1, cards_complete=1` | Explicitly downloaded: display “Available offline.” |
| `is_pinned=1, cards_complete=0` | Unverified legacy/interrupted state; never show available; online download can repair it. |

`downloaded_at` means last successful complete package install, including automatic caching; it is not a server revision or the sole proof of explicit download. Downloading/refreshing/error are transient operation states over the last committed persistent state. No durable “downloading” boolean or resumable job table is needed.

### Small extension to the same SQLite schema

Plan a v7→v8 migration, not a second persistence system:

- `offline_cards.in_current_package INTEGER NOT NULL DEFAULT 0`: identifies the current deck contents separately from rows retained only for old/pending sessions. Backfill existing cards under `cards_complete=1` to 1, other rows to 0; retain all data and flags. Legacy complete sets cannot retroactively identify protected extras; the next verified refresh repairs membership.
- `offline_decks.remote_missing INTEGER NOT NULL DEFAULT 0`: a confirmed targeted not-found/inaccessible result, for a durable saved-copy notice and to prevent repeated refresh/recreation attempts. A transport/authentication error or absent list row must not set it.
- `offline_decks.cache_suppressed INTEGER NOT NULL DEFAULT 0`: removing a copy suppresses incidental automatic repopulation across restarts. Explicit download clears it atomically. Online remote cards may still be displayed without mirroring when suppressed. This is needed to make removal survive provider invalidation; it is device-only and never synced.

Preserve pins, coverage, timestamps, dirty rows, UUIDs, ownership, and tombstones. Update fresh-schema and migration parity tests. No server migration is proposed.

### Required package payload and membership

Commit the full `Deck` metadata and its actual `Course`, plus every validated `FlashCard` field already persisted, sync baselines, and package state. Use shared domain models; a transport aggregate containing those models is acceptable, duplicate offline models are not.

Metadata/course/card upserts are dirty-aware and tombstone-aware in the same transaction. If a pending local deck edit changes its course, retain the locally authoritative parent and require that parent's metadata too. Missing required metadata fails the transaction. Do not persist unrelated courses/decks or mark the entire account list fetched after one targeted fetch.

Set membership for fetched cards; preserve local authored/dirty cards as the existing local overlay, and exclude tombstoned cards. Retain clean absent cards referenced by pending sessions as nonmembers; `cardById` and sync can still access them, while `cards()` and complete-package aggregates use current membership plus the intended dirty/local overlay. Card authoring must maintain membership without turning an incomplete set into a complete one. Compute totals after that merge, not solely from the remote count.

## Download Flow

1. From the current Deck Detail overflow choose **Download for offline use**. Keep it independent of card-body success so missing/failed cached data cannot hide the action. Hide offline actions without native storage; disable download when definitively offline.
2. Capture deck/account operation identity. Reject duplicate taps, read fresh targeted deck metadata and its required course through the source abstraction. No placeholder “Deck” header and no reliance on prior list navigation.
3. Fetch exact card count, all stable ordered pages, then recheck count and targeted deck existence/metadata. Validate IDs, expected page sizes, domain fields, and required parent metadata. If the deck moved courses during fetch, retry the whole bounded attempt rather than attach stale metadata.
4. Use a configurable six-second bound per network request and a two-minute overall attempt deadline initially. These are proposed values to validate with the large-deck Android test; total duration must not be six seconds for every deck size. No endless automatic retry.
5. Commit metadata, cards/membership, pin, completeness, timestamp, and suppression reset atomically. Guard obsolete/account-switched operations before the write.
6. Publish availability/card/metadata changes once; clear progress in `finally`. Announce **Available offline** only after commit. On failure, preserve prior package and offer retry of the normal download action.

A zero-card deck can download successfully; show the existing empty-deck state and no study mode. It must not be confused with a partial failed download.

## Offline Read Flow

- Decks tab uses existing local metadata and grouping. A downloaded deck remains discoverable after process restart, without waiting for account list refresh.
- Use persisted pin+coverage for the explicit badge and coverage for usable opportunistic caches. Preserve loading/error state while membership is being restored instead of asserting “cloud-only” from an empty fallback.
- For a definitively offline native read, skip remote deck/card/package refresh. Read complete cards immediately; missing/incomplete sets produce `DeckUnavailableOfflineException` immediately. Apply this to detail, card list, and direct study entry, not only tile gating.
- If connectivity is unknown or Wi-Fi has no internet, local data still renders first and actual network operations are bounded. Connectivity remains a hint, not an authentication or reachability guarantee.
- Unavailable copy: **This deck isn't available offline. Connect to the internet to download it.** Keep existing layout and Retry/Back affordances. The grid lock message should match. A never-downloaded but completely auto-cached deck remains usable as before; “never downloaded” with no complete cache is the graceful failure case.
- `loadStudyDeckCards` and existing study repositories use the same local `FlashCard` objects. No Supabase call is awaited to start, rate, or complete a downloaded session. Ancillary notification or sync work must not gate study.
- Existing restored-account authentication remains required. Do not add guest/offline login or redesign Home merely because it is the initial route.

## Remove Offline Copy Flow

1. Current Deck Detail overflow offers **Remove offline copy**, distinct from **Delete deck**. Confirm: “Remove the saved cards from this device? Your cloud deck will stay unchanged. Pending changes will be kept until synced.”
2. Check active-session state through the local service, not just a widget. If this deck has an active session, reject removal with “Finish or exit this study session before removing its offline copy.” Recheck inside the serialized transaction. Use the existing session exit/abandon path; never silently abandon or erase it.
3. Revoke any pending refresh generation. Atomically clear pin, completeness, download timestamp, and current membership; set cache suppression. Delete only discardable clean cards. Keep dirty cards, tombstones, sessions, queue rows, and cards required by unsynced session/queue work. Keep shared course/deck application metadata.
4. Pending-work inspection must include dirty deck/cards, unsynced sessions **and queue rows**, and deck/card tombstones; the current helper omits some of these.
5. Publish local state without triggering a replacement download. Already-running reads cannot recommit the removed package. Online card viewing works using remote data; it does not reverse removal. Another explicit download clears suppression.
6. After existing sync acknowledges protected work, targeted cleanup may discard nonmember clean cards no longer referenced by active/pending work. This must never delete session records or create remote tombstones. Keep cleanup narrow and idempotent.

“Local data removed” means the explicit usable package and discardable content are gone. Shared labels and protected pending work are deliberate exceptions, never falsely advertised as a still-available package. Removal issues zero remote deletion calls.

## Refresh / Staleness Strategy

Use automatic refresh on deck access, not a manual Update control. Reuse local-first rendering and the package service. On initial online detail/card access, refresh that deck once in the background; on offline→online while that deck is observed, refresh once again. Coalesce multiple consumers. Do not download every pinned deck on reconnect or add a periodic scheduler. Reopening a deck online is the refresh trigger for decks that were not being viewed at reconnect.

Skip automatic replacement while a local session is active; retry on next eligible access after completion/exit. Retain dirty overlays and never let a failed refresh replace a working saved copy. Keep pins on successful automatic refresh, and respect cache suppression. Retire the old manual-update behavior from any reused control; do not resurrect the unregistered overview route.

Full validated fetches are the simplest reliable freshness policy here. Deck timestamps alone miss card changes, maximum card timestamp misses deletions, and counts miss same-count changes. Do not introduce a misleading version comparison. `downloaded_at` may support a small “Saved copy” notice after refresh failure, but is not “up to date” proof.

Each install contains a validated full fetched set, not a guaranteed point-in-time database snapshot. Concurrent same-count edits can produce mixed revisions; the next access refresh converges. If strict snapshot consistency becomes a product requirement, a scoped server snapshot/revision contract is separate work to approve before changing this design.

### Remote deletion / access loss

Preserve a pinned complete snapshot and parent metadata when a deck disappears from a general list. List responses are currently unpaged and must not be treated as proof of deletion. Use a successful targeted deck lookup to confirm not-found/inaccessible; an auth failure, timeout, or network error is not confirmation.

For confirmed missing remote decks, retain the saved copy, set `remote_missing`, and show **This deck is no longer available online. Your saved copy is still on this device.** Permit local study and removal. Do not mark a missing deck as a newly successful empty download, do not auto-delete the saved copy, and do not auto-recreate the cloud deck.

Study writes remain local/pending if the remote parent no longer exists. `SyncService` must skip pushes for confirmed-missing deck descendants so an offline rename/content upsert cannot resurrect the deck; protected work remains durable. If targeted lookup later succeeds, clear the flag and resume the existing sync path. General conflict recovery/export for permanently deleted cloud decks is deferred. This saved-copy retention policy is an explicit review point, not a claim about current behavior.

Course/deck list pruning must preserve rows needed by pinned packages and protected work. This is package safety, not an account-list pagination redesign. Existing nonpackage list behavior need not be rewritten.

## Failure and Recovery Rules

| Event | Deterministic outcome |
| --- | --- |
| Successful new download | One complete committed package, pin set, success/badge published. |
| Failed page, short page, duplicate/wrong ID, missing metadata | No package commit; prior persistent state unchanged. Retry starts at page zero. |
| Network disappears / request hangs | Bounded failure; progress clears; old package still usable. No success at “100% fetched” before commit. |
| App killed during fetch | In-memory staging disappears; no new pin/completeness. Relaunch offers download again. |
| App killed during commit / disk-full transaction failure | SQLite rollback or complete commit; never a partially installed new package. Verify with real SQLite fault tests and Android process tests. |
| App restarted after success | Read durable metadata/coverage/content for the same restored account. No re-download required. |
| Failed refresh | Keep old cards, metadata, pin, and timestamp; retry on later eligible access. |
| Remote edit | Next eligible online access/reconnect of viewed deck atomically refreshes it, preserving local dirty work. |
| Remote deletion | Confirm through targeted lookup, preserve saved copy and local work, show saved-copy notice, suspend invalid descendant pushes. |
| Removal during fetch | Removal invalidates the operation; stale fetch cannot repin or recache. |
| Removal during active session | Rejected before any state is cleared; session remains locally writable. |
| Removal succeeds | Package no longer available; protected work and cloud data remain intact; incidental recaching suppressed. |
| Account switch/sign-out during fetch | Captured old generation cannot commit or publish into the new account. Existing account lifecycle policy remains. |
| Native database unavailable / web | No download success or offline controls; preserve online-only behavior. |

## Milestone 1 — Package state and retention contracts

### Objective and rationale

Make persisted explicit availability, retained pending rows, and removal semantics unambiguous before changing user controls. Existing v7 fields cover most requirements, but do not represent membership, confirmed remote absence, or intentional cache removal.

### Changes and data/storage

Implement the three small v8 columns/migration above; add typed package-status reads to `LocalDeckStore`, preserving existing provider compatibility. Make `cards()` and summary aggregates respect membership/dirty overlays and stable ordering. Maintain membership on existing local card add/edit/delete paths. Add complete pending-work/active-session predicates and guarded local-only removal with cache suppression. Capture operation generations for transaction validation. No widget changes yet.

### Files affected

- `lib/core/local_db/app_database.dart`: schema/migration.
- `lib/features/decks/data/local_deck_store.dart`: status, membership, aggregates, authoring maintenance, removal and retention predicates.
- `lib/features/decks/domain/offline_download.dart`: typed local state/operation value objects, reusing existing content models.
- `lib/features/decks/application/offline_providers.dart`: status provider adaptation.
- `test/core/local_db/schema_parity_test.dart`, `offline_foundation_test.dart`; new `test/core/local_db/schema_v8_test.dart`.
- `test/features/decks/local_deck_store_test.dart`, `reliable_deck_package_test.dart`.

### Tests / edge cases

Real v7→v8 close/reopen migration; fresh/upgrade parity; complete/incomplete/empty/legacy pins; migration preserves unsynced rows; active-session removal rejection; queue-only/tombstone-only pending work; clean protected nonmember excluded from a new deck read; dirty overlay included; two decks sharing a course; repeated removal; order ties.

### Acceptance criteria

Database state independently proves explicit availability after restart. Removal is local-only and idempotent, cannot break an active session, and retains protected work. No partial legacy set becomes complete due to migration or an authored card.

### Implementation Status

- **Status:** Completed
- **Implementation date:** 2026-09-08
- **Actual files changed:** `lib/core/local_db/app_database.dart`, `lib/features/decks/data/local_deck_store.dart`, `lib/features/decks/domain/offline_download.dart`, `lib/features/decks/application/offline_providers.dart`, `test/core/local_db/schema_parity_test.dart`, `test/core/local_db/offline_foundation_test.dart`, new `test/core/local_db/schema_v8_test.dart`, `test/features/decks/reliable_deck_package_test.dart`, `test/features/decks/offline_controller_test.dart`, and this plan.
- **Schema/migration implemented:** SQLite schema version 8 adds `offline_cards.in_current_package`, `offline_decks.remote_missing`, and `offline_decks.cache_suppressed`. The v7→v8 migration backfills membership only for rows belonging to a deck whose v7 `cards_complete` value was already 1; incomplete/metadata-only legacy caches remain incomplete. Existing rows and sync fields are preserved.
- **Important implementation decisions:** Persisted package state is exposed as typed `OfflinePackageStatus`; explicit availability still requires pin plus complete coverage. Normal card and complete-package aggregate reads use current membership plus unsynced/dirty local overlays, while `cardById` continues to expose retained nonmembers. Package replacement uses mark/install/cleanup rather than an ID-sized `NOT IN` list. Removal rechecks active-session state inside its SQLite transaction, clears membership/coverage/pin/timestamp, sets suppression, and deletes only unprotected clean cards. Dirty rows, sessions, queue rows, tombstones, and shared metadata are retained. Per-deck operation generations are checked inside package transactions so a superseded fetch cannot commit after removal.
- **Tests added/updated:** Real file-backed v7→v8 migration and close/reopen coverage; fresh/upgraded schema parity; complete, incomplete, zero-card, and legacy-pin state; unsynced-row preservation; active-session rejection; queue-only and deck/card-tombstone-only pending work; retained clean nonmember exclusion; dirty overlay inclusion; shared-course retention; repeated removal and suppression; stable order ties; incomplete-deck authoring; remote-missing persistence; and stale-operation rejection. Existing deck, study, and sync suites remain passing.
- **Deviations from the original plan:** No architectural correction was required. The generation value objects and registry are wired through the existing controller/store boundary as the Milestone 1 foundation; ownership of full fetch coordination remains deferred to the Milestone 2 service. Metadata pruning now also retains pinned, suppressed, remote-missing, and all currently detectable pending-work deck rows so the new persistence contract is not discarded by an incidental list refresh.
- **Intentionally deferred:** Self-contained targeted deck/course fetches, downloader deadlines/coalescing, the `OfflineDeckService`, automatic/reconnect refresh, confirmed-missing sync gating and post-ack cleanup, download/remove UI, session-start leases, and every other Milestone 2+ item remain unimplemented.

### Dependencies and not yet

First milestone. Do not add download UI, remote fetch changes, general eviction, or session engine changes. Do not delete old local data to simplify migration.

## Milestone 2 — Self-contained, cancellable package download

### Objective and rationale

Download a complete deck without relying on navigation having fetched its metadata, and ensure late/failed work cannot change persistent state.

### Changes and data/storage

Introduce `OfflineDeckService`, extend `OfflineDownloadSource` with targeted `Deck` and required `Course` reads, and route `OfflineController` through it. Preserve 100-card paging/progress, add deadlines, overlap/account/deck generation guards, and atomic dirty-aware metadata/course/card install. Respect suppression except for an explicit successful download. Service errors distinguish offline, request failure, missing remote deck, storage failure, and superseded operation; do not expose raw exceptions as the primary user copy. No additional tables.

### Files affected

- New `lib/features/decks/application/offline_deck_service.dart` (`OfflineDeckService`).
- `lib/features/decks/domain/deck_repository.dart` (`OfflineDownloadSource`).
- `lib/features/decks/data/supabase_deck_repository.dart` (targeted package source queries).
- `lib/features/decks/data/local_deck_store.dart` (`commitDeckPackage` transaction extension).
- `lib/features/decks/application/offline_providers.dart`, `lib/features/decks/domain/offline_download.dart`.
- `test/features/decks/offline_controller_test.dart`, `offline_download_test.dart`, `reliable_deck_package_test.dart`; new `offline_deck_service_test.dart`; affected fake download sources in tests.

### Tests / edge cases

Empty SQLite download including course metadata; stale supplied name ignored; dirty local course reassignment; 0/1/100/101/1,000/2,501/10,000 cards; short/duplicate/wrong-deck pages; changed count; deleted deck with zero cards; missing parent course; metadata request failure; timed-out request completing late; network loss then retry; account switch while a transaction is queued; double taps; insert failure rollback; prior complete package survives every failure.

### Acceptance criteria

Normal and multipage packages install from an empty mirror using only relevant deck/course data. Progress never announces durable success before commit. Failed or obsolete operations cannot pin, overwrite, or leak account data. Retry succeeds without partial leftovers.

### Implementation Status

- **Status:** Completed
- **Implementation date:** 2026-09-08
- **Actual files changed:** New `lib/features/decks/application/offline_deck_service.dart`; `lib/features/decks/application/offline_providers.dart`; `lib/features/decks/domain/deck_repository.dart`; `lib/features/decks/domain/offline_download.dart`; `lib/features/decks/data/supabase_deck_repository.dart`; `lib/features/decks/data/local_deck_store.dart`; new `test/features/decks/offline_deck_service_test.dart`; `test/features/decks/offline_controller_test.dart`; and this plan. Milestone 1 schema/store/test changes remain in the same working tree and were reused rather than duplicated.
- **Important implementation decisions:** `OfflineDeckService` owns targeted deck/course reads, stable 100-card paging, a six-second per-request timeout, a two-minute overall deadline, one retry when deck metadata/count changes, same-kind per-deck coalescing, and operation/account-scope checks before and inside commit. The remote deck name supplied by the service is authoritative; the controller's legacy presentation-supplied name remains in its signature for current UI compatibility but is ignored for storage. A pending local deck re-course remains authoritative and its existing parent metadata is required. Course, deck, cards, membership, pin/completeness, and aggregates install in one dirty/tombstone-aware SQLite transaction; suppression is checked before any package metadata write. Service failures expose stable offline/request/timeout/missing/invalid/storage/superseded categories while retaining the underlying cause only for diagnostics. Controller presentation generations prevent a stale completion from restoring progress or error state after a newer operation.
- **Tests added/updated:** Focused real-SQLite coverage includes self-contained zero-card install, representative 1/100/101/350 boundaries, multipage progress, short/duplicate/wrong-deck rejection, dirty local course reassignment, timeout preserving a prior package, superseded late completion, account switch, injected card-insert transaction rollback, clean retry after request failure, duplicate-tap coalescing, controller metadata sourcing, and removal superseding a download.
- **Tests run:** `dart format .` was attempted but encountered a transient missing generated `build/connectivity_plus` directory; all source and test Dart files were then formatted with `dart format lib test`, with unrelated formatter-only changes removed. `flutter analyze` completed with only the three pre-existing `home_tab_screen.dart` warnings and no new issues. `flutter test test/features/decks/offline_deck_service_test.dart test/features/decks/offline_controller_test.dart test/features/decks/offline_download_test.dart test/features/decks/reliable_deck_package_test.dart` passed (34 tests). Full `flutter test` ran: 877 passed and two unrelated existing `test/theme/app_tokens_test.dart` light-palette/accent assertions failed; no theme files are changed by this milestone.
- **Deviations from the original plan:** No architectural mismatch required a deviation. Per the implementation request's targeted-testing constraint, expensive 1,000/2,501/10,000-card fixtures were not added; paging behavior is covered at 0, 1, 100, 101, and 350 cards. No Android device run was performed in this code-only milestone.
- **Intentionally deferred:** All Milestone 3 offline read/refresh/removal coordination, connectivity-aware provider reads, session-start leases, confirmed-missing sync gating/cleanup, and automatic access/reconnect refresh remain unimplemented. Current-route UI controls/status remain Milestone 4, and Android process-kill/airplane-mode validation remains Milestone 5.

### Dependencies and not yet

Depends on M1. No new screen, OS download worker, automatic whole-library download, server revision system, or replacement result sync.

## Milestone 3 — Offline reads, refresh, and removal coordination

### Objective and rationale

Connect the persisted package guarantees delivered by M1 and the guarded full-package fetch delivered by M2 to the current deck/card/study reads. A complete local package must render and start study without waiting for Supabase, while bounded automatic refresh, removal suppression, targeted remote-missing confirmation, and sync gating remain race-safe.

### Verified M1/M2 baseline and corrected assumptions

- `OfflineDeckService` now exists and already owns targeted deck/course reads, full validated paging, deadlines, same-kind per-deck coalescing, account/operation generation checks, and atomic package install. M3 extends that service/coordinator; it does not introduce a second downloader.
- `LocalDeckStore` already persists `in_current_package`, `remote_missing`, and `cache_suppressed`; guarded removal and package commits already prevent a late service fetch from repinning a removed copy. Normal `CacheFirstDeckRepository.fetchCards`, however, still starts remote work for every read and can complete after its caller's timeout. M3 must route or suppress that write path explicitly rather than relying on `Future.timeout` cancellation.
- The existing service treats `pin: false` as a low-level package refresh, but it has no access/reconnect policy, active-session/startup lease, operation priority, commit publication, or remote-missing persistence. An automatic refresh must never supersede an explicit download/removal or make study startup await an in-flight network operation.
- Deck-list pruning already retains the M1 pin/suppression/remote-missing and most pending-work rows. Course pruning protects only parents of unsynced decks, and neither pruning policy completely states the active-session/queue parent requirements. M3 completes those predicates without treating list absence as targeted deletion confirmation.
- `SyncService` currently pushes all dirty decks, cards, sessions, and queue rows and counts all durable pending rows as attempted work. M3 must filter confirmed-missing parent chains while continuing to report those rows as pending, without classifying an otherwise successful pass as stalled merely because quarantined rows remain.

### Implementation scope

#### Native read routing

- Make `decksProvider`, `deckCardsProvider`, and `loadStudyDeckCards` consult the existing connectivity hint on native storage. When the hint is definitively offline, do not start a remote deck-list, card, or package request. Emit complete local `FlashCard` objects immediately; if no complete usable set exists, throw `DeckUnavailableOfflineException(deckId)` immediately. A verified zero-card package is successful local data, not unavailable data.
- When connectivity is unresolved or reports a link, retain local-first rendering and bound every remote operation. A timeout or failed reachability check is not proof of deletion and cannot erase or replace the local package.
- For an explicitly downloaded complete deck, separate the visible local read from background revalidation: return `LocalDeckStore.cards` immediately and trigger the shared package refresh without awaiting it. For incomplete/noncached native decks, keep the bounded online repository fetch. Preserve the current online-only path when SQLite is unavailable or on web.
- A suppressed deck may fetch and display online cards, but `CacheFirstDeckRepository` must check suppression before mirroring and again at commit through the existing store guard. It must not set coverage, membership, pin, or `downloaded_at`. Complete unpinned opportunistic caches remain usable under the existing contract when they have not been suppressed.

#### Access and reconnect refresh coordination

- Add one per-deck observation/access coordinator shared by Deck Detail, Card List, and pre-session consumers. The first eligible online observation starts at most one background refresh. A distinct offline→online edge starts at most one more refresh only while that deck has listeners. Provider invalidation caused by a successful commit is not a new access and must not start an invalidation/refresh loop. Reopening after the prior observation is disposed is a new access.
- Refresh only the observed deck; do not enumerate all pinned decks. Coalesce duplicate consumers and same-deck refresh requests. Do not add a timer, periodic scheduler, app-wide reconnect download, or manual-update dependency.
- Automatic refresh is eligible only for a complete explicitly saved package (including one marked `remote_missing`) with no suppression, no active local session, and no startup lease. Recheck these conditions before network work and inside the guarded state commit. A skipped or failed refresh leaves the committed package, pin, membership, metadata, and timestamp unchanged.
- Give operation kinds explicit priority: removal revokes stale fetches; an explicit download is never cancelled by an incidental automatic refresh; study startup synchronously acquires a short lease and supersedes/skips automatic refresh rather than waiting for its network future. A refresh that loses priority may finish its underlying request but cannot commit or publish.
- Publish card, deck-summary, package-status, explicit-membership, and grouped-deck changes once after an actual successful package/status commit. No-op, skipped, failed, superseded, and stale-account operations do not invalidate. Use a coordinator-owned commit event/version or an equivalent one-shot mechanism so refresh publication cannot retrigger itself.

#### Study startup

- Acquire the per-deck startup lease before the first awaited session-start mutation in both normal start and parked-card drill start. Hold it through local card selection and successful local session/queue creation; release it in `finally` on success, empty queue, or failure. Removal must reject while the lease is held, closing the gap before the persisted active-session row exists.
- If the package is complete, card loading and session creation use the existing local `FlashCard`, queue, mastery, and session repositories without awaiting Supabase or a background refresh. Sync and notification work remains fire-and-forget. Do not change mode selection, queue ordering, mastery, rating, parking, or completion behavior.

#### Removal and suppression

- Keep M1's transactional removal as the authority: it rechecks the startup/active-session guard, revokes older operations, clears pin/coverage/timestamp/current membership, sets suppression, and removes only discardable clean cards. Provider refresh after removal must be a local publication, not an implicit remote package read.
- Dirty cards/decks, tombstones, sessions, queue rows, queue/session-referenced cards, and required parent metadata remain durable. An already-running service refresh or ordinary repository read may return online display data but cannot recommit or repin after suppression. Only a later successful explicit download clears suppression.

#### Targeted remote deletion/access loss

- Only a successfully completed targeted `fetchDeck(deckId)` returning no visible row confirms remote missing/inaccessible state. An empty account list, missing course, zero card count, malformed package, auth error, timeout, transport error, or account change does not. Persist the result through an account- and operation-guarded local transaction so removal/account switching can supersede it.
- On confirmation, set `remote_missing` without changing the complete saved package, pin, parent metadata, cards, or pending work. Do not run an empty package commit, delete local data, create a deck tombstone, or recreate the remote deck. The saved package remains locally readable/studiable/removable.
- A later successful targeted deck lookup clears `remote_missing` in its own guarded status commit even if a subsequent course/card refresh fails; this is the evidence needed to resume normal sync. A successful full package commit also leaves the flag cleared. Publish either status transition once. Continue allowing one targeted retry on later eligible access/reconnect so a previously missing deck can be rediscovered.

#### Sync gating and retained-card cleanup

- Add local queries for confirmed-missing deck IDs and the session/card-to-deck relationships needed to filter sync payloads. Skip the missing deck's own upsert/position item and all descendant card-content, card-mastery, study-session, and session-card upserts. Unrelated rows continue through the existing foreign-key order and revision-safe acknowledgments. Deletion tombstones may retain their existing non-resurrecting behavior.
- Keep gated rows visible in the existing pending-work providers/counts and durable in SQLite. For sync outcome/backoff, compare attempted/eligible pending work separately from quarantined missing-parent work; a pass containing only intentionally gated rows is not a network/stall failure.
- After an exact existing revision acknowledgment, run a narrow idempotent SQLite cleanup for cards that are nonmembers, clean/synced, not tombstoned, and no longer referenced by an active or unsynced session/queue row. Recheck all predicates in the cleanup transaction. Never delete session records, dirty/tombstoned rows, active-session data, queue-dependent cards, or current package members. Publish reads only if cleanup actually changed visible/local state.

#### Metadata and list pruning

- Keep absence from general deck/course lists as cache-pruning information only, never as `remote_missing` evidence. Preserve deck and course rows required by an explicitly saved package, a startup/active session, dirty deck/card data, unsynced session/queue data, or deck/card tombstones. Preserve the locally authoritative parent of a pending re-course.
- When pruning truly discardable unprotected metadata, remove only corresponding clean unreferenced orphan cards in the same transaction or leave them for the same reference-aware cleanup. Do not broaden this into list pagination, cache quotas, or general eviction redesign.

### Files affected

- `lib/features/decks/application/deck_providers.dart`, `offline_providers.dart`, and the existing `offline_deck_service.dart`: connectivity-aware local reads, observed-deck coordinator, refresh priority/eligibility, guarded status commits, and commit publication.
- `lib/features/decks/domain/offline_download.dart`: startup lease/operation-priority state and any typed refresh outcome needed for one-shot publication.
- `lib/features/decks/data/cache_first_deck_repository.dart`, `local_deck_store.dart`: suppression-aware ordinary reads, remote-missing queries/status transitions, pruning protection, and retained-card cleanup.
- `lib/features/courses/data/local_course_store.dart`: preserve required pinned/protected course metadata during pruning.
- `lib/features/study/application/pre_session_cards_provider.dart`: immediate offline-unavailable path; reuse complete-card load.
- `lib/features/study/application/session_controller.dart`: acquire/release the package service's short startup lease around both card-load/session-creation paths; preserve engine and write ordering.
- `lib/features/study/data/local_study_store.dart`: only the narrow session/deck lookup or filtered-row support required to gate batched sync safely.
- `lib/core/sync/sync_service.dart`, `sync_providers.dart`: missing-parent filtering, eligible-vs-quarantined outcome accounting, post-ack cleanup, and commit-driven provider invalidation; preserve push/revision logic.
- `lib/core/local_db/mirror_scope_guard.dart`: invalidate newly introduced account-bound providers where necessary.
- Tests: `test/core/cache/immediate_read_providers_test.dart`; `test/features/decks/deck_providers_test.dart`, `cache_first_deck_repository_test.dart`, `reliable_deck_package_test.dart`, and new `offline_refresh_test.dart`; `test/features/courses/local_course_store_test.dart`; `test/features/study/pre_session_cards_provider_test.dart`, `session_controller_test.dart`; `test/core/sync/local_study_sync_test.dart`, `offline_chain_test.dart`, `revision_acknowledgment_test.dart`, `account_scope_sync_test.dart`; account-scope/provider tests only where the new coordinator requires them.

### Tests and edge cases

Keep fixtures focused and parameterize equivalent connectivity branches. At minimum prove:

1. A complete downloaded deck emits its local cards before a never-completing remote future and a definitively offline read makes zero remote calls.
2. Normal and parked-drill study entry create the local session/queue from complete local cards without awaiting Supabase, refresh, sync, or notifications.
3. A missing or incomplete native deck throws `DeckUnavailableOfflineException` immediately while definitively offline; a verified empty package returns an empty successful result.
4. Initial eligible online observation refreshes a downloaded deck once; Detail/Card List/pre-session consumers coalesce, and commit invalidation does not create a refresh loop.
5. Request failure, timeout, invalid page, course failure, and commit failure preserve the prior package and publish no false refresh success.
6. A persisted active session suppresses refresh. Startup acquires its lease before each await boundary, preempts an existing automatic refresh without waiting, blocks removal, and always releases on success/failure/empty queue.
7. Removal revokes a delayed refresh and a delayed ordinary mirror write; neither can restore pin, coverage, membership, timestamp, or clear suppression. Restart and incidental online viewing remain suppressed until explicit download.
8. One offline→online edge refreshes only the currently observed deck, coalesces duplicate consumers, and does not enumerate other pinned decks. Repeated online emissions and provider invalidation do not retrigger it.
9. An explicit download/removal has priority over incidental refresh, and same-account/switch-account/disposed late responses cannot commit or publish into the wrong scope.
10. Remote add/edit/delete converges on the next successful full refresh while dirty/tombstoned overlays remain authoritative; a protected clean deleted card is retained only as a nonmember and cannot enter a new session.
11. General deck-list absence and course-list absence do not set `remote_missing` or prune package/active/pending parent rows. Truly unprotected pruning does not leave unsafe orphan cleanup or delete referenced data.
12. Only a successful targeted null deck lookup sets `remote_missing`; zero cards is not missing, and timeout/network/auth/course/package failures leave the flag unchanged. Confirmation preserves the complete saved copy and local study/removal.
13. A later successful targeted deck lookup clears `remote_missing` even if the remaining refresh fails, publishes the status transition once, and permits the existing sync path on its next pass.
14. Confirmed-missing deck, card-content/mastery, session, and session-card rows make zero resurrecting upsert/position calls while unrelated work still syncs. Quarantined rows stay pending without causing false backoff/failure.
15. Post-ack cleanup runs only after revision-safe acknowledgment, is idempotent, and preserves current members, dirty/tombstoned rows, sessions, active/pending/queue references, and rows changed after the sent revision.
16. Native no-storage/web behavior remains online-only, and the existing opportunistic-cache read contract remains intact for unsuppressed decks.

### Acceptance criteria

- Deck Detail, Card List, pre-session mode selection, normal study start, and parked-drill start consume a complete local package immediately and do not initiate/await a doomed request while definitively offline.
- Eligible online access and observed-deck reconnect perform one coalesced background refresh with bounded network work. No refresh loop, whole-library reconnect fetch, periodic scheduler, active-session refresh, or study-start delay is introduced.
- A successful refresh publishes the atomically committed full package once and preserves pin plus protected local overlays. Every failure or superseded operation leaves the prior usable package unchanged.
- Remove offline copy remains authoritative across restart, provider invalidation, online viewing, and stale/in-flight work. Only explicit download can clear suppression and restore explicit availability.
- General list absence never confirms deletion. Targeted confirmed disappearance preserves package/metadata/pending work and local study/removal; targeted reappearance clears the flag and resumes normal synchronization.
- Sync never resurrects a confirmed-missing parent through deck or descendant upserts, quarantined work remains durable/pending without false failure accounting, and post-ack cleanup deletes only unreferenced discardable cards.
- Targeted M3 tests, `dart format .`, `flutter analyze`, and the full reasonably-fast Flutter suite complete with new failures distinguished from the existing theme baseline. Manual Android lifecycle/airplane-mode evidence remains M5.

### Non-goals / deferred work

Depends on M1–M2. Do not add Deck Detail/grid download controls or saved-copy notices (M4), Android process-kill/airplane-mode acceptance evidence (M5), dashboard/history/profile offline work, loading-screen redesign, manual Update UI, whole-library/background/periodic refresh, OS jobs, guest offline login, server revision/snapshot APIs, a new sync engine, cloud-deck recreation, or general missing-parent conflict/export recovery. Do not change the study algorithm, modes, queue/mastery/session semantics, card models, or unrelated account-list pagination and cache-eviction behavior.

### Implementation Status

- **Status:** Implemented and verified on 2026-09-09. Milestone 3 is complete; no Milestone 4+ work was started.
- **Important correction:** M3 now treats the existing M2 service as the base, gives study startup and explicit operations priority over automatic refresh, specifies one observed-deck access/reconnect coordinator with commit-only publication, defines guarded set/clear semantics for `remote_missing`, separates quarantined from eligible sync accounting, and includes the previously omitted study-store/sync-provider/course-pruning test surface.
- **Files changed:** `lib/features/decks/application/deck_providers.dart`, `offline_providers.dart`, `offline_runtime_providers.dart`, and `offline_deck_service.dart`; `lib/features/decks/domain/offline_download.dart`; `lib/features/decks/data/cache_first_deck_repository.dart` and `local_deck_store.dart`; `lib/features/courses/data/local_course_store.dart`; `lib/features/study/application/pre_session_cards_provider.dart` and `session_controller.dart`; `lib/features/study/data/local_study_store.dart`; `lib/core/sync/sync_service.dart` and `sync_providers.dart`; `lib/core/local_db/mirror_scope_guard.dart`; the Deck Detail, Card List, and pre-session study route consumers; and focused deck/study/sync/local-database tests. The M1/M2 schema/repository files already present in the working tree remain part of their earlier milestones.
- **Important implementation decisions:** Complete packages are returned from SQLite before any refresh; definitively offline native reads make no remote call and use `DeckUnavailableOfflineException` for incomplete/unavailable packages. A shared per-deck observation coordinator owns initial-access and offline-to-online refresh edges, and route-level observation leases keep commit-driven provider recomputation from becoming a new access. Automatic refresh uses the M2 downloader, is coalesced and lower priority than download/removal/startup, rechecks package/session/lease eligibility before its guarded commit, and publishes only actual package/status/removal/cleanup commits. Removal suppression is checked before and at ordinary mirror commit. Only targeted deck lookup results set/clear `remote_missing`. Sync snapshots confirmed-missing parents, excludes their descendant upserts from eligible work, and runs revision-safe, reference-aware retained-card cleanup after acknowledgements.
- **Tests run:** `dart format .`; `flutter analyze --no-pub` (no M3 errors; three pre-existing `home_tab_screen.dart` unused-declaration warnings); focused M3/provider/repository/session/sync suites (111 passing in the combined run, followed by the updated reconnect-focused run); and the full `flutter test --no-pub` suite (892 passing, with only the two pre-existing `test/theme/app_tokens_test.dart` palette expectation failures).
- **Deviations from plan:** No functional scope deviations. The observation lifetime is held explicitly by Deck Detail, Card List, and the pre-session route in addition to provider dependencies so a successful commit cannot momentarily dispose/recreate the coordinator under load. Full-suite green status remains blocked only by the unrelated pre-existing theme-token expectations noted above.
- **Deferred work:** Milestone 4 download/remove controls and saved-copy notices; Milestone 5 Android process-kill, airplane-mode, lifecycle, and remote-deletion manual evidence; and every Phase 2 non-goal listed above, including whole-library/background scheduling and unrelated offline dashboard/history/profile work.

## Milestone 4 — Current-route download/remove controls and status

### Objective and rationale

Expose the functionality where users actually open a deck, without bringing back the old overview or redesigning the screen.

### Changes and UI

Add Download/Remove entries to the existing Deck Detail overflow. Preserve Edit/Delete as separate actions. Show a compact deck-specific progress/status row and an “Available offline” indicator on detail and current grid tiles. Hide actions for unavailable storage/web; disable download offline, handle busy/status-loading correctly, allow safe local removal offline. Reuse the current confirmation/progress conventions from `OfflineToggle`, extracting a small shared presentation component only if needed. Use actionable error copy and the offline-unavailable state on detail/card-list/study direct entry. Display confirmed-missing saved-copy notice. No storage changes.

### Files affected

- `lib/features/decks/presentation/deck_detail_screen.dart` (`_DeckAction`, current menu and error state).
- `lib/features/decks/application/decks_tab_view.dart` (`DeckTileView` explicit availability).
- `lib/features/decks/presentation/widgets/deck_grid_tile.dart`, `deck_grid.dart` (compact status and layout sizing).
- `lib/features/decks/presentation/widgets/offline_toggle.dart` (reuse/extract existing presentation as needed; no new business logic).
- `lib/features/decks/presentation/card_list_screen.dart`, `lib/features/study/presentation/study_session_screen.dart` (typed unavailable copy only where absent).
- `test/features/decks/deck_detail_screen_test.dart`, `deck_grid_tile_test.dart`, `decks_tab_view_test.dart`, `offline_toggle_test.dart`, `card_list_screen_test.dart`; `test/routing/app_router_test.dart`.

### Tests / edge cases

Navigate through the actual registered route and download/remove; controls available when card body fails or is empty; pin restore loading not shown as a false cloud-only state; operation for A never shows progress/error on B; double taps; offline removal confirmation; active-session rejection; pending changes wording; success only after commit; no cloud Delete call; narrow widths and large text; web/null store hides actions; offline direct links show actionable copy.

### Acceptance criteria

A user can perform the intended flow using the current Decks tab and Detail screen, with durable status visible on return/restart. No new management screen or overview route is introduced. Download and cloud deletion are unambiguous and independently tested.

### Implementation Status

- **Status:** UI implemented on 2026-09-09.
- **Files changed:** Deck Detail, Decks-tab view/grid tile, OfflineToggle presentation, Card List, study entry, and the existing offline presentation/controller model; focused deck/routing tests.
- **Important UI/wiring decisions:** The current Detail overflow now keeps Download for offline use / Remove offline copy distinct from Edit / Delete. Detail status and grid badges read persisted explicit availability; transient progress and controller feedback are filtered by deck ID. Local removal confirms that the cloud deck remains unchanged and that pending work is retained. Unsupported web/no-storage environments hide the controls.
- **Focused tests run:** `dart format .`; the specified focused deck widget/routing suites (passing). `flutter analyze --no-pub` was started but did not return before the local command window elapsed.
- **Deviations:** None.
- **Deferred work:** Milestone 5 Android process-kill, airplane-mode, lifecycle, and manual verification.

### Dependencies and not yet

Depends on M1–M3. Do not redesign the mode picker, card content, completion view, global offline banner, or sync chip. Do not add manual update controls or rewire obsolete screens for cosmetic consistency.

## Milestone 5 — Restart, airplane-mode study, and regression verification

### Objective and rationale

Prove the entire promise on durable SQLite and Android, beyond mocked download success or tests against the obsolete overview.

### Changes, files, and storage/UI impact

Tests and recorded evidence only unless a failing acceptance case requires a scoped fix in earlier milestone files. Add `test/features/decks/offline_deck_restart_test.dart` and, if the current tooling supports device integration tests, `integration_test/explicit_offline_deck_test.dart`. Use `test/support/local_db_harness.dart` with a named on-disk database, dispose/recreate ProviderContainers and close/reopen SQLite. Extend `test/features/decks/offline_launch_test.dart`, `test/features/study/local_first_study_modes_test.dart`, `local_first_study_repository_test.dart`, and `session_write_order_test.dart`. No new production storage or UI behavior.

### Tests and acceptance criteria

Execute the automated matrix and manual Android sequence below. All three study modes start, progress, park/requeue where applicable, and complete offline with durable local session/mastery/queue data. Reconnect produces existing idempotent synchronization for an extant cloud deck. Completed download survives process death; failed download does not become available. Clean removal deletes package content, protected removal retains only required work, and cloud deck/cards remain present. Record actual outcomes and unresolved failures; do not infer Android durability from unit tests alone.

### Dependencies and not yet

Depends on M1–M4. No exact timer/queue restoration project, new sync infrastructure, benchmarking project, or unrelated lint/UI cleanup. A failed core acceptance case blocks Phase 2 completion.

### Implementation Status

- **Status:** Awaiting manual Android verification (2026-09-09).
- **Automated verification:** Added named on-disk SQLite lifecycle coverage for complete-package/provider recreation, failed incomplete package restart, clean removal restart, and protected pending-study removal restart. Focused M5 tests passed (16 tests), including existing Flip/Cloze/Feynman offline completion, local write ordering, idempotent reconnect, and confirmed-missing-parent quarantine coverage.
- **Production fixes:** None; no Phase 2 acceptance bug was found.
- **Full-suite result:** `dart format .` completed with no changes. `flutter test --no-pub` was launched after focused success, but this environment did not retain the command's final summary after the output window closed; do not treat it as a recorded pass. `flutter analyze --no-pub` has no errors, with four pre-existing diagnostics (one redundant import and three Home-screen warnings).
- **Phase 2 DoD:** PASS — registered controls/persisted availability, package integrity, local study engine/store/result-sync path, removal protection, refresh/missing-parent behavior, and automated acceptance coverage. MANUAL VERIFICATION REQUIRED — Android kill/airplane-mode/restart/navigation/study/reconnect/removal/account-switch matrix. FAIL — none observed.
- **Android checks still required:** On a signed-in Android test account, perform steps 1–12 in **Manual Android Verification**: successful download then force-stop/airplane-mode restart and card viewing; Flip/Cloze/Feynman completion; offline-route failure states; reconnect/idempotent cloud session verification; interrupted/multipage download; refresh/edit behavior; active/protected/clean removal; remote-deleted saved copy; and account switching. Record device, build commit, deck/card IDs, and results.
- **Blockers:** No product blocker. Phase 2 must remain awaiting manual verification until the Android matrix and a captured full-suite result are recorded.

## Full Testing Strategy

Extend existing tests rather than replace them. Existing coverage includes `offline_controller_test.dart` paging/progress/rollback, `reliable_deck_package_test.dart` dirty/tombstone/retention checks, `offline_launch_test.dart`, local-first study-mode tests, and revision/account sync tests. Update removal expectations deliberately where M1 adds active-session rejection. Preserve a separate test of retention for completed but unsynced sessions.

| Layer | Required proof |
| --- | --- |
| Unit/service | Page validation, deadline/retry, operation identities, same-deck coalescing, metadata selection, unavailable-state mapping. |
| Real SQLite repository | Atomic install/rollback, v8 parity, complete vs partial/empty, dirty overlays, membership, removal suppression, owner isolation, close/reopen persistence. |
| Provider | Local values with never-completing remote futures, known-offline skip, commit-driven status updates, refresh/removal races, observed-deck reconnect. |
| Widget/routing | Current Detail overflow, status/progress, grid badge, offline errors, storage capability, confirmation distinctions, responsive layout. |
| Study/sync regression | Flip/Cloze/Feynman offline start through completion, queue drain ordering, pending writes survive removal, idempotent reconnect, no deleted-parent resurrection. |
| Android | Process kill during fetch/after commit, airplane-mode cold launch, actual navigation/card rendering/study completion, cloud unchanged after removal. |

Required fixtures: normal deck with all modes; valid empty deck; 100/101-card page boundary; 2,501-card deck exceeding normal server page size; 10,000-card stress deck; missing course/header; partial cache; dirty card/deck; queue-only unsynced row; shared course; remote-deleted protected card; confirmed-missing cloud deck.

For large downloads, compare actual card IDs/fields with the remote fixture, not just UI count. Exercise SQLite bind-variable limits: current deletion SQL creates one placeholder per remote ID. Replace that package cleanup query with a transaction-local membership marking/deletion approach if necessary; do not ship a 10,000-card failure or add a second store. Measure foreground memory/responsiveness; request sizes alone do not bound the accumulated in-memory payload.

Fault injection must include network exceptions and never-completing futures, late completions after timeout/removal/account switch, commit insertion failure, interrupted replacement of an existing package, retry after failure, and course/deck edits between metadata/page reads. Test same-count remote edits on the **next** refresh; record the lack of server snapshot isolation rather than asserting an unsupported guarantee.

Suggested implementation verification commands (not run for this documentation-only turn):

```text
flutter test --no-pub test/core/local_db test/core/cache test/features/decks test/features/study test/core/sync test/routing
flutter test --no-pub
flutter analyze --no-pub
flutter build apk --debug --no-pub
```

Run focused milestone tests during implementation, then the full suite once for the completed integration. Prior documentation reports three existing Home warnings; verify the actual baseline and distinguish it from new issues. Do not treat a historical pass count as current validation.

## Manual Android Verification

Use a test account already signed in online. Record build commit, device/Android version, deck IDs/counts, app lifecycle action, local database observations, and cloud verification. Never clear app data as a substitute for restarting.

1. Open a normal deck from the current Decks tab. Choose Download for offline use. Observe progress, then Available offline on detail and grid. Verify course/title and every card type's content.
2. Force-stop the app after success. Enable airplane mode with Wi-Fi also off. Relaunch with the same restored account; navigate to Decks without requiring successful Home network data. Verify title/course/badge and View cards count/content/order.
3. Start Flip and complete it; repeat with Cloze and Feynman fixtures. Exercise rating, keyword entry, timer/reference behavior, requeue/parking, and completion. Inspect persisted sessions, queue rows, mastery/fail values, last-studied time, and pending flags. No Supabase response may be needed.
4. Open a known metadata-only deck and a direct card/study route offline. Verify prompt to connect/download, no endless spinner, and no misleading empty deck.
5. Reconnect. Let existing sync finish, verify exactly one matching UUID session per completion and correct cloud data. Open a downloaded deck online to refresh it.
6. Download a multipage deck, disable network mid-download; retry online. Repeat with force-stop mid-download and restart offline. Neither failed attempt may create a new available badge; a preexisting copy must still work after interrupted refresh.
7. Download the 2,501-card and 10,000-card fixtures. Verify all IDs and content, progress, reasonable memory/UI responsiveness, and offline restart. Include cards sharing creation timestamps.
8. Download a deck, edit its name/course and add/edit/delete cards remotely while this device is offline. Reconnect with that detail visible, or reopen it online if not visible. Verify the chosen access-triggered refresh, dirty local edit protection, and revised content on the next offline restart. Repeat with a failed refresh and confirm the old copy survives.
9. Attempt removal during an active session: verify rejection and that offline study can still finish. Exit/complete, then remove offline while work remains unsynced. Verify pin/coverage cleared, required pending data retained, and discardable cards removed. Restart and confirm the package stays unavailable.
10. Reconnect after removal. Verify cloud deck and cards still exist, pending results sync, and viewing online does not silently restore the removed copy. Download explicitly again and verify availability returns. Repeat clean removal after all work is synced to prove discardable local cards are actually deleted.
11. Delete a downloaded test deck remotely. Verify successful targeted confirmation shows a saved-copy notice, local copy remains usable/removable, and reconnect does not recreate the cloud deck. Record that new study data for a missing cloud deck stays local/pending.
12. Test account switch during download and same-account cold launch with an expired network token. No previous-account rows/badges may appear. Confirm web and simulated database-open failure retain online-only behavior without offline actions.

## Risks and Decisions to Review Before Implementation

- **Saved copy after remote deletion:** proposed retention allows local study while results cannot sync to a missing cloud parent. No silent data loss or resurrection; recovery/export is deferred. Confirm this product policy before implementation if different behavior is desired.
- **Removal semantics:** intentionally suppress incidental caching until another explicit download. This small persistent preference is stronger than current behavior and necessary for predictable removal. Shared metadata and pending work are retained, not falsely promised as erased.
- **Active session removal:** reject removal until finish/exit. This avoids expanding Phase 2 into a session write-authority redesign; it is enforced below UI, including a race with session start.
- **Snapshot consistency:** current schema has no deck-content revision. Full page validation is reliable for completeness checks but cannot provide a transactionally consistent server snapshot during concurrent same-count edits. Strict snapshot requirements would change scope.
- **Migration membership backfill:** v7 cannot identify every legacy protected extra. Preserve data, then repair on the next full refresh. Do not erase otherwise working packages on upgrade.
- **Large decks:** accumulated memory and SQLite placeholder limits must be tested; metadata aggregate counts from nested list queries are not download completeness evidence.
- **Auth/reachability:** restored local authentication is required. Captive Wi-Fi and expired tokens must fail refresh safely without erasing offline data. Android cold-start behavior needs device evidence.
- **Shared data paths:** changes must not regress opportunistic caching, offline authoring, dirty-card conflict handling, account isolation, or no-storage operation. Timestamp/revision checks in existing sync remain mandatory.

These are concrete proposed decisions, not reasons to reimplement Phase 1. No major new study-result synchronization infrastructure is required. The only sync extension is protecting confirmed-missing parents and cleaning now-discardable retained cards.

## Deferred Work

Web offline storage/service workers; media downloads until card media exists; OS background/resumable download jobs; exact interrupted-session queue/timer restoration; server snapshot/revision APIs; full missing-parent conflict recovery/export; general cache quotas/eviction; account-wide refresh scheduling; all unrelated roadmap items listed under Non-goals.

## Phase 2 Definition of Done

- Current registered Deck Detail exposes working download/remove actions and current grid/detail show persisted explicit availability.
- A successful package contains actual deck/course metadata and the complete effective card set; partial/failed/stale operations never produce false availability.
- Download → kill → airplane mode → restart → view cards → start/progress/complete study passes on Android.
- The same card models, study engine, SQLite store, and existing result-sync mechanisms are used online/offline.
- Removing a copy cannot delete cloud data, lose pending work, break an active local session, or be reversed by stale/automatic cache writes.
- Automatic refresh on eligible access/reconnect of the viewed deck behaves as documented; failed refresh preserves the prior copy, and remote deletion follows the explicit saved-copy policy.
- Migration, repository/provider/widget/study/sync tests and manual Android evidence satisfy the acceptance matrix, with no newly introduced analysis errors or scope expansion.

Implementation dependency chain: **M1 → M2 → M3 → M4 → M5**. Add focused tests within each milestone; M5 supplies end-to-end evidence rather than postponing testing until the end.
