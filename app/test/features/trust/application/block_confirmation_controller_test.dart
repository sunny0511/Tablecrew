import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tablecrew/data/connectivity_repository.dart';
import 'package:tablecrew/data/trust_repository.dart';
import 'package:tablecrew/features/trust/application/block_confirmation_controller.dart';

import '../../../fakes/fake_connectivity_repository.dart';
import '../../../fakes/fake_trust_repository.dart';

/// Unit tests for [BlockConfirmationController] — Milestone F6 (Trust &
/// Safety client chunk).
void main() {
  late FakeTrustRepository fakeTrust;
  late FakeConnectivityRepository fakeConnectivity;
  late ProviderContainer container;

  setUp(() {
    fakeTrust = FakeTrustRepository();
    fakeConnectivity = FakeConnectivityRepository();
    container = ProviderContainer(
      overrides: [
        trustRepositoryProvider.overrideWithValue(fakeTrust),
        connectivityRepositoryProvider.overrideWithValue(fakeConnectivity),
      ],
    );
    addTearDown(container.dispose);
    addTearDown(fakeConnectivity.dispose);
  });

  BlockConfirmationController controller(String targetUserId) {
    container.listen(
      blockConfirmationControllerProvider(targetUserId),
      (_, __) {},
    );
    return container
        .read(blockConfirmationControllerProvider(targetUserId).notifier);
  }

  BlockConfirmationState state(String targetUserId) =>
      container.read(blockConfirmationControllerProvider(targetUserId));

  test('online success calls blockUser with the target uid', () async {
    await controller('bob').submit();

    expect(state('bob').status, BlockConfirmationStatus.succeeded);
    expect(fakeTrust.blockUserCalls, ['bob']);
  });

  test('offline fails with an inline notice, never calling blockUser',
      () async {
    fakeConnectivity.setOffline(isOffline: true);

    await controller('carol').submit();

    expect(state('carol').status, BlockConfirmationStatus.failed);
    expect(fakeTrust.blockUserCalls, isEmpty);
    expect(state('carol').errorMessage, contains("can't be done offline"));
  });

  test('a callable failure surfaces its message', () async {
    fakeTrust.blockUserError = const TrustCallableException(
      code: 'invalid-argument',
      message: 'targetUserId is required and must not be the caller.',
    );

    await controller('dave').submit();

    expect(state('dave').status, BlockConfirmationStatus.failed);
    expect(
      state('dave').errorMessage,
      'targetUserId is required and must not be the caller.',
    );
  });
}
