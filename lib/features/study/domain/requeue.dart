import 'session_queue_selection.dart' show kPositionStep;

/// Where a failed card slots back into the queue — "3 positions ahead"
/// (spec §5), computed against sparse positions so the rest of the queue never
/// renumbers.
///
/// [aheadPositions] are the positions of the cards still queued *after* the
/// current one, ascending. [currentPosition] is the failed card's own position.
///
/// - 4+ cards ahead: land strictly between the 3rd and 4th, if there is room.
/// - Otherwise (exactly 3, fewer than 3, or the 3rd/4th are packed too tight
///   to interleave): go to the back of the queue.
/// - Nothing ahead (it was the only card): repeat immediately.
int requeuePosition(List<int> aheadPositions, {required int currentPosition}) {
  if (aheadPositions.isEmpty) return currentPosition + kPositionStep;
  if (aheadPositions.length >= 4) {
    final third = aheadPositions[2];
    final fourth = aheadPositions[3];
    if (fourth - third >= 2) return third + (fourth - third) ~/ 2;
  }
  return aheadPositions.last + kPositionStep;
}
