/// UI-only severity banding for the Mastery tab's "Troublemaker cards" list
/// (ui-spec-v1 §6.3).
///
/// **This is not an engine concept.** `cards.fail_count` is a raw lifetime
/// counter with no product-defined thresholds; these bands exist purely to tint
/// the list so the worst offenders stand out. The breakpoints below can be
/// retuned freely without touching any engine field, migration, or query —
/// nothing downstream reads them.
library;

/// `fail_count` at or above this is [TroublemakerSeverity.high] (red-tinted).
const int highSeverityFailCount = 5;

/// `fail_count` at or above this (but below [highSeverityFailCount]) is
/// [TroublemakerSeverity.moderate] (amber-tinted).
const int moderateSeverityFailCount = 3;

enum TroublemakerSeverity { none, moderate, high }

/// Maps a card's lifetime [failCount] to its display band. Below
/// [moderateSeverityFailCount] there is no badge at all.
TroublemakerSeverity severityFor(int failCount) {
  if (failCount >= highSeverityFailCount) return TroublemakerSeverity.high;
  if (failCount >= moderateSeverityFailCount) {
    return TroublemakerSeverity.moderate;
  }
  return TroublemakerSeverity.none;
}
