/// The app's window onto Supabase Auth.
///
/// Everything outside [SupabaseAuthRepository] and `main.dart` talks to auth
/// through this interface — never `Supabase.instance` directly — so widget and
/// router tests can run against a fake without `Supabase.initialize()`.
abstract interface class AuthRepository {
  /// Whether a session currently exists (restored from storage or just created).
  bool get isSignedIn;

  /// Emits the new [isSignedIn] value whenever the session appears or clears.
  Stream<bool> authStateChanges();

  /// Creates an account. With email confirmation disabled (beta), this also
  /// establishes a session, so [isSignedIn] flips to `true`.
  Future<void> signUp({required String email, required String password});

  Future<void> signInWithPassword({
    required String email,
    required String password,
  });

  Future<void> signOut();

  /// Sends Supabase's built-in password-reset email. The link opens Supabase's
  /// hosted reset page (no in-app deep link this milestone).
  Future<void> sendPasswordResetEmail(String email);
}
