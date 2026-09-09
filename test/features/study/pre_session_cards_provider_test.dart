import 'dart:async';

import 'package:fake_async/fake_async.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:open_recall/features/decks/application/deck_providers.dart';
import 'package:open_recall/features/decks/domain/card.dart';
import 'package:open_recall/features/study/application/pre_session_cards_provider.dart';

import '../../support/fake_deck_repository.dart';

FlashCard _card(String id, {String deckId = 'deck-1'}) => FlashCard(
  id: id,
  deckId: deckId,
  front: 'front-$id',
  back: 'back-$id',
  keywords: const [],
  isConcept: false,
  masteryLevel: 0,
  failCount: 0,
  createdAt: DateTime.utc(2026),
  updatedAt: DateTime.utc(2026),
);

ProviderContainer _container(FakeDeckRepository decks) {
  final container = ProviderContainer(
    overrides: [deckRepositoryProvider.overrideWithValue(decks)],
  );
  addTearDown(container.dispose);
  return container;
}

void main() {
  group('preSessionCardsProvider', () {
    test('returns the deck cards from the repository', () async {
      final decks = FakeDeckRepository(cards: [_card('a'), _card('b')]);
      final container = _container(decks);

      final cards = await container.read(
        preSessionCardsProvider('deck-1').future,
      );

      expect(cards.map((c) => c.id), ['a', 'b']);
    });

    test('resolves to an empty list for a deck with no cards', () async {
      final container = _container(FakeDeckRepository());

      final cards = await container.read(
        preSessionCardsProvider('deck-1').future,
      );

      expect(cards, isEmpty);
    });

    test('surfaces a repository failure as an error, not a hang', () async {
      final decks = FakeDeckRepository()..throwOnNextCall = StateError('boom');
      final container = _container(decks);

      await expectLater(
        container.read(preSessionCardsProvider('deck-1').future),
        throwsA(isA<StateError>()),
      );
    });
  });

  group('fetchDeckCardsBounded', () {
    test('returns the fetch result when it beats the timeout', () async {
      final cards = await fetchDeckCardsBounded(
        Future.value([_card('a')]),
        const Duration(seconds: 6),
        'deck-1',
      );

      expect(cards.single.id, 'a');
    });

    test('throws DeckLoadTimeoutException when the fetch stalls', () {
      fakeAsync((async) {
        Object? caught;
        fetchDeckCardsBounded(
          Completer<List<FlashCard>>().future, // never completes
          const Duration(seconds: 6),
          'deck-1',
        ).catchError((Object e) {
          caught = e;
          return <FlashCard>[];
        });

        async.elapse(const Duration(seconds: 7));

        expect(caught, isA<DeckLoadTimeoutException>());
        expect((caught! as DeckLoadTimeoutException).deckId, 'deck-1');
      });
    });
  });
}
