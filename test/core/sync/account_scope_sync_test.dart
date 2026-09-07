import 'dart:async';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:open_recall/core/connectivity/connectivity_service.dart';
import 'package:open_recall/core/sync/sync_service.dart';
import 'package:open_recall/features/courses/data/local_course_store.dart';
import 'package:open_recall/features/decks/data/local_deck_store.dart';
import 'package:open_recall/features/study/data/local_study_store.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../support/local_db_harness.dart';

void main() {
  setUpAll(initLocalDbTestFfi);

  test(
    'an in-flight old-account push cannot acknowledge or send another request',
    () async {
      final database = await openTestDatabase();
      addTearDown(database.close);
      final courses = LocalCourseStore(database.db);
      await courses.createCourse(
        id: 'course',
        userId: 'a',
        name: 'Biology',
        accentColor: 'green',
      );
      var current = true;
      var requests = 0;
      final requested = Completer<void>();
      final response = Completer<http.Response>();
      final client = SupabaseClient(
        'http://localhost:54321',
        'test-key',
        httpClient: MockClient((request) async {
          requests++;
          requested.complete();
          return response.future;
        }),
      );
      addTearDown(client.dispose);
      final sync = SyncService(
        client,
        LocalDeckStore(database.db),
        courses,
        LocalStudyStore(database.db),
        ConnectivityService(Connectivity()),
        isCurrent: () => current,
      );
      addTearDown(sync.dispose);
      final pending = sync.pushCourses('a');
      await requested.future;
      current = false;
      response.complete(
        http.Response(
          '{"updated_at":"2026-09-07T00:00:00.000Z"}',
          200,
          headers: {'content-type': 'application/json'},
        ),
      );
      await pending;
      expect(requests, 1);
      expect(await courses.unsyncedCourses(), hasLength(1));
    },
  );
}
