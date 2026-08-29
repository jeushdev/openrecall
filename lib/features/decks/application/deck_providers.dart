import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../data/supabase_deck_repository.dart';
import '../domain/bulk_paste_parser.dart';
import '../domain/card.dart';
import '../domain/deck.dart';
import '../domain/deck_repository.dart';

/// The live repository is backed by the initialized Supabase singleton. Tests
/// override this with a fake, so nothing else in the decks feature imports
/// `Supabase`.
final deckRepositoryProvider = Provider<DeckRepository>((ref) {
  return SupabaseDeckRepository(Supabase.instance.client);
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

  Future<Deck?> createDeck(String name) async {
    final deck = await _run(() => _repo.createDeck(name));
    if (deck != null) ref.invalidate(decksProvider);
    return deck;
  }

  Future<FlashCard?> addCard({
    required String deckId,
    required String front,
    required String back,
    String? keyword,
  }) async {
    final card = await _run(() => _repo.addCard(
          deckId: deckId,
          front: front,
          back: back,
          keyword: keyword,
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
    String? keyword,
  }) async {
    final card = await _run(() => _repo.updateCard(
          id: id,
          front: front,
          back: back,
          keyword: keyword,
        ));
    if (card != null) _refresh(deckId);
    return card;
  }

  Future<void> deleteCard({
    required String deckId,
    required String id,
  }) async {
    final done = await _run(() => _repo.deleteCard(id));
    // deleteCard returns void, so success is "no error was recorded".
    if (!state.hasError) {
      _refresh(deckId);
    }
    return done;
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
}
