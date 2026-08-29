import 'package:flutter/material.dart';

import '../../theme/app_tokens.dart';

/// A titled group of rows on the Settings tab (ui-spec-v1 §6.5). The title
/// matches the Mastery tab's `MasterySectionHeader` weight so the two screens
/// read as one family.
class SettingsSection extends StatelessWidget {
  const SettingsSection({
    super.key,
    required this.title,
    required this.children,
  });

  final String title;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    final tokens = Theme.of(context).extension<AppTokens>()!;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: TextStyle(
            fontSize: 17,
            fontWeight: FontWeight.w700,
            color: tokens.textPrimary,
          ),
        ),
        const SizedBox(height: 12),
        ...children,
      ],
    );
  }
}
