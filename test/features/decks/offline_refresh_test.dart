import 'dart:async';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:open_recall/core/connectivity/connectivity_service.dart';
import 'package:open_recall/core/local_db/app_database.dart';
import 'package:open_recall/core/local_db/local_db_providers.dart';
import 'package:open_recall/features/courses/domain/course.dart';
import 'package:open_recall/features/decks/application/deck_providers.dart';
import 'package:open_recall/features/decks/application/offline_deck_service.dart';
import 'package:open_recall/features/decks/application/offline_providers.dart';
import 'package:open_recall/features/decks/data/cache_first_deck_repository.dart';
import 'package:open_recall/features/decks/data/local_deck_store.dart';
import 'package:open_recall/features/decks/domain/card.dart';
import 'package:open_recall/features/decks/domain/deck.dart';
import 'package:open_recall/features/decks/domain/deck_repository.dart';
import 'package:open_recall/features/decks/domain/offline_download.dart';
import 'package:open_recall/features/decks/domain/study_mode.dart';
import 'package:open_recall/features/study/application/pre_session_cards_provider.dart';
import 'package:open_recall/features/study/data/local_study_store.dart';
import 'package:open_recall/features/study/domain/session_length.dart';
import 'package:open_recall/features/study/domain/session_status.dart';
import 'package:open_recall/features/study/domain/study_session.dart';

import '../../support/fake_deck_repository.dart';
import '../../support/local_db_harness.dart';

class _Connectivity extends ConnectivityService {
  _Connectivity(this.online) : super(Connectivity());

  bool online;

  @override
  Future<bool> isOnline() async => online;
}

class _Source implements OfflineDownloadSource {
  final Map<String, List<FlashCard>> cards = <String, List<FlashCard>>{};
  final List<String> fetchDeckCalls = <String>[];
  final List<String> pageCalls = <String>[];
  final Completer<void> pageStarted = Completer<void>();
  Completer<void>? pageGate;
  bool missing = false;
  bool failCourse = false;
  bool failPage = false;

  @override
  Future<Deck?> fetchDeck(String deckId) async {
    fetchDeckCalls.add(deckId);
    if (missing) return null;
    return Deck(
      id: deckId,
      name: 'Remote $deckId',
      courseId: 'course-1',
      lastStudiedAt: null,
      createdAt: DateTime.utc(2026),
      updatedAt: DateTime.utc(2026, 2),
    );
  }

  @override
  Future<Course?> fetchCourse(String courseId) async {
    if (failCourse) return null;
    return Course(
      id: courseId,
      userId: 'user-1',
      name: 'Science',
      accentColor: 'green',
      isDefault: false,
      createdAt: DateTime.utc(2026),
      updatedAt: DateTime.utc(2026),
    );
  }

  @override
  Future<int> countCards(String deckId) async => cards[deckId]?.length ?? 0;

  @override
  Future<List<FlashCard>> fetchCardsPage(
    String deckId, {
    required int offset,
    required int limit,
  }) async {
    pageCalls.add(deckId);
    if (!pageStarted.isCompleted) pageStarted.complete();
    if (pageGate != null) await pageGate!.future;
    if (failPage) throw StateError('page failed');
    return (cards[deckId] ?? const <FlashCard>[])
        .skip(offset)
        .take(limit)
        .toList();
  }
}

FlashCard _card(String id, String deckId, {String front = 'Old'}) => FlashCard(
  id: id,
  deckId: deckId,
  front: front,
  back: 'Answer',
  keywords: const [],
  isConcept: false,
  masteryLevel: 0,
  failCount: 0,
  createdAt: DateTime.utc(2026),
  updatedAt: DateTime.utc(2026),
);

Future<void> _install(LocalDeckStore store, String deckId) {
  return store.commitDeckPackage(
    deckId: deckId,
    deckName: 'Saved $deckId',
    cards: [_card('old-$deckId', deckId)],
    pin: true,
  );
}

void main() {
  setUpAll(initLocalDbTestFfi);

  late AppDatabase database;
  late LocalDeckStore store;
  late _Source source;
  late OfflineDeckService service;

  setUp(() async {
    database = await openTestDatabase();
    store = LocalDeckStore(database.db);
    source = _Source();
    service = OfflineDeckService(
      local: store,
      source: source,
      operations: OfflinePackageOperationRegistry(),
      isOnline: () async => true,
      requestTimeout: const Duration(milliseconds: 100),
      overallTimeout: const Duration(seconds: 2),
    );
  });

  tearDown(() async {
    service.dispose();
    await database.close();
  });

  test('refresh coalesces and failure preserves the saved package', () async {
    await _install(store, 'd1');
    source.cards['d1'] = [_card('new', 'd1', front: 'New')];
    source.pageGate = Completer<void>();

    final first = service.refresh('d1');
    final second = service.refresh('d1');
    expect(identical(first, second), isTrue);
    await source.pageStarted.future;
    source.pageGate!.complete();
    expect((await first).packageCommitted, isTrue);
    expect((await store.cards('d1')).single.id, 'new');

    source.failPage = true;
    final failed = await service.refresh('d1');
    expect(failed.packageCommitted, isFalse);
    expect(failed.error, isNotNull);
    expect((await store.cards('d1')).single.id, 'new');
    expect((await store.packageStatus('d1')).isExplicitlyAvailable, isTrue);
  });

  test('startup lease suppresses refresh and blocks removal', () async {
    await _install(store, 'd1');
    final lease = service.acquireStartupLease('d1');

    expect((await service.refresh('d1')).skipped, isTrue);
    expect(source.fetchDeckCalls, isEmpty);
    await expectLater(
      service.remove('d1'),
      throwsA(isA<OfflinePackageActiveSessionException>()),
    );

    service.releaseStartupLease(lease);
    await service.remove('d1');
    expect((await store.packageStatus('d1')).cacheSuppressed, isTrue);
  });

  test('persisted active session suppresses automatic refresh', () async {
    await _install(store, 'd1');
    await LocalStudyStore(database.db).insertSession(
      StudySession(
        id: 's1',
        deckId: 'd1',
        status: SessionStatus.active,
        studyMode: StudyMode.flip,
        lengthMode: SessionLengthMode.untilMastered,
        cappedLength: null,
        cardScope: CardScope.due,
        masteryDelta: null,
        startedAt: DateTime.utc(2026),
        completedAt: null,
      ),
      'user-1',
      synced: false,
    );

    expect((await service.refresh('d1')).skipped, isTrue);
    expect(source.fetchDeckCalls, isEmpty);
  });

  test('removal revokes a delayed refresh and prevents repinning', () async {
    await _install(store, 'd1');
    source.cards['d1'] = [_card('new', 'd1')];
    source.pageGate = Completer<void>();

    final refresh = service.refresh('d1');
    await source.pageStarted.future;
    await service.remove('d1');
    source.pageGate!.complete();
    await refresh;

    final status = await store.packageStatus('d1');
    expect(status.cacheSuppressed, isTrue);
    expect(status.cardsComplete, isFalse);
    expect(status.isPinned, isFalse);
    expect(await store.cardById('new'), isNull);
  });

  test(
    'targeted missing is guarded and later targeted success clears it',
    () async {
      await _install(store, 'd1');
      source.missing = true;

      final missing = await service.refresh('d1');
      expect(missing.packageCommitted, isFalse);
      expect((await store.packageStatus('d1')).remoteMissing, isTrue);
      expect((await store.cards('d1')).single.id, 'old-d1');

      source.missing = false;
      source.failCourse = true;
      final reappeared = await service.refresh('d1');
      expect(reappeared.packageCommitted, isFalse);
      expect(reappeared.statusChanged, isTrue);
      expect((await store.packageStatus('d1')).remoteMissing, isFalse);
      expect((await store.cards('d1')).single.id, 'old-d1');
    },
  );

  test(
    'offline complete reads are immediate and unavailable reads make no call',
    () async {
      await _install(store, 'd1');
      final connectivity = _Connectivity(false);
      final statuses = StreamController<bool>.broadcast();
      final repository = FakeDeckRepository()..hangForever = true;
      final container = ProviderContainer(
        overrides: [
          appDatabaseProvider.overrideWithValue(database),
          connectivityServiceProvider.overrideWithValue(connectivity),
          onlineStatusProvider.overrideWith((ref) => statuses.stream),
          offlineDownloadSourceProvider.overrideWithValue(source),
          deckRepositoryProvider.overrideWithValue(repository),
        ],
      );
      addTearDown(statuses.close);
      addTearDown(container.dispose);
      statuses.add(false);

      expect(
        (await container.read(localDeckStoreProvider).packageStatus('d1'))
            .isExplicitlyAvailable,
        isTrue,
      );
      final cardSub = container.listen(
        deckCardsProvider('d1'),
        (_, _) {},
        fireImmediately: true,
      );
      addTearDown(cardSub.close);
      expect(
        (await container
                .read(deckCardsProvider('d1').future)
                .timeout(
                  const Duration(seconds: 1),
                  onTimeout: () => throw StateError('cards read timed out'),
                ))
            .single
            .id,
        'old-d1',
      );
      await expectLater(
        container
            .read(preSessionCardsProvider('missing').future)
            .timeout(
              const Duration(seconds: 1),
              onTimeout: () => throw StateError('unavailable read timed out'),
            ),
        throwsA(isA<DeckUnavailableOfflineException>()),
      );
      expect(source.fetchDeckCalls, isEmpty);
      expect(repository.calls, isEmpty);
    },
  );

  test('observed access and reconnect refresh only that deck once', () async {
    await _install(store, 'd1');
    await _install(store, 'd2');
    source.cards['d1'] = [_card('fresh', 'd1', front: 'Fresh')];
    final statuses = StreamController<bool>.broadcast();
    final container = ProviderContainer(
      overrides: [
        appDatabaseProvider.overrideWithValue(database),
        connectivityServiceProvider.overrideWithValue(_Connectivity(true)),
        onlineStatusProvider.overrideWith((ref) => statuses.stream),
        offlineDownloadSourceProvider.overrideWithValue(source),
        deckRepositoryProvider.overrideWithValue(FakeDeckRepository()),
      ],
    );
    addTearDown(statuses.close);
    addTearDown(container.dispose);
    final firstPackageCommit = Completer<void>();
    final commitSub = container
        .read(offlineDeckCommitBusProvider)
        .events
        .where(
          (event) =>
              event.deckId == 'd1' &&
              event.kind == OfflineDeckCommitKind.package,
        )
        .listen((_) {
          if (!firstPackageCommit.isCompleted) firstPackageCommit.complete();
        });
    addTearDown(commitSub.cancel);
    final cardsSub = container.listen(
      deckCardsProvider('d1'),
      (_, _) {},
      fireImmediately: true,
    );
    final observationSub = container.listen(
      offlineDeckObservationProvider('d1'),
      (_, _) {},
      fireImmediately: true,
    );
    final preSessionSub = container.listen(
      preSessionCardsProvider('d1'),
      (_, _) {},
      fireImmediately: true,
    );
    addTearDown(cardsSub.close);
    addTearDown(observationSub.close);
    addTearDown(preSessionSub.close);
    expect(
      (await container.read(deckCardsProvider('d1').future)).single.id,
      'old-d1',
    );

    statuses.add(true);
    await _waitFor(
      () => source.fetchDeckCalls.length == 2,
      'initial refresh completes exactly once: ${source.fetchDeckCalls}',
    );
    await firstPackageCommit.future.timeout(const Duration(seconds: 2));
    expect(source.fetchDeckCalls, everyElement('d1'));
    statuses.add(true);
    await Future<void>.delayed(const Duration(milliseconds: 10));
    expect(source.fetchDeckCalls.length, 2);

    statuses.add(false);
    await _waitFor(
      () => container.read(onlineStatusProvider).asData?.value == false,
      'offline edge is observed',
    );
    statuses.add(true);
    await _waitFor(
      () => source.fetchDeckCalls.length == 4,
      'reconnect refresh completes exactly once: ${source.fetchDeckCalls}',
    );
    expect(source.fetchDeckCalls, everyElement('d1'));
  });

  test('pre-session online revalidation is bounded to genuine access', () async {
    await _install(store, 'downloaded');
    source.cards['downloaded'] = [_card('fresh-downloaded', 'downloaded')];
    final remote = FakeDeckRepository(cards: [_card('remote', 'online')]);
    final connectivity = _Connectivity(true);
    final statuses = StreamController<bool>.broadcast();
    final container = ProviderContainer(
      overrides: [
        appDatabaseProvider.overrideWithValue(database),
        connectivityServiceProvider.overrideWithValue(connectivity),
        onlineStatusProvider.overrideWith((ref) => statuses.stream),
        offlineDownloadSourceProvider.overrideWithValue(source),
        deckRepositoryProvider.overrideWith((ref) {
          return CacheFirstDeckRepository(
            remote,
            ref.watch(localDeckStoreProvider),
            ref.watch(localCourseStoreProvider),
          );
        }),
      ],
    );
    addTearDown(statuses.close);
    addTearDown(container.dispose);

    final onlineSub = container.listen(
      preSessionCardsProvider('online'),
      (_, _) {},
      fireImmediately: true,
    );
    expect(
      (await container.read(preSessionCardsProvider('online').future)).single.id,
      'remote',
    );
    statuses.add(true);
    statuses.add(true);
    await Future<void>.delayed(const Duration(milliseconds: 30));
    expect(remote.calls, ['fetchCards(online)']);

    // Keeping the mode-selection consumer mounted must not turn its own cache
    // commit, or duplicate online status events, into another revalidation.
    await Future<void>.delayed(const Duration(milliseconds: 30));
    expect(remote.calls, ['fetchCards(online)']);
    onlineSub.close();
    await Future<void>.delayed(Duration.zero);

    connectivity.online = false;
    statuses.add(false);
    await _waitFor(
      () => container.read(onlineStatusProvider).asData?.value == false,
      'offline state is visible before reopening',
    );
    final offlineSub = container.listen(
      preSessionCardsProvider('online'),
      (_, _) {},
      fireImmediately: true,
    );
    expect(
      (await container.read(preSessionCardsProvider('online').future)).single.id,
      'remote',
    );
    expect(remote.calls, ['fetchCards(online)']);
    offlineSub.close();
    await Future<void>.delayed(Duration.zero);

    connectivity.online = true;
    statuses.add(true);
    await _waitFor(
      () => container.read(onlineStatusProvider).asData?.value == true,
      'online state is visible before reopening',
    );
    final downloadedSub = container.listen(
      preSessionCardsProvider('downloaded'),
      (_, _) {},
      fireImmediately: true,
    );
    expect(
      (await container
              .read(preSessionCardsProvider('downloaded').future))
          .single
          .id,
      'old-downloaded',
    );
    expect(remote.calls, ['fetchCards(online)']);
    final automaticRefreshes = source.fetchDeckCalls.length;
    statuses.add(true);
    await Future<void>.delayed(const Duration(milliseconds: 30));
    expect(source.fetchDeckCalls.length, automaticRefreshes);
    downloadedSub.close();
    await Future<void>.delayed(Duration.zero);

    final reopenedSub = container.listen(
      preSessionCardsProvider('online'),
      (_, _) {},
      fireImmediately: true,
    );
    expect(
      (await container.read(preSessionCardsProvider('online').future)).single.id,
      'remote',
    );
    expect(remote.calls, ['fetchCards(online)', 'fetchCards(online)']);
    reopenedSub.close();
  });
}

Future<void> _waitFor(bool Function() condition, [String? reason]) async {
  for (var i = 0; i < 1000 && !condition(); i++) {
    await Future<void>.delayed(const Duration(milliseconds: 2));
  }
  expect(condition(), isTrue, reason: reason);
}
