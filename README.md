# OpenRecall

A Flutter study app built around multi-modal active recall (Flip, Cloze, List,
Feynman) with a guaranteed-mastery session loop. Backend is Supabase (Postgres +
Auth + Storage) — no custom server.

Android-only for this phase.

## Docs

- `docs/spec.md` — the complete feature/screen/schema spec. Read this before working on a feature.
- `docs/build-order.md` — the 14 dependency-ordered milestones.
- `CLAUDE.md` — orientation and project constraints.

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

Milestone 3 (auth): email + password signup / login / logout and send-email
password reset, wired to Supabase Auth. Splash does a real session check and
routes to Login or the Deck Library.
