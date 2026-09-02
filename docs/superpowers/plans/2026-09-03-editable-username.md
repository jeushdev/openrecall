# Editable Username Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Let a signed-in user set an optional display name that replaces the email-derived name on the Home greeting, the More identity row, and avatar initials.

**Architecture:** A nullable `profiles.username` column; the app's first profile repository (`ProfileRepository` interface + `SupabaseProfileRepository` + `FakeProfileRepository`, mirroring `AccountRepository`); a `profileProvider` (`FutureProvider<Profile?>`) and `profileControllerProvider` (`AsyncNotifier<void>`) added to the existing `profile_providers.dart`; a `ProfileEditSheet` bottom sheet opened from the More identity row; and a `displayNameOr()` helper in `avatar.dart` that both screens call.

**Tech Stack:** Flutter (Dart), Material 3, `flutter_riverpod` 3.x (manual providers), `supabase_flutter`, `go_router` 18.x. Supabase Postgres direct, RLS on every table.

**Spec:** `docs/superpowers/specs/2026-09-03-editable-username-design.md` (read it first — it carries the rationale and the accepted decisions this plan implements).

## Global Constraints

- **No AI API calls anywhere.** Not relevant here, but the rule stands.
- **No custom backend.** Flutter talks to Supabase directly; the repository uses `Supabase.instance.client`.
- **Android-only phase.** No iOS concerns.
- **Study interactions must never block on a network call.** Username editing is **not** on the study path, so it is allowed to be online-only and synchronous against Supabase.
- **`updated_at` is set by a DB trigger, not app code.** `profiles` has no `updated_at` column — nothing to set.
- **RLS ownership:** `profiles_owner` is `for all ... using (id = (select auth.uid())) with check (id = (select auth.uid()))` — already covers the owner updating their own row. **Do not add or change any policy.**
- **Riverpod 3.x manual provider declarations** — no codegen, no `@riverpod`.
- **Repository convention:** abstract interface in `domain/`, Supabase impl in `data/`, in-memory fake in `test/support/`. Nothing outside the `data/` impl imports `Supabase` for profile data.
- **Validation:** trim; 1–30 characters after trim; an all-whitespace entry stores `null` (clears the name). No character-set restriction.
- **Copy (assert verbatim in tests):** sheet title `Edit name`, field label/hint `Your name`, save button `Save`, error snackbar `Couldn't save your name, try again.`, signed-out identity title `Not signed in`, home greeting prefix `Hello, `.

---

## File Structure

**New**

- `lib/features/profile/domain/profile.dart` — the `Profile` record type.
- `lib/features/profile/domain/profile_repository.dart` — `ProfileRepository` abstract interface.
- `lib/features/profile/data/supabase_profile_repository.dart` — `SupabaseProfileRepository`.
- `lib/features/profile/presentation/profile_edit_sheet.dart` — `ProfileEditSheet` bottom sheet.
- `test/support/fake_profile_repository.dart` — `FakeProfileRepository`.
- `test/features/profile/profile_providers_test.dart`
- `test/features/profile/profile_edit_sheet_test.dart`
- `test/ui/common/avatar_test.dart` — covers the new `displayNameOr` / `initialsFrom` helpers.

**Modified**

- `supabase/schema.sql` — `username` column on `create table profiles` + idempotent migration block.
- `lib/features/profile/application/profile_providers.dart` — `profileRepositoryProvider`, `profileProvider`, `profileControllerProvider`.
- `lib/ui/common/avatar.dart` — `displayNameOr()`, `initialsFrom()`, `Avatar.name`.
- `lib/features/settings/presentation/more_tab_screen.dart` — identity row: title, avatar, `onTap`.
- `lib/features/home/presentation/home_tab_screen.dart` — greeting title.
- `test/features/settings/more_tab_screen_test.dart` — identity row opens the sheet; shows username.
- `test/features/home/home_tab_screen_test.dart` — greeting uses username.

---

## Task 1: Schema — `profiles.username` column

**Files:**
- Modify: `supabase/schema.sql` (the `create table profiles` block near line 23, and a new migration block appended at end of file)

**Interfaces:**
- Consumes: nothing.
- Produces: a nullable `profiles.username text` column. No new function, policy, or trigger.

- [ ] **Step 1: Add the column to the table definition**

In `supabase/schema.sql`, change:

```sql
create table profiles (
  id uuid primary key references auth.users(id) on delete cascade,
  email text not null,
  tier text not null default 'free',
  created_at timestamptz not null default now()
);
```

to:

```sql
create table profiles (
  id uuid primary key references auth.users(id) on delete cascade,
  email text not null,
  username text,
  tier text not null default 'free',
  created_at timestamptz not null default now()
);
```

- [ ] **Step 2: Append the idempotent migration block**

At the very end of `supabase/schema.sql`, after the milestone-D `cards_reviewed` block, add:

```sql

-- ---------------------------------------------------------------------------
-- Editable username migration — 2026-09-03
-- (docs/superpowers/specs/2026-09-03-editable-username-design.md)
--
-- No-op on a fresh project (the `create table profiles` above already carries
-- `username`). On an existing project: add the nullable column. RLS is
-- unchanged — `profiles_owner` already scopes `for all` to `id = auth.uid()`,
-- so the owner can update their own `username`.
-- ---------------------------------------------------------------------------

alter table public.profiles add column if not exists username text;
```

- [ ] **Step 3: Verify the file is internally consistent**

Run: `grep -n "username" supabase/schema.sql`
Expected: two hits — the column in `create table profiles`, and the `alter table ... add column if not exists username text;` line. No policy or trigger mentions `username`.

- [ ] **Step 4: Commit**

```bash
git add supabase/schema.sql
git commit -m "feat: add nullable profiles.username column (editable-username spec)"
```

- [ ] **Step 5: Manual apply (record only — not blocking)**

The live Supabase project has no migration runner. Before this feature ships, run this against it via the SQL Editor:

```sql
alter table public.profiles add column if not exists username text;
```

Note it in the PR / release notes. Nothing in the plan's automated verification depends on the live DB.

---

## Task 2: Profile domain type + repository interface + Supabase impl + fake

**Files:**
- Create: `lib/features/profile/domain/profile.dart`
- Create: `lib/features/profile/domain/profile_repository.dart`
- Create: `lib/features/profile/data/supabase_profile_repository.dart`
- Create: `test/support/fake_profile_repository.dart`

**Interfaces:**
- Consumes: nothing (new feature slice).
- Produces:
  - `typedef Profile = ({String id, String email, String? username});`
  - `abstract interface class ProfileRepository { Future<Profile> fetch(); Future<void> updateUsername(String? name); }`
  - `class SupabaseProfileRepository implements ProfileRepository` — constructor `SupabaseProfileRepository(SupabaseClient client)`.
  - `class FakeProfileRepository implements ProfileRepository` — constructor `FakeProfileRepository({Profile? profile})`; fields `Profile? profile`, `List<String?> updateUsernameCalls`, `Object? throwOnNextCall`.

- [ ] **Step 1: Create the domain type**

`lib/features/profile/domain/profile.dart`:

```dart
/// The current user's `profiles` row, as the identity UI needs it.
///
/// [username] is the optional, user-set display name (spec:
/// docs/superpowers/specs/2026-09-03-editable-username-design.md). When it is
/// null or blank the UI falls back to the email-derived name — see
/// `displayNameOr` in `lib/ui/common/avatar.dart`.
typedef Profile = ({String id, String email, String? username});
```

- [ ] **Step 2: Create the repository interface**

`lib/features/profile/domain/profile_repository.dart`:

```dart
import 'profile.dart';

/// The app's window onto the current user's `profiles` row. Everything outside
/// [SupabaseProfileRepository] (in `../data/`) talks to profile data through
/// this interface — never `Supabase.instance` directly — so widget and
/// controller tests run against [FakeProfileRepository] without
/// `Supabase.initialize()`.
abstract interface class ProfileRepository {
  /// The signed-in user's profile row. Throws when there is no session or the
  /// row cannot be read; callers treat a throw as "no profile" (null).
  Future<Profile> fetch();

  /// Sets `profiles.username` for the signed-in user. Pass `null` to clear it
  /// (revert to the email-derived name). Throws on a network / RLS failure.
  Future<void> updateUsername(String? name);
}
```

- [ ] **Step 3: Create the Supabase implementation**

`lib/features/profile/data/supabase_profile_repository.dart`:

```dart
import 'package:supabase_flutter/supabase_flutter.dart';

import '../domain/profile.dart';
import '../domain/profile_repository.dart';

/// The only class in the profile feature that talks to Supabase directly.
class SupabaseProfileRepository implements ProfileRepository {
  SupabaseProfileRepository(this._client);

  final SupabaseClient _client;

  @override
  Future<Profile> fetch() async {
    final user = _client.auth.currentUser;
    if (user == null) {
      throw StateError('No signed-in user to load a profile for.');
    }
    final row = await _client
        .from('profiles')
        .select('id, email, username')
        .eq('id', user.id)
        .single();
    return (
      id: row['id'] as String,
      email: row['email'] as String,
      username: row['username'] as String?,
    );
  }

  @override
  Future<void> updateUsername(String? name) async {
    final user = _client.auth.currentUser;
    if (user == null) {
      throw StateError('No signed-in user to update.');
    }
    await _client
        .from('profiles')
        .update({'username': name})
        .eq('id', user.id);
  }
}
```

- [ ] **Step 4: Create the fake**

`test/support/fake_profile_repository.dart`:

```dart
import 'package:open_recall/features/profile/domain/profile.dart';
import 'package:open_recall/features/profile/domain/profile_repository.dart';

/// In-memory [ProfileRepository] for widget and controller tests — runs without
/// `Supabase.initialize()`.
class FakeProfileRepository implements ProfileRepository {
  FakeProfileRepository({Profile? profile})
      : profile = profile ??
            (id: 'user-1', email: 'jeush.b@example.com', username: null);

  /// The row [fetch] returns and [updateUsername] mutates.
  Profile profile;

  /// Every `name` passed to [updateUsername], in order.
  final List<String?> updateUsernameCalls = <String?>[];

  /// When set, the next call throws this and then clears it.
  Object? throwOnNextCall;

  void _maybeThrow() {
    final err = throwOnNextCall;
    if (err != null) {
      throwOnNextCall = null;
      throw err;
    }
  }

  @override
  Future<Profile> fetch() async {
    _maybeThrow();
    return profile;
  }

  @override
  Future<void> updateUsername(String? name) async {
    _maybeThrow();
    updateUsernameCalls.add(name);
    profile = (id: profile.id, email: profile.email, username: name);
  }
}
```

- [ ] **Step 5: Verify it compiles**

Run: `flutter analyze lib/features/profile test/support/fake_profile_repository.dart`
Expected: "No issues found!"

- [ ] **Step 6: Commit**

```bash
git add lib/features/profile/domain lib/features/profile/data test/support/fake_profile_repository.dart
git commit -m "feat: ProfileRepository (interface, Supabase impl, fake)"
```

---

## Task 3: `profileProvider` + `profileControllerProvider`

**Files:**
- Modify: `lib/features/profile/application/profile_providers.dart`
- Test: `test/features/profile/profile_providers_test.dart`

**Interfaces:**
- Consumes: `ProfileRepository`, `Profile`, `FakeProfileRepository` (Task 2).
- Produces:
  - `final profileRepositoryProvider = Provider<ProfileRepository>(...)`
  - `final profileProvider = FutureProvider<Profile?>(...)` — yields `null` on any failure (signed out, uninitialized Supabase, read error).
  - `final profileControllerProvider = AsyncNotifierProvider<ProfileController, void>(ProfileController.new)` with `Future<void> setUsername(String? name)`.

- [ ] **Step 1: Write the failing test**

`test/features/profile/profile_providers_test.dart`:

```dart
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:open_recall/features/profile/application/profile_providers.dart';
import 'package:open_recall/features/profile/domain/profile.dart';

import '../../support/fake_profile_repository.dart';

void main() {
  ProviderContainer containerWith(FakeProfileRepository repo) {
    final c = ProviderContainer(
      overrides: [profileRepositoryProvider.overrideWithValue(repo)],
    );
    addTearDown(c.dispose);
    return c;
  }

  test('profileProvider returns the repository row', () async {
    final repo = FakeProfileRepository(
      profile: (id: 'u1', email: 'a@b.com', username: 'Ada'),
    );
    final c = containerWith(repo);

    final profile = await c.read(profileProvider.future);

    expect(profile, isNotNull);
    expect(profile!.username, 'Ada');
  });

  test('profileProvider yields null when the repository throws', () async {
    final repo = FakeProfileRepository()..throwOnNextCall = StateError('no session');
    final c = containerWith(repo);

    expect(await c.read(profileProvider.future), isNull);
  });

  test('setUsername calls the repository and refreshes profileProvider',
      () async {
    final repo = FakeProfileRepository(
      profile: (id: 'u1', email: 'a@b.com', username: null),
    );
    final c = containerWith(repo);

    await c.read(profileProvider.future); // prime it
    await c.read(profileControllerProvider.notifier).setUsername('Grace');

    expect(repo.updateUsernameCalls, ['Grace']);
    final refreshed = await c.read(profileProvider.future);
    expect(refreshed!.username, 'Grace');
  });

  test('setUsername surfaces a repository failure as AsyncError', () async {
    final repo = FakeProfileRepository()..throwOnNextCall = Exception('offline');
    final c = containerWith(repo);

    await c.read(profileControllerProvider.notifier).setUsername('X');

    expect(c.read(profileControllerProvider).hasError, isTrue);
  });
}
```

- [ ] **Step 2: Run it, verify it fails**

Run: `flutter test test/features/profile/profile_providers_test.dart`
Expected: FAIL — `profileRepositoryProvider` / `profileProvider` / `profileControllerProvider` are undefined.

- [ ] **Step 3: Implement the providers**

Append to `lib/features/profile/application/profile_providers.dart` (keep the existing `userIdentityProvider` and its imports; add the new imports at the top):

```dart
// add to the existing import block:
import 'dart:async';

import '../data/supabase_profile_repository.dart';
import '../domain/profile.dart';
import '../domain/profile_repository.dart';
```

```dart
// append below userIdentityProvider:

/// The live repository is backed by the initialized Supabase singleton. Tests
/// override this with [FakeProfileRepository], so nothing else imports
/// `Supabase` for profile data.
final profileRepositoryProvider = Provider<ProfileRepository>((ref) {
  return SupabaseProfileRepository(Supabase.instance.client);
});

/// The current user's profile row, or `null` when there is no session, Supabase
/// is not initialized (widget tests), or the row can't be read. The name is
/// cosmetic, so every failure degrades to `null` and the UI shows the
/// email-derived name.
final profileProvider = FutureProvider<Profile?>((ref) async {
  try {
    return await ref.read(profileRepositoryProvider).fetch();
  } catch (_) {
    return null;
  }
});

/// Drives the "edit display name" action: `isLoading` disables the sheet's Save
/// button, `hasError` feeds its SnackBar. Holds no value of its own — it tracks
/// the in-flight state of the most recent [setUsername] (mirrors
/// `AccountActionsController` in the settings feature).
final profileControllerProvider =
    AsyncNotifierProvider<ProfileController, void>(ProfileController.new);

class ProfileController extends AsyncNotifier<void> {
  @override
  FutureOr<void> build() {}

  /// Persists `profiles.username` and refreshes [profileProvider]. Pass `null`
  /// to clear the name.
  Future<void> setUsername(String? name) async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(() async {
      await ref.read(profileRepositoryProvider).updateUsername(name);
      ref.invalidate(profileProvider);
    });
  }
}
```

- [ ] **Step 4: Run the test, verify it passes**

Run: `flutter test test/features/profile/profile_providers_test.dart`
Expected: PASS (4 tests).

- [ ] **Step 5: Analyze**

Run: `flutter analyze lib/features/profile`
Expected: "No issues found!"

- [ ] **Step 6: Commit**

```bash
git add lib/features/profile/application/profile_providers.dart test/features/profile/profile_providers_test.dart
git commit -m "feat: profileProvider + profileControllerProvider"
```

---

## Task 4: `displayNameOr` + `initialsFrom` + `Avatar.name`

**Files:**
- Modify: `lib/ui/common/avatar.dart`
- Test: `test/ui/common/avatar_test.dart` (new)

**Interfaces:**
- Consumes: nothing.
- Produces:
  - `String displayNameOr(String? username, String? email)` — trimmed `username` when non-blank, else `greetingName(email)`.
  - `String initialsFrom(String name)` — 1–2 uppercase letters from the first two words.
  - `Avatar` gains `final String? name;` (named param `name`); initials come from `name` when non-blank, else `emailInitials(email)`.

- [ ] **Step 1: Write the failing test**

`test/ui/common/avatar_test.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:open_recall/theme/app_theme.dart';
import 'package:open_recall/ui/common/avatar.dart';

void main() {
  group('displayNameOr', () {
    test('uses the trimmed username when it has content', () {
      expect(displayNameOr('  Ada Lovelace  ', 'x@y.com'), 'Ada Lovelace');
    });

    test('falls back to the email-derived greeting when username is null', () {
      expect(displayNameOr(null, 'jeush.b@example.com'), 'Jeush');
    });

    test('falls back when username is blank / whitespace', () {
      expect(displayNameOr('   ', 'jeush.b@example.com'), 'Jeush');
    });
  });

  group('initialsFrom', () {
    test('first letters of the first two words', () {
      expect(initialsFrom('Ada Lovelace'), 'AL');
    });

    test('first two letters of a single word', () {
      expect(initialsFrom('Ada'), 'AD');
    });

    test('one letter for a single-character name', () {
      expect(initialsFrom('A'), 'A');
    });
  });

  testWidgets('Avatar uses name initials when name is given', (tester) async {
    await tester.pumpWidget(MaterialApp(
      theme: AppTheme.light,
      home: const Scaffold(
        body: Avatar(email: 'jeush.b@example.com', name: 'Ada Lovelace'),
      ),
    ));
    expect(find.text('AL'), findsOneWidget);
  });

  testWidgets('Avatar falls back to email initials when name is null',
      (tester) async {
    await tester.pumpWidget(MaterialApp(
      theme: AppTheme.light,
      home: const Scaffold(body: Avatar(email: 'jeush.b@example.com')),
    ));
    expect(find.text('JE'), findsOneWidget);
  });
}
```

- [ ] **Step 2: Run it, verify it fails**

Run: `flutter test test/ui/common/avatar_test.dart`
Expected: FAIL — `displayNameOr` / `initialsFrom` undefined, `Avatar` has no `name` param.

- [ ] **Step 3: Implement**

In `lib/ui/common/avatar.dart`:

Add the `name` field to `Avatar`:

```dart
class Avatar extends StatelessWidget {
  const Avatar({super.key, required this.email, this.name, this.size = 56});

  final String? email;

  /// The user's display name, when set — initials derive from this rather than
  /// [email]'s local part.
  final String? name;

  final double size;
```

and in `build`, replace `emailInitials(email)` with:

```dart
        (name != null && name!.trim().isNotEmpty)
            ? initialsFrom(name!)
            : emailInitials(email),
```

Append the two helpers at the bottom of the file (next to `greetingName`):

```dart
/// The display name to show for a user: [username] when it has non-whitespace
/// content, otherwise the email-derived greeting token from [greetingName].
String displayNameOr(String? username, String? email) =>
    (username != null && username.trim().isNotEmpty)
        ? username.trim()
        : greetingName(email);

/// Up to two uppercase letters from a display [name]: the first letters of its
/// first two whitespace-separated words, or the first two letters of a single
/// word. Falls back to `?` for an empty name.
String initialsFrom(String name) {
  final words =
      name.trim().split(RegExp(r'\s+')).where((w) => w.isNotEmpty).toList();
  if (words.isEmpty) return '?';
  if (words.length == 1) {
    final w = words.first;
    return w.substring(0, w.length >= 2 ? 2 : 1).toUpperCase();
  }
  return (words[0][0] + words[1][0]).toUpperCase();
}
```

- [ ] **Step 4: Run the test, verify it passes**

Run: `flutter test test/ui/common/avatar_test.dart`
Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add lib/ui/common/avatar.dart test/ui/common/avatar_test.dart
git commit -m "feat: displayNameOr / initialsFrom helpers + Avatar.name"
```

---

## Task 5: `ProfileEditSheet`

**Files:**
- Create: `lib/features/profile/presentation/profile_edit_sheet.dart`
- Test: `test/features/profile/profile_edit_sheet_test.dart`

**Interfaces:**
- Consumes: `profileProvider`, `profileControllerProvider` (Task 3); `AppTokens`, `AppType`, `AppBorders`.
- Produces: `class ProfileEditSheet` with `static Future<void> show(BuildContext context, {String? currentName})`.

**Behaviour:**
- Prefills the field with `currentName` (the caller passes the value it already
  has from `profileProvider`; empty when unset). The sheet does not read the
  initial value from a provider — `profileProvider` is async and would not be
  resolved at sheet-build time.
- Save is enabled when: not busy **and** the trimmed value differs from the stored username **and** the trimmed value is ≤ 30 chars. (An empty field with a stored username is a valid change — it clears.)
- Over 30 chars: Save disabled + a helper line `Keep it under 30 characters.`
- Save → `profileControllerProvider.setUsername(trimmed.isEmpty ? null : trimmed)`; pop on success; on `AsyncError` show SnackBar `Couldn't save your name, try again.` and stay open.

- [ ] **Step 1: Write the failing test**

`test/features/profile/profile_edit_sheet_test.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:open_recall/features/profile/application/profile_providers.dart';
import 'package:open_recall/features/profile/domain/profile.dart';
import 'package:open_recall/features/profile/presentation/profile_edit_sheet.dart';
import 'package:open_recall/theme/app_theme.dart';

import '../../support/fake_profile_repository.dart';

Future<FakeProfileRepository> _open(
  WidgetTester tester, {
  String? username,
}) async {
  final repo = FakeProfileRepository(
    profile: (id: 'u1', email: 'a@b.com', username: username),
  );
  await tester.pumpWidget(
    ProviderScope(
      overrides: [profileRepositoryProvider.overrideWithValue(repo)],
      child: MaterialApp(
        theme: AppTheme.light,
        home: Builder(
          builder: (context) => Scaffold(
            body: Center(
              child: ElevatedButton(
                onPressed: () =>
                    ProfileEditSheet.show(context, currentName: username),
                child: const Text('open'),
              ),
            ),
          ),
        ),
      ),
    ),
  );
  await tester.tap(find.text('open'));
  await tester.pumpAndSettle();
  return repo;
}

void main() {
  testWidgets('prefills the current username', (tester) async {
    await _open(tester, username: 'Ada');
    expect(find.widgetWithText(TextField, 'Ada'), findsOneWidget);
  });

  testWidgets('Save is disabled until the value changes', (tester) async {
    await _open(tester, username: 'Ada');
    final save = tester.widget<FilledButton>(
      find.widgetWithText(FilledButton, 'Save'),
    );
    expect(save.onPressed, isNull);
  });

  testWidgets('typing a new name and tapping Save calls the controller',
      (tester) async {
    final repo = await _open(tester, username: null);
    await tester.enterText(find.byType(TextField), '  Grace Hopper ');
    await tester.pump();
    await tester.tap(find.widgetWithText(FilledButton, 'Save'));
    await tester.pumpAndSettle();

    expect(repo.updateUsernameCalls, ['Grace Hopper']);
    expect(find.byType(TextField), findsNothing); // sheet popped
  });

  testWidgets('clearing a set name saves null', (tester) async {
    final repo = await _open(tester, username: 'Ada');
    await tester.enterText(find.byType(TextField), '   ');
    await tester.pump();
    await tester.tap(find.widgetWithText(FilledButton, 'Save'));
    await tester.pumpAndSettle();

    expect(repo.updateUsernameCalls, [null]);
  });

  testWidgets('over 30 chars disables Save and shows the hint', (tester) async {
    await _open(tester, username: null);
    await tester.enterText(find.byType(TextField), 'x' * 31);
    await tester.pump();

    expect(find.text('Keep it under 30 characters.'), findsOneWidget);
    final save = tester.widget<FilledButton>(
      find.widgetWithText(FilledButton, 'Save'),
    );
    expect(save.onPressed, isNull);
  });

  testWidgets('a save failure keeps the sheet open with a snackbar',
      (tester) async {
    final repo = await _open(tester, username: null);
    repo.throwOnNextCall = Exception('offline');
    await tester.enterText(find.byType(TextField), 'Grace');
    await tester.pump();
    await tester.tap(find.widgetWithText(FilledButton, 'Save'));
    await tester.pumpAndSettle();

    expect(find.text("Couldn't save your name, try again."), findsOneWidget);
    expect(find.byType(TextField), findsOneWidget); // still open
  });
}
```

- [ ] **Step 2: Run it, verify it fails**

Run: `flutter test test/features/profile/profile_edit_sheet_test.dart`
Expected: FAIL — `profile_edit_sheet.dart` missing.

- [ ] **Step 3: Implement the sheet**

`lib/features/profile/presentation/profile_edit_sheet.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../theme/app_geometry.dart';
import '../../../theme/app_tokens.dart';
import '../../../theme/app_type.dart';
import '../application/profile_providers.dart';

/// Edit the user's display name (spec:
/// docs/superpowers/specs/2026-09-03-editable-username-design.md). Opened from
/// the More identity row. Chrome mirrors `_CourseEditSheet` in
/// `decks_tab_screen.dart`.
class ProfileEditSheet extends ConsumerStatefulWidget {
  const ProfileEditSheet._({this.currentName});

  final String? currentName;

  static const int maxLength = 30;

  static Future<void> show(BuildContext context, {String? currentName}) {
    final tokens = Theme.of(context).extension<AppTokens>()!;
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: tokens.cardFill,
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
        side: BorderSide(
          color: tokens.borderHairline,
          width: AppBorders.hairline,
        ),
      ),
      builder: (_) => ProfileEditSheet._(currentName: currentName),
    );
  }

  @override
  ConsumerState<ProfileEditSheet> createState() => _ProfileEditSheetState();
}

class _ProfileEditSheetState extends ConsumerState<ProfileEditSheet> {
  late final String _initial = widget.currentName?.trim() ?? '';
  late final TextEditingController _name =
      TextEditingController(text: _initial);

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  String get _trimmed => _name.text.trim();
  bool get _tooLong => _trimmed.length > ProfileEditSheet.maxLength;
  bool get _changed => _trimmed != _initial;
  bool get _canSave => _changed && !_tooLong;

  Future<void> _save() async {
    final value = _trimmed.isEmpty ? null : _trimmed;
    await ref.read(profileControllerProvider.notifier).setUsername(value);
    if (!mounted) return;
    if (ref.read(profileControllerProvider).hasError) {
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
          const SnackBar(content: Text("Couldn't save your name, try again.")),
        );
      return;
    }
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final tokens = Theme.of(context).extension<AppTokens>()!;
    final busy = ref.watch(profileControllerProvider).isLoading;

    return SafeArea(
      top: false,
      child: Padding(
        padding: EdgeInsets.fromLTRB(
          20,
          12,
          20,
          20 + MediaQuery.viewInsetsOf(context).bottom,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Center(
              child: Container(
                width: 36,
                height: 4,
                decoration: BoxDecoration(
                  color: tokens.borderHairline,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 16),
            Text(
              'Edit name',
              style: AppType.title.copyWith(color: tokens.textPrimary),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _name,
              autofocus: true,
              textCapitalization: TextCapitalization.words,
              onChanged: (_) => setState(() {}),
              onSubmitted: (_) {
                if (_canSave && !busy) _save();
              },
              style: TextStyle(color: tokens.textPrimary),
              decoration: const InputDecoration(
                labelText: 'Your name',
                hintText: 'Your name',
              ),
            ),
            if (_tooLong) ...[
              const SizedBox(height: 8),
              Text(
                'Keep it under 30 characters.',
                style: AppType.caption.copyWith(color: tokens.accent('red').text),
              ),
            ],
            const SizedBox(height: 20),
            FilledButton(
              onPressed: (_canSave && !busy) ? _save : null,
              child: busy
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Text('Save'),
            ),
          ],
        ),
      ),
    );
  }
}
```

- [ ] **Step 4: Run the test, verify it passes**

Run: `flutter test test/features/profile/profile_edit_sheet_test.dart`
Expected: PASS (6 tests).

- [ ] **Step 5: Analyze**

Run: `flutter analyze lib/features/profile`
Expected: "No issues found!"

- [ ] **Step 6: Commit**

```bash
git add lib/features/profile/presentation/profile_edit_sheet.dart test/features/profile/profile_edit_sheet_test.dart
git commit -m "feat: ProfileEditSheet — edit display name"
```

---

## Task 6: Wire the More identity row

**Files:**
- Modify: `lib/features/settings/presentation/more_tab_screen.dart`
- Test: `test/features/settings/more_tab_screen_test.dart`

**Interfaces:**
- Consumes: `profileProvider` (Task 3), `displayNameOr` (Task 4), `ProfileEditSheet` (Task 5).
- Produces: nothing new.

**Current identity row** (in `MoreTabScreen.build`):

```dart
IosSection(
  children: [
    IosRow(
      leading: Avatar(email: email, size: 28),
      title: email == null ? 'Not signed in' : greetingName(email),
      trailingValue: email,
      showChevron: true,
      onTap: openSettings,
    ),
  ],
),
```

- [ ] **Step 1: Give `_pumpMore` optional identity overrides**

In `test/features/settings/more_tab_screen_test.dart`, add the imports:

```dart
import 'package:open_recall/features/profile/application/profile_providers.dart';
import 'package:open_recall/features/profile/domain/profile.dart';
import 'package:open_recall/features/profile/presentation/profile_edit_sheet.dart';
```

Change `_pumpMore`'s signature and add two overrides — defaults keep every
existing call (which passes no identity) on the current null-email path, so the
existing `find.text('Not signed in')` test is untouched:

```dart
Future<GoRouter> _pumpMore(
  WidgetTester tester, {
  String? email,
  String? username,
}) async {
```

In the `ProviderScope.overrides` list add:

```dart
        userIdentityProvider.overrideWithValue((email: email)),
        profileProvider.overrideWith(
          (ref) async => username == null
              ? null
              : (id: 'u1', email: email ?? 'a@b.com', username: username),
        ),
```

- [ ] **Step 2: Add the failing tests**

```dart
  testWidgets('the identity row opens the edit-name sheet, not Settings',
      (tester) async {
    await _pumpMore(tester, email: 'jeush.b@example.com', username: 'Ada Lovelace');

    await tester.tap(find.text('Ada Lovelace'));
    await tester.pumpAndSettle();

    expect(find.byType(ProfileEditSheet), findsOneWidget);
  });

  testWidgets('the identity row shows the username when one is set',
      (tester) async {
    await _pumpMore(tester, email: 'jeush.b@example.com', username: 'Ada Lovelace');
    expect(find.text('Ada Lovelace'), findsOneWidget);
  });

  testWidgets('the identity row shows the email-derived name when no username',
      (tester) async {
    await _pumpMore(tester, email: 'jeush.b@example.com');
    expect(find.text('Jeush'), findsOneWidget);
  });
```

> The existing test **"renders the profile block and the four grouped sections"** calls `_pumpMore(tester)` with no args → `email` is null → identity title stays `'Not signed in'`. Unchanged.

- [ ] **Step 3: Run the new tests, verify they fail**

Run: `flutter test test/features/settings/more_tab_screen_test.dart`
Expected: FAIL — `ProfileEditSheet` not imported into the screen / row still routes to Settings.

- [ ] **Step 4: Update the screen**

In `lib/features/settings/presentation/more_tab_screen.dart`:

Add import:

```dart
import '../../profile/presentation/profile_edit_sheet.dart';
```

(`profile_providers.dart` and `avatar.dart` are already imported.)

In `build`, add near the other `ref.watch` lines:

```dart
    final username = ref.watch(profileProvider).asData?.value?.username;
```

Replace the identity `IosRow` with:

```dart
    IosRow(
      leading: Avatar(email: email, name: username, size: 28),
      title: email == null ? 'Not signed in' : displayNameOr(username, email),
      trailingValue: email,
      showChevron: true,
      onTap: () => ProfileEditSheet.show(context, currentName: username),
    ),
```

(The `greetingName` call that was here is gone; `displayNameOr` covers the
fallback. Keep the `avatar.dart` import — `Avatar` and `displayNameOr` both come
from it.)

- [ ] **Step 5: Run the settings tests, verify green**

Run: `flutter test test/features/settings/ -r expanded`
Expected: PASS (all of them — the new tests plus the untouched existing ones).

- [ ] **Step 6: Commit**

```bash
git add lib/features/settings/presentation/more_tab_screen.dart test/features/settings/more_tab_screen_test.dart
git commit -m "feat: More identity row edits the display name (ui-spec-v5 §8)"
```

---

## Task 7: Wire the Home greeting

**Files:**
- Modify: `lib/features/home/presentation/home_tab_screen.dart`
- Test: `test/features/home/home_tab_screen_test.dart`

**Interfaces:**
- Consumes: `profileProvider` (Task 3), `displayNameOr` (Task 4).
- Produces: nothing new.

**Current** (in `HomeTabScreen.build`):

```dart
    final email = ref.watch(userIdentityProvider).email;
    ...
    return LargeTitleScaffold(
      title: 'Hello, ${greetingName(email)}',
```

- [ ] **Step 1: Add a failing test**

In `test/features/home/home_tab_screen_test.dart`, add the import:

```dart
import 'package:open_recall/features/profile/application/profile_providers.dart';
import 'package:open_recall/features/profile/domain/profile.dart';
```

Add an optional param to `pumpHome` and an override:

```dart
  Future<void> pumpHome(
    WidgetTester tester, {
    required List<DeckSummary> decks,
    required FakeStatsRepository stats,
    String? username,
  }) async {
```

and in the `overrides` list:

```dart
          profileProvider.overrideWith(
            (ref) async => username == null
                ? null
                : (id: 'u1', email: 'a@b.com', username: username),
          ),
```

Then the test:

```dart
  testWidgets('the greeting uses the username when one is set', (tester) async {
    await pumpHome(
      tester,
      decks: [_deck('d1', courseId: 'c1')],
      stats: FakeStatsRepository(),
      username: 'Ada',
    );

    expect(find.text('Hello, Ada'), findsOneWidget);
  });
```

- [ ] **Step 2: Run it, verify it fails**

Run: `flutter test test/features/home/home_tab_screen_test.dart`
Expected: FAIL — greeting still reads `Hello, ${greetingName(email)}` (email is null in tests → `Hello, there`).

- [ ] **Step 3: Update the screen**

In `lib/features/home/presentation/home_tab_screen.dart`:

Add import:

```dart
import '../../profile/application/profile_providers.dart';
```

(`avatar.dart`'s `greetingName` is already imported via `../../../ui/common/avatar.dart`.)

In `build`:

```dart
    final email = ref.watch(userIdentityProvider).email;
    final username = ref.watch(profileProvider).asData?.value?.username;
```

```dart
      title: 'Hello, ${displayNameOr(username, email)}',
```

- [ ] **Step 4: Run the home tests, verify green**

Run: `flutter test test/features/home/ -r expanded`
Expected: PASS. The existing `renders the greeting` test (`find.textContaining('Hello,')`) still holds — `displayNameOr(null, null)` → `greetingName(null)` → `there`.

- [ ] **Step 5: Commit**

```bash
git add lib/features/home/presentation/home_tab_screen.dart test/features/home/home_tab_screen_test.dart
git commit -m "feat: Home greeting uses the display name when set"
```

---

## Task 8: Full verification + doc updates

**Files:**
- Modify: `docs/ui-spec-v5-native-ios.md` (§8 note)
- Modify: `docs/superpowers/specs/2026-09-03-editable-username-design.md` (status line)

- [ ] **Step 1: Full static analysis**

Run: `flutter analyze`
Expected: "No issues found!"

- [ ] **Step 2: Full test suite**

Run: `flutter test`
Expected: all green. Any failure is almost certainly a screen that asserted the old email-derived greeting / identity title — fix it to the `displayNameOr` equivalent, do not `skip`.

- [ ] **Step 3: Update `ui-spec-v5-native-ios.md` §8**

Change the §8 "Follow-up (not this milestone)" paragraph so it covers **only** profile pictures now. Replace:

```
Editable username and user-uploaded profile pictures: add a `username` (and
`avatar_url`) column to `profiles`, a Supabase Storage `avatars` bucket with
owner-scoped RLS, an `image_picker` dependency, an edit screen pushed from the
More profile row, and a client-side downscale/compress before upload. Scoped and
built in its own session on top of v5.
```

with:

```
**Editable username — done** (`docs/superpowers/specs/2026-09-03-editable-username-design.md`):
a nullable `profiles.username`, edited from the More identity row, replacing the
email-derived name everywhere.

User-uploaded profile pictures — still deferred: add an `avatar_url` column to
`profiles`, a Supabase Storage `avatars` bucket with owner-scoped RLS, an
`image_picker` dependency, and a client-side downscale/compress before upload.
Its own session on top of v5.
```

- [ ] **Step 4: Flip the spec status**

In `docs/superpowers/specs/2026-09-03-editable-username-design.md`, change the status line to:

```
**Status:** implemented 2026-09-03
```

- [ ] **Step 5: Commit**

```bash
git add docs/
git commit -m "docs: editable username shipped; narrow ui-spec-v5 §8 to avatars"
```

- [ ] **Step 6: Manual smoke (emulator) — record, not blocking**

`flutter run`. Sign in, open More, tap the identity row → the sheet opens. Set a name → Save → the row title and the Home greeting both change; the avatar shows the new initials. Clear it → both revert to the email-derived name. (Requires the live DB to have the `username` column — see Task 1 Step 5.)

---

## Self-Review

- **Spec §1 Schema** → Task 1. ✓
- **Spec §2 Domain (`Profile`)** → Task 2 Step 1. ✓
- **Spec §3 Data (interface / Supabase impl / fake)** → Task 2. ✓
- **Spec §4 Application (`profileProvider`, `profileControllerProvider`)** → Task 3. ✓
- **Spec §5 Display-name resolution (`displayNameOr`, `initialsFrom`, `Avatar.name`)** → Task 4. ✓
- **Spec §6 Edit sheet** → Task 5. ✓
- **Spec §7 Screen wiring (More row, Home greeting)** → Tasks 6, 7. ✓
- **Spec "Data flow" / "Error handling"** → Task 3 (guard → AsyncError; fetch throw → null), Task 5 (snackbar + stay open), Tasks 6/7 (`.asData?.value` fallback). ✓
- **Spec "Testing" table** → `profile_providers_test` (Task 3), `profile_edit_sheet_test` (Task 5), `avatar_test` (Task 4), More/Home updates (Tasks 6/7). The spec's separate `profile_repository_test` was dropped during spec self-review (the interface + thin Supabase passthrough has no unit-testable logic; `FakeProfileRepository`'s contract is exercised through the provider and sheet tests). ✓
- **Spec "Out of scope"** → no task adds uniqueness, avatars, offline queueing, or new surfaces. ✓
- **Validation rules** (trim / 1–30 / whitespace→null) → Task 5 Step 3 (`_trimmed`, `_tooLong`, `_save` null coalesce) + Task 5 Step 1 tests. ✓
- **Copy constants** → asserted in Task 5 tests (`Edit name`, `Your name`, `Save`, the snackbar) and Task 6 (`Not signed in`). ✓
- **Type consistency:** `Profile` record shape `(id, email, username)` identical in Tasks 2/3/5/6/7. `setUsername(String?)`, `displayNameOr(String?, String?)`, `initialsFrom(String)`, `Avatar({email, name, size})`, `ProfileEditSheet.show(BuildContext)` — consistent across all references. ✓
