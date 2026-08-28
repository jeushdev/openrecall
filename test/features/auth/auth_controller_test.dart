import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:open_recall/features/auth/application/auth_providers.dart';

import '../../support/fake_auth_repository.dart';

void main() {
  late FakeAuthRepository fake;
  late ProviderContainer container;

  setUp(() {
    fake = FakeAuthRepository();
    container = ProviderContainer(
      overrides: [authRepositoryProvider.overrideWithValue(fake)],
    );
    addTearDown(container.dispose);
    addTearDown(fake.dispose);
  });

  test('starts idle with a data state', () {
    expect(container.read(authControllerProvider), const AsyncData<void>(null));
  });

  test('signIn forwards credentials and resolves to data on success', () async {
    await container
        .read(authControllerProvider.notifier)
        .signIn(email: 'a@b.com', password: 'secret');

    expect(fake.calls, ['signInWithPassword(a@b.com)']);
    expect(container.read(authControllerProvider).hasError, isFalse);
    expect(container.read(authControllerProvider).isLoading, isFalse);
  });

  test('signIn captures a thrown error as AsyncError', () async {
    final failure = Exception('nope');
    fake.throwOnNextCall = failure;

    await container
        .read(authControllerProvider.notifier)
        .signIn(email: 'a@b.com', password: 'secret');

    final state = container.read(authControllerProvider);
    expect(state.hasError, isTrue);
    expect(state.error, failure);
  });

  test('signUp forwards to the repository', () async {
    await container
        .read(authControllerProvider.notifier)
        .signUp(email: 'new@b.com', password: 'secret');
    expect(fake.calls, ['signUp(new@b.com)']);
  });

  test('signOut forwards to the repository', () async {
    await container.read(authControllerProvider.notifier).signOut();
    expect(fake.calls, ['signOut()']);
  });

  test('sendResetEmail forwards to the repository', () async {
    await container
        .read(authControllerProvider.notifier)
        .sendResetEmail('a@b.com');
    expect(fake.calls, ['sendPasswordResetEmail(a@b.com)']);
  });

  test('a failed call does not leave the controller stuck loading', () async {
    fake.throwOnNextCall = Exception('boom');
    await container
        .read(authControllerProvider.notifier)
        .signIn(email: 'a@b.com', password: 'secret');
    expect(container.read(authControllerProvider).isLoading, isFalse);
  });
}
