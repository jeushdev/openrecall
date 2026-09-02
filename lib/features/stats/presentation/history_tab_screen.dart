import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../theme/app_tokens.dart';

/// The History tab (`/history`, ui-spec-v4-navigation §4) — replaces the
/// retired Mastery tab.
///
/// U16 ships this as an empty placeholder so the routing shell compiles and is
/// navigable. The real layout (calendar heatmap, All/By Deck toggle, merged
/// session log) lands in U18.
class HistoryTabScreen extends ConsumerWidget {
  const HistoryTabScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tokens = Theme.of(context).extension<AppTokens>()!;
    return Scaffold(
      backgroundColor: tokens.background,
      body: SafeArea(
        bottom: false,
        child: Center(
          child: Text(
            'History',
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
