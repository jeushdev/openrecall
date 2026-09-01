import 'package:flutter/foundation.dart';

/// Determinate progress for a per-deck offline download (design spec §E.2).
///
/// [total] is the card count read once up front; [done] is how many have been
/// fetched so far. Held in `downloadProgressProvider` while a download runs and
/// `null` otherwise, so the `OfflineToggle` can show a real bar rather than an
/// indeterminate spinner on a large deck.
@immutable
class DownloadProgress {
  const DownloadProgress({required this.done, required this.total});

  final int done;
  final int total;

  /// 0.0–1.0. A zero-card deck is complete immediately (no divide-by-zero); a
  /// transient over-fill from a page boundary is clamped.
  double get fraction => total <= 0 ? 1.0 : (done / total).clamp(0.0, 1.0);

  bool get isComplete => done >= total;
}
