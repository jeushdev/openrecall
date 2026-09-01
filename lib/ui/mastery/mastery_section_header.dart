import 'package:flutter/material.dart';

import '../../theme/app_tokens.dart';

/// The shared section title on the Mastery tab (ui-spec-v1 §6.3), so
/// "Deck completions" and "Recent activity" read as one family.
class MasterySectionHeader extends StatelessWidget {
  const MasterySectionHeader({super.key, required this.title});

  final String title;

  @override
  Widget build(BuildContext context) {
    final tokens = Theme.of(context).extension<AppTokens>()!;
    return Text(
      title,
      style: TextStyle(
        fontSize: 17,
        fontWeight: FontWeight.w700,
        color: tokens.textPrimary,
      ),
    );
  }
}
