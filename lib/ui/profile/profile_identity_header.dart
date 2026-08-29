import 'package:flutter/material.dart';

import '../../theme/app_tokens.dart';

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
    final amber = tokens.accent('amber');

    return Row(
      children: [
        Container(
          width: 56,
          height: 56,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: amber.fill.withValues(alpha: 0.35),
            shape: BoxShape.circle,
          ),
          child: Text(
            emailInitials(email),
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w700,
              color: amber.text,
            ),
          ),
        ),
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

/// Up to two uppercase alphanumeric characters from the start of [email]'s
/// local part, e.g. `jeush.b@example.com` → `JE`. Falls back to `?` for a null,
/// empty, or symbol-only address.
String emailInitials(String? email) {
  if (email == null) return '?';
  final local = email.split('@').first;
  final letters = local.replaceAll(RegExp('[^A-Za-z0-9]'), '');
  if (letters.isEmpty) return '?';
  return letters.substring(0, letters.length >= 2 ? 2 : 1).toUpperCase();
}
