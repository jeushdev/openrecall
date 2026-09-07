/// The default bound on a revalidation call. Matches the Decks tab's existing
/// budget and the study screen's `fetchDeckCardsBounded`
/// (`pre_session_cards_provider.dart`) — the app never sits on a spinner
/// because Supabase is slow, asleep or unreachable.
const Duration kRevalidateTimeout = Duration(seconds: 6);
const Object _noFallback = Object();

/// A stale-first read: yield what the local mirror already has, then replace it
/// with the freshly-fetched value.
///
/// This is the launch-path contract from `docs/spec.md` "Performance &
/// Responsiveness" — first paint comes from local state, never from a network
/// round-trip. Offline, [remote] fails (or times out) and the cached value is
/// simply the final one.
///
/// [remoteTimeout] bounds **only** [remote]. That distinction is the whole
/// point: the previous `fetchDecks().timeout(6s)` wrapped a remote-first read
/// *including its own cache fallback*, so an unreachable host burned the budget
/// before the fallback ran and the Decks tab rendered an error screen while a
/// perfectly good mirror sat unread on disk.
///
/// [cached] returns `null` for "nothing worth showing" — callers pass `null`
/// rather than an empty list so the UI never flashes an empty state it is about
/// to replace. A throwing [cached] is treated as no cache: a broken local
/// database must not take the remote path down with it. Callers whose legacy
/// contract degrades an uncached remote error to data can provide
/// [noCacheErrorFallback].
Stream<T> staleFirst<T>({
  required Future<T?> Function() cached,
  required Future<T> Function() remote,
  Duration remoteTimeout = kRevalidateTimeout,
  Object? noCacheErrorFallback = _noFallback,
}) async* {
  T? seed;
  try {
    seed = await cached();
  } catch (_) {
    seed = null;
  }
  if (seed != null) yield seed;

  try {
    yield await remote().timeout(remoteTimeout);
  } catch (_) {
    // With a seed already emitted this is an ordinary offline revalidation
    // miss — the stale value stands. With no seed there is nothing to show, so
    // the error is the screen's state and the caller's Retry applies.
    if (seed == null) {
      if (!identical(noCacheErrorFallback, _noFallback)) {
        yield noCacheErrorFallback as T;
      } else {
        rethrow;
      }
    }
  }
}
