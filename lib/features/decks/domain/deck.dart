import 'package:flutter/foundation.dart';

import 'card.dart';

/// A deck row on its own (spec §2 schema).
@immutable
class Deck {
  const Deck({
    required this.id,
    required this.name,
    required this.lastStudiedAt,
    required this.createdAt,
    required this.updatedAt,
  });

  factory Deck.fromJson(Map<String, dynamic> json) => Deck(
        id: json['id'] as String,
        name: json['name'] as String,
        lastStudiedAt: _parseNullableDate(json['last_studied_at']),
        createdAt: DateTime.parse(json['created_at'] as String),
        updatedAt: DateTime.parse(json['updated_at'] as String),
      );

  final String id;
  final String name;
  final DateTime? lastStudiedAt;
  final DateTime createdAt;
  final DateTime updatedAt;
}

/// A deck plus the aggregate counts the Deck Library shows for it (spec §2):
/// mastery %, due/total card counts, last-studied date.
///
/// Mastery % and due count are derived from `cards.mastery_level`. Until the
/// session engine (milestone 6) starts moving that value, every card sits at
/// 0, so a fresh deck shows 0% with every card due — expected, not a bug.
@immutable
class DeckSummary {
  const DeckSummary({
    required this.id,
    required this.name,
    required this.lastStudiedAt,
    required this.totalCards,
    required this.dueCards,
    required this.masteryPercent,
  });

  /// Builds from a `decks` row with an embedded `cards(mastery_level)` list,
  /// as returned by the nested select in [DeckRepository.fetchDecks].
  factory DeckSummary.fromJson(Map<String, dynamic> json) {
    final cards = (json['cards'] as List<dynamic>? ?? const [])
        .cast<Map<String, dynamic>>();
    final levels = cards.map((c) => c['mastery_level'] as int).toList();

    return DeckSummary(
      id: json['id'] as String,
      name: json['name'] as String,
      lastStudiedAt: _parseNullableDate(json['last_studied_at']),
      totalCards: levels.length,
      dueCards: levels.where((l) => l < masteredLevel).length,
      masteryPercent: masteryPercentFromLevels(levels),
    );
  }

  final String id;
  final String name;
  final DateTime? lastStudiedAt;
  final int totalCards;
  final int dueCards;
  final int masteryPercent;
}

DateTime? _parseNullableDate(Object? value) =>
    value == null ? null : DateTime.parse(value as String);
