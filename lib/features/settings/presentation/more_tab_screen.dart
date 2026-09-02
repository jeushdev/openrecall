import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/sync/sync_providers.dart';
import '../../../routing/app_routes.dart';
import '../../../theme/app_tokens.dart';
import '../../../theme/app_type.dart';
import '../../../ui/common/avatar.dart';
import '../../../ui/profile/sign_out_button.dart';
import '../../../ui/settings/feedback_info_dialog.dart';
import '../../profile/application/profile_providers.dart';
import '../application/settings_providers.dart';

/// The More tab (`/more`, ui-spec-v4-navigation §5) — replaces the retired
/// Profile tab and is the entry point into the pushed `/settings` route.
///
/// Top to bottom: an identity-only profile block, then four grouped sections —
/// Account (sign out), Preferences and Data (rows that push `/settings`), and
/// About (feedback dialog + app version). The streak / mastery stat blocks that
/// used to live on Profile are retired: that data is now on Home's Overall
/// Mastery card and History's log. "Delete account" stays inside the Settings
/// screen — this screen never duplicates the destructive path.
class MoreTabScreen extends ConsumerWidget {
  const MoreTabScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tokens = Theme.of(context).extension<AppTokens>()!;
    final email = ref.watch(userIdentityProvider).email;
    final version = ref.watch(appVersionProvider);
    final pending = ref.watch(pendingSyncCountProvider);

    void openSettings() => context.push(AppRoutes.settingsPath);

    return Scaffold(
      backgroundColor: tokens.background,
      body: SafeArea(
        bottom: false,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 120),
          children: [
            Text(
              'More',
              style: AppType.headline.copyWith(color: tokens.textPrimary),
            ),
            const SizedBox(height: 20),

            _ProfileBlock(email: email),
            const SizedBox(height: 28),

            _Group(
              title: 'Account',
              child: const Padding(
                padding: EdgeInsets.all(16),
                child: SignOutButton(),
              ),
            ),
            const SizedBox(height: 20),

            _Group(
              title: 'Preferences',
              child: Column(
                children: [
                  _NavRow(label: 'Notifications', onTap: openSettings),
                  _RowDivider(),
                  _NavRow(label: 'Study preferences', onTap: openSettings),
                ],
              ),
            ),
            const SizedBox(height: 20),

            _Group(
              title: 'Data',
              child: Column(
                children: [
                  _StatusRow(
                    label: 'Offline sync',
                    value: pending.when(
                      data: (n) => n == 0 ? 'Up to date' : '$n waiting to sync',
                      loading: () => '…',
                      error: (_, _) => 'Unknown',
                    ),
                  ),
                  _RowDivider(),
                  // No standalone import route exists (import is always scoped
                  // to a deck); fall back to the Settings screen per §5.3.
                  _NavRow(label: 'Export / import cards', onTap: openSettings),
                ],
              ),
            ),
            const SizedBox(height: 20),

            _Group(
              title: 'About',
              child: Column(
                children: [
                  _NavRow(
                    label: 'Help & feedback',
                    onTap: () => showFeedbackInfo(context),
                  ),
                  _RowDivider(),
                  _StatusRow(
                    label: 'Version',
                    value: version.when(
                      data: (v) => v,
                      loading: () => '…',
                      error: (_, _) => 'unknown',
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Avatar + identity lines. There is no display name in the schema, so the
/// primary line is the same greeting token Home derives from the email and the
/// email itself sits below it. No chevron — there is no edit-profile flow to
/// wire it to yet, and a dead affordance is worse than none (§5.1).
class _ProfileBlock extends StatelessWidget {
  const _ProfileBlock({required this.email});

  final String? email;

  @override
  Widget build(BuildContext context) {
    final tokens = Theme.of(context).extension<AppTokens>()!;
    final signedIn = email != null;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: tokens.cardFill,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: tokens.borderHairline),
      ),
      child: Row(
        children: [
          Avatar(email: email, size: 48),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  signedIn ? greetingName(email) : 'Not signed in',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppType.title.copyWith(color: tokens.textPrimary),
                ),
                if (signedIn) ...[
                  const SizedBox(height: 2),
                  Text(
                    email!,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AppType.body.copyWith(color: tokens.textSecondary),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// A titled section: a small heading above a hairline-bordered card holding the
/// section's rows (or, for Account, the sign-out button).
class _Group extends StatelessWidget {
  const _Group({required this.title, required this.child});

  final String title;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final tokens = Theme.of(context).extension<AppTokens>()!;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 4, bottom: 10),
          child: Text(
            title,
            style: AppType.label.copyWith(color: tokens.textSecondary),
          ),
        ),
        Container(
          decoration: BoxDecoration(
            color: tokens.cardFill,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: tokens.borderHairline),
          ),
          child: child,
        ),
      ],
    );
  }
}

class _RowDivider extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final tokens = Theme.of(context).extension<AppTokens>()!;
    return Divider(height: 1, thickness: 0.5, color: tokens.borderHairline);
  }
}

/// A tappable row with a trailing chevron.
class _NavRow extends StatelessWidget {
  const _NavRow({required this.label, required this.onTap});

  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final tokens = Theme.of(context).extension<AppTokens>()!;
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        child: Row(
          children: [
            Expanded(
              child: Text(
                label,
                style: AppType.body.copyWith(color: tokens.textPrimary),
              ),
            ),
            Icon(Icons.chevron_right, size: 20, color: tokens.textTertiary),
          ],
        ),
      ),
    );
  }
}

/// A read-only row: a label on the left, a status value on the right.
class _StatusRow extends StatelessWidget {
  const _StatusRow({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final tokens = Theme.of(context).extension<AppTokens>()!;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      child: Row(
        children: [
          Expanded(
            child: Text(
              label,
              style: AppType.body.copyWith(color: tokens.textPrimary),
            ),
          ),
          Text(
            value,
            style: AppType.caption.copyWith(color: tokens.textSecondary),
          ),
        ],
      ),
    );
  }
}
