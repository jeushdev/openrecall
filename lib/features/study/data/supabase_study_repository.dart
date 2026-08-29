import 'package:supabase_flutter/supabase_flutter.dart';

import '../../decks/domain/study_mode.dart';
import '../domain/queue_seed.dart';
import '../domain/session_card.dart';
import '../domain/session_length.dart';
import '../domain/study_repository.dart';
import '../domain/study_session.dart';

/// The only class in the study feature that talks to Supabase Postgres
/// directly. RLS scopes every query to the signed-in user.
class SupabaseStudyRepository implements StudyRepository {
  SupabaseStudyRepository(this._client);

  final SupabaseClient _client;

  String get _userId => _client.auth.currentUser!.id;

  @override
  Future<void> abandonActiveSessions(String deckId) async {
    await _client
        .from('study_sessions')
        .update({'status': 'abandoned'})
        .eq('deck_id', deckId)
        .eq('status', 'active');
  }

  @override
  Future<StudySession> createSession({
    required String deckId,
    required StudyMode studyMode,
    required SessionLengthMode lengthMode,
    int? cappedLength,
    CardScope cardScope = CardScope.due,
  }) async {
    final row = await _client
        .from('study_sessions')
        .insert({
          'user_id': _userId,
          'deck_id': deckId,
          'study_mode': studyMode.name,
          'length_mode': lengthMode.db,
          'capped_length': cappedLength,
          'card_scope': cardScope.db,
        })
        .select()
        .single();
    return StudySession.fromJson(row);
  }

  @override
  Future<List<SessionCard>> createSessionCards(
    String sessionId,
    List<QueueSeed> seeds,
  ) async {
    // No user_id — session_cards ownership is checked through the join to
    // study_sessions (spec RLS pattern).
    final rows = await _client
        .from('session_cards')
        .insert([
          for (final seed in seeds)
            {
              'session_id': sessionId,
              'card_id': seed.cardId,
              'position': seed.position,
            },
        ])
        .select();
    return rows.map(SessionCard.fromJson).toList();
  }

  @override
  Future<void> updateSessionCard({
    required String sessionCardId,
    int? position,
    int? consecutiveFails,
    bool? isParked,
  }) async {
    final values = <String, dynamic>{
      'position': ?position,
      'consecutive_fails': ?consecutiveFails,
      'is_parked': ?isParked,
    };
    if (values.isEmpty) return;
    await _client.from('session_cards').update(values).eq('id', sessionCardId);
  }

  @override
  Future<void> completeSession(String sessionId, {int? masteryDelta}) async {
    await _client
        .from('study_sessions')
        .update({
          'status': 'completed',
          'completed_at': DateTime.now().toUtc().toIso8601String(),
          'mastery_delta': ?masteryDelta,
        })
        .eq('id', sessionId);
  }
}
