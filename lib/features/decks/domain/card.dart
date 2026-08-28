import 'package:flutter/foundation.dart';

/// The `mastery_level` value that means "Mastered" — the top of the 0–4
/// Unfamiliar…Mastered scale (spec §6). A card counts as "due" until it
/// reaches this.
const int masteredLevel = 4;

/// Deck-level mastery %, defined once (spec §6/§88): the average `mastery_level`
/// across [levels], scaled from the 0–[masteredLevel] range to 0–100 and
/// rounded. An empty deck is 0%. Shared by the Deck Library and Deck Overview.
int masteryPercentFromLevels(Iterable<int> levels) {
  final list = levels.toList();
  if (list.isEmpty) return 0;
  final sum = list.reduce((a, b) => a + b);
  return (sum / (list.length * masteredLevel) * 100).round();
}

/// The unified card model (spec §3): every card is `front` + `back` +
/// optional `keyword`, with no stored `type`. Which study modes a card
/// supports is computed elsewhere, at read time.
@immutable
class FlashCard {
  const FlashCard({
    required this.id,
    required this.deckId,
    required this.front,
    required this.back,
    required this.keyword,
    required this.masteryLevel,
    required this.failCount,
    required this.createdAt,
    required this.updatedAt,
  });

  factory FlashCard.fromJson(Map<String, dynamic> json) => FlashCard(
        id: json['id'] as String,
        deckId: json['deck_id'] as String,
        front: json['front'] as String,
        back: json['back'] as String,
        keyword: json['keyword'] as String?,
        masteryLevel: json['mastery_level'] as int,
        failCount: json['fail_count'] as int,
        createdAt: DateTime.parse(json['created_at'] as String),
        updatedAt: DateTime.parse(json['updated_at'] as String),
      );

  final String id;
  final String deckId;
  final String front;
  final String back;
  final String? keyword;
  final int masteryLevel;
  final int failCount;
  final DateTime createdAt;
  final DateTime updatedAt;

  bool get isDue => masteryLevel < masteredLevel;

  @override
  bool operator ==(Object other) =>
      other is FlashCard &&
      other.id == id &&
      other.deckId == deckId &&
      other.front == front &&
      other.back == back &&
      other.keyword == keyword &&
      other.masteryLevel == masteryLevel &&
      other.failCount == failCount &&
      other.createdAt == createdAt &&
      other.updatedAt == updatedAt;

  @override
  int get hashCode => Object.hash(
        id,
        deckId,
        front,
        back,
        keyword,
        masteryLevel,
        failCount,
        createdAt,
        updatedAt,
      );
}
