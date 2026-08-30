import 'package:flutter/foundation.dart';

import 'levenshtein.dart';

/// How one run of characters in a Cloze attempt relates to the expected
/// keyword (spec §5B "letter-by-letter diff feedback").
enum DiffOp {
  /// Present and equal in both the attempt and the keyword.
  match,

  /// The attempt has a different character where the keyword has one.
  wrong,

  /// The keyword has a character the attempt left out.
  missing,

  /// The attempt has a character the keyword does not.
  extra,
}

/// One contiguous run of characters sharing a [DiffOp]. For [DiffOp.missing]
/// the [text] is the keyword's characters; otherwise it is the attempt's.
@immutable
class DiffSegment {
  const DiffSegment(this.text, this.op);

  final String text;
  final DiffOp op;

  @override
  bool operator ==(Object other) =>
      other is DiffSegment && other.text == text && other.op == op;

  @override
  int get hashCode => Object.hash(text, op);
}

/// Aligns the user's [actual] answer against the [expected] keyword via a
/// Levenshtein edit-distance backtrace and returns the alignment as merged
/// [DiffSegment] runs. Both sides are normalised first
/// (see [normalizeClozeAnswer]), so the diff reflects the same comparison
/// [isClozeMatch] makes.
List<DiffSegment> letterDiff(String expected, String actual) {
  final e = normalizeClozeAnswer(expected).runes.toList();
  final a = normalizeClozeAnswer(actual).runes.toList();

  // dp[i][j] = edit distance between e[0..i) and a[0..j).
  final dp = List.generate(
    e.length + 1,
    (i) => List<int>.filled(a.length + 1, 0),
  );
  for (var i = 0; i <= e.length; i++) {
    dp[i][0] = i;
  }
  for (var j = 0; j <= a.length; j++) {
    dp[0][j] = j;
  }
  for (var i = 1; i <= e.length; i++) {
    for (var j = 1; j <= a.length; j++) {
      final cost = e[i - 1] == a[j - 1] ? 0 : 1;
      final sub = dp[i - 1][j - 1] + cost;
      final del = dp[i - 1][j] + 1;
      final ins = dp[i][j - 1] + 1;
      dp[i][j] = sub < del ? (sub < ins ? sub : ins) : (del < ins ? del : ins);
    }
  }

  // Backtrace, emitting one op per step, then reverse and merge.
  final ops = <(DiffOp, String)>[];
  var i = e.length;
  var j = a.length;
  while (i > 0 || j > 0) {
    if (i > 0 && j > 0) {
      final cost = e[i - 1] == a[j - 1] ? 0 : 1;
      if (dp[i][j] == dp[i - 1][j - 1] + cost) {
        ops.add((
          cost == 0 ? DiffOp.match : DiffOp.wrong,
          String.fromCharCode(a[j - 1]),
        ));
        i--;
        j--;
        continue;
      }
    }
    if (i > 0 && dp[i][j] == dp[i - 1][j] + 1) {
      ops.add((DiffOp.missing, String.fromCharCode(e[i - 1])));
      i--;
      continue;
    }
    ops.add((DiffOp.extra, String.fromCharCode(a[j - 1])));
    j--;
  }

  final segments = <DiffSegment>[];
  for (final (op, char) in ops.reversed) {
    if (segments.isNotEmpty && segments.last.op == op) {
      final merged = segments.removeLast();
      segments.add(DiffSegment(merged.text + char, op));
    } else {
      segments.add(DiffSegment(char, op));
    }
  }
  return segments;
}
