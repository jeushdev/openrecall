import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/local_db/local_db_providers.dart';
import '../../decks/application/deck_providers.dart';
import '../../decks/domain/card.dart';

/// Thrown by [loadStudyDeckCards] when the deck isn't downloaded and the online
/// card fetch didn't return within [preSessionLoadTimeoutProvider].
///
/// The study screen treats this differently from a plain load error: it's a
/// "check your connection" state with a Retry, not a dead end. It exists so the
/// screen can never sit on a spinner forever waiting on a network call that may
/// never answer (unreachable host, a paused free-tier project) — the
/// zero-network invariant (ui-spec-v1 §2) in spirit: every screen resolves
/// against local/cached state or fails fast.
class DeckLoadTimeoutException implements Exception {
  const DeckLoadTimeoutException(this.deckId);

  final String deckId;

  @override
  String toString() => 'DeckLoadTimeoutException($deckId)';
}

/// How long the pre-session card fetch may run before it gives up with a
/// [DeckLoadTimeoutException]. Overridden short in tests.
final preSessionLoadTimeoutProvider = Provider<Duration>(
  (ref) => const Duration(seconds: 6),
);

/// Awaits [fetch], but no longer than [timeout] — a stall becomes a
/// [DeckLoadTimeoutException] instead of an open-ended hang.
@visibleForTesting
Future<List<FlashCard>> fetchDeckCardsBounded(
  Future<List<FlashCard>> fetch,
  Duration timeout,
  String deckId,
) async {
  try {
    return await fetch.timeout(timeout);
  } on TimeoutException {
    throw DeckLoadTimeoutException(deckId);
  }
}

/// The cards for a deck about to be studied, resolved so the study screen can
/// always leave its loading state.
///
/// - A **downloaded** deck reads straight from the local SQLite mirror — instant,
///   no network (spec §10; ui-spec-v1 §1 accepts a slightly-stale local set at
///   session start).
/// - Any other deck fetches from Supabase, bounded by
///   [preSessionLoadTimeoutProvider].
Future<List<FlashCard>> loadStudyDeckCards(Ref ref, String deckId) async {
  final local = ref.read(localDeckStoreProvider);
  if (await local.isCardSetComplete(deckId)) {
    return local.cards(deckId);
  }
  return fetchDeckCardsBounded(
    ref.read(deckRepositoryProvider).fetchCards(deckId),
    ref.read(preSessionLoadTimeoutProvider),
    deckId,
  );
}

/// The pre-session card load, keyed by deck id. The study screen watches this
/// for the mode picker; [invalidate] it to drive a Retry.
final preSessionCardsProvider = FutureProvider.family<List<FlashCard>, String>(
  (ref, deckId) => loadStudyDeckCards(ref, deckId),
);
