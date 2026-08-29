import 'package:flutter/foundation.dart';

import '../../decks/domain/study_mode.dart';
import 'session_length.dart';
import 'session_status.dart';

/// One `study_sessions` row (spec schema): a single-mode, resumable study
/// session over one deck. Has no `updated_at` — that column and its trigger
/// exist only on `decks` and `cards`.
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
  });

  factory StudySession.fromJson(Map<String, dynamic> json) => StudySession(
        id: json['id'] as String,
        deckId: json['deck_id'] as String,
        status: sessionStatusFromDb(json['status'] as String),
        studyMode: StudyMode.values.byName(json['study_mode'] as String),
        lengthMode: sessionLengthModeFromDb(json['length_mode'] as String),
        cappedLength: json['capped_length'] as int?,
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
        masteryDelta,
        startedAt,
        completedAt,
      );
}
