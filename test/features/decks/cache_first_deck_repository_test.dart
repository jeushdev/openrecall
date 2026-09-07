import 'package:flutter_test/flutter_test.dart';
import 'package:open_recall/features/courses/data/local_course_store.dart';
import 'package:open_recall/features/decks/data/cache_first_deck_repository.dart';
import 'package:open_recall/features/decks/data/local_deck_store.dart';
import 'package:open_recall/features/decks/domain/card.dart';
import 'package:open_recall/features/decks/domain/deck.dart';

import '../../support/fake_deck_repository.dart';

/// A [LocalDeckStore] that reports a live database and records `createDeck`.
class _FakeLocalDeckStore extends LocalDeckStore {
  _FakeLocalDeckStore() : super(null);

  final List<String> createDeckCalls = [];
  final List<List<String>> reorderDeckCalls = [];
  final List<Deck> savedRemoteDecks = [];

  @override
  bool get isNoop => false;

  @override
  Future<void> createDeck({
    required String id,
    required String name,
    String? courseId,
  }) async {
    createDeckCalls.add('id=$id name=$name course=$courseId');
  }

  @override
  Future<void> reorderDecks(List<String> orderedIds) async {
    reorderDeckCalls.add(orderedIds);
  }

  @override
  Future<void> saveRemoteDeck(Deck deck) async {
    savedRemoteDecks.add(deck);
  }
}

class _FakeLocalCourseStore extends LocalCourseStore {
  _FakeLocalCourseStore(this._defaultCourseId) : super(null);

  final String? _defaultCourseId;

  @override
  bool get isNoop => false;

  @override
  Future<String?> defaultCourseId() async => _defaultCourseId;
}

/// A deck whose header is cached but whose cards were never mirrored — the
/// state every deck is in after `refreshDeckMeta` until it is opened online.
class _MetaOnlyLocalDeckStore extends LocalDeckStore {
  _MetaOnlyLocalDeckStore() : super(null);

  @override
  bool get isNoop => false;

  @override
  Future<bool> isDownloaded(String deckId) async => true;

  @override
  Future<bool> isCardSetComplete(String deckId) async => false;
}

/// Records the card sets handed to [mirrorCards]. `isDownloaded` is true for
/// every deck — since spec-v4 `refreshDeckMeta` writes a header row for each
/// listed deck, which is what makes the read-through mirror-on-open behave as
/// the spec's "opportunistic refresh".
class _MirrorRecordingLocalDeckStore extends LocalDeckStore {
  _MirrorRecordingLocalDeckStore() : super(null);

  final Map<String, List<String>> mirrored = {};
  final Map<String, List<FlashCard>> cardsByDeck = {};

  @override
  bool get isNoop => false;

  @override
  Future<bool> isDownloaded(String deckId) async => true;

  @override
  Future<void> mirrorCards(String deckId, List<FlashCard> remote) async {
    mirrored[deckId] = [for (final c in remote) c.id];
    cardsByDeck[deckId] = remote;
  }

  @override
  Future<List<FlashCard>> cards(String deckId) async =>
      cardsByDeck[deckId] ?? const [];
}

class _RejectingPackageStore extends LocalDeckStore {
  _RejectingPackageStore(this.cached) : super(null);

  final List<FlashCard> cached;

  @override
  bool get isNoop => false;

  @override
  Future<bool> isCardSetComplete(String deckId) async => true;

  @override
  Future<void> mirrorCards(String deckId, List<FlashCard> remote) async {
    throw StateError('package write failed');
  }

  @override
  Future<List<FlashCard>> cards(String deckId) async => cached;
}

void main() {
  test('successful remote deck authoring refreshes cached metadata', () async {
    final local = _FakeLocalDeckStore();
    final repo = CacheFirstDeckRepository(
      FakeDeckRepository(),
      local,
      _FakeLocalCourseStore(null),
    );

    final created = await repo.createDeck('Cells');

    expect(local.savedRemoteDecks.single.id, created.id);
    expect(local.savedRemoteDecks.single.name, 'Cells');
  });

  group('CacheFirstDeckRepository.createDeck offline', () {
    test(
      'queues locally, resolving a null course to the mirrored default',
      () async {
        final local = _FakeLocalDeckStore();
        final repo = CacheFirstDeckRepository(
          FakeDeckRepository()..throwOnNextCall = StateError('offline'),
          local,
          _FakeLocalCourseStore('default-course'),
        );

        final deck = await repo.createDeck('Cells');

        expect(deck.name, 'Cells');
        expect(deck.courseId, 'default-course');
        expect(local.createDeckCalls.single, contains('course=default-course'));
        expect(local.createDeckCalls.single, contains('name=Cells'));
      },
    );

    test('queues with a null course when the mirror has no default', () async {
      final local = _FakeLocalDeckStore();
      final repo = CacheFirstDeckRepository(
        FakeDeckRepository()..throwOnNextCall = StateError('offline'),
        local,
        _FakeLocalCourseStore(null),
      );

      final deck = await repo.createDeck('Cells');

      expect(deck.courseId, isNull);
      expect(local.createDeckCalls.single, contains('course=null'));
    });

    test('rethrows when there is no local database', () async {
      final repo = CacheFirstDeckRepository(
        FakeDeckRepository()..throwOnNextCall = StateError('offline'),
        LocalDeckStore(null), // isNoop == true
        LocalCourseStore(null),
      );

      expect(repo.createDeck('Cells'), throwsStateError);
    });
  });

  group('CacheFirstDeckRepository.fetchCards offline', () {
    test('a deck with no mirrored cards is unavailable, not empty', () async {
      // Since spec-v4 `refreshDeckMeta` writes an `offline_decks` row for every
      // deck the user has, so row existence no longer implies a mirrored card
      // set. Gating on `isDownloaded` here returned an empty deck instead of
      // the "unavailable offline" state.
      final repo = CacheFirstDeckRepository(
        FakeDeckRepository()..throwOnNextCall = StateError('offline'),
        _MetaOnlyLocalDeckStore(),
        _FakeLocalCourseStore(null),
      );

      await expectLater(
        repo.fetchCards('deck-1'),
        throwsA(isA<DeckUnavailableOfflineException>()),
      );
    });
  });

  group('CacheFirstDeckRepository.fetchCards online', () {
    test(
      'opening a listed deck refreshes its card mirror in place '
      '(the spec\'s "opportunistic refresh" — no separate code needed)',
      () async {
        final remote = FakeDeckRepository(
          cards: [
            FlashCard(
              id: 'k1',
              deckId: 'deck-1',
              front: 'Q',
              back: 'A',
              keywords: const [],
              isConcept: false,
              masteryLevel: 0,
              failCount: 0,
              createdAt: DateTime.utc(2026),
              updatedAt: DateTime.utc(2026),
            ),
            FlashCard(
              id: 'k2',
              deckId: 'deck-1',
              front: 'Q2',
              back: 'A2',
              keywords: const [],
              isConcept: false,
              masteryLevel: 0,
              failCount: 0,
              createdAt: DateTime.utc(2026),
              updatedAt: DateTime.utc(2026),
            ),
          ],
        );
        final local = _MirrorRecordingLocalDeckStore();
        final repo = CacheFirstDeckRepository(
          remote,
          local,
          _FakeLocalCourseStore(null),
        );

        final cards = await repo.fetchCards('deck-1');

        expect(cards.map((c) => c.id), ['k1', 'k2']);
        expect(local.mirrored['deck-1'], [
          'k1',
          'k2',
        ], reason: 'the fresh set was written to the local mirror on success');
      },
    );

    test(
      'without SQLite the successful online result remains authoritative',
      () async {
        final remote = FakeDeckRepository(
          cards: [
            FlashCard(
              id: 'online',
              deckId: 'deck-1',
              front: 'Q',
              back: 'A',
              keywords: const [],
              isConcept: false,
              masteryLevel: 0,
              failCount: 0,
              createdAt: DateTime.utc(2026),
              updatedAt: DateTime.utc(2026),
            ),
          ],
        );
        final repo = CacheFirstDeckRepository(
          remote,
          LocalDeckStore(null),
          LocalCourseStore(null),
        );

        expect((await repo.fetchCards('deck-1')).single.id, 'online');
      },
    );

    test(
      'a local package failure retains the prior valid cached value',
      () async {
        final old = FlashCard(
          id: 'old',
          deckId: 'deck-1',
          front: 'Old',
          back: 'A',
          keywords: const [],
          isConcept: false,
          masteryLevel: 0,
          failCount: 0,
          createdAt: DateTime.utc(2026),
          updatedAt: DateTime.utc(2026),
        );
        final repo = CacheFirstDeckRepository(
          FakeDeckRepository(
            cards: [
              FlashCard(
                id: 'new',
                deckId: 'deck-1',
                front: 'New',
                back: 'A',
                keywords: const [],
                isConcept: false,
                masteryLevel: 0,
                failCount: 0,
                createdAt: DateTime.utc(2026),
                updatedAt: DateTime.utc(2026),
              ),
            ],
          ),
          _RejectingPackageStore([old]),
          _FakeLocalCourseStore(null),
        );

        expect((await repo.fetchCards('deck-1')).single.id, 'old');
      },
    );
  });

  group('CacheFirstDeckRepository.reorderDecks', () {
    test('delegates the new order straight to the remote', () async {
      final remote = FakeDeckRepository();
      final repo = CacheFirstDeckRepository(
        remote,
        _FakeLocalDeckStore(),
        _FakeLocalCourseStore(null),
      );

      await repo.reorderDecks(['d3', 'd1', 'd2']);

      expect(remote.calls, contains('reorderDecks([d3, d1, d2])'));
    });

    test('offline, queues the new order into the local mirror instead of '
        'throwing', () async {
      final local = _FakeLocalDeckStore();
      final repo = CacheFirstDeckRepository(
        FakeDeckRepository()..throwOnNextCall = StateError('offline'),
        local,
        _FakeLocalCourseStore(null),
      );

      await repo.reorderDecks(['d2', 'd1']); // must not throw

      expect(local.reorderDeckCalls.single, ['d2', 'd1']);
    });

    test('with no local database the offline error still propagates', () async {
      final repo = CacheFirstDeckRepository(
        FakeDeckRepository()..throwOnNextCall = StateError('offline'),
        LocalDeckStore(null), // isNoop == true
        _FakeLocalCourseStore(null),
      );

      await expectLater(repo.reorderDecks(['d1']), throwsStateError);
    });
  });
}
