import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../features/profile/application/profile_providers.dart';
import '../../features/settings/application/settings_providers.dart';
import '../../theme/app_tokens.dart';
import 'account_rows_card.dart';
import 'profile_identity_header.dart';
import 'profile_metrics_section.dart';
import 'profile_stats_row.dart';
import 'sign_out_button.dart';

/// The Profile tab (`/profile`, ui-spec-v1 §6.4).
///
/// Identity (avatar + email), the streak / mastery stat blocks, the Study habits
/// metrics block (milestone D), placeholder Account/Subscription rows, and the
/// outlined "Sign out" button.
/// No leave/close affordance — Profile is a shell-branch tab, the bottom nav
/// bar is the way back.
class ProfileTabScreen extends ConsumerWidget {
  const ProfileTabScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tokens = Theme.of(context).extension<AppTokens>()!;
    final email = ref.watch(userIdentityProvider).email;

    // Surface a failed sign-out the same way the legacy settings screen does.
    ref.listen(accountActionsProvider, (_, next) {
      if (next case AsyncError(:final error)) {
        ScaffoldMessenger.of(context)
          ..hideCurrentSnackBar()
          ..showSnackBar(
            SnackBar(content: Text("Couldn't sign out: $error")),
          );
      }
    });

    return Scaffold(
      backgroundColor: tokens.background,
      body: SafeArea(
        bottom: false,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 120),
          children: [
            Text(
              'Profile',
              style: TextStyle(
                fontSize: 28,
                fontWeight: FontWeight.w700,
                color: tokens.textPrimary,
              ),
            ),
            const SizedBox(height: 20),
            ProfileIdentityHeader(email: email),
            const SizedBox(height: 24),
            const ProfileStatsRow(),
            const SizedBox(height: 24),
            const ProfileMetricsSection(),
            const SizedBox(height: 24),
            const AccountRowsCard(),
            const SizedBox(height: 32),
            const SignOutButton(),
          ],
        ),
      ),
    );
  }
}
