import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../stats/application/stats_providers.dart';
import '../../stats/domain/streak.dart';

/// The signed-in user as the Profile tab needs them (ui-spec-v1 §6.4). Only the
/// email is available — there is no display name anywhere in the schema, so the
/// avatar initials are derived from the email's local part downstream.
typedef UserIdentity = ({String? email});

/// Reads the current user's email straight off the Supabase session.
///
/// Wrapped in try/catch the same way `syncServiceProvider` is: widget tests
/// pump the app without `Supabase.initialize()`, and `Supabase.instance` throws
/// until it is initialized. A signed-out or uninitialized state simply yields a
/// null email rather than crashing the Profile screen.
final userIdentityProvider = Provider<UserIdentity>((ref) {
  try {
    return (email: Supabase.instance.client.auth.currentUser?.email);
  } catch (_) {
    return (email: null);
  }
});

/// The Profile tab's "current streak" — consecutive calendar days ending today
/// or yesterday with at least one `completed` session (ui-spec-v1 §6.4).
///
/// Derived on read from `study_sessions.started_at` via the same cache-first
/// stats repository the Mastery tab uses; never a stored counter (see
/// [currentStreak]).
final currentStreakProvider = FutureProvider<int>((ref) async {
  final starts =
      await ref.watch(statsRepositoryProvider).fetchCompletedSessionStarts();
  return currentStreak(starts);
});
