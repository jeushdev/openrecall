import 'package:flutter/foundation.dart';

/// One `session_cards` row (spec schema): a card's slot in a session's queue,
/// plus the two loop-prevention counters that are strictly session-scoped —
/// [consecutiveFails] resets on a pass, [isParked] dies with the session, and
/// neither is ever written back to `cards`. No `updated_at`.
@immutable
class SessionCard {
  const SessionCard({
    required this.id,
    required this.sessionId,
    required this.cardId,
    required this.position,
    required this.consecutiveFails,
    required this.isParked,
  });

  factory SessionCard.fromJson(Map<String, dynamic> json) => SessionCard(
    id: json['id'] as String,
    sessionId: json['session_id'] as String,
    cardId: json['card_id'] as String,
    position: json['position'] as int,
    consecutiveFails: json['consecutive_fails'] as int,
    isParked: json['is_parked'] as bool,
  );

  final String id;
  final String sessionId;
  final String cardId;
  final int position;
  final int consecutiveFails;
  final bool isParked;

  @override
  bool operator ==(Object other) =>
      other is SessionCard &&
      other.id == id &&
      other.sessionId == sessionId &&
      other.cardId == cardId &&
      other.position == position &&
      other.consecutiveFails == consecutiveFails &&
      other.isParked == isParked;

  @override
  int get hashCode =>
      Object.hash(id, sessionId, cardId, position, consecutiveFails, isParked);
}
