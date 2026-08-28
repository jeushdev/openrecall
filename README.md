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

## Status

Milestone 1 (repo + scaffold): navigation shell with stub screens
(Splash → Login → Deck Library). No Supabase wiring yet — that lands in milestone 3.
