/// Pure parser for the Deck Creator's bulk-paste box (spec §3, block format
/// added in milestone R5 — see `docs/spec-v3-card-model.md`, "Import (R5)").
///
/// Input is free text arranged in **blocks separated by blank lines**:
///
/// - the first line of a block is the **front**;
/// - the remaining lines are the **back**, joined with newlines, with `- ` / `* `
///   bullet markers kept verbatim;
/// - a line reading exactly `[concept]` (any case) sets [ParsedCard.isConcept]
///   and is dropped from the text;
/// - `{{double braces}}` anywhere in a block mark Cloze keywords (any number,
///   either side): each is lifted into [ParsedCard.keywords] in reading order
///   (front markers first, then back) and the braces are stripped from the
///   stored text.
///
/// A block that is a single line of `FRONT | BACK` still works, so simple
/// one-fact cards need no blank-line ceremony. Blank lines are the *only*
/// separator — a run of `A | B` lines with no blank line between them is one
/// multi-line card, not many.
///
/// Nothing here touches the network or the database — it only turns text into
/// a [BulkParseResult] the UI can preview and the repository can insert.
library;

/// One block of parsed bulk-paste input: either a [ParsedCard] or a
/// [ParseFailure]. Blank lines produce neither — they only separate blocks.
sealed class BulkParseLine {
  const BulkParseLine({required this.lineNumber, required this.raw});

  /// 1-based line number of the block's **first line** in the original text,
  /// for the preview to reference.
  final int lineNumber;

  /// The block's original text (its lines joined with `\n`) — so a failing
  /// block can be shown back to the user verbatim for correction.
  final String raw;
}

/// A block that parsed into a usable card.
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

  /// The back, with interior newlines and `- ` / `* ` bullet markers preserved.
  final String back;

  /// The `{{ }}`-marked Cloze keywords, in reading order (front markers first,
  /// then back). Zero or more per card.
  final List<String> keywords;

  /// Whether this card is a Feynman concept — set by a `[concept]` line in the
  /// block.
  final bool isConcept;
}

/// A block that could not be parsed, with a user-facing reason. Never dropped
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

const _noBackReason =
    'This card has no back — add it on the next line, or write FRONT | BACK on '
    'one line.';

/// Parses [raw] into a [BulkParseResult]. See the library doc for the rules.
BulkParseResult parseBulkPaste(String raw) {
  final lines = <BulkParseLine>[];
  final rawLines = raw.split('\n');

  var i = 0;
  while (i < rawLines.length) {
    if (rawLines[i].trim().isEmpty) {
      i++;
      continue;
    }

    final startLine = i + 1;
    final block = <String>[];
    while (i < rawLines.length && rawLines[i].trim().isNotEmpty) {
      block.add(rawLines[i]);
      i++;
    }

    lines.add(_parseBlock(startLine, block));
  }

  return BulkParseResult(lines);
}

BulkParseLine _parseBlock(int lineNumber, List<String> block) {
  final raw = block.join('\n');

  var isConcept = false;
  final content = <String>[];
  for (final line in block) {
    if (line.trim().toLowerCase() == '[concept]') {
      isConcept = true;
    } else {
      content.add(line);
    }
  }

  if (content.isEmpty) {
    return ParseFailure(
      lineNumber: lineNumber,
      raw: raw,
      reason: 'A [concept] card still needs a front and a back.',
    );
  }

  String front;
  String back;

  final onlyLine = content.length == 1 ? content.single : null;
  if (onlyLine != null && onlyLine.contains('|')) {
    final pipe = onlyLine.indexOf('|');
    front = onlyLine.substring(0, pipe).trim();
    back = onlyLine.substring(pipe + 1).trim();
  } else if (onlyLine != null) {
    return ParseFailure(
      lineNumber: lineNumber,
      raw: raw,
      reason: _noBackReason,
    );
  } else {
    front = content.first.trim();
    back = content.skip(1).map((l) => l.trimRight()).join('\n');
  }

  final markers = _keywordPattern
      .allMatches(front)
      .followedBy(_keywordPattern.allMatches(back))
      .toList();
  final keywords = [for (final m in markers) m.group(1)!.trim()]
    ..removeWhere((k) => k.isEmpty);
  if (markers.isNotEmpty) {
    front = _stripBraces(front);
    back = _stripBraces(back);
  }

  if (front.isEmpty) {
    return ParseFailure(
      lineNumber: lineNumber,
      raw: raw,
      reason: 'The front is empty.',
    );
  }
  if (back.trim().isEmpty) {
    return ParseFailure(
      lineNumber: lineNumber,
      raw: raw,
      reason: _noBackReason,
    );
  }

  return ParsedCard(
    lineNumber: lineNumber,
    raw: raw,
    front: front,
    back: back,
    keywords: keywords,
    isConcept: isConcept,
  );
}

/// Replaces `{{ word }}` with `word`, collapsing the padding the braces added.
String _stripBraces(String text) =>
    text.replaceAllMapped(_keywordPattern, (m) => m.group(1)!.trim());
