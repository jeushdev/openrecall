import 'package:flutter/foundation.dart';

import '../../decks/domain/card.dart';

/// The non-empty lines of one card side, split on `\n` with each line trimmed
/// and blank lines dropped — the same rule `study_mode.dart` uses to decide
/// whether a card is multi-line (spec §4).
List<String> contentLines(String side) => side
    .split('\n')
    .map((line) => line.trim())
    .where((line) => line.isNotEmpty)
    .toList();

/// A List card resolved to its parts (spec §5C / "Why List and Feynman share
/// one data shape"): the single-line [prompt] and the ordered [lines] the user
/// reveals one at a time.
@immutable
class ListContent {
  const ListContent({required this.prompt, required this.lines});

  final String prompt;
  final List<String> lines;
}

/// Splits [card] into prompt + content, orientation-agnostically: whichever
/// side has 2+ non-empty lines is the content and the other side is the prompt.
/// If both sides are multi-line, `back` is the content by default (spec §4).
ListContent listContentOf(FlashCard card) {
  final frontLines = contentLines(card.front);
  final backLines = contentLines(card.back);

  final backIsContent = backLines.length > 1 || frontLines.length <= 1;
  return backIsContent
      ? ListContent(prompt: card.front.trim(), lines: backLines)
      : ListContent(prompt: card.back.trim(), lines: frontLines);
}
