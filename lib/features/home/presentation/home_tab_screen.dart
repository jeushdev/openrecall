import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../theme/app_tokens.dart';

/// The Home tab (`/home`, ui-spec-v4-navigation §3) — the shell's default
/// branch.
///
/// U16 ships this as an empty placeholder so the routing shell compiles and is
/// navigable. The real layout (greeting header, Overall Mastery card,
/// Unfinished Sessions, Most Reviewed Decks) lands in U17.
class HomeTabScreen extends ConsumerWidget {
  const HomeTabScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tokens = Theme.of(context).extension<AppTokens>()!;
    return Scaffold(
      backgroundColor: tokens.background,
      body: SafeArea(
        bottom: false,
        child: Center(
          child: Text(
            'Home',
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
