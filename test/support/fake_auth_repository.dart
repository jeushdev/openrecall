import 'dart:async';

import 'package:open_recall/features/auth/domain/auth_repository.dart';

/// In-memory [AuthRepository] for widget, router, and controller tests.
///
/// Records every call, lets a test seed the signed-in state, drive auth-state
/// changes, and arm the next call to throw.
class FakeAuthRepository implements AuthRepository {
  FakeAuthRepository({this.signedIn = false});

  bool signedIn;
  final _controller = StreamController<bool>.broadcast();

  /// Method-name + arguments for each call, in order.
  final List<String> calls = <String>[];

  /// When set, the next repository call throws this and then clears it.
  Object? throwOnNextCall;

  @override
  bool get isSignedIn => signedIn;

  @override
  Stream<bool> authStateChanges() => _controller.stream;

  /// Flip the session state and notify listeners, as a real sign-in/out would.
  void emitSignedIn(bool value) {
    signedIn = value;
    _controller.add(value);
  }

  void _maybeThrow() {
    final error = throwOnNextCall;
    if (error != null) {
      throwOnNextCall = null;
      throw error;
    }
  }

  @override
  Future<void> signUp({required String email, required String password}) async {
    calls.add('signUp($email)');
    _maybeThrow();
    emitSignedIn(true);
  }

  @override
  Future<void> signInWithPassword({
    required String email,
    required String password,
  }) async {
    calls.add('signInWithPassword($email)');
    _maybeThrow();
    emitSignedIn(true);
  }

  @override
  Future<void> signOut() async {
    calls.add('signOut()');
    _maybeThrow();
    emitSignedIn(false);
  }

  @override
  Future<void> sendPasswordResetEmail(String email) async {
    calls.add('sendPasswordResetEmail($email)');
    _maybeThrow();
  }

  void dispose() => _controller.close();
}
