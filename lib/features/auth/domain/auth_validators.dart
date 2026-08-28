/// Pure form-field validators shared by the Login and Sign-up screens.
///
/// Each returns `null` when the value is acceptable, or a short user-facing
/// message otherwise — the shape `TextFormField.validator` expects.
library;

final _emailPattern = RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$');

/// Minimum accepted by Supabase Auth's default password policy.
const _minPasswordLength = 6;

String? emailError(String value) {
  final trimmed = value.trim();
  if (trimmed.isEmpty) return 'Enter your email.';
  if (!_emailPattern.hasMatch(trimmed)) return 'Enter a valid email.';
  return null;
}

String? passwordError(String value) {
  if (value.isEmpty) return 'Enter your password.';
  if (value.length < _minPasswordLength) {
    return 'Password must be at least $_minPasswordLength characters.';
  }
  return null;
}
