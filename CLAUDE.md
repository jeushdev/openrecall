# ActiveRecall — Claude Code Project Guide

## What this is
A Flutter mobile study app implementing multi-modal active recall (Flip, Cloze, List, Feynman modes) with a guaranteed-mastery session loop. Backend is Supabase (Postgres + Auth + Storage) directly — no custom backend server.

## Full spec — read this before starting any feature
`docs/spec.md` is the complete, decision-by-decision spec: screens, the unified card model, mastery translation rules, the full database schema, offline/sync design, and performance requirements. This file is a short orientation, not a substitute for it. If something isn't covered in docs/spec.md, it isn't decided yet — ask rather than assume.

## Non-negotiable constraints
- No AI API calls anywhere in the app, for any reason — not grading, not anything server-side. Cost, not capability.
- No custom backend. Flutter talks to Supabase directly.
- Android-only for this phase. No billing/paywall logic yet — a `tier` column exists on `profiles` but nothing reads it.
- Study interactions (flip, rate, type an answer) must never block on a network call, online or offline — see "Performance & Responsiveness" in the spec.
- `cards` has no `type` column. Which study modes a card supports is computed from `front`/`back`/`keyword` at read time.
- `cards` and `session_cards` have no direct owner column — their RLS policies check ownership through a join (`cards` → `decks.user_id`, `session_cards` → `study_sessions.user_id`). Read the generated policy SQL and confirm it's actually scoped correctly; don't assume it.
- `updated_at` is set by a database trigger, not by application code, on every table that has one.

## Stack
- Flutter (Dart), Android target first, iOS not built yet
- Supabase: Postgres + Auth + Storage, RLS enabled on every table
- No ORM — Supabase client queries / plain SQL

## Commands
- `flutter pub get` — install dependencies
- `flutter run` — run on a connected Android device/emulator (the Android SDK is installed and working on this machine as of milestone 3). `flutter doctor` reports "Android license status unknown" — this is known and safe to ignore; `flutter run` and `flutter build apk` work fine regardless.
- `flutter test` — run the test suite
- `flutter analyze` — static analysis / lint (must be clean before committing)
- `flutter build apk` — build the Android APK (`--debug` for a quick sanity build, `--release` for distribution)

## Project layout
- Feature-first: `lib/features/<feature>/presentation|domain|data/`
- Cross-cutting: `lib/routing/` (go_router), `lib/theme/`
- Entry point: `lib/main.dart` → `lib/app.dart` (`OpenRecallApp`)
- State management: Riverpod (`flutter_riverpod` 3.x, manual provider declarations — the 3.x codegen/lint tooling isn't stable yet)
- Android application ID: `com.openrecall.app` (namespace stays `com.openrecall.open_recall`)

## Working style
- One feature/milestone per session — don't build multiple unrelated features in one sitting, even if there's room in the context window
- Conventional commits
- If a design decision genuinely isn't covered in docs/spec.md, stop and ask rather than picking a reasonable-sounding default