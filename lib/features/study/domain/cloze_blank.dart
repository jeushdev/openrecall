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

/// One piece of a card side split for Cloze reveal: either a run of literal
/// [text], or a blank standing in for the keyword (identified by its
/// card-wide [blankIndex], counting front then back).
class ClozeSegment {
  const ClozeSegment.text(this.text) : blankIndex = null;
  const ClozeSegment.blank(this.blankIndex, this.text);

  final String text;

  /// `null` for literal text; otherwise this blank's index across the whole
  /// card (front blanks first, then back).
  final int? blankIndex;

  bool get isBlank => blankIndex != null;
}

/// Splits [text] into literal and blank [ClozeSegment]s, numbering blanks from
/// [startIndex] (so a card's back can continue the front's numbering). Matching
/// is the same case-insensitive substring scan [blankKeyword] uses. Returns the
/// segments and the next unused blank index.
(List<ClozeSegment>, int) clozeSegments(
  String text,
  String? keyword, {
  int startIndex = 0,
}) {
  final needle = keyword?.trim() ?? '';
  if (needle.isEmpty) {
    return ([ClozeSegment.text(text)], startIndex);
  }

  final lowerText = text.toLowerCase();
  final lowerNeedle = needle.toLowerCase();
  final segments = <ClozeSegment>[];
  var start = 0;
  var index = startIndex;
  while (true) {
    final match = lowerText.indexOf(lowerNeedle, start);
    if (match < 0) {
      if (start < text.length) {
        segments.add(ClozeSegment.text(text.substring(start)));
      }
      break;
    }
    if (match > start) {
      segments.add(ClozeSegment.text(text.substring(start, match)));
    }
    segments.add(
      ClozeSegment.blank(index, text.substring(match, match + needle.length)),
    );
    index++;
    start = match + lowerNeedle.length;
  }
  return (segments, index);
}
