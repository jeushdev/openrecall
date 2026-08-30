/// Validators for the manually-typed keyword chips on the card forms
/// (docs/spec-v3-card-model.md: each keyword "must be a substring of front or
/// back").
///
/// The bulk-paste path guarantees this by construction — it lifts keywords
/// straight out of the text — so only manual entry needs checking.
library;

/// Returns `null` when [keyword] is acceptable (empty, or appearing verbatim in
/// [front] or [back]), otherwise a short user-facing message. Called as each
/// chip is committed.
///
/// Matching is case-sensitive: a keyword is blanked "as it appears" during
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

/// Returns `null` when every entry of [keywords] is acceptable, otherwise the
/// first offending keyword's message. Used as the whole-field `FormField`
/// validator so a bad chip still blocks Save.
String? keywordsError(
  List<String> keywords, {
  required String front,
  required String back,
}) {
  for (final keyword in keywords) {
    final message = keywordError(keyword, front: front, back: back);
    if (message != null) return message;
  }
  return null;
}
