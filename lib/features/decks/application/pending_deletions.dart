import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Ids of courses, decks, and cards whose deletion has been *requested* but
/// whose Supabase write hasn't confirmed yet (milestone R1: optimistic deletes).
///
/// The derived read models — [decksTabViewProvider] and the card list — subtract
/// these ids so the row disappears the instant the user taps Delete. On a
/// successful write the controller invalidates the real providers and drops the
/// id here; on failure it just drops the id and the row reappears.
@immutable
class PendingDeletions {
  const PendingDeletions({
    this.courseIds = const {},
    this.deckIds = const {},
    this.cardIds = const {},
  });

  final Set<String> courseIds;
  final Set<String> deckIds;
  final Set<String> cardIds;

  bool get isEmpty =>
      courseIds.isEmpty && deckIds.isEmpty && cardIds.isEmpty;

  PendingDeletions copyWith({
    Set<String>? courseIds,
    Set<String>? deckIds,
    Set<String>? cardIds,
  }) =>
      PendingDeletions(
        courseIds: courseIds ?? this.courseIds,
        deckIds: deckIds ?? this.deckIds,
        cardIds: cardIds ?? this.cardIds,
      );
}

class PendingDeletionsNotifier extends Notifier<PendingDeletions> {
  @override
  PendingDeletions build() => const PendingDeletions();

  void addCourse(String id) =>
      state = state.copyWith(courseIds: {...state.courseIds, id});

  void removeCourse(String id) =>
      state = state.copyWith(courseIds: {...state.courseIds}..remove(id));

  void addDeck(String id) =>
      state = state.copyWith(deckIds: {...state.deckIds, id});

  void removeDeck(String id) =>
      state = state.copyWith(deckIds: {...state.deckIds}..remove(id));

  void addCard(String id) =>
      state = state.copyWith(cardIds: {...state.cardIds, id});

  void removeCard(String id) =>
      state = state.copyWith(cardIds: {...state.cardIds}..remove(id));
}

/// Session-scoped (never persisted): a pending deletion that outlives an app
/// restart would just be reconciled by the next fetch anyway.
final pendingDeletionsProvider =
    NotifierProvider<PendingDeletionsNotifier, PendingDeletions>(
  PendingDeletionsNotifier.new,
);
