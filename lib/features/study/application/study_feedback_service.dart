import 'dart:async';
import 'dart:collection';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../settings/application/settings_providers.dart';
import '../data/study_audio_adapter.dart';

/// Meaningful study transitions that may produce user feedback.
enum StudyFeedbackEvent { cardMastered, sessionCompleted }

/// Identifies one accepted session transition independently of UI lifecycle.
@immutable
class StudyFeedbackTransitionId {
  const StudyFeedbackTransitionId({
    required this.sessionId,
    required this.sessionCardId,
    required this.queuePosition,
  });

  final String sessionId;
  final String sessionCardId;
  final int queuePosition;

  @override
  bool operator ==(Object other) =>
      other is StudyFeedbackTransitionId &&
      other.sessionId == sessionId &&
      other.sessionCardId == sessionCardId &&
      other.queuePosition == queuePosition;

  @override
  int get hashCode => Object.hash(sessionId, sessionCardId, queuePosition);
}

/// Injectable audio boundary for the live feedback service.
final studyAudioAdapterProvider = Provider<StudyAudioAdapter>((ref) {
  final adapter = AudioplayersStudyAudioAdapter();
  ref.onDispose(() => unawaited(adapter.dispose()));
  return adapter;
});

/// Central event gate for preference handling, deduplication, and playback.
final studyFeedbackServiceProvider = Provider<StudyFeedbackService>((ref) {
  final service = StudyFeedbackService(ref.watch(studyAudioAdapterProvider));

  void applyPreference(AsyncValue<bool> preference) {
    service.setEnabled(preference.asData?.value == true);
  }

  ref.listen<AsyncValue<bool>>(
    studySoundsEnabledProvider,
    (_, next) => applyPreference(next),
    fireImmediately: true,
  );
  ref.onDispose(service.dispose);
  return service;
});

/// Owns the sound policy independently of session state and UI rendering.
class StudyFeedbackService {
  StudyFeedbackService(this._audio);

  static const int _deduplicationWindow = 256;

  final StudyAudioAdapter _audio;
  final LinkedHashSet<StudyFeedbackTransitionId> _handledTransitions =
      LinkedHashSet();
  bool _enabled = false;
  bool _disposed = false;

  /// Loading/error states are passed as false. Disabling also cancels queued or
  /// active playback; enabling never replays events missed while silent.
  void setEnabled(bool enabled) {
    if (_disposed || _enabled == enabled) return;
    _enabled = enabled;
    if (!enabled) unawaited(_ignoreAudioFailure(_audio.stop()));
  }

  /// Accepts a transition once and starts its cue without blocking the caller.
  void handle(
    StudyFeedbackEvent event,
    StudyFeedbackTransitionId transitionId,
  ) {
    if (_disposed || !_remember(transitionId) || !_enabled) return;
    final cue = switch (event) {
      StudyFeedbackEvent.cardMastered => StudySoundCue.cardMastered,
      StudyFeedbackEvent.sessionCompleted => StudySoundCue.sessionCompleted,
    };
    unawaited(_ignoreAudioFailure(_audio.play(cue)));
  }

  void dispose() {
    if (_disposed) return;
    _disposed = true;
    _enabled = false;
    _handledTransitions.clear();
    unawaited(_ignoreAudioFailure(_audio.stop()));
  }

  bool _remember(StudyFeedbackTransitionId transitionId) {
    if (!_handledTransitions.add(transitionId)) return false;
    if (_handledTransitions.length > _deduplicationWindow) {
      _handledTransitions.remove(_handledTransitions.first);
    }
    return true;
  }

  Future<void> _ignoreAudioFailure(Future<void> operation) async {
    try {
      await operation;
    } catch (_) {
      // Feedback is optional: playback must never affect study progression.
    }
  }
}
