# ActiveRecall — Build Order

17 numbered milestones plus several lettered revamp series, in dependency order — each assumes the ones above it work. Use these as your GitHub issues, same as Synapse. Point Claude Code at exactly one per session (see the loop in CLAUDE.md / our planning chat).

Milestones 1–14 are v1 / Beta. Milestones 15–17 are **Engine V2** — see `docs/engine-v2-spec.md`. The lettered series (A–E, UX4–UX6, O1–O4, U16–U19) are post-v1 revamps specced in their own docs.

## Status — all shipped ✅

Every milestone below is complete and on `main` as of the U16–U19 navigation revamp (commit `2b0aefc`, 2026-09-02). `flutter analyze` is clean and `flutter test` is green (636 passing).

| Series | Milestones | Spec | Status |
|---|---|---|---|
| v1 / Beta | 1–14 | `docs/spec.md`, `docs/ui-spec-v1.md` | ✅ Done |
| Engine V2 | 15–17 | `docs/engine-v2-spec.md` | ✅ Done |
| Offline & UX polish | A–E (incl. E1–E3) | planning spec (commit `9c67167`) | ✅ Done |
| Editorial UI revamp | UX4–UX6 | `docs/ui-spec-v2.md`, `docs/ui-spec-v3-design-language.md`, `docs/spec-v5-dark-mode.md` | ✅ Done |
| Offline-first authoring | O1–O4 | `docs/spec-v4-offline-authoring.md` | ✅ Done |
| Web MVP | (unnumbered) | `docs/spec-web-mvp.md` | ✅ Done |
| Navigation restructure | U16–U19 | `docs/ui-spec-v4-navigation.md` | ✅ Done |

The only work left is **milestone 14's remaining beta-logistics items** — a signed release APK and a real feedback-form URL to replace the "coming soon" placeholder in the More tab's "Help & feedback" dialog. Both need input outside the codebase (signing keystore, the form link).

---

**1. Repo + scaffold** ✅
- Scope: Flutter project created, Supabase project created (your manual step — account + keys), basic navigation shell with stub screens (Splash → Login → Deck Library), `docs/spec.md` + `CLAUDE.md` + Flutter `.gitignore` committed
- Spec refs: none specific — this is infrastructure
- Done when: `flutter run` launches a blank app that navigates between empty Splash/Login/Deck Library screens, and the repo contains `docs/spec.md` and `CLAUDE.md`

**2. Database** ✅
- Scope: all 5 tables (`profiles`, `decks`, `cards`, `study_sessions`, `session_cards`), the `profiles`-auto-creation trigger, `updated_at` triggers, RLS policies (including the join-based ownership on `cards`/`session_cards`), indexes
- Spec refs: "Data Model (Schema)"
- Done when: all 5 tables exist in Supabase's table editor, a test signup auto-creates a matching `profiles` row, and a second test user's RLS-scoped query cannot see the first user's decks

**3. Auth** ✅
- Scope: signup / login / logout, forgot password
- Spec refs: §1
- Done when: you can sign up, get logged in, log out, and log back in on a real device or emulator

**4. Deck Library + Deck Creator** ✅
- Scope: deck list + create-deck flow, unified card model (front/back/keyword), manual entry, bulk paste with `{{keyword}}` extraction, live preview, edit/delete
- Spec refs: §2, §3
- Done when: you can create a deck, add cards both manually and via bulk paste (including one with a `{{keyword}}`), and see them stored with the correct front/back/keyword split

**5. Deck Overview** ✅
- Scope: mode buttons filtered to what the deck actually supports, session-length toggle (presets), Troublemaker Cards, empty states
- Spec refs: §4
- Done when: mode buttons only appear for modes the deck has qualifying cards for, and the session-length toggle shows fixed presets

**6. Session engine + Flip mode** ✅
- Scope: session creation (`study_sessions` + `session_cards`), mode-filtered queue building, sparse `position` values, requeue-on-fail, park-after-3-consecutive-fails, `mastery_level` translation for Flip, session-conflict rule (new session abandons old active one)
- Spec refs: §5 (5A + shared mechanics), §6, schema
- Done when: on a small test deck, a failed card correctly requeues, gets parked after 3 consecutive fails, and `mastery_level` updates according to your ratings

**7. Cloze mode** ✅
- Scope: blank the keyword, Levenshtein fuzzy match, diff feedback, manual override, `mastery_level` translation for Cloze
- Spec refs: §5, §6
- Done when: a typo'd-but-close answer is accepted via fuzzy match, and a genuinely wrong answer can be manually overridden to "I was right"

**8. List mode** ✅ shipped, then removed
- Scope: reveal-in-order mechanic, orientation-agnostic detection (multi-line front vs. multi-line back), `mastery_level` translation for List
- Spec refs: §5, §6
- Done when: a card written either direction (multi-line front, or multi-line back) correctly offers List mode and reveals lines in order
- **Removed by the revised card model — see `docs/spec-v3-card-model.md`.** List mode no longer exists; `availableModes()` never returns it and there is no List UI.

**9. Feynman mode** ✅
- Scope: timer, free-text input, diff against reference lines, self-checkoff, gap mini-deck spawn, `mastery_level` translation for Feynman
- Spec refs: §5, §6
- Done when: finishing a Feynman card with unchecked points spawns a follow-up mini-deck containing just those missed points

**10. Session Summary + drill-parked-cards** ✅
- Scope: mastery delta (deck % before/after), recall metrics for the session's mode, "drill parked cards now" as a scoped session reusing the same `study_mode`
- Spec refs: §7
- Done when: after a session leaves a card parked, "drill parked cards now" starts a new session containing only that card, in the same mode

**11. Notifications** ✅
- Scope: local push reminders for parked/unfinished cards from the most recent session
- Spec refs: §8
- Done when: leaving a card parked and closing the app produces a local notification referencing it

**12. Settings** ✅
- Scope: account info, delete account (via Supabase Edge Function), notification preferences, about/version
- Spec refs: §9
- Done when: deleting a test account removes the `auth.users` row and cascades away all their decks/cards/sessions

**13. Offline & sync** ✅
- Scope: per-deck "available offline" toggle, local SQLite mirror, `is_synced` flag mechanism, fully offline session flow, batched sync-on-reconnect
- Spec refs: §10, Performance & Responsiveness
- Done when: with wifi off, a downloaded deck runs a full study session, and turning wifi back on syncs the results into Supabase within a few seconds
- **Superseded by the Offline-First Authoring revamp (O1–O4) — see `docs/spec-v4-offline-authoring.md`.** That revamp makes browsing, studying, and full course/deck/card authoring work offline (not just pinned decks, not study-only), by extending the `is_synced` dirty-flag surface to content plus a tombstone table.

**14. Beta polish** ✅
- Scope: sample starter deck, signed release APK build, Google Form link placed somewhere reachable, final check against Beta Logistics
- Spec refs: Phase scope, Beta logistics
- Done when: a classmate can install the signed APK with zero developer tools and it runs

---

## Engine V2 (milestones 15–17)

Data layer, one queue-scope option, and a local aggregation layer — the plumbing for a
later UI revamp. No new screens in these milestones. Full spec: `docs/engine-v2-spec.md`.

**15. Engine V2 data layer** ✅
- Scope: new `courses` table (RLS, `updated_at` trigger, `user_id` index, `is_default` partial-unique index, named `accent_color` check); `decks.course_id` (`NO ACTION` FK) + index + `before insert` default-course trigger + course-ownership clause on the `decks` RLS `with check`; `study_sessions.card_scope`; `handle_new_user` extended to create the default course; rewrite `supabase/schema.sql` and re-apply to the fresh (test-only) project; `Course` model + `CourseRepository` (read path); `Deck`/`DeckSummary`/`StudySession`/`StudySessionArgs` field additions; `fetchDecks`/`fetchDeck` select updates; SQLite `_version` → 2 + `onUpgrade` + `offline_courses` + `offline_decks.course_id` + `offline_study_sessions.card_scope` + store map updates + schema-parity test
- Spec refs: engine-v2-spec.md §3, §5
- Done when: the schema re-applies cleanly to a fresh project, a new signup auto-creates a `profiles` row and a default `courses` row, every existing deck ends up on its owner's default course, `flutter analyze` is clean, and `flutter test` is green (including the schema-parity test) — with zero visible change to the app

**16. "Study all cards" queue option** ✅
- Scope: `CardScope` argument on `selectSessionCards` (skips the `isDue` filter for `all`); `SessionController.start` threads `cardScope` from args → queue selection → `_seedSession`'s `card_scope` write; extend the `session_queue_selection` / `session_controller` / `study_session_state` suites. Plumbing only — the toggle widget is part of the UI revamp
- Spec refs: engine-v2-spec.md §4
- Done when: a test session seeded with `CardScope.all` on a fully-mastered deck builds a non-empty queue containing the Mastered cards, its `study_sessions` row records `card_scope = 'all'`, and a `due` session behaves exactly as before

**17. Local aggregation layer** ✅
- Scope: `overallMasteryProvider` (card-weighted, pure); app-wide Troublemakers repo method + provider (targeted `cards` query); per-deck run-through count derived from `study_sessions` (`card_scope = 'all' and status = 'completed'`); `CourseSummary` per-course rollups. Providers + repo methods + tests, no widgets
- Spec refs: engine-v2-spec.md §6
- Done when: each provider returns correct values against a fixture dataset, the pure functions have no DB dependency, and `flutter test` is green

(16 and 17 are both light and can be done in one session if preferred; 15 stands alone.)

---

## Navigation restructure (milestones U16–U19)

The shell moves from Decks/Mastery/Profile/Settings to **Home/Decks/History/More**, with
Settings demoted to a pushed route. Full spec: `docs/ui-spec-v4-navigation.md`. All four
landed one per session per CLAUDE.md's working style.

**U16. Shell nav restructure** ✅
- Scope: `StatefulShellRoute` branches reordered to `/home /decks /history /more`; `/settings` becomes a pushed top-level route; `/` splash redirect retargeted to `/home`; `GlassBottomNavBar` icon/label pairs; `MasteryTabScreen` + `ProfileTabScreen` deleted; empty `HomeTabScreen` / `HistoryTabScreen` / `MoreTabScreen` placeholders; the collapse-sections-on-entry behaviour moved into `SettingsTabScreen.initState`.
- Spec refs: ui-spec-v4-navigation §2
- Done when: the four branches render in order with the bottom bar, `/settings` is reachable but bar-less, splash lands on `/home`, `flutter analyze` clean, `flutter test` green.

**U17. Home tab** ✅
- Scope: `activeSessionsProvider`, `mostReviewedDecksProvider`, the full `HomeTabScreen` layout (greeting, reused Overall Mastery card, unfinished-sessions strip, most-reviewed deck stack), resume-session tap-through.
- Spec refs: ui-spec-v4-navigation §3
- Done when: Home renders every section, tapping an unfinished session resumes it, tapping a deck opens deck detail; both new provider suites green.

**U18. History tab** ✅
- Scope: `dailyActivityProvider` (per-day activity buckets), the calendar-heatmap widget with month navigation, the All / By Deck segmented toggle, and the merged session log (`recentActivityProvider` + deck-completion data). `CourseRollupStrip` dropped.
- Spec refs: ui-spec-v4-navigation §4
- Done when: History renders a real heatmap from local data, the toggle filters the log, tapping a row behaves like the old activity feed; provider tests green.

**U19. More tab** ✅
- Scope: identity-only profile block plus Account / Preferences / Data / About groups; rows push `/settings`; `SignOutButton` reused; `pendingSyncCountProvider` offline-sync status; feedback dialog extracted to `ui/settings/feedback_info_dialog.dart` and shared; `ProfileTabScreen`'s stat widgets (`ProfileStatsRow`, `ProfileMetricsSection`, `ProfileStatBlock`, `AccountRowsCard`, `ProfileIdentityHeader`) and `currentStreakProvider` retired. Follow-up: the study-reminders toggle and the type-`DELETE` account-deletion flow were restored to the live `SettingsTabScreen` (they had been stranded in a dead `settings_screen.dart`, now deleted).
- Spec refs: ui-spec-v4-navigation §5
- Done when: More renders the profile block + three grouped sections, every row navigates or is omitted per §5, sign-out works, the old Profile screen and its unused widgets are gone, `flutter analyze` clean, `flutter test` green.