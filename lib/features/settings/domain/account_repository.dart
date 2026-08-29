/// The app's window onto the current user's account (spec §9).
///
/// Everything outside [SupabaseAccountRepository] talks to account data through
/// this interface — never `Supabase.instance` directly — so widget tests can run
/// against a fake without `Supabase.initialize()`.
abstract interface class AccountRepository {
  /// The signed-in user's email, or `null` if there is no session.
  String? get currentEmail;

  /// The signed-in user's UUID, or `null` if there is no session.
  String? get currentUserId;

  /// Permanently deletes the account via the `delete-account` Edge Function
  /// (the client SDK can't remove a user's own `auth.users` row). All decks,
  /// cards and sessions cascade away through the schema's FKs. Signs out on
  /// success so the router falls back to Login.
  Future<void> deleteAccount();
}
