import 'package:flutter_test/flutter_test.dart';
import 'package:open_recall/features/decks/domain/study_mode.dart';
import 'package:open_recall/features/study/domain/session_card.dart';
import 'package:open_recall/features/study/domain/session_length.dart';
import 'package:open_recall/features/study/domain/session_status.dart';
import 'package:open_recall/features/study/domain/study_session.dart';

void main() {
  group('SessionStatus', () {
    test('round-trips every DB string', () {
      for (final status in SessionStatus.values) {
        expect(sessionStatusFromDb(status.name), status);
      }
    });
  });

  group('StudySession.fromJson', () {
    Map<String, dynamic> row({
      String status = 'active',
      String lengthMode = 'uncapped',
      int? cappedLength,
      int? masteryDelta,
      String? completedAt,
    }) => {
      'id': 'session-1',
      'deck_id': 'deck-1',
      'status': status,
      'study_mode': 'flip',
      'length_mode': lengthMode,
      'capped_length': cappedLength,
      'mastery_delta': masteryDelta,
      'started_at': '2026-08-01T00:00:00Z',
      'completed_at': completedAt,
    };

    test('maps the columns onto the model', () {
      final session = StudySession.fromJson(
        row(
          status: 'completed',
          lengthMode: 'capped',
          cappedLength: 20,
          masteryDelta: 15,
          completedAt: '2026-08-01T01:00:00Z',
        ),
      );

      expect(session.id, 'session-1');
      expect(session.deckId, 'deck-1');
      expect(session.status, SessionStatus.completed);
      expect(session.studyMode, StudyMode.flip);
      expect(session.lengthMode, SessionLengthMode.capped);
      expect(session.cappedLength, 20);
      expect(session.masteryDelta, 15);
      expect(session.startedAt, DateTime.utc(2026, 8, 1));
      expect(session.completedAt, DateTime.utc(2026, 8, 1, 1));
    });

    test('leaves the nullable columns null', () {
      final session = StudySession.fromJson(row());
      expect(session.cappedLength, isNull);
      expect(session.masteryDelta, isNull);
      expect(session.completedAt, isNull);
      expect(session.lengthMode, SessionLengthMode.untilMastered);
    });

    test('equal field-for-field', () {
      expect(StudySession.fromJson(row()), StudySession.fromJson(row()));
      expect(
        StudySession.fromJson(row(status: 'abandoned')),
        isNot(StudySession.fromJson(row())),
      );
    });
  });

  group('SessionCard.fromJson', () {
    Map<String, dynamic> row({
      int position = 1000,
      int consecutiveFails = 0,
      bool isParked = false,
    }) => {
      'id': 'sc-1',
      'session_id': 'session-1',
      'card_id': 'card-1',
      'position': position,
      'consecutive_fails': consecutiveFails,
      'is_parked': isParked,
    };

    test('maps the columns onto the model', () {
      final sc = SessionCard.fromJson(
        row(position: 3000, consecutiveFails: 2, isParked: true),
      );
      expect(sc.id, 'sc-1');
      expect(sc.sessionId, 'session-1');
      expect(sc.cardId, 'card-1');
      expect(sc.position, 3000);
      expect(sc.consecutiveFails, 2);
      expect(sc.isParked, isTrue);
    });

    test('equal field-for-field', () {
      expect(SessionCard.fromJson(row()), SessionCard.fromJson(row()));
      expect(
        SessionCard.fromJson(row(position: 2000)),
        isNot(SessionCard.fromJson(row())),
      );
    });
  });
}
