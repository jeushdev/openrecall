import 'package:flutter/foundation.dart';

/// A card that shows up under the app-wide "Troublemakers" list
/// (engine-v2-spec §6): the cards with the highest lifetime `fail_count` across
/// every deck the user owns.
///
/// Lean by design — the query behind it selects only these five columns, not
/// the full `cards` row, so this is a separate model from `FlashCard` (no
/// `mastery_level`, no timestamps, no keywords — nothing here renders them).
@immutable
class TroublemakerCard {
  const TroublemakerCard({
    required this.id,
    required this.deckId,
    required this.front,
    required this.back,
    required this.failCount,
  });

  factory TroublemakerCard.fromJson(Map<String, dynamic> json) =>
      TroublemakerCard(
        id: json['id'] as String,
        deckId: json['deck_id'] as String,
        front: json['front'] as String,
        back: json['back'] as String,
        failCount: json['fail_count'] as int,
      );

  final String id;
  final String deckId;
  final String front;
  final String back;
  final int failCount;

  @override
  bool operator ==(Object other) =>
      other is TroublemakerCard &&
      other.id == id &&
      other.deckId == deckId &&
      other.front == front &&
      other.back == back &&
      other.failCount == failCount;

  @override
  int get hashCode => Object.hash(id, deckId, front, back, failCount);
}
