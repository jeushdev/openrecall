import 'dart:async';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:open_recall/core/connectivity/connectivity_service.dart';
import 'package:open_recall/core/sync/sync_service.dart';
import 'package:open_recall/features/courses/data/local_course_store.dart';
import 'package:open_recall/features/decks/data/local_deck_store.dart';
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

class _StudyOnlySyncService extends SyncService {
  _StudyOnlySyncService(
    SupabaseClient client,
    LocalDeckStore decks,
    LocalCourseStore courses,
    LocalStudyStore study,
  ) : super(client, decks, courses, study, _AlwaysOnline());

  @override
  String? currentUserId() => 'user-1';

  @override
  Future<void> pushCourses(String userId) async {}
  @override
  Future<void> pushDecks(String userId) async {}
  @override
  Future<void> pushCardContent() async {}
  @override
  Future<void> pushCards() async {}
  @override
  Future<void> processDeletions() async {}
}

StudySession _session() => StudySession(
  id: 'session-1',
  deckId: 'deck-1',
  status: SessionStatus.active,
  studyMode: StudyMode.flip,
  lengthMode: SessionLengthMode.untilMastered,
  cappedLength: null,
  cardScope: CardScope.due,
  masteryDelta: null,
  startedAt: DateTime.utc(2026),
  completedAt: null,
);

const _queue = SessionCard(
  id: 'queue-1',
  sessionId: 'session-1',
  cardId: 'card-1',
  position: 1000,
  consecutiveFails: 0,
  isParked: false,
);

void main() {
  setUpAll(initLocalDbTestFfi);

  test(
    'reconnect replay is parent-first, idempotent, and does not duplicate',
    () async {
      final database = await openTestDatabase();
      addTearDown(database.close);
      final study = LocalStudyStore(database.db);
      await study.insertSession(_session(), 'user-1', synced: false);
      await study.insertSessionCards(const [_queue], synced: false);
      final requests = <String>[];
      final client = SupabaseClient(
        'http://localhost:54321',
        'test-key',
        httpClient: MockClient((request) async {
          requests.add('${request.method} ${request.url.path}');
          return http.Response(
            '[]',
            200,
            headers: {'content-type': 'application/json'},
            request: request,
          );
        }),
      );
      addTearDown(client.dispose);
      final sync = _StudyOnlySyncService(
        client,
        LocalDeckStore(database.db),
        LocalCourseStore(database.db),
        study,
      );
      addTearDown(sync.dispose);

      await sync.syncPending();
      await sync.syncPending();

      expect(requests, [
        'PATCH /rest/v1/study_sessions',
        'POST /rest/v1/study_sessions',
        'POST /rest/v1/session_cards',
      ]);
      expect(await study.unsyncedSessions(), isEmpty);
      expect(await study.unsyncedSessionCards(), isEmpty);
      expect(sync.lastOutcome.kind, SyncOutcomeKind.ok);
    },
  );

  test(
    'a completion committed after send survives the late acknowledgment',
    () async {
      final database = await openTestDatabase();
      addTearDown(database.close);
      final study = LocalStudyStore(database.db);
      await study.insertSession(_session(), 'user-1', synced: false);
      final requested = Completer<void>();
      final response = Completer<http.Response>();
      late http.BaseRequest upsertRequest;
      final client = SupabaseClient(
        'http://localhost:54321',
        'test-key',
        httpClient: MockClient((request) async {
          if (request.method == 'PATCH') {
            return http.Response(
              '[]',
              200,
              headers: {'content-type': 'application/json'},
              request: request,
            );
          }
          upsertRequest = request;
          requested.complete();
          return response.future;
        }),
      );
      addTearDown(client.dispose);
      final sync = _StudyOnlySyncService(
        client,
        LocalDeckStore(database.db),
        LocalCourseStore(database.db),
        study,
      );
      addTearDown(sync.dispose);

      final pending = sync.pushSessions();
      await requested.future;
      await study.completeSession('session-1', 100, 1, synced: false);
      response.complete(
        http.Response(
          '[]',
          200,
          headers: {'content-type': 'application/json'},
          request: upsertRequest,
        ),
      );
      await pending;

      final dirty = (await study.unsyncedSessions()).single;
      expect(dirty.values['status'], 'completed');
      expect(dirty.values['mastery_delta'], 100);
      expect(dirty.values['cards_reviewed'], 1);
    },
  );
}
