import 'package:open_recall/features/profile/domain/profile.dart';
import 'package:open_recall/features/profile/domain/profile_repository.dart';

/// In-memory [ProfileRepository] for widget and controller tests — runs without
/// `Supabase.initialize()`.
class FakeProfileRepository implements ProfileRepository {
  FakeProfileRepository({Profile? profile})
    : profile =
          profile ??
          (id: 'user-1', email: 'jeush.b@example.com', username: null);

  /// The row [fetch] returns and [updateUsername] mutates.
  Profile profile;

  /// Every `name` passed to [updateUsername], in order.
  final List<String?> updateUsernameCalls = <String?>[];

  /// When set, the next call throws this and then clears it.
  Object? throwOnNextCall;

  void _maybeThrow() {
    final err = throwOnNextCall;
    if (err != null) {
      throwOnNextCall = null;
      throw err;
    }
  }

  @override
  Future<Profile> fetch() async {
    _maybeThrow();
    return profile;
  }

  @override
  Future<void> updateUsername(String? name) async {
    _maybeThrow();
    updateUsernameCalls.add(name);
    profile = (id: profile.id, email: profile.email, username: name);
  }
}
