import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../application/settings_providers.dart';
import 'widgets/delete_account_dialog.dart';

/// Settings & account management (spec §9): account info, sign out, reminder
/// preferences, about/version, and the account-deletion flow.
class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    ref.listen(accountActionsProvider, (_, next) {
      if (next case AsyncError(:final error)) {
        ScaffoldMessenger.of(context)
          ..hideCurrentSnackBar()
          ..showSnackBar(SnackBar(content: Text('Something went wrong: $error')));
      }
    });

    final account = ref.watch(accountRepositoryProvider);
    final busy = ref.watch(accountActionsProvider).isLoading;
    final remindersEnabled = ref.watch(notificationsEnabledProvider);
    final version = ref.watch(appVersionProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Settings')),
      body: ListView(
        children: [
          const _SectionHeader('Account'),
          ListTile(
            leading: const Icon(Icons.email_outlined),
            title: const Text('Email'),
            subtitle: Text(account.currentEmail ?? 'Not signed in'),
          ),
          ListTile(
            leading: const Icon(Icons.badge_outlined),
            title: const Text('User ID'),
            subtitle: Text(account.currentUserId ?? '—'),
          ),
          ListTile(
            leading: const Icon(Icons.logout),
            title: const Text('Log out'),
            enabled: !busy,
            onTap: () => ref.read(accountActionsProvider.notifier).signOut(),
          ),
          const Divider(),

          const _SectionHeader('Notifications'),
          SwitchListTile(
            secondary: const Icon(Icons.notifications_outlined),
            title: const Text('Study reminders'),
            subtitle: const Text(
              'Nudge me a few hours after I leave cards unfinished or parked.',
            ),
            value: remindersEnabled.asData?.value ?? true,
            onChanged: remindersEnabled.isLoading
                ? null
                : (value) => ref
                    .read(notificationsEnabledProvider.notifier)
                    .setEnabled(value),
          ),
          const Divider(),

          const _SectionHeader('About'),
          ListTile(
            leading: const Icon(Icons.info_outline),
            title: const Text('Version'),
            subtitle: Text(
              version.when(
                data: (v) => v,
                loading: () => '…',
                error: (_, _) => 'unknown',
              ),
            ),
          ),
          const Divider(),

          _SectionHeader(
            'Danger zone',
            color: Theme.of(context).colorScheme.error,
          ),
          ListTile(
            leading: Icon(
              Icons.delete_forever_outlined,
              color: Theme.of(context).colorScheme.error,
            ),
            title: Text(
              'Delete account',
              style: TextStyle(color: Theme.of(context).colorScheme.error),
            ),
            subtitle: const Text(
              'Permanently removes your account and all of your decks.',
            ),
            enabled: !busy,
            onTap: () => _confirmDelete(context, ref),
          ),
        ],
      ),
    );
  }

  Future<void> _confirmDelete(BuildContext context, WidgetRef ref) async {
    final confirmed = await DeleteAccountDialog.show(context);
    if (confirmed != true) return;
    await ref.read(accountActionsProvider.notifier).deleteAccount();
  }
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader(this.label, {this.color});

  final String label;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
      child: Text(
        label.toUpperCase(),
        style: theme.textTheme.labelSmall?.copyWith(
          color: color ?? theme.colorScheme.primary,
          letterSpacing: 0.8,
        ),
      ),
    );
  }
}
