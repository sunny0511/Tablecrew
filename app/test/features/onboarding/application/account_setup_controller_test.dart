import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tablecrew/data/connectivity_repository.dart';
import 'package:tablecrew/data/user_profile_repository.dart';
import 'package:tablecrew/features/onboarding/application/account_setup_controller.dart';
import 'package:tablecrew/features/onboarding/application/onboarding_profile_draft_controller.dart';

import '../../../fakes/fake_connectivity_repository.dart';
import '../../../fakes/fake_user_profile_repository.dart';

/// Unit tests for [AccountSetupController.submit]'s success/offline-queue/
/// failure paths against [FakeUserProfileRepository] and
/// [FakeConnectivityRepository] — the coverage this milestone's own
/// `README.md`/`TASKS.md` disclosed as deferred to task #96. Also exercises
/// the reconciliation (this same task) of this controller's raw
/// `Connectivity()` use onto `ConnectivityRepository`, the gap `TASKS.md`
/// flagged as missed by task #113's otherwise-identical refactor of the 4
/// onboarding screens.
///
/// Every test subscribes via [ProviderContainer.listen] before driving the
/// controllers, even though both `AccountSetupController` and
/// `OnboardingProfileDraftController` (staged here to give `submit()`
/// something valid to send) are `keepAlive: true` and don't strictly need
/// it — `OnboardingProfileDraftController` only just became `keepAlive`
/// while writing these tests (see that file's doc comment: every real call
/// site only ever `ref.read`s it, so with the old plain-`@riverpod`
/// default it was liable to be silently disposed and reset between
/// screens, the same bug class `SplashScreen` had). Listening explicitly
/// here documents the dependency rather than relying on an annotation a
/// future edit could silently revert.
void main() {
  late FakeUserProfileRepository fakeUserRepository;
  late FakeConnectivityRepository fakeConnectivity;
  late ProviderContainer container;
  late AccountSetupController controller;

  setUp(() {
    fakeUserRepository = FakeUserProfileRepository();
    fakeConnectivity = FakeConnectivityRepository();
    container = ProviderContainer(
      overrides: [
        userProfileRepositoryProvider.overrideWithValue(fakeUserRepository),
        connectivityRepositoryProvider.overrideWithValue(fakeConnectivity),
      ],
    );
    addTearDown(container.dispose);
    addTearDown(fakeUserRepository.dispose);
    addTearDown(fakeConnectivity.dispose);
    container
      ..listen(accountSetupControllerProvider, (_, __) {})
      ..listen(onboardingProfileDraftControllerProvider, (_, __) {});
    controller = container.read(accountSetupControllerProvider.notifier);
  });

  AccountSetupState state() => container.read(accountSetupControllerProvider);

  void stageValidDraft() {
    container
        .read(onboardingProfileDraftControllerProvider.notifier)
        .setDateOfBirth(DateTime(2000, 5));
    container
        .read(onboardingProfileDraftControllerProvider.notifier)
        .setProfileFields(displayName: 'Ada', bio: 'Loves board games.');
    container
        .read(onboardingProfileDraftControllerProvider.notifier)
        .setInterestTags(['coffee', 'hiking', 'board_games']);
  }

  group('submit (online)', () {
    test(
        'a valid draft succeeds, resets the draft, and calls '
        'completeAccountSetup with the staged fields', () async {
      stageValidDraft();

      final result = await controller.submit();

      expect(result, isTrue);
      expect(state().status, AccountSetupStatus.succeeded);
      expect(fakeUserRepository.completeAccountSetupCalls, hasLength(1));
      final call = fakeUserRepository.completeAccountSetupCalls.single;
      expect(call.displayName, 'Ada');
      expect(call.bio, 'Loves board games.');
      expect(call.interestTags, ['coffee', 'hiking', 'board_games']);
      expect(
        container.read(onboardingProfileDraftControllerProvider).displayName,
        isNull,
        reason: 'the draft should be reset once completeAccountSetup '
            'actually succeeds',
      );
    });

    test(
        'a missing required field fails defensively without calling '
        'completeAccountSetup', () async {
      // No stageValidDraft() — dateOfBirth/displayName are still null,
      // the state Screens 4/5 are supposed to prevent this controller
      // from ever seeing in practice.
      final result = await controller.submit();

      expect(result, isFalse);
      expect(state().status, AccountSetupStatus.failed);
      expect(fakeUserRepository.completeAccountSetupCalls, isEmpty);
    });

    test(
        'a known callable error (e.g. PHOTO_NOT_APPROVED) surfaces its '
        'code and message', () async {
      stageValidDraft();
      fakeUserRepository.completeAccountSetupError =
          const OnboardingCallableException(
        code: 'PHOTO_NOT_APPROVED',
        message: 'Your photo needs another look.',
      );

      final result = await controller.submit();

      expect(result, isFalse);
      expect(state().status, AccountSetupStatus.failed);
      expect(state().errorCode, 'PHOTO_NOT_APPROVED');
      expect(state().errorMessage, 'Your photo needs another look.');
      expect(
        container.read(onboardingProfileDraftControllerProvider).displayName,
        'Ada',
        reason: 'a failed submit must not discard the draft',
      );
    });

    test(
        'a known callable error (e.g. UNDER_MINIMUM_AGE) surfaces its '
        'code and message', () async {
      stageValidDraft();
      fakeUserRepository.completeAccountSetupError =
          const OnboardingCallableException(
        code: 'UNDER_MINIMUM_AGE',
        message: "You're not old enough yet.",
      );

      await controller.submit();

      expect(state().status, AccountSetupStatus.failed);
      expect(state().errorCode, 'UNDER_MINIMUM_AGE');
    });
  });

  group('submit (offline)', () {
    test(
        'queues immediately without calling completeAccountSetup, then '
        'retries and succeeds once reconnected', () async {
      stageValidDraft();
      fakeConnectivity.setOffline(isOffline: true);

      final result = await controller.submit();

      expect(result, isTrue);
      expect(state().status, AccountSetupStatus.queued);
      expect(fakeUserRepository.completeAccountSetupCalls, isEmpty);

      final succeeded = Completer<void>();
      container.listen(accountSetupControllerProvider, (previous, next) {
        if (next.status == AccountSetupStatus.succeeded) {
          succeeded.complete();
        }
      });
      fakeConnectivity.setOffline(isOffline: false);
      await succeeded.future.timeout(const Duration(seconds: 2));

      expect(state().status, AccountSetupStatus.succeeded);
      expect(fakeUserRepository.completeAccountSetupCalls, hasLength(1));
    });
  });
}
