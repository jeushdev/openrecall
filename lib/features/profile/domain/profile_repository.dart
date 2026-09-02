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
