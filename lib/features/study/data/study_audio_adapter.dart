import 'package:audioplayers/audioplayers.dart';

/// The two short cues supported by the study loop.
enum StudySoundCue { cardMastered, sessionCompleted }

/// Playback boundary used by the application layer.
///
/// Implementations are responsible for non-overlapping playback and resource
/// cleanup. Study controllers and widgets never call an audio package directly.
abstract interface class StudyAudioAdapter {
  Future<void> play(StudySoundCue cue);

  Future<void> stop();

  Future<void> dispose();
}

/// Asset-backed, cross-platform adapter for the live app.
///
/// One player and one serialized operation chain guarantee that cues never
/// overlap. A newer play supersedes queued plays and stops a cue already in
/// progress before it starts.
class AudioplayersStudyAudioAdapter implements StudyAudioAdapter {
  AudioplayersStudyAudioAdapter([AudioPlayer? player])
    : _player = player ?? AudioPlayer();

  static const Map<StudySoundCue, String> _assets = {
    StudySoundCue.cardMastered: 'sounds/card_mastered.wav',
    StudySoundCue.sessionCompleted: 'sounds/session_completed.wav',
  };

  final AudioPlayer _player;
  Future<void> _operations = Future<void>.value();
  int _generation = 0;
  bool _disposed = false;

  @override
  Future<void> play(StudySoundCue cue) {
    if (_disposed) return Future<void>.value();
    final generation = ++_generation;
    return _enqueue(() async {
      if (_disposed || generation != _generation) return;
      await _player.stop();
      if (_disposed || generation != _generation) return;
      await _player.play(
        AssetSource(_assets[cue]!),
        mode: PlayerMode.lowLatency,
      );
    });
  }

  @override
  Future<void> stop() {
    ++_generation;
    if (_disposed) return Future<void>.value();
    return _enqueue(_player.stop);
  }

  @override
  Future<void> dispose() async {
    if (_disposed) return;
    _disposed = true;
    ++_generation;
    try {
      await _operations;
    } catch (_) {
      // A prior best-effort playback failure must not prevent cleanup.
    }
    try {
      await _player.stop();
    } catch (_) {
      // The platform may already have released or rejected the player.
    }
    try {
      await _player.dispose();
    } catch (_) {
      // Disposal is best-effort on an unavailable platform audio backend.
    }
  }

  Future<void> _enqueue(Future<void> Function() operation) {
    final previous = _operations;
    final next = () async {
      try {
        await previous;
      } catch (_) {
        // Keep the queue usable after an unavailable-device/asset failure.
      }
      await operation();
    }();
    _operations = next;
    return next;
  }
}
