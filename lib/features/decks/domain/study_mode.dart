import 'card.dart';

/// The four ways a card can be studied (spec §5). A session runs in exactly one
/// of these (`study_sessions.study_mode`).
///
/// There is no stored card `type` — which modes a deck offers is computed from
/// its cards at read time (spec §4), via [availableModes].
enum StudyMode { flip, cloze, list, feynman }

extension StudyModeLabel on StudyMode {
  /// The button label shown on the Deck Overview mode selector.
  String get label => switch (this) {
        StudyMode.flip => 'Flip & Rate',
        StudyMode.cloze => 'Cloze Type-in',
        StudyMode.list => 'List Unmask',
        StudyMode.feynman => 'Feynman Synthesis',
      };
}

/// Whether [card] carries a keyword worth blanking — the Cloze trigger (spec §4).
bool cardHasKeyword(FlashCard card) => (card.keyword?.trim().isNotEmpty ?? false);

/// Whether either side of [card] is written as two or more non-empty lines — the
/// List / Feynman trigger (spec §4: "2+ lines on either side"). Blank lines
/// don't count, so a trailing newline alone doesn't make a card multi-line.
bool cardIsMultiLine(FlashCard card) =>
    _lineCount(card.front) > 1 || _lineCount(card.back) > 1;

int _lineCount(String text) =>
    text.split('\n').where((line) => line.trim().isNotEmpty).length;

/// The modes [cards] structurally supports (spec §4):
/// - Flip is always available (every card has a front and a back).
/// - Cloze needs at least one card with a keyword.
/// - List and Feynman share a trigger: at least one card with 2+ lines on a side.
Set<StudyMode> availableModes(Iterable<FlashCard> cards) {
  final modes = {StudyMode.flip};
  if (cards.any(cardHasKeyword)) modes.add(StudyMode.cloze);
  if (cards.any(cardIsMultiLine)) {
    modes
      ..add(StudyMode.list)
      ..add(StudyMode.feynman);
  }
  return modes;
}
