// On-device fuzzy matching for Cloze answers (spec §5B). Plain string work —
// no network, ever (spec "Performance & Responsiveness").

/// The classic dynamic-programming Levenshtein edit distance between [a] and
/// [b]: the fewest single-character insertions, deletions, or substitutions
/// that turn one into the other.
int levenshtein(String a, String b) {
  if (a == b) return 0;
  if (a.isEmpty) return b.length;
  if (b.isEmpty) return a.length;

  final aRunes = a.runes.toList();
  final bRunes = b.runes.toList();
  var prev = List<int>.generate(bRunes.length + 1, (i) => i);
  var curr = List<int>.filled(bRunes.length + 1, 0);

  for (var i = 1; i <= aRunes.length; i++) {
    curr[0] = i;
    for (var j = 1; j <= bRunes.length; j++) {
      final cost = aRunes[i - 1] == bRunes[j - 1] ? 0 : 1;
      curr[j] = _min3(
        curr[j - 1] + 1, // insertion
        prev[j] + 1, // deletion
        prev[j - 1] + cost, // substitution / match
      );
    }
    final swap = prev;
    prev = curr;
    curr = swap;
  }
  return prev[bRunes.length];
}

int _min3(int a, int b, int c) => a < b ? (a < c ? a : c) : (b < c ? b : c);

/// Normalises a Cloze answer or keyword before comparison: trims, lowercases,
/// and strips leading/trailing punctuation and quotes (so `"cell."` matches
/// `cell`). Internal punctuation and spacing are left alone.
String normalizeClozeAnswer(String value) {
  final lowered = value.trim().toLowerCase();
  return lowered.replaceAll(_edgePunctuation, '');
}

final RegExp _edgePunctuation = RegExp(r'''^[\s"'“”‘’.,;:!?()\[\]{}\-–—]+|[\s"'“”‘’.,;:!?()\[\]{}\-–—]+$''');

/// Whether [actual] is close enough to [expected] to accept as correct
/// (spec §5B "accept minor typos"). After normalisation: an exact match always
/// passes; otherwise the edit distance must be within a length-tiered budget —
/// 1 for keywords of 6 characters or fewer, 2 for 7 or more. An empty answer
/// never matches.
bool isClozeMatch(String expected, String actual) {
  final e = normalizeClozeAnswer(expected);
  final a = normalizeClozeAnswer(actual);
  if (a.isEmpty) return false;
  if (e == a) return true;
  final budget = e.length <= 6 ? 1 : 2;
  return levenshtein(e, a) <= budget;
}
