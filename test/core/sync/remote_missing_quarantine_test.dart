import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:open_recall/core/connectivity/connectivity_service.dart';
import 'package:open_recall/core/sync/sync_service.dart';
import 'package:open_recall/features/courses/data/local_course_store.dart';
import 'package:open_recall/features/decks/data/local_deck_store.dart';
import 'package:open_recall/features/decks/domain/card.dart';
import 'package:open_recall/features/decks/domain/study_mode.dart';
import 'package:open_recall/features/study/data/local_study_store.dart';
import 'package:open_recall/features/study/domain/session_card.dart';
import 'package:open_recall/features/study/domain/session_length.dart';
import 'package:open_recall/features/study/domain/session_status.dart';
import 'package:open_recall/features/study/domain/study_session.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../support/local_db_harness.dart';

class _AlwaysOnline extends ConnectivityService {
  _AlwaysOnline() : super(Connectivity());

  @override
  Future<bool> isOnline() async => true;
}

class _SignedInSyncService extends SyncService {
  _SignedInSyncService(
    super.client,
    super.decks,
    super.courses,
    super.study,
    super.connectivity,
  );

  @override
  String? currentUserId() => 'user-1';
}

FlashCard _card() => FlashCard(
  id: 'card-1',
  deckId: 'deck-1',
  front: 'Question',
  back: 'Answer',
  keywords: const [],
  isConcept: false,
  masteryLevel: 0,
  failCount: 0,
  createdAt: DateTime.utc(2026),
  updatedAt: DateTime.utc(2026),
);

StudySession _session() => StudySession(
  id: 'session-1',
  deckId: 'deck-1',
  status: SessionStatus.completed,
  studyMode: StudyMode.flip,
  lengthMode: SessionLengthMode.untilMastered,
  cappedLength: null,
  cardScope: CardScope.due,
  masteryDelta: 0,
  startedAt: DateTime.utc(2026),
  completedAt: DateTime.utc(2026, 1, 2),
);

void main() {
  setUpAll(initLocalDbTestFfi);

  test('confirmed-missing descendants stay pending without remote resurrection or false failure', () async {
    final database = await openTestDatabase();
    addTearDown(database.close);
    final decks = LocalDeckStore(database.db);
    final courses = LocalCourseStore(database.db);
    final study = LocalStudyStore(database.db);
    await decks.createDeck(id: 'deck-1', name: 'Local deck');
    await decks.insertCards([_card()]);
    await study.insertSession(_session(), 'user-1', synced: false);
    await study.insertSessionCards(const [
      SessionCard(
        id: 'queue-1',
        sessionId: 'session-1',
        cardId: 'card-1',
        position: 0,
        consecutiveFails: 0,
        isParked: false,
      ),
    ], synced: false);
    await decks.setRemoteMissing('deck-1', missing: true);

    final requests = <String>[];
    final client = SupabaseClient(
      'http://localhost:54321',
      'test-key',
      httpClient: MockClient((request) async {
        requests.add('${request.method} ${request.url.path}');
        if (request.url.path == '/rest/v1/decks') {
          return http.Response(
            '{"id":"deck-1","updated_at":"2026-02-01T00:00:00.000Z"}',
            200,
            headers: {'content-type': 'application/json'},
            request: request,
          );
        }
        return http.Response(
          '[]',
          200,
          headers: {'content-type': 'application/json'},
          request: request,
        );
      }),
    );
    addTearDown(client.dispose);
    final sync = _SignedInSyncService(
      client,
      decks,
      courses,
      study,
      _AlwaysOnline(),
    );
    addTearDown(sync.dispose);

    await sync.syncPending();

    expect(requests, isEmpty);
    expect(sync.lastOutcome.kind, SyncOutcomeKind.ok);
    expect(sync.nextAllowedAt, isNull);
    expect(await decks.unsyncedDecks(), hasLength(1));
    expect(await decks.contentDirtyCards(), hasLength(1));
    expect(await study.unsyncedSessions(), hasLength(1));
    expect(await study.unsyncedSessionCards(), hasLength(1));

    await decks.setRemoteMissing('deck-1', missing: false);
    await sync.pushDecks('user-1');

    expect(requests, [
      'POST /rest/v1/decks',
      'POST /rest/v1/rpc/set_deck_positions',
    ]);
    expect(await decks.unsyncedDecks(), isEmpty);
  });
}
