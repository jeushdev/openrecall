import 'package:open_recall/features/settings/domain/account_repository.dart';

/// In-memory [AccountRepository] for Settings widget and controller tests —
/// runs without `Supabase.initialize()`.
class FakeAccountRepository implements AccountRepository {
  FakeAccountRepository({this.currentEmail, this.currentUserId});

  @override
  final String? currentEmail;

  @override
  final String? currentUserId;

  int deleteAccountCalls = 0;

  /// When set, [deleteAccount] throws this instead of recording the call.
  Object? throwOnDelete;

  @override
  Future<void> deleteAccount() async {
    if (throwOnDelete case final err?) throw err;
    deleteAccountCalls++;
  }
}
