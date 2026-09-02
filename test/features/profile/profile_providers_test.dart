import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:open_recall/features/profile/application/profile_providers.dart';
import 'package:open_recall/features/profile/domain/profile.dart';

import '../../support/fake_profile_repository.dart';

void main() {
  ProviderContainer containerWith(FakeProfileRepository repo) {
    final c = ProviderContainer(
      overrides: [profileRepositoryProvider.overrideWithValue(repo)],
    );
    addTearDown(c.dispose);
    return c;
  }

  test('profileProvider returns the repository row', () async {
    final repo = FakeProfileRepository(
      profile: (id: 'u1', email: 'a@b.com', username: 'Ada'),
    );
    final c = containerWith(repo);

    final profile = await c.read(profileProvider.future);

    expect(profile, isNotNull);
    expect(profile!.username, 'Ada');
  });

  test('profileProvider yields null when the repository throws', () async {
    final repo = FakeProfileRepository()..throwOnNextCall = StateError('no session');
    final c = containerWith(repo);

    expect(await c.read(profileProvider.future), isNull);
  });

  test('setUsername calls the repository and refreshes profileProvider',
      () async {
    final repo = FakeProfileRepository(
      profile: (id: 'u1', email: 'a@b.com', username: null),
    );
    final c = containerWith(repo);

    await c.read(profileProvider.future); // prime it
    await c.read(profileControllerProvider.notifier).setUsername('Grace');

    expect(repo.updateUsernameCalls, ['Grace']);
    final refreshed = await c.read(profileProvider.future);
    expect(refreshed!.username, 'Grace');
  });

  test('setUsername surfaces a repository failure as AsyncError', () async {
    final repo = FakeProfileRepository()..throwOnNextCall = Exception('offline');
    final c = containerWith(repo);

    await c.read(profileControllerProvider.notifier).setUsername('X');

    expect(c.read(profileControllerProvider).hasError, isTrue);
  });
}
