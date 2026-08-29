import 'package:flutter/foundation.dart';

import '../../decks/domain/study_mode.dart';
import 'session_length.dart';
import 'session_status.dart';

/// Which cards a session's queue was built from (engine-v2-spec §3.3): [due]
/// only drills cards below Mastered (the V1 behaviour), [all] also includes
/// already-Mastered cards. This is queue-selection metadata recorded on the
/// `study_sessions` row — not a separate study mode.
enum CardScope { due, all }

extension CardScopeDb on CardScope {
  /// The `study_sessions.card_scope` string this scope is stored as.
  String get db => this == CardScope.all ? 'all' : 'due';
}

/// Reads a `study_sessions.card_scope` string back into a [CardScope].
CardScope cardScopeFromDb(String value) =>
    value == 'all' ? CardScope.all : CardScope.due;

/// One `study_sessions` row (spec schema): a single-mode, resumable study
/// session over one deck. Has no `updated_at` — that column and its trigger
/// exist only on `courses`, `decks` and `cards`.
@immutable
class StudySession {
  const StudySession({
    required this.id,
    required this.deckId,
    required this.status,
    required this.studyMode,
    required this.lengthMode,
    required this.cappedLength,
    required this.masteryDelta,
    required this.startedAt,
    required this.completedAt,
    this.cardScope = CardScope.due,
  });

  factory StudySession.fromJson(Map<String, dynamic> json) => StudySession(
        id: json['id'] as String,
        deckId: json['deck_id'] as String,
        status: sessionStatusFromDb(json['status'] as String),
        studyMode: StudyMode.values.byName(json['study_mode'] as String),
        lengthMode: sessionLengthModeFromDb(json['length_mode'] as String),
        cappedLength: json['capped_length'] as int?,
        cardScope: json['card_scope'] == null
            ? CardScope.due
            : cardScopeFromDb(json['card_scope'] as String),
        masteryDelta: json['mastery_delta'] as int?,
        startedAt: DateTime.parse(json['started_at'] as String),
        completedAt: json['completed_at'] == null
            ? null
            : DateTime.parse(json['completed_at'] as String),
      );

  final String id;
  final String deckId;
  final SessionStatus status;
  final StudyMode studyMode;
  final SessionLengthMode lengthMode;
  final int? cappedLength;
  final CardScope cardScope;
  final int? masteryDelta;
  final DateTime startedAt;
  final DateTime? completedAt;

  @override
  bool operator ==(Object other) =>
      other is StudySession &&
      other.id == id &&
      other.deckId == deckId &&
      other.status == status &&
      other.studyMode == studyMode &&
      other.lengthMode == lengthMode &&
      other.cappedLength == cappedLength &&
      other.cardScope == cardScope &&
      other.masteryDelta == masteryDelta &&
      other.startedAt == startedAt &&
      other.completedAt == completedAt;

  @override
  int get hashCode => Object.hash(
        id,
        deckId,
        status,
        studyMode,
        lengthMode,
        cappedLength,
        cardScope,
        masteryDelta,
        startedAt,
        completedAt,
      );
}
