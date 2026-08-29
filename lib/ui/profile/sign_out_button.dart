import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/sync/sync_providers.dart';
import '../../features/settings/application/settings_providers.dart';
import '../../theme/app_tokens.dart';
import 'sign_out_dialog.dart';

/// The Profile tab's "Sign out" affordance (ui-spec-v1 §6.4): an outlined (not
/// filled) button whose border and label are the fixed `red` accent
/// (`#B0453A`) — deliberately not derived from any deck's course accent, so
/// "sign out" stays recognizable everywhere.
///
/// Tapping it confirms via [SignOutDialog], which warns when
/// `pendingSyncProvider` reports unsynced local writes. Confirming reuses the
/// settings feature's `accountActionsProvider.signOut()`; the router's
/// auth redirect handles navigation to `/login`.
class SignOutButton extends ConsumerWidget {
  const SignOutButton({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final red = Theme.of(context).extension<AppTokens>()!.accent('red').text;
    final busy = ref.watch(accountActionsProvider).isLoading;
    // Watched (not just read) so its value is resolved by the time of the tap.
    final hasUnsynced = ref.watch(pendingSyncProvider).asData?.value ?? false;

    return SizedBox(
      width: double.infinity,
      child: OutlinedButton(
        style: OutlinedButton.styleFrom(
          foregroundColor: red,
          side: BorderSide(color: red),
          padding: const EdgeInsets.symmetric(vertical: 14),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
        ),
        onPressed: busy ? null : () => _confirm(context, ref, hasUnsynced),
        child: const Text(
          'Sign out',
          style: TextStyle(fontWeight: FontWeight.w600),
        ),
      ),
    );
  }

  Future<void> _confirm(
    BuildContext context,
    WidgetRef ref,
    bool hasUnsynced,
  ) async {
    final confirmed = await SignOutDialog.show(
      context,
      hasUnsyncedWrites: hasUnsynced,
    );
    if (confirmed != true) return;
    await ref.read(accountActionsProvider.notifier).signOut();
  }
}
