/// The placeholder shown in place of the blanked keyword during Cloze study.
const String kClozeBlank = ' _____ ';

/// Replaces every occurrence of [keyword] in [text] with [kClozeBlank],
/// case-insensitively (spec §5B: "blanks the single keyword wherever it
/// appears" — §3: "every occurrence gets blanked"). Matching is a plain
/// substring scan, so a keyword that also appears mid-word is still blanked —
/// consistent with how the keyword was validated as a substring of the card
/// text. Returns [text] unchanged when [keyword] is null or blank.
String blankKeyword(String text, String? keyword) {
  final needle = keyword?.trim() ?? '';
  if (needle.isEmpty) return text;

  final lowerText = text.toLowerCase();
  final lowerNeedle = needle.toLowerCase();
  final buffer = StringBuffer();
  var start = 0;
  while (true) {
    final match = lowerText.indexOf(lowerNeedle, start);
    if (match < 0) {
      buffer.write(text.substring(start));
      break;
    }
    buffer
      ..write(text.substring(start, match))
      ..write(kClozeBlank);
    start = match + lowerNeedle.length;
  }
  return buffer.toString();
}
