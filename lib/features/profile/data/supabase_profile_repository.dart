import 'package:supabase_flutter/supabase_flutter.dart';

import '../domain/profile.dart';
import '../domain/profile_repository.dart';

/// The only class in the profile feature that talks to Supabase directly.
class SupabaseProfileRepository implements ProfileRepository {
  SupabaseProfileRepository(this._client);

  final SupabaseClient _client;

  @override
  Future<Profile> fetch() async {
    final user = _client.auth.currentUser;
    if (user == null) {
      throw StateError('No signed-in user to load a profile for.');
    }
    final row = await _client
        .from('profiles')
        .select('id, email, username')
        .eq('id', user.id)
        .single();
    return (
      id: row['id'] as String,
      email: row['email'] as String,
      username: row['username'] as String?,
    );
  }

  @override
  Future<void> updateUsername(String? name) async {
    final user = _client.auth.currentUser;
    if (user == null) {
      throw StateError('No signed-in user to update.');
    }
    await _client.from('profiles').update({'username': name}).eq('id', user.id);
  }
}
