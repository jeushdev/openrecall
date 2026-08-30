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
}
