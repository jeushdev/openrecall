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
    this.courseId,
    this.position = 0,
  });

  factory Deck.fromJson(Map<String, dynamic> json) => Deck(
    id: json['id'] as String,
    name: json['name'] as String,
    courseId: json['course_id'] as String?,
    lastStudiedAt: _parseNullableDate(json['last_studied_at']),
    createdAt: DateTime.parse(json['created_at'] as String),
    updatedAt: DateTime.parse(json['updated_at'] as String),
    position: json['position'] as int? ?? 0,
  );

  final String id;
  final String name;

  /// The user's manual ordering key within its course's deck list (milestone
  /// B). Ascending; ties broken by [createdAt].
  final int position;

  /// The `courses` row this deck belongs to (engine-v2-spec §3.2). Nullable in
  /// the model only because the local mirror may not have it yet; a deck fetched
  /// from Supabase always has one (the column is NOT NULL, filled by a trigger).
  final String? courseId;
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
    this.courseId,
    this.masteryLevelSum = 0,
    this.position = 0,
    this.createdAt,
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
      courseId: json['course_id'] as String?,
      lastStudiedAt: _parseNullableDate(json['last_studied_at']),
      totalCards: levels.length,
      dueCards: levels.where((l) => l < masteredLevel).length,
      masteryPercent: masteryPercentFromLevels(levels),
      masteryLevelSum: levels.fold(0, (a, b) => a + b),
      position: json['position'] as int? ?? 0,
      createdAt: _parseNullableDate(json['created_at']),
    );
  }

  final String id;
  final String name;

  /// See [Deck.courseId].
  final String? courseId;
  final DateTime? lastStudiedAt;
  final int totalCards;
  final int dueCards;
  final int masteryPercent;

  /// The sum of every card's `mastery_level` in this deck. Kept alongside
  /// [totalCards] so the aggregation layer (engine-v2-spec §6) can compute a
  /// card-weighted overall / per-course mastery % without re-fetching cards —
  /// `masteryPercent` alone is lossy (already rounded and deck-averaged).
  final int masteryLevelSum;

  /// See [Deck.position].
  final int position;

  /// When the deck row was created (`decks.created_at`). Nullable because the
  /// offline mirror's older rows may predate the column; the Mastery tab's
  /// activity feed (milestone C) skips a deck that has no known creation time.
  final DateTime? createdAt;
}

DateTime? _parseNullableDate(Object? value) =>
    value == null ? null : DateTime.parse(value as String);
