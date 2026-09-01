# OpenRecall

A Flutter study app built around multi-modal active recall (Flip, Cloze, List,
Feynman) with a guaranteed-mastery session loop. Backend is Supabase (Postgres +
Auth + Storage) — no custom server.

Android-only for this phase.

## Docs

- `docs/spec.md` — the complete feature/screen/schema spec. Read this before working on a feature.
- `docs/build-order.md` — the 14 dependency-ordered milestones.
- `docs/spec-web-mvp.md` — the hosted web build: goals, non-goals, code changes, rollout.
- `docs/web-known-issues.md` — web build limitations and cross-browser status.
- `CLAUDE.md` — orientation and project constraints.

## Web build

The app is also deployed as a hosted web build at **https://open-recall.pages.dev**
(Cloudflare Pages, auto-deployed from `main`). Same app, same Supabase project,
same account — phone-first and online-only. Build locally with
`flutter build web --release` (output in `build/web/`).

Known limitations — mid-session write-loss window, no offline, no reminders,
not installable, and a Safari/iOS zoom defect — are documented in
`docs/web-known-issues.md`. Report browser issues there; Safari/iOS is
best-effort and not a release gate.

## Dev setup

Requires the Flutter SDK (stable) and, for running on-device, the Android SDK.

```
flutter pub get
flutter test         # run the suite
flutter analyze      # lint — keep clean
flutter run          # needs an Android device/emulator + Android SDK
```

### Supabase config

The app reads its Supabase credentials from a git-ignored `.env` file at the
repo root:

```
cp .env.example .env
```

Then fill in `SUPABASE_URL` and `SUPABASE_ANON_KEY` from your Supabase project
(Dashboard → Project Settings → API — use the **anon / public** key, never the
service role key). In the dashboard, also turn **off** "Confirm email" under
Authentication → Providers → Email so sign-up logs the user straight in.

## Status

Core study loop, decks/courses/cards CRUD, offline mirror + reconnect sync
(Android), and profile metrics are in place. The app also ships as a hosted
web build — see **Web build** above and `docs/web-known-issues.md`.
