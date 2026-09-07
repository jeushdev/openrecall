import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:open_recall/core/local_db/local_db_providers.dart';
import 'package:open_recall/core/local_db/local_meta_store.dart';
import 'package:open_recall/core/local_db/mirror_scope_guard.dart';
import 'package:open_recall/core/local_db/stale_account_scope.dart';

import '../../support/local_db_harness.dart';

void main() {
  setUpAll(initLocalDbTestFfi);

  test(
    'identity changes refresh the barrier and invalidate account-bound stores',
    () async {
      final database = await openTestDatabase();
      final identities = StreamController<String?>();
      final container = ProviderContainer(
        overrides: [
          appDatabaseProvider.overrideWithValue(database),
          accountScopeIdentityProvider.overrideWith((ref) => identities.stream),
        ],
      );
      addTearDown(() async {
        container.dispose();
        await identities.close();
        await database.close();
      });
      container.listen(
        mirrorScopeGuardProvider,
        (_, _) {},
        fireImmediately: true,
      );
      identities.add('a');
      await container.read(mirrorScopeGuardProvider.future);
      final first = container.read(applicationCacheProvider);
      await first.saveProfile((
        id: 'a',
        email: 'a@example.com',
        username: 'Ada',
      ));

      final switched = Completer<void>();
      container.listen(mirrorScopeGuardProvider, (_, next) {
        if (next.hasValue &&
            database.scopeGeneration > 1 &&
            !switched.isCompleted) {
          switched.complete();
        }
      });
      identities.add('b');
      await switched.future.timeout(const Duration(seconds: 2));
      expect(await LocalMetaStore(database.db).lastUserId(), 'b');
      expect(await container.read(applicationCacheProvider).profile(), isNull);
      await expectLater(first.profile(), throwsA(isA<StaleAccountScope>()));
    },
  );

  test('null database reports no offline capability', () {
    final container = ProviderContainer();
    addTearDown(container.dispose);
    expect(container.read(localStorageAvailableProvider), isFalse);
    expect(container.read(applicationCacheProvider).isAvailable, isFalse);
  });
}
