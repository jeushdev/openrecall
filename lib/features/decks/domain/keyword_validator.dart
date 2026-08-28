/// Validator for the manually-typed keyword field on the single-card form
/// (spec §3: the keyword "must be a substring of front or back").
///
/// The bulk-paste path guarantees this by construction — it lifts the keyword
/// straight out of the text — so only manual entry needs checking.
library;

/// Returns `null` when [keyword] is acceptable (empty, or appearing verbatim in
/// [front] or [back]), otherwise a short user-facing message.
///
/// Matching is case-sensitive: the keyword is blanked "as it appears" during
/// Cloze study, so a case mismatch would blank nothing.
String? keywordError(
  String keyword, {
  required String front,
  required String back,
}) {
  final trimmed = keyword.trim();
  if (trimmed.isEmpty) return null;
  if (front.contains(trimmed) || back.contains(trimmed)) return null;
  return 'Keyword must appear in the front or back text.';
}
