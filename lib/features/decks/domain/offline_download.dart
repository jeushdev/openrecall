import 'dart:async';

import 'package:flutter/foundation.dart';

/// Durable local package state. Downloading and refresh progress remain
/// transient; these values can be reconstructed from SQLite after restart.
enum OfflinePackageAvailability {
  unavailable,
  incomplete,
  opportunistic,
  availableOffline,
  suppressed,
}

@immutable
class OfflinePackageStatus {
  const OfflinePackageStatus({
    required this.deckId,
    required this.hasLocalMetadata,
    required this.isPinned,
    required this.cardsComplete,
    required this.cacheSuppressed,
    required this.remoteMissing,
    required this.downloadedAt,
  });

  const OfflinePackageStatus.missing(String deckId)
    : this(
        deckId: deckId,
        hasLocalMetadata: false,
        isPinned: false,
        cardsComplete: false,
        cacheSuppressed: false,
        remoteMissing: false,
        downloadedAt: null,
      );

  final String deckId;
  final bool hasLocalMetadata;
  final bool isPinned;
  final bool cardsComplete;
  final bool cacheSuppressed;
  final bool remoteMissing;
  final DateTime? downloadedAt;

  bool get isExplicitlyAvailable => isPinned && cardsComplete;
  bool get isUsableOffline => cardsComplete;

  OfflinePackageAvailability get availability {
    if (cacheSuppressed) return OfflinePackageAvailability.suppressed;
    if (isExplicitlyAvailable) {
      return OfflinePackageAvailability.availableOffline;
    }
    if (cardsComplete) return OfflinePackageAvailability.opportunistic;
    if (hasLocalMetadata || isPinned) {
      return OfflinePackageAvailability.incomplete;
    }
    return OfflinePackageAvailability.unavailable;
  }
}

/// The operation identity passed through an asynchronous package transaction.
/// A later operation for the same deck invalidates older generations.
@immutable
class OfflinePackageOperation {
  const OfflinePackageOperation({
    required this.deckId,
    required this.generation,
    required this.kind,
  });

  final String deckId;
  final int generation;
  final OfflinePackageOperationKind kind;
}

enum OfflinePackageOperationKind { download, refresh, remove }

@immutable
class OfflineDeckStartupLease {
  const OfflineDeckStartupLease._(this.deckId, this.generation);

  final String deckId;
  final int generation;
}

/// Cards fetched per network request for an explicit package download.
const int kDownloadPageSize = 100;

class OfflinePackageOperationRegistry {
  final Map<String, int> _generations = <String, int>{};
  final Map<String, int> _leaseGenerations = <String, int>{};
  final Map<String, Set<int>> _startupLeases = <String, Set<int>>{};

  OfflinePackageOperation begin(
    String deckId,
    OfflinePackageOperationKind kind,
  ) {
    final generation = (_generations[deckId] ?? 0) + 1;
    _generations[deckId] = generation;
    return OfflinePackageOperation(
      deckId: deckId,
      generation: generation,
      kind: kind,
    );
  }

  void cancel(String deckId) {
    _generations[deckId] = (_generations[deckId] ?? 0) + 1;
  }

  bool isCurrent(OfflinePackageOperation operation) =>
      _generations[operation.deckId] == operation.generation;

  OfflineDeckStartupLease acquireStartupLease(String deckId) {
    final generation = (_leaseGenerations[deckId] ?? 0) + 1;
    _leaseGenerations[deckId] = generation;
    (_startupLeases[deckId] ??= <int>{}).add(generation);
    return OfflineDeckStartupLease._(deckId, generation);
  }

  void releaseStartupLease(OfflineDeckStartupLease lease) {
    final leases = _startupLeases[lease.deckId];
    leases?.remove(lease.generation);
    if (leases?.isEmpty ?? false) _startupLeases.remove(lease.deckId);
  }

  bool hasStartupLease(String deckId) =>
      _startupLeases[deckId]?.isNotEmpty ?? false;
}

enum OfflineDeckCommitKind { package, status, removal, cleanup }

@immutable
class OfflineDeckCommitEvent {
  const OfflineDeckCommitEvent(this.deckId, this.kind);

  final String deckId;
  final OfflineDeckCommitKind kind;
}

/// One-shot local commit notifications. Consumers use these to reload the
/// mirror without turning a successful package refresh into another network
/// revalidation.
class OfflineDeckCommitBus {
  final StreamController<OfflineDeckCommitEvent> _controller =
      StreamController<OfflineDeckCommitEvent>.broadcast(sync: true);

  Stream<OfflineDeckCommitEvent> get events => _controller.stream;

  void publish(String deckId, OfflineDeckCommitKind kind) {
    if (!_controller.isClosed) {
      _controller.add(OfflineDeckCommitEvent(deckId, kind));
    }
  }

  void dispose() => _controller.close();
}

@immutable
class OfflineDeckRefreshResult {
  const OfflineDeckRefreshResult._({
    required this.skipped,
    required this.packageCommitted,
    required this.statusChanged,
    this.error,
  });

  const OfflineDeckRefreshResult.skipped()
    : this._(skipped: true, packageCommitted: false, statusChanged: false);

  const OfflineDeckRefreshResult.completed({
    required bool packageCommitted,
    required bool statusChanged,
    OfflineDeckServiceException? error,
  }) : this._(
         skipped: false,
         packageCommitted: packageCommitted,
         statusChanged: statusChanged,
         error: error,
       );

  final bool skipped;
  final bool packageCommitted;
  final bool statusChanged;
  final OfflineDeckServiceException? error;
}

enum OfflineDeckServiceErrorCode {
  offline,
  requestFailed,
  timedOut,
  remoteDeckMissing,
  invalidPackage,
  storageUnavailable,
  storageFailure,
  superseded,
}

/// A stable service-level failure suitable for presentation and retry logic.
/// The underlying exception is retained for diagnostics but is not user copy.
class OfflineDeckServiceException implements Exception {
  const OfflineDeckServiceException(
    this.code,
    this.deckId,
    this.message, {
    this.cause,
  });

  final OfflineDeckServiceErrorCode code;
  final String deckId;
  final String message;
  final Object? cause;

  @override
  String toString() => message;
}

class OfflinePackageOperationSuperseded implements Exception {
  const OfflinePackageOperationSuperseded(this.deckId);

  final String deckId;

  @override
  String toString() => 'Offline package operation was superseded for $deckId.';
}

class OfflinePackageActiveSessionException implements Exception {
  const OfflinePackageActiveSessionException(this.deckId);

  final String deckId;

  @override
  String toString() =>
      'Finish or exit this study session before removing its offline copy.';
}

/// Determinate progress for a per-deck offline download (design spec §E.2).
///
/// [total] is the card count read once up front; [done] is how many have been
/// fetched so far. Held in `downloadProgressProvider` while a download runs and
/// `null` otherwise, so the `OfflineToggle` can show a real bar rather than an
/// indeterminate spinner on a large deck.
@immutable
class DownloadProgress {
  const DownloadProgress({
    this.deckId = '',
    required this.done,
    required this.total,
  });

  final String deckId;
  final int done;
  final int total;

  /// 0.0–1.0. A zero-card deck is complete immediately (no divide-by-zero); a
  /// transient over-fill from a page boundary is clamped.
  double get fraction => total <= 0 ? 1.0 : (done / total).clamp(0.0, 1.0);

  bool get isComplete => done >= total;
}
