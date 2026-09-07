import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:open_recall/core/connectivity/connectivity_service.dart';
import 'package:open_recall/core/local_db/local_db_providers.dart';
import 'package:open_recall/core/sync/sync_providers.dart';
import 'package:open_recall/features/decks/domain/study_mode.dart';
import 'package:open_recall/features/study/domain/session_length.dart';
import 'package:open_recall/features/study/domain/session_status.dart';
import 'package:open_recall/features/study/domain/study_session.dart';

import '../../support/local_db_harness.dart';

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

void main() {
  setUpAll(initLocalDbTestFfi);

  test('pending providers expose locally committed study work', () async {
    final database = await openTestDatabase();
    addTearDown(database.close);
    final container = ProviderContainer(
      overrides: [
        appDatabaseProvider.overrideWithValue(database),
        onlineStatusProvider.overrideWith((ref) => Stream.value(true)),
      ],
    );
    addTearDown(container.dispose);

    await container
        .read(localStudyStoreProvider)
        .insertSession(_session(), 'user-1', synced: false);

    expect(await container.read(pendingSyncProvider.future), isTrue);
    expect(await container.read(pendingSyncCountProvider.future), 1);
  });

  test(
    'without SQLite pending providers preserve online-only semantics',
    () async {
      final container = ProviderContainer(
        overrides: [
          onlineStatusProvider.overrideWith((ref) => Stream.value(true)),
        ],
      );
      addTearDown(container.dispose);

      expect(await container.read(pendingSyncProvider.future), isFalse);
      expect(await container.read(pendingSyncCountProvider.future), 0);
    },
  );
}
