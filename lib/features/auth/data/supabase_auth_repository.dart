import 'dart:async';

import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/connectivity/connectivity_service.dart';
import '../domain/auth_repository.dart';
import '../domain/offline_session_grace.dart';

/// The only class in the app that talks to Supabase Auth directly.
///
/// It layers an [OfflineSessionGrace] over gotrue: if a cached token can't be
/// refreshed because the device is offline, gotrue drops the session but this
/// repository keeps reporting [isSignedIn] `true` so the router does not bounce
/// the user to Login (design spec §E.1). The grace clears itself on the next
/// real auth event.
class SupabaseAuthRepository implements AuthRepository {
  SupabaseAuthRepository(this._auth, {ConnectivityService? connectivity}) {
    if (connectivity != null) {
      // Cache the connectivity state so it can be read synchronously when an
      // auth event arrives.
      connectivity.isOnline().then((v) => _online = v).catchError((_) {
        _online = true;
        return true;
      });
      _connSub = connectivity.onStatusChange.listen((v) => _online = v);
    }
    _authSub = _auth.onAuthStateChange.listen((state) {
      _grace.onAuthState(state, offline: !_online);
      _stateController.add(isSignedIn);
    });
  }

  final GoTrueClient _auth;
  final OfflineSessionGrace _grace = OfflineSessionGrace();
  final StreamController<bool> _stateController =
      StreamController<bool>.broadcast();

  bool _online = true;
  StreamSubscription<Object?>? _authSub;
  StreamSubscription<bool>? _connSub;

  @override
  bool get isSignedIn => _auth.currentSession != null || _grace.isActive;

  @override
  Stream<bool> authStateChanges() => _stateController.stream;

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
  Future<void> signOut() {
    // A deliberate sign-out must never be caught by the offline grace.
    _grace.clear();
    return _auth.signOut();
  }

  @override
  Future<void> sendPasswordResetEmail(String email) {
    return _auth.resetPasswordForEmail(email);
  }

  /// Releases the auth- and connectivity-state subscriptions.
  void dispose() {
    _authSub?.cancel();
    _connSub?.cancel();
    _stateController.close();
  }
}
