import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:open_recall/features/decks/application/deck_providers.dart';
import 'package:open_recall/features/decks/domain/card.dart';
import 'package:open_recall/features/decks/domain/study_mode.dart';
import 'package:open_recall/features/study/application/session_controller.dart';
import 'package:open_recall/features/study/domain/flip_rating.dart';
import 'package:open_recall/features/study/domain/session_length.dart';

import '../../support/fake_deck_repository.dart';
import '../../support/fake_study_repository.dart';

void main() {
  test(
    'queue mutations drain before session completion is committed',
    () async {
      final decks = FakeDeckRepository(
        cards: [
          FlashCard(
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
          ),
        ],
      );
      final study = FakeStudyRepository();
      final container = ProviderContainer(
        overrides: [
          deckRepositoryProvider.overrideWithValue(decks),
          studyRepositoryProvider.overrideWithValue(study),
        ],
      );
      addTearDown(container.dispose);
      final controller = container.read(sessionControllerProvider.notifier);
      await controller.start(
        deckId: 'deck-1',
        deckName: 'Biology',
        mode: StudyMode.flip,
        lengthMode: SessionLengthMode.untilMastered,
        cap: null,
      );

      controller.rate(FlipRating.forgotten);
      controller.rate(FlipRating.mastered);
      await pumpEventQueue();

      final queueWrite = study.calls.indexWhere(
        (call) => call.startsWith('updateSessionCard'),
      );
      final completion = study.calls.indexWhere(
        (call) => call.startsWith('completeSession'),
      );
      expect(queueWrite, isNonNegative);
      expect(completion, greaterThan(queueWrite));
    },
  );
}
