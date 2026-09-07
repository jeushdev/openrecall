import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/cache/stale_first.dart';
import '../../../core/local_db/local_db_providers.dart';
import '../data/supabase_profile_repository.dart';
import '../domain/profile.dart';
import '../domain/profile_repository.dart';

/// The signed-in user's auth identity. The profile username is loaded
/// separately through [profileProvider].
typedef UserIdentity = ({String? email});

/// Reads the current user's email straight off the Supabase session.
///
/// Wrapped in try/catch the same way `syncServiceProvider` is: widget tests
/// pump the app without `Supabase.initialize()`, and `Supabase.instance` throws
/// until it is initialized. A signed-out or uninitialized state simply yields a
/// null email rather than crashing the screen that reads it.
final userIdentityProvider = Provider<UserIdentity>((ref) {
  try {
    return (email: Supabase.instance.client.auth.currentUser?.email);
  } catch (_) {
    return (email: null);
  }
});

/// The live repository is backed by the initialized Supabase singleton. Tests
/// override this with [FakeProfileRepository], so nothing else imports
/// `Supabase` for profile data.
final profileRepositoryProvider = Provider<ProfileRepository>((ref) {
  return SupabaseProfileRepository(Supabase.instance.client);
});

/// The current profile is restored from SQLite first and refreshed in the
/// background. A failed refresh never replaces a cached username. With no
/// SQLite this remains the previous online-only nullable read.
class _ProfileSnapshot {
  const _ProfileSnapshot(this.value);
  final Profile? value;
}

final profileProvider = StreamProvider<Profile?>((ref) {
  final cache = ref.watch(applicationCacheProvider);
  final repository = ref.watch(profileRepositoryProvider);
  return staleFirst<_ProfileSnapshot>(
    cached: () async {
      final profile = await cache.profile();
      return profile == null ? null : _ProfileSnapshot(profile);
    },
    remote: () async {
      final profile = await repository.fetch();
      await cache.saveProfile(profile);
      return _ProfileSnapshot(profile);
    },
    noCacheErrorFallback: const _ProfileSnapshot(null),
  ).map((snapshot) => snapshot.value);
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
      final cache = ref.read(applicationCacheProvider);
      final current =
          ref.read(profileProvider).asData?.value ?? await cache.profile();
      if (current != null) {
        await cache.saveProfile((
          id: current.id,
          email: current.email,
          username: name,
        ));
      }
      ref.invalidate(profileProvider);
    });
  }
}
