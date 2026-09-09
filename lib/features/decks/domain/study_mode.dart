import 'card.dart';

/// The three ways a card can be studied (docs/spec-v3-card-model.md). A session
/// runs in exactly one of these (`study_sessions.study_mode`).
///
/// There is no stored card `type` — which modes a deck offers is computed from
/// its cards at read time, via [availableModes].
enum StudyMode { flip, cloze, feynman }

extension StudyModeLabel on StudyMode {
  /// The button label shown on the deck mode selector.
  String get label => switch (this) {
    StudyMode.flip => 'Flip & Rate',
    StudyMode.cloze => 'Cloze Type-in',
    StudyMode.feynman => 'Feynman Synthesis',
  };
}

/// Whether [card] carries at least one keyword worth blanking — the Cloze
/// trigger (docs/spec-v3-card-model.md).
bool cardHasKeywords(FlashCard card) =>
    card.keywords.any((k) => k.trim().isNotEmpty);

/// Whether [card] is flagged as a concept — the Feynman trigger
/// (docs/spec-v3-card-model.md). Feynman-ing a bare term makes no sense, so
/// only concept-flagged cards offer it.
bool cardIsConcept(FlashCard card) => card.isConcept;

/// Whether either side of [card] is written as two or more non-empty lines.
/// No longer a mode trigger (List mode was removed in R3) — kept only for the
/// Deck Overview's "multi-line back" stat. Blank lines don't count.
bool cardIsMultiLine(FlashCard card) =>
    _lineCount(card.front) > 1 || _lineCount(card.back) > 1;

int _lineCount(String text) =>
    text.split('\n').where((line) => line.trim().isNotEmpty).length;

/// The modes [cards] structurally supports (docs/spec-v3-card-model.md):
/// - Flip is always available (every card has a front and a back).
/// - Cloze needs at least one card with a keyword.
/// - Feynman needs at least one concept-flagged card.
Set<StudyMode> availableModes(Iterable<FlashCard> cards) {
  final modes = {StudyMode.flip};
  if (cards.any(cardHasKeywords)) modes.add(StudyMode.cloze);
  if (cards.any(cardIsConcept)) modes.add(StudyMode.feynman);
  return modes;
}
