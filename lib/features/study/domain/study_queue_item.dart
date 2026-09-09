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
  });

  final String sessionCardId;
  final FlashCard card;
  final int position;
  final int consecutiveFails;
  final bool isParked;
  final int masteryLevel;

  String get cardId => card.id;

  StudyQueueItem copyWith({
    int? position,
    int? consecutiveFails,
    bool? isParked,
    int? masteryLevel,
  }) => StudyQueueItem(
    sessionCardId: sessionCardId,
    card: card,
    position: position ?? this.position,
    consecutiveFails: consecutiveFails ?? this.consecutiveFails,
    isParked: isParked ?? this.isParked,
    masteryLevel: masteryLevel ?? this.masteryLevel,
  );

  @override
  bool operator ==(Object other) =>
      other is StudyQueueItem &&
      other.sessionCardId == sessionCardId &&
      other.card == card &&
      other.position == position &&
      other.consecutiveFails == consecutiveFails &&
      other.isParked == isParked &&
      other.masteryLevel == masteryLevel;

  @override
  int get hashCode => Object.hash(
    sessionCardId,
    card,
    position,
    consecutiveFails,
    isParked,
    masteryLevel,
  );
}
