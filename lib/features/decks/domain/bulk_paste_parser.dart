/// Pure parser for the Deck Creator's bulk-paste box (spec §3).
///
/// Input is free text, one card per line, in `FRONT | BACK` form. Any number of
/// keywords can be marked inline with `{{double braces}}` on either side; the
/// parser lifts each into [ParsedCard.keywords] (front markers first, then
/// back, in reading order) and strips the braces from the stored text, so
/// however a card was entered, what ends up stored is identical — clean text
/// plus a separate list of keyword values. (R5 adds a multi-line block format
/// with a `[concept]` tag.)
///
/// Nothing here touches the network or the database — it only turns text into
/// a [BulkParseResult] the UI can preview and the repository can insert.
library;

/// One line of parsed bulk-paste input: either a [ParsedCard] or a
/// [ParseFailure]. Blank lines produce neither — they are skipped entirely.
sealed class BulkParseLine {
  const BulkParseLine({required this.lineNumber, required this.raw});

  /// 1-based line number in the original text, for the preview to reference.
  final int lineNumber;

  /// The original, untrimmed line — so a failing line can be shown back to the
  /// user verbatim for correction.
  final String raw;
}

/// A line that parsed into a usable card.
class ParsedCard extends BulkParseLine {
  const ParsedCard({
    required super.lineNumber,
    required super.raw,
    required this.front,
    required this.back,
    this.keywords = const [],
    this.isConcept = false,
  });

  final String front;
  final String back;

  /// The `{{ }}`-marked Cloze keywords, in reading order (front markers first,
  /// then back). Zero or more per card.
  final List<String> keywords;

  /// Whether this card is a Feynman concept. Always `false` from the current
  /// single-line bulk format (R5 adds a `[concept]` tag).
  final bool isConcept;
}

/// A line that could not be parsed, with a user-facing reason. Never dropped
/// silently (spec §3 / "Error states").
class ParseFailure extends BulkParseLine {
  const ParseFailure({
    required super.lineNumber,
    required super.raw,
    required this.reason,
  });

  final String reason;
}

/// The outcome of parsing a whole bulk-paste blob.
class BulkParseResult {
  const BulkParseResult(this.lines);

  final List<BulkParseLine> lines;

  Iterable<ParsedCard> get cards => lines.whereType<ParsedCard>();
  Iterable<ParseFailure> get failures => lines.whereType<ParseFailure>();

  int get readyCount => cards.length;
  int get failureCount => failures.length;
}

final _keywordPattern = RegExp(r'\{\{(.*?)\}\}');

/// Parses [raw] into a [BulkParseResult]. See the library doc for the rules.
BulkParseResult parseBulkPaste(String raw) {
  final lines = <BulkParseLine>[];
  final rawLines = raw.split('\n');

  for (var i = 0; i < rawLines.length; i++) {
    final lineNumber = i + 1;
    final line = rawLines[i];
    if (line.trim().isEmpty) continue;

    final pipe = line.indexOf('|');
    if (pipe < 0) {
      lines.add(ParseFailure(
        lineNumber: lineNumber,
        raw: line,
        reason: 'Missing a "|" separator between the front and back.',
      ));
      continue;
    }

    var front = line.substring(0, pipe).trim();
    var back = line.substring(pipe + 1).trim();

    final markers = _keywordPattern
        .allMatches(front)
        .followedBy(_keywordPattern.allMatches(back))
        .toList();

    final keywords = [
      for (final m in markers) m.group(1)!.trim(),
    ]..removeWhere((k) => k.isEmpty);
    if (markers.isNotEmpty) {
      front = _stripBraces(front);
      back = _stripBraces(back);
    }

    if (front.isEmpty) {
      lines.add(ParseFailure(
        lineNumber: lineNumber,
        raw: line,
        reason: 'The front is empty.',
      ));
      continue;
    }
    if (back.isEmpty) {
      lines.add(ParseFailure(
        lineNumber: lineNumber,
        raw: line,
        reason: 'The back is empty.',
      ));
      continue;
    }

    lines.add(ParsedCard(
      lineNumber: lineNumber,
      raw: line,
      front: front,
      back: back,
      keywords: keywords,
    ));
  }

  return BulkParseResult(lines);
}

/// Replaces `{{ word }}` with `word`, collapsing the padding the braces added.
String _stripBraces(String text) =>
    text.replaceAllMapped(_keywordPattern, (m) => m.group(1)!.trim());
