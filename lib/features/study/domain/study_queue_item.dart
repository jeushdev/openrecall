import 'package:flutter/foundation.dart';

import '../../decks/domain/card.dart';

/// A card's live slot in the in-memory session queue. Merges the persisted
/// `session_cards` counters ([position], [consecutiveFails], [isParked]) with
/// the card itself and its optimistic [masteryLevel] — the value shown and
/// written before the background `cards` write confirms.
@immutable
class StudyQueueItem {
  const StudyQueueItem({
    required this.sessionCardId,
    required this.card,
    required this.position,
    required this.consecutiveFails,
    required this.isParked,
    required this.masteryLevel,
    this.requeueCount = 0,
  });

  final String sessionCardId;
  final FlashCard card;
  final int position;
  final int consecutiveFails;
  final bool isParked;
  final int masteryLevel;

  /// The number of below-Mastered results for this card in this live session.
  /// This is deliberately in-memory only: it identifies a returning attempt,
  /// not the card's lifetime failure history.
  final int requeueCount;

  String get cardId => card.id;

  StudyQueueItem copyWith({
    int? position,
    int? consecutiveFails,
    bool? isParked,
    int? masteryLevel,
    int? requeueCount,
  }) => StudyQueueItem(
    sessionCardId: sessionCardId,
    card: card,
    position: position ?? this.position,
    consecutiveFails: consecutiveFails ?? this.consecutiveFails,
    isParked: isParked ?? this.isParked,
    masteryLevel: masteryLevel ?? this.masteryLevel,
    requeueCount: requeueCount ?? this.requeueCount,
  );

  @override
  bool operator ==(Object other) =>
      other is StudyQueueItem &&
      other.sessionCardId == sessionCardId &&
      other.card == card &&
      other.position == position &&
      other.consecutiveFails == consecutiveFails &&
      other.isParked == isParked &&
      other.masteryLevel == masteryLevel &&
      other.requeueCount == requeueCount;

  @override
  int get hashCode => Object.hash(
    sessionCardId,
    card,
    position,
    consecutiveFails,
    isParked,
    masteryLevel,
    requeueCount,
  );
}
