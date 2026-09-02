import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../theme/app_tokens.dart';

/// The More tab (`/more`, ui-spec-v4-navigation §5) — replaces the retired
/// Profile tab and is the entry point into the pushed `/settings` route.
///
/// U16 ships this as an empty placeholder so the routing shell compiles and is
/// navigable. The real layout (profile block, Account / Preferences / Data /
/// About groups) lands in U19.
class MoreTabScreen extends ConsumerWidget {
  const MoreTabScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tokens = Theme.of(context).extension<AppTokens>()!;
    return Scaffold(
      backgroundColor: tokens.background,
      body: SafeArea(
        bottom: false,
        child: Center(
          child: Text(
            'More',
            style: TextStyle(
              fontSize: 28,
              fontWeight: FontWeight.w700,
              color: tokens.textPrimary,
            ),
          ),
        ),
      ),
    );
  }
}
