import 'package:flutter/material.dart';

import '../../theme/app_tokens.dart';
import '../common/avatar.dart';

export '../common/avatar.dart' show emailInitials;

/// Avatar + email at the top of the Profile tab (ui-spec-v1 §6.4).
///
/// There is no display name anywhere in the schema, so the circle shows
/// initials derived from the email's local part and the email is the only
/// identity line.
class ProfileIdentityHeader extends StatelessWidget {
  const ProfileIdentityHeader({super.key, required this.email});

  final String? email;

  @override
  Widget build(BuildContext context) {
    final tokens = Theme.of(context).extension<AppTokens>()!;

    return Row(
      children: [
        Avatar(email: email),
        const SizedBox(width: 14),
        Expanded(
          child: Text(
            email ?? 'Not signed in',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w600,
              color: tokens.textPrimary,
            ),
          ),
        ),
      ],
    );
  }
}
