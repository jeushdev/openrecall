# ActiveRecall — Build Order

14 milestones, in dependency order — each assumes the ones above it work. Use these as your GitHub issues, same as Synapse. Point Claude Code at exactly one per session (see the loop in CLAUDE.md / our planning chat).

---

**1. Repo + scaffold**
- Scope: Flutter project created, Supabase project created (your manual step — account + keys), basic navigation shell with stub screens (Splash → Login → Deck Library), `docs/spec.md` + `CLAUDE.md` + Flutter `.gitignore` committed
- Spec refs: none specific — this is infrastructure
- Done when: `flutter run` launches a blank app that navigates between empty Splash/Login/Deck Library screens, and the repo contains `docs/spec.md` and `CLAUDE.md`

**2. Database**
- Scope: all 5 tables (`profiles`, `decks`, `cards`, `study_sessions`, `session_cards`), the `profiles`-auto-creation trigger, `updated_at` triggers, RLS policies (including the join-based ownership on `cards`/`session_cards`), indexes
- Spec refs: "Data Model (Schema)"
- Done when: all 5 tables exist in Supabase's table editor, a test signup auto-creates a matching `profiles` row, and a second test user's RLS-scoped query cannot see the first user's decks

**3. Auth**
- Scope: signup / login / logout, forgot password
- Spec refs: §1
- Done when: you can sign up, get logged in, log out, and log back in on a real device or emulator

**4. Deck Library + Deck Creator**
- Scope: deck list + create-deck flow, unified card model (front/back/keyword), manual entry, bulk paste with `{{keyword}}` extraction, live preview, edit/delete
- Spec refs: §2, §3
- Done when: you can create a deck, add cards both manually and via bulk paste (including one with a `{{keyword}}`), and see them stored with the correct front/back/keyword split

**5. Deck Overview**
- Scope: mode buttons filtered to what the deck actually supports, session-length toggle (presets), Troublemaker Cards, empty states
- Spec refs: §4
- Done when: mode buttons only appear for modes the deck has qualifying cards for, and the session-length toggle shows fixed presets

**6. Session engine + Flip mode**
- Scope: session creation (`study_sessions` + `session_cards`), mode-filtered queue building, sparse `position` values, requeue-on-fail, park-after-3-consecutive-fails, `mastery_level` translation for Flip, session-conflict rule (new session abandons old active one)
- Spec refs: §5 (5A + shared mechanics), §6, schema
- Done when: on a small test deck, a failed card correctly requeues, gets parked after 3 consecutive fails, and `mastery_level` updates according to your ratings

**7. Cloze mode**
- Scope: blank the keyword, Levenshtein fuzzy match, diff feedback, manual override, `mastery_level` translation for Cloze
- Spec refs: §5, §6
- Done when: a typo'd-but-close answer is accepted via fuzzy match, and a genuinely wrong answer can be manually overridden to "I was right"

**8. List mode**
- Scope: reveal-in-order mechanic, orientation-agnostic detection (multi-line front vs. multi-line back), `mastery_level` translation for List
- Spec refs: §5, §6
- Done when: a card written either direction (multi-line front, or multi-line back) correctly offers List mode and reveals lines in order

**9. Feynman mode**
- Scope: timer, free-text input, diff against reference lines, self-checkoff, gap mini-deck spawn, `mastery_level` translation for Feynman
- Spec refs: §5, §6
- Done when: finishing a Feynman card with unchecked points spawns a follow-up mini-deck containing just those missed points

**10. Session Summary + drill-parked-cards**
- Scope: mastery delta (deck % before/after), recall metrics for the session's mode, "drill parked cards now" as a scoped session reusing the same `study_mode`
- Spec refs: §7
- Done when: after a session leaves a card parked, "drill parked cards now" starts a new session containing only that card, in the same mode

**11. Notifications**
- Scope: local push reminders for parked/unfinished cards from the most recent session
- Spec refs: §8
- Done when: leaving a card parked and closing the app produces a local notification referencing it

**12. Settings**
- Scope: account info, delete account (via Supabase Edge Function), notification preferences, about/version
- Spec refs: §9
- Done when: deleting a test account removes the `auth.users` row and cascades away all their decks/cards/sessions

**13. Offline & sync**
- Scope: per-deck "available offline" toggle, local SQLite mirror, `is_synced` flag mechanism, fully offline session flow, batched sync-on-reconnect
- Spec refs: §10, Performance & Responsiveness
- Done when: with wifi off, a downloaded deck runs a full study session, and turning wifi back on syncs the results into Supabase within a few seconds

**14. Beta polish**
- Scope: sample starter deck, signed release APK build, Google Form link placed somewhere reachable, final check against Beta Logistics
- Spec refs: Phase scope, Beta logistics
- Done when: a classmate can install the signed APK with zero developer tools and it runs