import 'package:flutter/foundation.dart';

import '../../decks/domain/deck.dart';

/// One row in the Mastery tab's "Deck completions" list (ui-spec-v1 §6.3): a
/// deck and how many times it has been fully cleared (`card_scope: 'all'`
/// sessions completed, engine-v2-spec §4.3).
///
/// Derived, never stored — see [deckCompletions].
@immutable
class DeckCompletion {
  const DeckCompletion({
    required this.deckId,
    required this.deckName,
    required this.runThroughs,
  });

  final String deckId;
  final String deckName;
  final int runThroughs;

  @override
  bool operator ==(Object other) =>
      other is DeckCompletion &&
      other.deckId == deckId &&
      other.deckName == deckName &&
      other.runThroughs == runThroughs;

  @override
  int get hashCode => Object.hash(deckId, deckName, runThroughs);
}

/// Joins [runThroughs] (the `deckRunThroughsProvider` map, keyed by deck id)
/// against [decks] to attach a display name, then orders the result by
/// run-through count descending, breaking ties on deck name.
///
/// Pure: both inputs are things the app has already fetched
/// (`deckRunThroughsProvider` / `decksProvider`). A run-through entry whose deck
/// id matches no deck in [decks] is dropped — it's a deck that was deleted, or
/// one the local mirror hasn't seen. Decks with no run-throughs are simply
/// absent from [runThroughs] and so never appear.
List<DeckCompletion> deckCompletions(
  Map<String, int> runThroughs,
  Iterable<DeckSummary> decks,
) {
  final nameById = {for (final deck in decks) deck.id: deck.name};

  final completions =
      <DeckCompletion>[
        for (final entry in runThroughs.entries)
          if (nameById.containsKey(entry.key))
            DeckCompletion(
              deckId: entry.key,
              deckName: nameById[entry.key]!,
              runThroughs: entry.value,
            ),
      ]..sort((a, b) {
        final byCount = b.runThroughs.compareTo(a.runThroughs);
        return byCount != 0 ? byCount : a.deckName.compareTo(b.deckName);
      });

  return completions;
}
