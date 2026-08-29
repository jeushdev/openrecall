/// The Decks-tab segmented control's two states (ui-spec-v1 §6.1).
///
/// Per §1's naming reconciliation this maps 1:1 to `CardScope.due` /
/// `CardScope.all`; U4 keeps it a presentation-only enum because the study
/// route isn't wired yet (that's out of scope for this milestone).
enum DeckSegment {
  due('Due'),
  all('All');

  const DeckSegment(this.label);

  /// The label shown on the segmented control.
  final String label;
}
