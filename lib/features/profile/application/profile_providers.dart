import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../data/supabase_profile_repository.dart';
import '../domain/profile.dart';
import '../domain/profile_repository.dart';

/// The signed-in user as the identity blocks need them (ui-spec-v1 §6.4,
/// ui-spec-v4-navigation §5). Only the email is available — there is no display
/// name anywhere in the schema, so the avatar initials and the greeting token
/// are derived from the email's local part downstream.
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
