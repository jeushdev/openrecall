import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/connectivity/connectivity_service.dart';
import '../data/supabase_auth_repository.dart';
import '../domain/auth_repository.dart';

/// The live repository is backed by the initialized Supabase singleton. Tests
/// override this with a fake, so nothing else in the app imports `Supabase`.
final authRepositoryProvider = Provider<AuthRepository>((ref) {
  final repo = SupabaseAuthRepository(
    Supabase.instance.client.auth,
    connectivity: ref.watch(connectivityServiceProvider),
  );
  ref.onDispose(repo.dispose);
  return repo;
});

/// Emits `true`/`false` as the session appears or clears. The router listens to
/// this to re-run its redirect.
final authStateChangesProvider = StreamProvider<bool>((ref) {
  return ref.watch(authRepositoryProvider).authStateChanges();
});

/// Drives the auth screens' buttons: `isLoading` disables them, `hasError`
/// feeds the SnackBar. Holds no value of its own — it only tracks the
/// in-flight state of the most recent action.
final authControllerProvider = AsyncNotifierProvider<AuthController, void>(
  AuthController.new,
);

class AuthController extends AsyncNotifier<void> {
  @override
  FutureOr<void> build() {}

  AuthRepository get _repo => ref.read(authRepositoryProvider);

  Future<void> _run(Future<void> Function() action) async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(action);
  }

  Future<void> signIn({required String email, required String password}) {
    return _run(
      () => _repo.signInWithPassword(email: email, password: password),
    );
  }

  Future<void> signUp({required String email, required String password}) {
    return _run(() => _repo.signUp(email: email, password: password));
  }

  Future<void> signOut() => _run(_repo.signOut);

  Future<void> sendResetEmail(String email) {
    return _run(() => _repo.sendPasswordResetEmail(email));
  }
}
