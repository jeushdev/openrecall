import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:open_recall/core/local_db/local_db_providers.dart';
import 'package:open_recall/features/courses/data/local_course_store.dart';
import 'package:open_recall/features/decks/application/deck_providers.dart';
import 'package:open_recall/features/decks/data/cache_first_deck_repository.dart';
import 'package:open_recall/features/decks/data/local_deck_store.dart';
import 'package:open_recall/features/decks/domain/card.dart';
import 'package:open_recall/features/decks/domain/study_mode.dart';
import 'package:open_recall/features/study/application/session_controller.dart';
import 'package:open_recall/features/study/data/cache_first_study_repository.dart';
import 'package:open_recall/features/study/data/local_study_store.dart';
import 'package:open_recall/features/study/domain/cloze_outcome.dart';
import 'package:open_recall/features/study/domain/flip_rating.dart';
import 'package:open_recall/features/study/domain/session_length.dart';

import '../../support/fake_deck_repository.dart';
import '../../support/fake_study_repository.dart';
import '../../support/local_db_harness.dart';

FlashCard _card() => FlashCard(
  id: 'card-1',
  deckId: 'deck-1',
  front: 'Mitochondria produce ATP',
  back: 'Cellular respiration',
  keywords: const ['ATP'],
  isConcept: true,
  masteryLevel: 0,
  failCount: 0,
  createdAt: DateTime.utc(2026),
  updatedAt: DateTime.utc(2026),
);

void main() {
  setUpAll(initLocalDbTestFfi);

  for (final mode in StudyMode.values) {
    test(
      '${mode.name} starts and finishes while every remote write is stalled',
      () async {
        final database = await openTestDatabase();
        addTearDown(database.close);
        final localDecks = LocalDeckStore(database.db);
        final localStudy = LocalStudyStore(database.db);
        final card = _card();
        await localDecks.commitDeckPackage(
          deckId: 'deck-1',
          deckName: 'Biology',
          cards: [card],
        );
        final remoteDecks = FakeDeckRepository(cards: [card])
          ..guardGate = Completer<void>();
        final remoteStudy = FakeStudyRepository()
          ..writeGate = Completer<void>();
        final decks = CacheFirstDeckRepository(
          remoteDecks,
          localDecks,
          LocalCourseStore(database.db),
        );
        final study = CacheFirstStudyRepository(
          remoteStudy,
          localStudy,
          localDecks,
          () => 'user-1',
        );
        final container = ProviderContainer(
          overrides: [
            appDatabaseProvider.overrideWithValue(database),
            deckRepositoryProvider.overrideWithValue(decks),
            studyRepositoryProvider.overrideWithValue(study),
          ],
        );
        addTearDown(container.dispose);
        final controller = container.read(sessionControllerProvider.notifier);

        await controller
            .start(
              deckId: 'deck-1',
              deckName: 'Biology',
              mode: mode,
              lengthMode: SessionLengthMode.untilMastered,
              cap: null,
            )
            .timeout(const Duration(milliseconds: 250));
        expect(
          container.read(sessionControllerProvider).value!.isComplete,
          isFalse,
        );

        if (mode == StudyMode.cloze) {
          final attemptId = container
              .read(sessionControllerProvider)
              .value!
              .currentAttemptId!;
          controller.submitCloze(
            attemptId,
            const ClozeResult(outcome: ClozeOutcome.correct, hintUsed: false),
          );
        } else {
          controller.rate(FlipRating.mastered);
        }
        for (var i = 0; i < 20; i++) {
          await Future<void>.delayed(Duration.zero);
          final rows = await localStudy.unsyncedSessions();
          if (rows.any((row) => row.values['status'] == 'completed')) break;
        }

        expect(
          container.read(sessionControllerProvider).value!.isComplete,
          isTrue,
        );
        expect(
          (await localStudy.unsyncedSessions()).single.values['status'],
          'completed',
        );
        expect((await localStudy.unsyncedSessionCards()).single.id, isNotEmpty);
        expect((await localDecks.unsyncedCards()).single.masteryLevel, 4);
        expect(
          (await localDecks.unsyncedDecks()).single.lastStudiedAt,
          isNotNull,
        );
        expect(remoteDecks.calls, isEmpty);
        expect(remoteStudy.calls, isEmpty);
      },
    );
  }
}
