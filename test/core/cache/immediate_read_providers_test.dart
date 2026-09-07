import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:open_recall/core/local_db/application_cache.dart';
import 'package:open_recall/core/local_db/local_db_providers.dart';
import 'package:open_recall/features/courses/application/course_providers.dart';
import 'package:open_recall/features/courses/data/local_course_store.dart';
import 'package:open_recall/features/courses/domain/course.dart';
import 'package:open_recall/features/courses/domain/course_repository.dart';
import 'package:open_recall/features/decks/application/deck_providers.dart';
import 'package:open_recall/features/decks/data/local_deck_store.dart';
import 'package:open_recall/features/decks/domain/card.dart';
import 'package:open_recall/features/decks/domain/deck.dart';
import 'package:open_recall/features/profile/application/profile_providers.dart';
import 'package:open_recall/features/profile/domain/profile.dart';
import 'package:open_recall/features/profile/domain/profile_repository.dart';

import '../../support/fake_deck_repository.dart';

const cachedDeck = DeckSummary(
  id: 'cached-deck',
  name: 'Cached deck',
  lastStudiedAt: null,
  totalCards: 1,
  dueCards: 1,
  masteryPercent: 0,
);

final cachedCourse = Course(
  id: 'cached-course',
  userId: 'user',
  name: 'Cached course',
  accentColor: 'green',
  isDefault: false,
  createdAt: DateTime.utc(2026),
  updatedAt: DateTime.utc(2026),
);

final cachedCard = FlashCard(
  id: 'cached-card',
  deckId: cachedDeck.id,
  front: 'Cached question',
  back: 'Cached answer',
  keywords: const [],
  isConcept: false,
  masteryLevel: 0,
  failCount: 0,
  createdAt: DateTime.utc(2026),
  updatedAt: DateTime.utc(2026),
);

class _LocalDecks extends LocalDeckStore {
  _LocalDecks() : super(null);

  @override
  bool get isNoop => false;

  @override
  Future<List<DeckSummary>> cachedDeckSummaries() async => const [cachedDeck];

  @override
  Future<bool> hasFetchedDeckMetadata() async => true;

  @override
  Future<bool> isCardSetComplete(String deckId) async => true;

  @override
  Future<List<FlashCard>> cards(String deckId) async => [cachedCard];
}

class _LocalCourses extends LocalCourseStore {
  _LocalCourses() : super(null);

  @override
  bool get isNoop => false;

  @override
  Future<List<Course>> cachedCourses() async => [cachedCourse];

  @override
  Future<bool> hasFetchedCourses() async => true;
}

class _ProfileCache extends ApplicationCache {
  _ProfileCache(this.cached) : super(null);
  Profile? cached;

  @override
  Future<Profile?> profile() async => cached;

  @override
  Future<void> saveProfile(Profile? profile) async => cached = profile;
}

class _PendingCourses implements CourseRepository {
  final completer = Completer<List<Course>>();

  @override
  Future<List<Course>> fetchCourses() => completer.future;

  @override
  Future<Course> createCourse({
    required String name,
    required String accentColor,
  }) => throw UnimplementedError();

  @override
  Future<void> deleteCourse(String id, {required String defaultCourseId}) =>
      throw UnimplementedError();

  @override
  Future<void> reorderCourses(List<String> orderedIds) =>
      throw UnimplementedError();

  @override
  Future<Course> updateCourse({
    required String id,
    String? name,
    String? accentColor,
  }) => throw UnimplementedError();
}

class _PendingProfile implements ProfileRepository {
  final completer = Completer<Profile>();

  @override
  Future<Profile> fetch() => completer.future;

  @override
  Future<void> updateUsername(String? name) => throw UnimplementedError();
}

void main() {
  test(
    'profile, decks, courses and complete cards emit before remote futures',
    () async {
      final remoteDecks = FakeDeckRepository()..hangForever = true;
      final remoteCourses = _PendingCourses();
      final remoteProfile = _PendingProfile();
      final container = ProviderContainer(
        overrides: [
          localDeckStoreProvider.overrideWithValue(_LocalDecks()),
          localCourseStoreProvider.overrideWithValue(_LocalCourses()),
          applicationCacheProvider.overrideWithValue(
            _ProfileCache((
              id: 'user',
              email: 'cached@example.com',
              username: 'Cached Ada',
            )),
          ),
          deckRepositoryProvider.overrideWithValue(remoteDecks),
          courseRepositoryProvider.overrideWithValue(remoteCourses),
          profileRepositoryProvider.overrideWithValue(remoteProfile),
        ],
      );
      addTearDown(container.dispose);
      container.listen(profileProvider, (_, _) {}, fireImmediately: true);
      container.listen(decksProvider, (_, _) {}, fireImmediately: true);
      container.listen(coursesProvider, (_, _) {}, fireImmediately: true);
      container.listen(
        deckCardsProvider(cachedDeck.id),
        (_, _) {},
        fireImmediately: true,
      );

      expect(
        (await container.read(profileProvider.future))!.username,
        'Cached Ada',
      );
      expect(
        (await container.read(decksProvider.future)).single.name,
        'Cached deck',
      );
      expect(
        (await container.read(coursesProvider.future)).single.name,
        'Cached course',
      );
      expect(
        (await container.read(deckCardsProvider(cachedDeck.id).future))
            .single
            .front,
        'Cached question',
      );
    },
  );

  test('background refresh replaces visible cached data', () async {
    final gate = Completer<void>();
    final repository = FakeDeckRepository(
      decks: const [
        DeckSummary(
          id: 'remote-deck',
          name: 'Fresh deck',
          lastStudiedAt: null,
          totalCards: 0,
          dueCards: 0,
          masteryPercent: 0,
        ),
      ],
    )..fetchGate = gate;
    final container = ProviderContainer(
      overrides: [
        localDeckStoreProvider.overrideWithValue(_LocalDecks()),
        deckRepositoryProvider.overrideWithValue(repository),
      ],
    );
    addTearDown(container.dispose);
    container.listen(decksProvider, (_, _) {}, fireImmediately: true);
    expect(
      (await container.read(decksProvider.future)).single.name,
      'Cached deck',
    );

    gate.complete();
    for (
      var i = 0;
      i < 20 &&
          container.read(decksProvider).asData?.value.single.name !=
              'Fresh deck';
      i++
    ) {
      await Future<void>.delayed(Duration.zero);
    }
    expect(
      container.read(decksProvider).requireValue.single.name,
      'Fresh deck',
    );
  });

  test('background refresh failure leaves cached data visible', () async {
    final repository = FakeDeckRepository()
      ..alwaysThrow = StateError('refresh failed');
    final container = ProviderContainer(
      overrides: [
        localDeckStoreProvider.overrideWithValue(_LocalDecks()),
        deckRepositoryProvider.overrideWithValue(repository),
      ],
    );
    addTearDown(container.dispose);
    container.listen(decksProvider, (_, _) {}, fireImmediately: true);
    expect(
      (await container.read(decksProvider.future)).single.name,
      'Cached deck',
    );

    await Future<void>.delayed(Duration.zero);
    await Future<void>.delayed(Duration.zero);
    expect(
      container.read(decksProvider).requireValue.single.name,
      'Cached deck',
    );
    expect(container.read(decksProvider).hasError, isFalse);
  });

  test(
    'without SQLite there is no local emission and the remote stays source',
    () async {
      final remote = FakeDeckRepository(
        decks: const [
          DeckSummary(
            id: 'remote',
            name: 'Remote only',
            lastStudiedAt: null,
            totalCards: 0,
            dueCards: 0,
            masteryPercent: 0,
          ),
        ],
      );
      final container = ProviderContainer(
        overrides: [deckRepositoryProvider.overrideWithValue(remote)],
      );
      addTearDown(container.dispose);
      container.listen(decksProvider, (_, _) {}, fireImmediately: true);

      expect(
        (await container.read(decksProvider.future)).single.name,
        'Remote only',
      );
      expect(remote.calls, ['fetchDecks()']);
    },
  );
}
