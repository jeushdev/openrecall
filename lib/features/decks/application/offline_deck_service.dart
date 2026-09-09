import 'dart:async';

import '../data/local_deck_store.dart';
import '../../courses/domain/course.dart';
import '../domain/card.dart';
import '../domain/deck.dart';
import '../domain/deck_repository.dart';
import '../domain/offline_download.dart';

typedef DownloadProgressCallback = void Function(DownloadProgress progress);

/// Fetches and atomically installs one self-contained deck package.
///
/// Network work is staged in memory. Only a fully validated deck, parent
/// course, and card set reaches the short SQLite transaction.
class OfflineDeckService {
  factory OfflineDeckService({
    required LocalDeckStore local,
    required OfflineDownloadSource source,
    required OfflinePackageOperationRegistry operations,
    required Future<bool> Function() isOnline,
    OfflineDeckCommitBus? commitBus,
    Duration requestTimeout = const Duration(seconds: 6),
    Duration overallTimeout = const Duration(minutes: 2),
  }) => OfflineDeckService._(
    local,
    source,
    operations,
    isOnline,
    commitBus,
    requestTimeout,
    overallTimeout,
  );

  OfflineDeckService._(
    this._local,
    this._source,
    this._operations,
    this._isOnline,
    this._commitBus,
    this.requestTimeout,
    this.overallTimeout,
  );

  final LocalDeckStore _local;
  final OfflineDownloadSource _source;
  final OfflinePackageOperationRegistry _operations;
  final Future<bool> Function() _isOnline;
  final OfflineDeckCommitBus? _commitBus;
  final Duration requestTimeout;
  final Duration overallTimeout;
  final Map<String, _InFlight> _inFlight = {};
  final Map<String, _AutomaticRefresh> _automaticRefreshes = {};
  bool _disposed = false;

  Future<void> download(
    String deckId, {
    required bool pin,
    DownloadProgressCallback? onProgress,
  }) {
    final kind = pin
        ? OfflinePackageOperationKind.download
        : OfflinePackageOperationKind.refresh;
    final active = _inFlight[deckId];
    if (active != null && active.kind == kind) return active.future;

    final operation = _operations.begin(deckId, kind);
    final future = _run(
      deckId,
      pin: pin,
      operation: operation,
      onProgress: onProgress,
    );
    _inFlight[deckId] = _InFlight(kind, future);
    future.then(
      (_) => _clear(deckId, future),
      onError: (Object _, StackTrace _) => _clear(deckId, future),
    );
    return future;
  }

  /// Revalidates a complete explicitly saved package without delaying the
  /// visible local read. Automatic refresh has the lowest operation priority.
  Future<OfflineDeckRefreshResult> refresh(String deckId) {
    final active = _automaticRefreshes[deckId];
    if (active != null) return active.future;
    if (_disposed ||
        _inFlight.containsKey(deckId) ||
        _operations.hasStartupLease(deckId)) {
      return Future.value(const OfflineDeckRefreshResult.skipped());
    }

    final operation = _operations.begin(
      deckId,
      OfflinePackageOperationKind.refresh,
    );
    final future = _runAutomaticRefresh(deckId, operation);
    _automaticRefreshes[deckId] = _AutomaticRefresh(operation, future);
    future.whenComplete(() {
      if (identical(_automaticRefreshes[deckId]?.future, future)) {
        _automaticRefreshes.remove(deckId);
      }
    });
    return future;
  }

  Future<void> remove(String deckId) async {
    if (_operations.hasStartupLease(deckId)) {
      throw OfflinePackageActiveSessionException(deckId);
    }
    final operation = _operations.begin(
      deckId,
      OfflinePackageOperationKind.remove,
    );
    await _local.removeDeck(
      deckId,
      operation: operation,
      isOperationCurrent: _isCurrent,
      hasStartupLease: _operations.hasStartupLease,
    );
    _commitBus?.publish(deckId, OfflineDeckCommitKind.removal);
  }

  OfflineDeckStartupLease acquireStartupLease(String deckId) {
    final automatic = _automaticRefreshes[deckId];
    if (automatic != null && _operations.isCurrent(automatic.operation)) {
      _operations.cancel(deckId);
    }
    return _operations.acquireStartupLease(deckId);
  }

  void releaseStartupLease(OfflineDeckStartupLease lease) {
    _operations.releaseStartupLease(lease);
  }

  void cancelAutomaticRefresh(String deckId) {
    final automatic = _automaticRefreshes[deckId];
    if (automatic != null && _operations.isCurrent(automatic.operation)) {
      _operations.cancel(deckId);
    }
  }

  void dispose() {
    _disposed = true;
    for (final deckId in _inFlight.keys.toList()) {
      _operations.cancel(deckId);
    }
    for (final deckId in _automaticRefreshes.keys.toList()) {
      _operations.cancel(deckId);
    }
  }

  void _clear(String deckId, Future<void> future) {
    if (identical(_inFlight[deckId]?.future, future)) _inFlight.remove(deckId);
  }

  Future<void> _run(
    String deckId, {
    required bool pin,
    required OfflinePackageOperation operation,
    DownloadProgressCallback? onProgress,
  }) async {
    if (_local.isNoop) {
      throw OfflineDeckServiceException(
        OfflineDeckServiceErrorCode.storageUnavailable,
        deckId,
        'Offline storage is unavailable on this device.',
      );
    }
    final deadline = DateTime.now().add(overallTimeout);
    late final bool online;
    try {
      online = await _request(_isOnline(), deadline);
    } on TimeoutException catch (error) {
      throw OfflineDeckServiceException(
        OfflineDeckServiceErrorCode.timedOut,
        deckId,
        'The deck download timed out. Try again.',
        cause: error,
      );
    } catch (error) {
      throw OfflineDeckServiceException(
        OfflineDeckServiceErrorCode.requestFailed,
        deckId,
        'Could not check the network connection. Try again.',
        cause: error,
      );
    }
    _ensureCurrent(operation);
    if (!online) {
      throw OfflineDeckServiceException(
        OfflineDeckServiceErrorCode.offline,
        deckId,
        'Connect to the internet to download this deck.',
      );
    }

    late _FetchedPackage package;
    try {
      package = await _fetchStablePackage(
        deckId,
        operation,
        deadline,
        onProgress,
        recordRemotePresence: (missing) =>
            _recordRemotePresence(deckId, operation, missing),
      );
    } on OfflineDeckServiceException {
      rethrow;
    } on TimeoutException catch (error) {
      if (!_isCurrent(operation)) _throwSuperseded(deckId, error);
      throw OfflineDeckServiceException(
        OfflineDeckServiceErrorCode.timedOut,
        deckId,
        'The deck download timed out. Try again.',
        cause: error,
      );
    } on _InvalidPackage catch (error) {
      throw OfflineDeckServiceException(
        error.missingDeck
            ? OfflineDeckServiceErrorCode.remoteDeckMissing
            : OfflineDeckServiceErrorCode.invalidPackage,
        deckId,
        error.message,
        cause: error,
      );
    } catch (error) {
      if (!_isCurrent(operation)) _throwSuperseded(deckId, error);
      throw OfflineDeckServiceException(
        OfflineDeckServiceErrorCode.requestFailed,
        deckId,
        'Could not download this deck. Check your connection and try again.',
        cause: error,
      );
    }

    _ensureCurrent(operation);
    try {
      await _local.commitDeckPackage(
        deckId: deckId,
        deck: package.deck,
        courses: package.courses,
        cards: package.cards,
        pin: pin ? true : null,
        operation: operation,
        isOperationCurrent: _isCurrent,
      );
      _commitBus?.publish(deckId, OfflineDeckCommitKind.package);
    } on OfflinePackageOperationSuperseded catch (error) {
      _throwSuperseded(deckId, error);
    } catch (error) {
      if (!_isCurrent(operation)) _throwSuperseded(deckId, error);
      throw OfflineDeckServiceException(
        OfflineDeckServiceErrorCode.storageFailure,
        deckId,
        'The offline copy could not be saved. Your previous copy is unchanged.',
        cause: error,
      );
    }
  }

  Future<OfflineDeckRefreshResult> _runAutomaticRefresh(
    String deckId,
    OfflinePackageOperation operation,
  ) async {
    var statusChanged = false;
    OfflineDeckServiceException? failure;
    try {
      if (!await _eligibleForAutomaticRefresh(deckId, operation)) {
        return const OfflineDeckRefreshResult.skipped();
      }
      final deadline = DateTime.now().add(overallTimeout);
      if (!await _request(_isOnline(), deadline)) {
        return const OfflineDeckRefreshResult.skipped();
      }
      _ensureCurrent(operation);
      final package = await _fetchStablePackage(
        deckId,
        operation,
        deadline,
        null,
        recordRemotePresence: (missing) async {
          if (await _recordRemotePresence(deckId, operation, missing)) {
            statusChanged = true;
          }
        },
      );
      if (!await _eligibleForAutomaticRefresh(deckId, operation)) {
        return OfflineDeckRefreshResult.completed(
          packageCommitted: false,
          statusChanged: statusChanged,
        );
      }
      await _local.commitDeckPackage(
        deckId: deckId,
        deck: package.deck,
        courses: package.courses,
        cards: package.cards,
        operation: operation,
        isOperationCurrent: _isCurrent,
        hasStartupLease: _operations.hasStartupLease,
      );
      _commitBus?.publish(deckId, OfflineDeckCommitKind.package);
      return OfflineDeckRefreshResult.completed(
        packageCommitted: true,
        statusChanged: statusChanged,
      );
    } on OfflineDeckServiceException catch (error) {
      failure = error;
    } on OfflinePackageActiveSessionException {
      return OfflineDeckRefreshResult.completed(
        packageCommitted: false,
        statusChanged: statusChanged,
      );
    } on OfflinePackageOperationSuperseded catch (error) {
      failure = OfflineDeckServiceException(
        OfflineDeckServiceErrorCode.superseded,
        deckId,
        'This deck refresh was cancelled by a higher-priority operation.',
        cause: error,
      );
    } on TimeoutException catch (error) {
      failure = OfflineDeckServiceException(
        OfflineDeckServiceErrorCode.timedOut,
        deckId,
        'The deck refresh timed out.',
        cause: error,
      );
    } on _InvalidPackage catch (error) {
      failure = OfflineDeckServiceException(
        error.missingDeck
            ? OfflineDeckServiceErrorCode.remoteDeckMissing
            : OfflineDeckServiceErrorCode.invalidPackage,
        deckId,
        error.message,
        cause: error,
      );
    } catch (error) {
      failure = OfflineDeckServiceException(
        OfflineDeckServiceErrorCode.requestFailed,
        deckId,
        'Could not refresh this deck.',
        cause: error,
      );
    }
    return OfflineDeckRefreshResult.completed(
      packageCommitted: false,
      statusChanged: statusChanged,
      error: failure,
    );
  }

  Future<bool> _eligibleForAutomaticRefresh(
    String deckId,
    OfflinePackageOperation operation,
  ) async {
    if (!_isCurrent(operation) || _operations.hasStartupLease(deckId)) {
      return false;
    }
    final status = await _local.packageStatus(deckId);
    if (!_isCurrent(operation)) return false;
    if (!status.isExplicitlyAvailable || status.cacheSuppressed) return false;
    if (await _local.hasActiveSession(deckId)) return false;
    return _isCurrent(operation) && !_operations.hasStartupLease(deckId);
  }

  Future<bool> _recordRemotePresence(
    String deckId,
    OfflinePackageOperation operation,
    bool missing,
  ) async {
    final changed = await _local.setRemoteMissingGuarded(
      deckId,
      missing: missing,
      operation: operation,
      isOperationCurrent: _isCurrent,
    );
    if (changed) {
      _commitBus?.publish(deckId, OfflineDeckCommitKind.status);
    }
    return changed;
  }

  Future<_FetchedPackage> _fetchStablePackage(
    String deckId,
    OfflinePackageOperation operation,
    DateTime deadline,
    DownloadProgressCallback? onProgress, {
    required Future<void> Function(bool missing) recordRemotePresence,
  }) async {
    for (var attempt = 0; attempt < 2; attempt++) {
      _ensureCurrent(operation);
      final deck = await _request(_source.fetchDeck(deckId), deadline);
      _ensureCurrent(operation);
      if (deck == null) {
        await recordRemotePresence(true);
        throw _InvalidPackage(
          'This deck is no longer available from the server.',
          missingDeck: true,
        );
      }
      await recordRemotePresence(false);
      _validateDeck(deckId, deck);

      final remoteCourse = await _request(
        _source.fetchCourse(deck.courseId!),
        deadline,
      );
      _ensureCurrent(operation);
      if (remoteCourse == null || remoteCourse.id != deck.courseId) {
        throw _InvalidPackage('The deck\'s course metadata is unavailable.');
      }
      final courses = [remoteCourse];

      final localCourseId = await _local.locallyAuthoritativeCourseId(deckId);
      if (localCourseId != null &&
          localCourseId != remoteCourse.id &&
          !await _local.hasCourseMetadata(localCourseId)) {
        final localParent = await _request(
          _source.fetchCourse(localCourseId),
          deadline,
        );
        _ensureCurrent(operation);
        if (localParent == null) {
          throw _InvalidPackage(
            'The deck\'s local course metadata is unavailable.',
          );
        }
        courses.add(localParent);
      }

      final total = await _request(_source.countCards(deckId), deadline);
      if (total < 0) {
        throw _InvalidPackage('The server returned an invalid card count.');
      }
      onProgress?.call(DownloadProgress(deckId: deckId, done: 0, total: total));
      final cards = <FlashCard>[];
      final ids = <String>{};
      for (var offset = 0; offset < total; offset += kDownloadPageSize) {
        _ensureCurrent(operation);
        final expected = (total - offset) < kDownloadPageSize
            ? total - offset
            : kDownloadPageSize;
        final page = await _request(
          _source.fetchCardsPage(deckId, offset: offset, limit: expected),
          deadline,
        );
        if (page.length != expected ||
            page.any(
              (card) =>
                  card.id.isEmpty || card.deckId != deckId || !ids.add(card.id),
            )) {
          throw _InvalidPackage(
            'The server returned an incomplete or invalid card page.',
          );
        }
        cards.addAll(page);
        onProgress?.call(
          DownloadProgress(deckId: deckId, done: cards.length, total: total),
        );
      }

      final finalCount = await _request(_source.countCards(deckId), deadline);
      final finalDeck = await _request(_source.fetchDeck(deckId), deadline);
      _ensureCurrent(operation);
      if (finalDeck == null) {
        await recordRemotePresence(true);
        throw _InvalidPackage(
          'This deck is no longer available from the server.',
          missingDeck: true,
        );
      }
      await recordRemotePresence(false);
      if (finalCount == total && _sameDeck(deck, finalDeck)) {
        return _FetchedPackage(deck, courses, cards);
      }
      if (attempt == 1) {
        throw _InvalidPackage(
          'The deck changed while it was downloading. Try again.',
        );
      }
    }
    throw _InvalidPackage('The deck package could not be validated.');
  }

  Future<T> _request<T>(Future<T> request, DateTime deadline) {
    final remaining = deadline.difference(DateTime.now());
    if (remaining <= Duration.zero) throw TimeoutException('Overall deadline');
    final timeout = remaining < requestTimeout ? remaining : requestTimeout;
    return request.timeout(timeout);
  }

  bool _isCurrent(OfflinePackageOperation operation) =>
      !_disposed && _local.isScopeCurrent && _operations.isCurrent(operation);

  void _ensureCurrent(OfflinePackageOperation operation) {
    if (!_isCurrent(operation)) _throwSuperseded(operation.deckId);
  }

  Never _throwSuperseded(String deckId, [Object? cause]) {
    throw OfflineDeckServiceException(
      OfflineDeckServiceErrorCode.superseded,
      deckId,
      'This deck download was cancelled by a newer operation.',
      cause: cause,
    );
  }

  void _validateDeck(String deckId, Deck deck) {
    if (deck.id != deckId ||
        deck.name.trim().isEmpty ||
        deck.courseId == null ||
        deck.courseId!.isEmpty) {
      throw _InvalidPackage('The server returned invalid deck metadata.');
    }
  }

  bool _sameDeck(Deck first, Deck second) =>
      first.id == second.id &&
      first.name == second.name &&
      first.courseId == second.courseId &&
      first.position == second.position &&
      first.lastStudiedAt == second.lastStudiedAt &&
      first.createdAt == second.createdAt &&
      first.updatedAt == second.updatedAt;
}

class _InFlight {
  const _InFlight(this.kind, this.future);
  final OfflinePackageOperationKind kind;
  final Future<void> future;
}

class _AutomaticRefresh {
  const _AutomaticRefresh(this.operation, this.future);

  final OfflinePackageOperation operation;
  final Future<OfflineDeckRefreshResult> future;
}

class _FetchedPackage {
  const _FetchedPackage(this.deck, this.courses, this.cards);
  final Deck deck;
  final List<Course> courses;
  final List<FlashCard> cards;
}

class _InvalidPackage implements Exception {
  const _InvalidPackage(this.message, {this.missingDeck = false});
  final String message;
  final bool missingDeck;
}
