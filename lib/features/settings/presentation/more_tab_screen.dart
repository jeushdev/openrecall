import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/sync/sync_providers.dart';
import '../../../routing/app_routes.dart';
import '../../../ui/common/avatar.dart';
import '../../../ui/common/ios_list.dart';
import '../../../ui/common/large_title_scaffold.dart';
import '../../../ui/profile/sign_out_dialog.dart';
import '../../../ui/settings/feedback_info_dialog.dart';
import '../../profile/application/profile_providers.dart';
import '../../profile/presentation/profile_edit_sheet.dart';
import '../application/settings_providers.dart';

/// The More tab (`/more`, ui-spec-v4-navigation §5; restyled ui-spec-v5 §6.6) —
/// replaces the retired Profile tab and is the entry point into the pushed
/// `/settings` route.
///
/// A large-title shell over iOS grouped-inset lists: a single tappable identity
/// row that pushes `/settings`, then Account (sign out), Preferences and Data
/// (rows that push `/settings`), and About (feedback dialog + app version). The
/// streak / mastery stat blocks that used to live on Profile are retired — that
/// data is now on Home's Overall Mastery card and History's log. "Delete
/// account" stays inside the Settings screen; this screen never duplicates the
/// destructive path.
class MoreTabScreen extends ConsumerWidget {
  const MoreTabScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final email = ref.watch(userIdentityProvider).email;
    final username = ref.watch(profileProvider).asData?.value?.username;
    final version = ref.watch(appVersionProvider);
    final pending = ref.watch(pendingSyncCountProvider);

    void openSettings() => context.push(AppRoutes.settingsPath);

    return LargeTitleScaffold(
      title: 'More',
      contentPadding: EdgeInsets.zero,
      slivers: [
        SliverToBoxAdapter(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const SizedBox(height: 8),

              // Identity. Tapping the row opens the edit-name sheet; the title
              // is the user-set display name when there is one, else the
              // greeting token derived from the email (see `displayNameOr`).
              IosSection(
                children: [
                  IosRow(
                    leading: Avatar(email: email, name: username, size: 28),
                    title: email == null
                        ? 'Not signed in'
                        : displayNameOr(username, email),
                    trailingValue: email,
                    showChevron: true,
                    onTap: () =>
                        ProfileEditSheet.show(context, currentName: username),
                  ),
                ],
              ),
              const SizedBox(height: 28),

              const IosSection(
                header: 'Account',
                children: [_SignOutRow()],
              ),
              const SizedBox(height: 20),

              IosSection(
                header: 'Preferences',
                children: [
                  IosRow(
                    title: 'Notifications',
                    showChevron: true,
                    onTap: openSettings,
                  ),
                  IosRow(
                    title: 'Study preferences',
                    showChevron: true,
                    onTap: openSettings,
                  ),
                ],
              ),
              const SizedBox(height: 20),

              IosSection(
                header: 'Data',
                children: [
                  IosRow(
                    title: 'Offline sync',
                    trailingValue: pending.when(
                      data: (n) => n == 0 ? 'Up to date' : '$n waiting to sync',
                      loading: () => '…',
                      error: (_, _) => 'Unknown',
                    ),
                  ),
                  // No standalone import route exists (import is always scoped
                  // to a deck); fall back to the Settings screen per §5.3.
                  IosRow(
                    title: 'Export / import cards',
                    showChevron: true,
                    onTap: openSettings,
                  ),
                ],
              ),
              const SizedBox(height: 20),

              IosSection(
                header: 'About',
                children: [
                  IosRow(
                    title: 'Help & feedback',
                    showChevron: true,
                    onTap: () => showFeedbackInfo(context),
                  ),
                  IosRow(
                    title: 'Version',
                    trailingValue: version.when(
                      data: (v) => v,
                      loading: () => '…',
                      error: (_, _) => 'unknown',
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 120),
            ],
          ),
        ),
      ],
    );
  }
}

/// "Sign out" as a grouped-list row. Carries the same confirm flow the old
/// `SignOutButton` did: [SignOutDialog] warns when `pendingSyncProvider` reports
/// unsynced local writes, and confirming calls `accountActionsProvider.signOut()`
/// — the router's auth redirect handles navigation to `/login`.
class _SignOutRow extends ConsumerWidget {
  const _SignOutRow();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final busy = ref.watch(accountActionsProvider).isLoading;
    final hasUnsynced = ref.watch(pendingSyncProvider).asData?.value ?? false;

    return IosRow(
      title: 'Sign out',
      onTap: busy
          ? null
          : () async {
              final confirmed = await SignOutDialog.show(
                context,
                hasUnsyncedWrites: hasUnsynced,
              );
              if (confirmed != true) return;
              await ref.read(accountActionsProvider.notifier).signOut();
            },
    );
  }
}
