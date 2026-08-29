import 'package:supabase_flutter/supabase_flutter.dart';

import '../domain/account_repository.dart';

/// The only class in the settings feature that talks to Supabase directly.
class SupabaseAccountRepository implements AccountRepository {
  SupabaseAccountRepository(this._client);

  final SupabaseClient _client;

  GoTrueClient get _auth => _client.auth;

  @override
  String? get currentEmail => _auth.currentUser?.email;

  @override
  String? get currentUserId => _auth.currentUser?.id;

  @override
  Future<void> deleteAccount() async {
    // Throws FunctionException on a non-2xx response; let it propagate so the
    // controller surfaces an error and the account stays intact.
    await _client.functions.invoke('delete-account');
    await _auth.signOut();
  }
}
