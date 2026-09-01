import 'package:flutter_test/flutter_test.dart';
import 'package:open_recall/core/cache/stale_first.dart';

void main() {
  test('emits the cached value first, then the remote one', () async {
    final events = await staleFirst<String>(
      cached: () async => 'cache',
      remote: () async => 'remote',
    ).toList();
    expect(events, ['cache', 'remote']);
  });

  test('emits only the remote value when there is no cache', () async {
    final events = await staleFirst<String>(
      cached: () async => null,
      remote: () async => 'remote',
    ).toList();
    expect(events, ['remote']);
  });

  test('a remote failure after a cache hit is swallowed', () async {
    final events = await staleFirst<String>(
      cached: () async => 'cache',
      remote: () async => throw StateError('offline'),
    ).toList();
    expect(events, ['cache']);
  });

  test('a remote failure with no cache surfaces as an error', () {
    expect(
      staleFirst<String>(
        cached: () async => null,
        remote: () async => throw StateError('offline'),
      ).toList(),
      throwsA(isA<StateError>()),
    );
  });

  test('the timeout bounds the remote leg only, never the cache', () async {
    // The bug this exists to prevent: wrapping the whole cache-first read in a
    // timeout meant a hanging remote call killed the cache fallback too, and
    // the screen showed an error instead of the user's cached decks.
    final events = await staleFirst<String>(
      cached: () async => 'cache',
      remote: () => Future.delayed(const Duration(seconds: 30), () => 'remote'),
      remoteTimeout: const Duration(milliseconds: 20),
    ).toList();
    expect(events, ['cache']);
  });

  test('a slow cache read never blocks the remote value', () async {
    final events = await staleFirst<String>(
      cached: () async => throw StateError('local db is broken'),
      remote: () async => 'remote',
    ).toList();
    expect(events, ['remote']);
  });
}
