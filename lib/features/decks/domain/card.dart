import 'package:flutter/foundation.dart';

/// The `mastery_level` value that means "Mastered" — the top of the 0–4
/// Unfamiliar…Mastered scale (spec §6). A card counts as "due" until it
/// reaches this.
const int masteredLevel = 4;

/// Deck-level mastery %, defined once (spec §6/§88): the average `mastery_level`
/// across [levels], scaled from the 0–[masteredLevel] range to 0–100 and
/// rounded. An empty deck is 0%. Shared by the Deck Library and Deck Overview.
int masteryPercentFromLevels(Iterable<int> levels) {
  var sum = 0;
  var count = 0;
  for (final level in levels) {
    sum += level;
    count++;
  }
  return masteryPercentFromLevelSum(sum, count);
}

/// The same 0–100 mastery figure as [masteryPercentFromLevels], but from a
/// pre-computed level [sum] over [count] cards. Lets the aggregation layer
/// (engine-v2-spec §6) roll a card-weighted overall/per-course % up from the
/// `masteryLevelSum` each `DeckSummary` already carries, without re-flattening
/// every card. [count] of 0 is 0%.
int masteryPercentFromLevelSum(int sum, int count) {
  if (count == 0) return 0;
  return (sum / (count * masteredLevel) * 100).round();
}

/// The unified card model (docs/spec-v3-card-model.md): every card is `front` +
/// `back`, plus a list of Cloze `keywords` and an `isConcept` flag, with no
/// stored `type`. Which study modes a card supports is computed elsewhere, at
/// read time.
@immutable
class FlashCard {
  const FlashCard({
    required this.id,
    required this.deckId,
    required this.front,
    required this.back,
    required this.keywords,
    required this.isConcept,
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
        keywords:
            (json['keywords'] as List?)?.cast<String>() ?? const <String>[],
        isConcept: json['is_concept'] as bool? ?? false,
        masteryLevel: json['mastery_level'] as int,
        failCount: json['fail_count'] as int,
        createdAt: DateTime.parse(json['created_at'] as String),
        updatedAt: DateTime.parse(json['updated_at'] as String),
      );

  final String id;
  final String deckId;
  final String front;
  final String back;
  final List<String> keywords;
  final bool isConcept;
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
      listEquals(other.keywords, keywords) &&
      other.isConcept == isConcept &&
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
        Object.hashAll(keywords),
        isConcept,
        masteryLevel,
        failCount,
        createdAt,
        updatedAt,
      );
}

/// Just the three `cards` columns the session engine needs to rebase a guarded
/// background write after the `updated_at` compare-and-set misses (see
/// [DeckRepository.updateCardMasteryGuarded]).
@immutable
class CardMasteryState {
  const CardMasteryState({
    required this.masteryLevel,
    required this.failCount,
    required this.updatedAt,
  });

  factory CardMasteryState.fromJson(Map<String, dynamic> json) =>
      CardMasteryState(
        masteryLevel: json['mastery_level'] as int,
        failCount: json['fail_count'] as int,
        updatedAt: DateTime.parse(json['updated_at'] as String),
      );

  final int masteryLevel;
  final int failCount;
  final DateTime updatedAt;
}
