import 'package:supabase_flutter/supabase_flutter.dart';

import '../domain/auth_repository.dart';

/// The only class in the app that talks to Supabase Auth directly.
class SupabaseAuthRepository implements AuthRepository {
  SupabaseAuthRepository(this._auth);

  final GoTrueClient _auth;

  @override
  bool get isSignedIn => _auth.currentSession != null;

  @override
  Stream<bool> authStateChanges() =>
      _auth.onAuthStateChange.map((state) => state.session != null);

  @override
  Future<void> signUp({required String email, required String password}) {
    return _auth.signUp(email: email, password: password);
  }

  @override
  Future<void> signInWithPassword({
    required String email,
    required String password,
  }) {
    return _auth.signInWithPassword(email: email, password: password);
  }

  @override
  Future<void> signOut() => _auth.signOut();

  @override
  Future<void> sendPasswordResetEmail(String email) {
    return _auth.resetPasswordForEmail(email);
  }
}
