import 'package:flutter_test/flutter_test.dart';
import 'package:open_recall/features/courses/data/local_course_store.dart';
import 'package:open_recall/features/decks/data/cache_first_deck_repository.dart';
import 'package:open_recall/features/decks/data/local_deck_store.dart';

import '../../support/fake_deck_repository.dart';

/// A [LocalDeckStore] that reports a live database and records `createDeck`.
class _FakeLocalDeckStore extends LocalDeckStore {
  _FakeLocalDeckStore() : super(null);

  final List<String> createDeckCalls = [];

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
  Future<bool> hasMirroredCards(String deckId) async => false;
}

void main() {
  group('CacheFirstDeckRepository.createDeck offline', () {
    test('queues locally, resolving a null course to the mirrored default',
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
    });

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

    test('propagates a remote failure (offline) without a local queue', () async {
      final repo = CacheFirstDeckRepository(
        FakeDeckRepository()..throwOnNextCall = StateError('offline'),
        _FakeLocalDeckStore(),
        _FakeLocalCourseStore(null),
      );

      await expectLater(repo.reorderDecks(['d1']), throwsStateError);
    });
  });
}
