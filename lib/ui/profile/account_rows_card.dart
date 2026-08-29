import 'package:flutter/material.dart';

import '../../theme/app_geometry.dart';
import '../../theme/app_tokens.dart';

/// The "Account" / "Subscription" list card on the Profile tab (ui-spec-v1
/// §6.4). Both rows are placeholders — product hasn't specified their contents —
/// so they are non-interactive with a muted "Coming soon" trailing label.
class AccountRowsCard extends StatelessWidget {
  const AccountRowsCard({super.key});

  @override
  Widget build(BuildContext context) {
    final tokens = Theme.of(context).extension<AppTokens>()!;
    return Container(
      decoration: BoxDecoration(
        color: tokens.cardFill,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: tokens.borderHairline,
          width: AppBorders.hairline,
        ),
      ),
      child: Column(
        children: [
          _row(tokens, 'Account'),
          Divider(
            height: AppBorders.hairline,
            thickness: AppBorders.hairline,
            color: tokens.borderHairline,
          ),
          _row(tokens, 'Subscription'),
        ],
      ),
    );
  }

  Widget _row(AppTokens tokens, String label) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      child: Row(
        children: [
          Expanded(
            child: Text(
              label,
              style: TextStyle(fontSize: 15, color: tokens.textPrimary),
            ),
          ),
          Text(
            'Coming soon',
            style: TextStyle(fontSize: 13, color: tokens.textTertiary),
          ),
        ],
      ),
    );
  }
}
