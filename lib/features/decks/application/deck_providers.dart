import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/local_db/local_db_providers.dart';
import '../../../core/ui/app_messenger.dart';
import '../data/cache_first_deck_repository.dart';
import '../data/supabase_deck_repository.dart';
import '../domain/bulk_paste_parser.dart';
import '../domain/card.dart';
import '../domain/deck.dart';
import '../domain/deck_repository.dart';
import '../domain/sample_deck.dart';
import 'decks_tab_view.dart';
import 'pending_deletions.dart';

/// The live repository is the Supabase-backed one wrapped in the cache-first
/// layer (spec §10): reads fall back to the local SQLite mirror for downloaded
/// decks, and offline study-loop writes are queued locally for sync-on-reconnect.
/// Tests override this with a fake, so nothing else in the decks feature imports
/// `Supabase` or the local store.
final deckRepositoryProvider = Provider<DeckRepository>((ref) {
  return CacheFirstDeckRepository(
    SupabaseDeckRepository(Supabase.instance.client),
    ref.watch(localDeckStoreProvider),
  );
});

/// The signed-in user's decks with their aggregate counts, for the Deck
/// Library. Re-fetched whenever [DecksController] invalidates it.
final decksProvider = FutureProvider<List<DeckSummary>>((ref) {
  return ref.watch(deckRepositoryProvider).fetchDecks();
});

/// The cards in one deck, for the Deck Creator. Keyed by deck id.
final deckCardsProvider =
    FutureProvider.family<List<FlashCard>, String>((ref, deckId) {
  return ref.watch(deckRepositoryProvider).fetchCards(deckId);
});

/// Drives the create-deck and card add/edit/delete actions: `isLoading`
/// disables the relevant button, `AsyncError` feeds a SnackBar. Holds no value
/// of its own — it only tracks the in-flight state of the most recent action
/// (mirrors `AuthController`).
final decksControllerProvider =
    AsyncNotifierProvider<DecksController, void>(DecksController.new);

class DecksController extends AsyncNotifier<void> {
  @override
  FutureOr<void> build() {}

  DeckRepository get _repo => ref.read(deckRepositoryProvider);

  /// Runs [action], reflecting its progress in [state]. Returns the action's
  /// value on success, or `null` if it threw (the error is left in [state] for
  /// the UI to surface — callers never have to catch).
  Future<T?> _run<T>(Future<T> Function() action) async {
    state = const AsyncLoading<void>();
    final result = await AsyncValue.guard(action);
    switch (result) {
      case AsyncError(:final error, :final stackTrace):
        state = AsyncError<void>(error, stackTrace);
        return null;
      case AsyncData(:final value):
        state = const AsyncData<void>(null);
        return value;
      case _:
        state = const AsyncData<void>(null);
        return null;
    }
  }

  Future<Deck?> createDeck(String name, {String? courseId}) async {
    final deck = await _run(() => _repo.createDeck(name, courseId: courseId));
    if (deck != null) ref.invalidate(decksProvider);
    return deck;
  }

  /// Creates the pre-made starter deck (spec §2 empty state) and fills it with
  /// [sampleDeckCards] in one action, so a first-run user has something to study
  /// every mode against. Reuses the normal create/insert path — no special
  /// server support. Returns the new deck, or `null` if either step failed.
  Future<Deck?> seedSampleDeck() async {
    final deck = await _run(() async {
      final deck = await _repo.createDeck(sampleDeckName);
      await _repo.addCards(deck.id, [
        for (final (i, c) in sampleDeckCards.indexed)
          ParsedCard(
            lineNumber: i + 1,
            raw: '',
            front: c.front,
            back: c.back,
            keywords: c.keywords,
            isConcept: c.isConcept,
          ),
      ]);
      return deck;
    });
    if (deck != null) ref.invalidate(decksProvider);
    return deck;
  }

  /// Renames a deck or moves it to another course (ui-spec-v2 §3.3). Refreshes
  /// the deck list, the Decks-tab view, and the deck's card list.
  Future<Deck?> updateDeck({
    required String id,
    String? name,
    String? courseId,
  }) async {
    final deck = await _run(
      () => _repo.updateDeck(id: id, name: name, courseId: courseId),
    );
    if (deck != null) _refreshDeck(id);
    return deck;
  }

  /// Deletes a deck and, by cascade, its cards (ui-spec-v2 §3.3).
  ///
  /// Optimistic (milestone R1): the id lands in [pendingDeletionsProvider] at
  /// once so the Decks-tab grid drops the tile and `DeckDetailScreen` can pop
  /// immediately, without awaiting. On failure the id is cleared (tile returns)
  /// and a snackbar is shown through the app messenger, since the originating
  /// screen is already gone.
  Future<void> deleteDeck(String id) async {
    final pending = ref.read(pendingDeletionsProvider.notifier);
    pending.addDeck(id);

    final result = await AsyncValue.guard(() => _repo.deleteDeck(id));
    if (result case AsyncError(:final error)) {
      pending.removeDeck(id);
      showAppSnackBar('Something went wrong: $error');
      return;
    }

    _refreshDeck(id);
    ref.invalidate(tabDecksProvider);
    await _settleDecks();
    pending.removeDeck(id);
  }

  Future<void> _settleDecks() async {
    try {
      await ref.read(decksProvider.future);
      await ref.read(tabDecksProvider.future);
    } catch (_) {
      // A refetch failure doesn't strand the delete — it already succeeded.
    }
  }

  Future<FlashCard?> addCard({
    required String deckId,
    required String front,
    required String back,
    List<String> keywords = const [],
    bool isConcept = false,
  }) async {
    final card = await _run(() => _repo.addCard(
          deckId: deckId,
          front: front,
          back: back,
          keywords: keywords,
          isConcept: isConcept,
        ));
    if (card != null) _refresh(deckId);
    return card;
  }

  Future<List<FlashCard>?> addCards(String deckId, List<ParsedCard> cards) async {
    final added = await _run(() => _repo.addCards(deckId, cards));
    if (added != null) _refresh(deckId);
    return added;
  }

  Future<FlashCard?> updateCard({
    required String deckId,
    required String id,
    required String front,
    required String back,
    List<String> keywords = const [],
    bool isConcept = false,
  }) async {
    final card = await _run(() => _repo.updateCard(
          id: id,
          front: front,
          back: back,
          keywords: keywords,
          isConcept: isConcept,
        ));
    if (card != null) _refresh(deckId);
    return card;
  }

  /// Optimistic (milestone R1): the card id lands in [pendingDeletionsProvider]
  /// at once so the card list drops the row and the edit dialog can pop without
  /// awaiting. On failure the id is cleared (row returns) and a snackbar shown.
  Future<void> deleteCard({
    required String deckId,
    required String id,
  }) async {
    final pending = ref.read(pendingDeletionsProvider.notifier);
    pending.addCard(id);

    final result = await AsyncValue.guard(() => _repo.deleteCard(id));
    if (result case AsyncError(:final error)) {
      pending.removeCard(id);
      showAppSnackBar('Something went wrong: $error');
      return;
    }

    _refresh(deckId);
    try {
      await ref.read(deckCardsProvider(deckId).future);
    } catch (_) {
      // A refetch failure doesn't strand the delete — it already succeeded.
    }
    pending.removeCard(id);
  }

  Future<void> resetDeckMastery(String deckId) async {
    await _run(() => _repo.resetDeckMastery(deckId));
    // resetDeckMastery returns void, so success is "no error was recorded".
    if (!state.hasError) {
      _refresh(deckId);
    }
  }

  /// A card change moves both the deck's card list and the Library's counts.
  void _refresh(String deckId) {
    ref.invalidate(deckCardsProvider(deckId));
    ref.invalidate(decksProvider);
  }

  /// A deck rename / re-course / delete moves the card list, the Library
  /// counts, and the course-grouped Decks-tab view (ui-spec-v2 §3.3).
  void _refreshDeck(String deckId) {
    _refresh(deckId);
    ref.invalidate(decksTabViewProvider);
  }
}
