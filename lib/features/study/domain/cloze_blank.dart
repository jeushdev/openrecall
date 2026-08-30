/// The placeholder shown in place of a blanked keyword during Cloze study.
const String kClozeBlank = ' _____ ';

/// One piece of a card side split for Cloze reveal: either a run of literal
/// [text], or a blank standing in for a keyword (identified by its card-wide
/// [blankIndex], counting front then back).
class ClozeSegment {
  const ClozeSegment.text(this.text) : blankIndex = null;
  const ClozeSegment.blank(this.blankIndex, this.text);

  final String text;

  /// `null` for literal text; otherwise this blank's index across the whole
  /// card (front blanks first, then back).
  final int? blankIndex;

  bool get isBlank => blankIndex != null;
}

/// Splits [text] into literal and blank [ClozeSegment]s, blanking every
/// occurrence of any entry in [keywords] (docs/spec-v3-card-model.md: "all
/// occurrences of every keyword are blanked"). Blanks are numbered from
/// [startIndex] so a card's back can continue the front's numbering. Matching
/// is a case-insensitive substring scan; at each position the earliest match
/// wins, and among ties the longest keyword. Returns the segments and the next
/// unused blank index.
(List<ClozeSegment>, int) clozeSegments(
  String text,
  List<String> keywords, {
  int startIndex = 0,
}) {
  final needles = [
    for (final k in keywords)
      if (k.trim().isNotEmpty) k.trim(),
  ];
  if (needles.isEmpty) {
    return ([ClozeSegment.text(text)], startIndex);
  }

  final lowerText = text.toLowerCase();
  final lowerNeedles = [for (final n in needles) n.toLowerCase()];
  final segments = <ClozeSegment>[];
  var start = 0;
  var index = startIndex;
  while (true) {
    var matchAt = -1;
    var matchLen = 0;
    for (final needle in lowerNeedles) {
      final at = lowerText.indexOf(needle, start);
      if (at < 0) continue;
      if (matchAt < 0 ||
          at < matchAt ||
          (at == matchAt && needle.length > matchLen)) {
        matchAt = at;
        matchLen = needle.length;
      }
    }
    if (matchAt < 0) {
      if (start < text.length) {
        segments.add(ClozeSegment.text(text.substring(start)));
      }
      break;
    }
    if (matchAt > start) {
      segments.add(ClozeSegment.text(text.substring(start, matchAt)));
    }
    segments.add(
      ClozeSegment.blank(index, text.substring(matchAt, matchAt + matchLen)),
    );
    index++;
    start = matchAt + matchLen;
  }
  return (segments, index);
}
