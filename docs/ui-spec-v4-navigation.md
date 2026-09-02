# ActiveRecall — UI Revamp Spec (v4): Navigation restructure

## 0. Status & relationship to other specs

This is the third presentation-layer revamp, on top of:

- `docs/ui-spec-v1.md` — routing shell, glass nav bar, visual tokens (`AppTokens`,
  8 accent pairs), the four original tabs (Decks / Mastery / Profile / Settings).
  **Still the source of truth for the token system, the glass nav bar mechanics,
  and every screen this doc doesn't touch.**
- `docs/ui-spec-v2.md` — Decks tab course accordion, deck/course write path.
  **Unchanged by this doc.**
- `docs/ui-spec-v3-design-language.md` — typography (Fraunces/sans pairing),
  component theming, motion. **Unchanged and binding.** This revamp is a
  restructure of *what tabs exist and what's on them*, not a new visual
  language — every new screen in this doc is dressed in v3's existing tokens,
  type ramp, accent pairs, and glass nav bar, not the flat/plain style of the
  reference wireframes in `docs/wireframe/` (those wireframes are content/layout
  sketches only; see §1 and the published canvas linked there for the restyled
  direction).

**What this revamp changes:** the four shell tabs go from
**Decks / Mastery / Profile / Settings** to **Home / Decks / History / More**.
`Decks` is unchanged. `Mastery`, `Profile`, and `Settings` are retired as
top-level tabs; their content is redistributed onto `Home`, `History`, and
`More` as detailed below. `Settings` (the screen) keeps existing as a pushed
route, reachable from `More`.

Milestones here are **U16–U19**, executed one per session per `CLAUDE.md`.

---

## 1. Reference wireframes

`docs/wireframe/home-view.png` and `docs/wireframe/decks-view.png` are the
original low-fi references (Decks unchanged from what's already shipped). A
flat/plain History + More content sketch — layout and structure only, **not**
the visual treatment to build — lives at
<https://claude.ai/code/artifact/0162554b-22e6-450d-814c-b49cb7e241da>
(source `.dc.html` files under `docs/wireframe/canvas-src/`). Content and
layout structure (what's on each screen, in what order) come from the
wireframes and that sketch; visual treatment (color, type, elevation, radii)
comes from v3 tokens, never from the sketch's flat/plain rendering or its
indigo/teal accent-color exploration (v3's existing 8 accent pairs govern
color).

---

## 2. Routing changes

`StatefulShellRoute.indexedStack`, branch order and paths:

| # | Path | Old (v1/v2) | New (this doc) |
|---|---|---|---|
| 0 | `/home` | — (didn't exist) | **New.** `HomeTabScreen`. Becomes the shell's default branch. |
| 1 | `/decks` | `DecksTabScreen` | Unchanged. |
| 2 | `/history` | `/mastery` → `MasteryTabScreen` | **New.** `HistoryTabScreen` replaces Mastery. |
| 3 | `/more` | `/profile` → `ProfileTabScreen` | **New.** `MoreTabScreen` replaces Profile. |

- `/settings` **stops being a shell branch** (was branch 3, had its own bottom-tab
  slot). It becomes a normal pushed route, reached only from a row inside
  `MoreTabScreen`. `SettingsScreen` itself is unchanged — same widget, same
  providers, just a different entry point (`context.push('/settings')` instead
  of a tab).
- The `/` splash redirect target changes from `/decks` to `/home`.
- `GlassBottomNavBar` gets four new icon/label pairs: Home (house outline),
  Decks (unchanged), History (clock outline, replacing Mastery's icon), More
  (the existing overflow/menu icon already used elsewhere in the app if one
  exists, else a new one) — drawn in the app's existing icon stroke style, not
  the wireframe's icon set.
- `ScaffoldWithNavBar`'s branch-order doc comment and the `_settingsBranchIndex`
  special-case (used to skip the branch-transition slide animation for
  Settings, per its own doc comment) go away with the Settings branch;
  re-verify whether any other index-based special-casing in that file assumed
  4 branches in the old order.

---

## 3. Home tab (`/home`, `HomeTabScreen`)

New screen, new file `lib/features/home/presentation/home_tab_screen.dart`
(new `home` feature folder — `presentation/`, `application/` for its new
providers).

Content, top to bottom (wireframe order):

1. **Greeting header** — "Hello, {name}" + a static subtitle line, plus the
   avatar already rendered by `ProfileIdentityHeader` reused here (or a shared
   small `Avatar` widget extracted from it if `ProfileIdentityHeader` is too
   coupled to the full Profile layout — decide while implementing, keep it
   DRY, don't fork the avatar rendering).
2. **Overall Mastery card** — reuses `OverallMasteryCard` widget and
   `overallMasteryProvider` verbatim (both already exist, currently rendered
   on Mastery).
3. **Unfinished Sessions** — horizontal scrolling list of in-progress
   sessions. **New**: `activeSessionsProvider`
   (`lib/features/home/application/home_providers.dart`) queries
   `study_sessions` where `status == SessionStatus.active`, joined to deck
   name (via `decksProvider`) and percent-complete. Percent-complete uses the
   same mastered/total math `SessionController` already computes mid-session
   (`session_controller.dart`) — extract that into a shared pure function if
   it isn't already one, rather than reimplementing it. Card shows deck name +
   `{percent}%`; **"See all" link** — out of scope for U16, stub it as
   disabled/hidden until a destination screen is speced (don't build a screen
   with nowhere to go).
   Tapping a card resumes that session: `context.push('/study/${deckId}')`
   with the existing resume behavior `StudySessionScreen` already has for an
   `active` session on that deck (confirm it does; if resuming isn't wired
   today, that's a gap this milestone must close, not skip).

   > **U17 as built.** There is no persisted session-queue state to resume —
   > `SessionController` holds the resumable state in memory only, and a
   > `session_cards` row is never rewritten when its card is mastered, so
   > mid-session progress cannot be reconstructed from the table. So:
   > `StatsRepository.fetchActiveSessions()` (new; local-mirror fallback like
   > `fetchDeckRunThroughs`) reads the `active` `study_sessions` rows and, per
   > session, joins `session_cards` to each card's **live** `cards.mastery_level`
   > — a card counts as done when it is at/above `masteredLevel` or parked.
   > `percentComplete = mastered / total`, rounded. Tapping a card pushes
   > `/study/:deckId` with the session's mode as `extra`; the study route
   > already always runs until-mastered over the whole deck, and the
   > session-conflict rule retires the stale `active` row — so "resume" re-queues
   > the deck's still-unmastered cards in that mode. No study-path or engine
   > change; the join is read-only and only runs while Home is open.
4. **Most Reviewed Decks** — stacked-card carousel. **New**:
   `mostReviewedDecksProvider` — decks ordered by session count (recency
   secondary), sourced from the same local data `deckRunThroughsProvider`
   already aggregates (extend rather than duplicate the query). Each card:
   course code + underline (accent-paired to the course), deck name, "View
   Deck" button → `/deck/:deckId`, card count.

   > **U17 as built.** `deckRunThroughsProvider` only counts whole-deck
   > (`card_scope = 'all'`) clears, so ordering needs a broader signal:
   > `StatsRepository.fetchSessionCountsByDeck()` (new; sibling of
   > `fetchDeckRunThroughs` without the scope filter) gives the completed-session
   > count per deck across all scopes. `mostReviewedDecksProvider` sorts decks by
   > that count desc, ties broken by `lastStudiedAt` desc, capped at 6. There is
   > no separate course *code* in the schema — the card's "code" line is the
   > course **name**, upper-cased, over an accent underline. Rendered as a real card stack
   (z-order + slight offset + rotation, matching the wireframe's layered
   look) using v3's card tokens (radius, accent-pair border, no hard drop
   shadow — v3 explicitly bans `BoxShadow`).

`CourseRollupStrip`, `DeckCompletionsSection`, and `ActivityFeedSection` (all
currently on Mastery) do **not** move to Home — they move to History (§4).

---

## 4. History tab (`/history`, `HistoryTabScreen`)

New screen, new file `lib/features/stats/presentation/history_tab_screen.dart`
(replaces `mastery_tab_screen.dart` in the `stats` feature — same feature
folder, new screen name; `MasteryTabScreen` is deleted, not kept dead-code).

Content, top to bottom:

1. **Calendar heatmap** — month grid, each day shaded by that day's study
   activity. **New**: `dailyActivityProvider`
   (`lib/features/stats/application/stats_providers.dart`) groups completed
   `study_sessions` (or the local session log, whichever `recentActivityProvider`
   already reads from) by calendar day and buckets into an intensity level.
   This is a genuinely new query — no existing provider computes per-day
   totals. Month navigation (prev/next chevrons) is in scope; only the current
   and past months have data, future months render empty.
2. **All / By Deck segmented toggle** — filters the session list below.
   "By Deck" groups using the same course/deck grouping `courseSummariesProvider`
   already provides; "All" is today's flat chronological order.
3. **Session log list** — reuses `recentActivityProvider` (backs today's
   `ActivityFeedSection`) and the deck-completion data
   (`deckCompletions`/`DeckCompletionsSection`), merged into one row list:
   deck name, mode + card count, relative time, mastery delta. Each row's
   left accent bar uses that deck's course accent-pair color (v3 tokens), not
   the wireframe's flat hex.

`CourseRollupStrip` — decide while implementing whether it's dropped (its
information is now implicit in the By Deck grouping) or kept as a compact
strip above the segmented control; default to dropping it unless it's clearly
missed, per YAGNI.

---

## 5. More tab (`/more`, `MoreTabScreen`)

New screen, new file `lib/features/settings/presentation/more_tab_screen.dart`
(lives in the existing `settings` feature folder since it's mostly a settings
entry point, not a new feature).

Content, top to bottom:

1. **Profile block** — identity only: avatar, name, email, chevron (chevron
   currently has nowhere to go — either wire it to an edit-profile flow if one
   already exists, or drop the chevron until one is speced; don't add a dead
   affordance). `ProfileStatsRow` and `ProfileMetricsSection` (streak/mastery
   stat blocks, currently on Profile) are **retired**, not moved — their data
   now lives on Home's Overall Mastery card and History's log, and the
   wireframe's More screen doesn't repeat them. Confirm with a quick look that
   nothing else depends on those two widgets before deleting.
2. **Account group** — "Edit profile" (same caveat as the chevron above — only
   include if a destination exists) and **Sign out**, using
   `accountActionsProvider` exactly as `SignOutButton`/`ProfileTabScreen` do
   today (reuse that button widget, don't reimplement sign-out).
3. **Preferences group** — "Notifications" and "Study preferences" rows. Since
   `SettingsScreen` is one flat `ListView` (not split into deep-linkable
   sub-routes), **both rows push the same `/settings` route** — no new
   sub-routing. (If this feels wrong once the two screens sit side by side,
   splitting `SettingsScreen` into sub-routes is a follow-up, not part of
   U16–U19.)
2. **Data group** — "Offline sync" (status text, read-only — check
   `is_synced`/dirty-flag surface for a suitable read, e.g. a count of
   unsynced rows or a simple "Up to date"/"Syncing…" state) and "Export /
   import cards" → existing `/import-cards` flow if one exists at that route,
   else push `/settings` as a fallback (confirm the actual route while
   implementing).
3. **About group** — "Help & feedback" (reuses `SettingsScreen`'s existing
   feedback dialog logic — extract it to a shared function rather than
   duplicating the `AlertDialog`) and "Version" (reuses `appVersionProvider`).
   "Delete account" (danger zone) **stays inside `SettingsScreen`**, not
   duplicated on More — this is destructive-account-deletion territory and
   the existing single-entry-point-with-confirmation stays as the only path.

---

## 6. Testing

- Delete/rewrite the existing `MasteryTabScreen` and `ProfileTabScreen` widget
  tests against `HistoryTabScreen`, `HomeTabScreen`, and `MoreTabScreen`.
- New pure-logic tests: `activeSessionsProvider`, `mostReviewedDecksProvider`,
  `dailyActivityProvider` — all fakeable against the existing fake
  repositories, no real Supabase/SQLite needed (mirror the pattern the
  existing `stats_providers` tests already use).
- A routing test confirming the four branches are `/home /decks /history
  /more` in that order, `/settings` is reachable but not a branch, and the
  splash redirect lands on `/home`.

---

## 7. Milestones

| # | Scope | Done when |
|---|---|---|
| **U16** | Routing shell change (§2): new branches, `ScaffoldWithNavBar` branch-order updates, nav bar icons, splash redirect. Stub `HomeTabScreen`/`HistoryTabScreen`/`MoreTabScreen` as empty placeholders so the shell compiles and is navigable. Old `/mastery`/`/profile` routes and their screens removed. | App launches on Home, all four tabs switch correctly, `/settings` opens by direct navigation (no UI yet), `flutter analyze` clean, `flutter test` green. |
| **U17** | Home tab (§3): `activeSessionsProvider`, `mostReviewedDecksProvider`, full `HomeTabScreen` layout, resume-session tap-through. | Home renders greeting, mastery card, unfinished sessions (tapping resumes), most-reviewed deck stack (tapping opens deck detail); tests for both new providers green. |
| **U18** | History tab (§4): `dailyActivityProvider`, calendar heatmap widget, All/By Deck toggle, merged session log. | History renders a real calendar heatmap from local data, toggle filters the log correctly, tapping a log row behaves like the old activity feed did; provider tests green. |
| **U19** | More tab (§5): profile block, grouped rows pushing into `/settings`, retirement of `ProfileTabScreen`/`ProfileStatsRow`/`ProfileMetricsSection`. | More renders profile + three grouped sections, every row either navigates correctly or is omitted per §5's caveats, sign-out works, old Profile screen and its now-unused widgets are deleted, `flutter analyze` clean, `flutter test` green. |

U16 must land first (everything else needs the shell). U17–U19 can be done in
any order relative to each other once U16 is in.
