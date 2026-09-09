import 'package:flutter/foundation.dart';

/// Identifies one appearance of a card in a live study queue.
///
/// A requeue changes [queuePosition], so even an immediate retry of the same
/// session-card row is a distinct attempt.
@immutable
class StudyAttemptId {
  const StudyAttemptId({
    required this.sessionId,
    required this.sessionCardId,
    required this.queuePosition,
  });

  final String sessionId;
  final String sessionCardId;
  final int queuePosition;

  @override
  bool operator ==(Object other) =>
      other is StudyAttemptId &&
      other.sessionId == sessionId &&
      other.sessionCardId == sessionCardId &&
      other.queuePosition == queuePosition;

  @override
  int get hashCode => Object.hash(sessionId, sessionCardId, queuePosition);
}

/// Live-session metadata recorded for a single study attempt.
@immutable
class StudyAttemptMetadata {
  const StudyAttemptMetadata({required this.hintUsed});

  final bool hintUsed;

  /// Assistance is monotonic: later writes can add it but never erase it.
  StudyAttemptMetadata merge({required bool hintUsed}) =>
      StudyAttemptMetadata(hintUsed: this.hintUsed || hintUsed);

  @override
  bool operator ==(Object other) =>
      other is StudyAttemptMetadata && other.hintUsed == hintUsed;

  @override
  int get hashCode => hintUsed.hashCode;
}
