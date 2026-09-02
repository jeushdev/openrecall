import 'package:flutter/material.dart';

import '../../theme/app_tokens.dart';

/// The circular initials avatar, shared by the Home greeting header and the
/// Profile / More identity blocks. There is no image or display name anywhere
/// in the schema, so it is always initials on an `amber` fill.
class Avatar extends StatelessWidget {
  const Avatar({super.key, required this.email, this.size = 56});

  final String? email;
  final double size;

  @override
  Widget build(BuildContext context) {
    final tokens = Theme.of(context).extension<AppTokens>()!;
    final amber = tokens.accent('amber');
    return Container(
      width: size,
      height: size,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: amber.fill.withValues(alpha: 0.35),
        shape: BoxShape.circle,
      ),
      child: Text(
        emailInitials(email),
        style: TextStyle(
          fontSize: size * 0.32,
          fontWeight: FontWeight.w700,
          color: amber.text,
        ),
      ),
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

/// A first-name-ish greeting token from [email]'s local part: the first
/// `.`/`_`/`-`-separated chunk, title-cased, e.g. `jeush.b@x` → `Jeush`. Falls
/// back to `there` ("Hello there") for a null or symbol-only address.
String greetingName(String? email) {
  if (email == null) return 'there';
  final local = email.split('@').first;
  final first = local.split(RegExp('[._-]')).firstWhere(
        (p) => p.replaceAll(RegExp('[^A-Za-z0-9]'), '').isNotEmpty,
        orElse: () => '',
      );
  final cleaned = first.replaceAll(RegExp('[^A-Za-z0-9]'), '');
  if (cleaned.isEmpty) return 'there';
  return cleaned[0].toUpperCase() + cleaned.substring(1).toLowerCase();
}
