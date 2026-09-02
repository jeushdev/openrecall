# Editable Username — Design

**Status:** implemented 2026-09-03
**Date:** 2026-09-03
**Supersedes:** the username half of `docs/ui-spec-v5-native-ios.md` §8 (profile
pictures remain deferred there).

## Goal

Let a signed-in user set an optional display name that replaces the
email-derived name everywhere the app currently shows one (Home greeting, the
More identity row, avatar initials). Clearing it falls back to the
email-derived name.

## Scope

**In:** a nullable `profiles.username` column, the app's first `ProfileRepository`,
an edit sheet reached from the More identity row, and display-name resolution in
the two screens that show a name.

**Out (still deferred):** user-uploaded profile pictures — Supabase Storage
bucket, `image_picker`, client-side compression. Tracked in
`ui-spec-v5-native-ios.md` §8; its own later session.

## Decisions

| Question | Decision |
| --- | --- |
| Unique handle or display name? | **Non-unique display name.** No unique index, no "name taken" flow. There are no @mentions or social features. |
| Edit surface | **Bottom sheet** from the More identity row, built like `_CourseEditSheet` / `_DeckEditSheet`. |
| Where the name is applied | **Everywhere a name shows** — Home large title, More identity row, avatar initials — with the email-derived name as the fallback when `username` is blank. |
| Offline | **Online-only.** Save calls Supabase directly; on failure the sheet shows a snackbar and stays open (as `CourseCreatorScreen` does). Username editing is not on the study path, so the no-blocking-network rule does not apply. |
| Validation | Trim; 1–30 characters after trim; an all-whitespace entry is treated as "clear" and stores `null`. No character-set restriction — it is a display name. |

## Components

### 1. Schema — `supabase/schema.sql`

Add to `create table profiles`:

```sql
username text
```

Append an idempotent migration block at the end of the file, in the style of
the existing card-model / backfill blocks:

```sql
-- ---------------------------------------------------------------------------
-- Editable username — 2026-09-03
--
-- No-op on a fresh project (the create table above already has the column).
-- ---------------------------------------------------------------------------
alter table public.profiles add column if not exists username text;
```

No RLS change: `profiles_owner` is already `for all ... using (id = auth.uid())
with check (id = auth.uid())`, which covers the owner updating their own row.
No trigger change: `handle_new_user` keeps inserting only `id, email`; `username`
stays `null` until the user sets it.

**Manual step:** run the `alter table` line against the live Supabase project via
the SQL Editor — there is no migration runner.

### 2. Domain — `lib/features/profile/domain/profile.dart`

```dart
typedef Profile = ({String id, String email, String? username});
```

### 3. Data — repository

Follows the app's established repository convention (`AccountRepository`): an
abstract interface in `domain/`, a Supabase implementation in `data/`, a fake in
`test/support/`.

- **`lib/features/profile/domain/profile_repository.dart`**
  ```dart
  abstract interface class ProfileRepository {
    Future<Profile> fetch();             // select id, email, username where id = auth.uid()
    Future<void> updateUsername(String? name); // update({'username': name}) on that row
  }
  ```
- **`lib/features/profile/data/supabase_profile_repository.dart`** —
  `SupabaseProfileRepository implements ProfileRepository`, using
  `Supabase.instance.client`.
- **`profileRepositoryProvider`** — `Provider<ProfileRepository>` in
  `application/profile_providers.dart`, returning `SupabaseProfileRepository`.
- **`test/support/fake_profile_repository.dart`** — in-memory
  `FakeProfileRepository`, runs without `Supabase.initialize()`, records
  `updateUsername` calls and holds a settable current `Profile`.

`updateUsername(null)` clears the column. The `profiles` row always exists (the
new-user trigger creates it), so this is always an UPDATE.

### 4. Application — extend `lib/features/profile/application/profile_providers.dart`

- `profileProvider` — `FutureProvider<Profile?>`. Wrapped in the same try/catch
  as `userIdentityProvider`: yields `null` when signed out or when
  `Supabase.instance` is uninitialized (widget tests).
- `profileControllerProvider` — `AsyncNotifier<void>` exposing
  `Future<void> setUsername(String? name)`, which calls
  `profileRepositoryProvider.updateUsername` then
  `ref.invalidate(profileProvider)`. Mirrors `accountActionsProvider`: holds no
  value of its own, surfaces errors through its `AsyncError` state.
- `userIdentityProvider` is unchanged — it stays the synchronous,
  offline-safe source of the email.

### 5. Display-name resolution — `lib/ui/common/avatar.dart`

This file already owns `greetingName()` and `emailInitials()`. Add:

```dart
/// The display name to show for a user: [username] when it has non-whitespace
/// content, otherwise the email-derived greeting token.
String displayNameOr(String? username, String? email) =>
    (username != null && username.trim().isNotEmpty)
        ? username.trim()
        : greetingName(email);
```

`Avatar` gains an optional `String? name`. When set, initials derive from it
(first letters of the first two whitespace-separated words, e.g. "Jeush
Samuel" → "JS"); otherwise `emailInitials(email)` as today. Add a small
`initialsFrom(String)` helper alongside `emailInitials`.

### 6. UI — edit sheet

New `lib/features/profile/presentation/profile_edit_sheet.dart`:

- `ProfileEditSheet` with a static `Future<void> show(BuildContext)` —
  `showModalBottomSheet`, `isScrollControlled: true`, the same
  `RoundedRectangleBorder` + hairline `side` + `tokens.cardFill` chrome as
  `_CourseEditSheet.show`.
- Body (mirrors `_CourseEditSheetState.build`): grab handle, "Edit name" title
  (`AppType`/`tokens`), a `TextField` prefilled with the current `username`
  (empty when unset; hint "Your name"; `autofocus`; sentence capitalization;
  `onChanged` → `setState`), and a Save `FilledButton`.
- Save is enabled when not busy and the trimmed value differs from the stored
  one (an empty field is a valid "clear" only when a username is currently set).
  `> 30` chars after trim disables Save and shows a short helper line.
- On tap: `ref.read(profileControllerProvider.notifier).setUsername(trimmedOrNull)`;
  pop on success; on `AsyncError`, a snackbar ("Couldn't save your name, try
  again.") and keep the sheet open.

### 7. UI — screen wiring

- **`more_tab_screen.dart`** — the identity `IosRow`:
  - `title: displayNameOr(username, email)` (still `'Not signed in'` when
    `email == null`)
  - `leading: Avatar(email: email, name: username, size: 28)`
  - `onTap: () => ProfileEditSheet.show(context)` (was `openSettings`)
  - `showChevron` stays. Settings remains reachable through the Preferences /
    Data / About rows.
  - Reads `username` from `ref.watch(profileProvider).asData?.value?.username`.
- **`home_tab_screen.dart`** — `title: 'Hello, ${displayNameOr(username, email)}'`,
  with `username` from `ref.watch(profileProvider).asData?.value?.username`. The
  email-derived greeting renders first and snaps to the username once
  `profileProvider` resolves.

## Data flow

```
ProfileEditSheet ─setUsername()─▶ profileControllerProvider
                                        │
                                        ├─▶ ProfileRepository.updateUsername ──▶ Supabase profiles row
                                        └─▶ invalidate(profileProvider)
                                                    │
profileProvider ◀── refetch ─────────────────────────┘
      │
      ├─▶ HomeTabScreen  (Hello, <name>)
      └─▶ MoreTabScreen  (identity row title + avatar initials)
```

## Error handling

- **Save fails (network / RLS / offline):** `profileControllerProvider` enters
  `AsyncError`; the sheet catches it, shows a snackbar, stays open. Nothing is
  lost.
- **`profileProvider` fails to load:** screens fall back to the email-derived
  name (`displayNameOr(null, email)`), exactly as today. No error UI — the name
  is cosmetic.
- **Signed out / Supabase uninitialized:** `profileProvider` yields `null`;
  `userIdentityProvider` yields a `null` email; existing signed-out fallbacks
  ("Not signed in", "Hello, there") apply unchanged.

## Testing

| File | Covers |
| --- | --- |
| `test/features/profile/profile_providers_test.dart` | `profileControllerProvider.setUsername` calls the repo (via `FakeProfileRepository`) then invalidates `profileProvider`; a repo throw surfaces as `AsyncError`. |
| `test/features/profile/profile_edit_sheet_test.dart` | prefill from current username; Save disabled for `>30` chars and for an unchanged value; Save calls the controller with the trimmed value; a blank field with a stored name calls it with `null`; an error keeps the sheet open. |
| `test/features/settings/more_tab_screen_test.dart` (update) | the identity row opens `ProfileEditSheet`, not `SettingsTabScreen`; the row title shows the username when `profileProvider` is overridden to supply one. |
| `test/features/home/home_tab_screen_test.dart` (update) | the greeting shows the username when `profileProvider` supplies one, and the email-derived token when it does not. |

Existing `more_tab_screen_test` currently asserts "a preferences row pushes the
Settings screen" via `Study preferences` — unaffected. The test that taps the
identity row (if any) is retargeted.

## Files

**New**

- `lib/features/profile/domain/profile.dart`
- `lib/features/profile/domain/profile_repository.dart`
- `lib/features/profile/data/supabase_profile_repository.dart`
- `lib/features/profile/presentation/profile_edit_sheet.dart`
- `test/support/fake_profile_repository.dart`
- `test/features/profile/profile_providers_test.dart`
- `test/features/profile/profile_edit_sheet_test.dart`

**Modified**

- `supabase/schema.sql` — `username` column + migration block
- `lib/features/profile/application/profile_providers.dart` — `profileProvider`, `profileControllerProvider`
- `lib/ui/common/avatar.dart` — `displayNameOr`, `initialsFrom`, `Avatar.name`
- `lib/features/settings/presentation/more_tab_screen.dart` — identity row
- `lib/features/home/presentation/home_tab_screen.dart` — greeting
- `test/features/settings/more_tab_screen_test.dart`, `test/features/home/home_tab_screen_test.dart`

## Out of scope / non-goals

- Profile pictures / avatar upload.
- Uniqueness enforcement, reserved names, profanity filtering.
- Offline queueing of the username edit.
- Showing the username anywhere new (session history, shared decks — none exist).
- Changing the email address.
