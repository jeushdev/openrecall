import 'package:flutter/foundation.dart';

/// One entry to write into `session_cards` at session creation: a card id and
/// its sparse [position] in the queue.
@immutable
class QueueSeed {
  const QueueSeed({required this.cardId, required this.position});

  final String cardId;
  final int position;

  @override
  bool operator ==(Object other) =>
      other is QueueSeed &&
      other.cardId == cardId &&
      other.position == position;

  @override
  int get hashCode => Object.hash(cardId, position);
}
