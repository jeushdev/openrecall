import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

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
