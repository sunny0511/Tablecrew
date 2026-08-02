import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tablecrew/features/onboarding/application/onboarding_phone_flow_controller.dart';
import 'package:tablecrew/features/onboarding/data/phone_auth_repository.dart';

import '../../../fakes/fake_phone_auth_repository.dart';

const _phoneNumber = '+919876543210';

/// Unit tests for [OnboardingPhoneFlowController]'s real send/resend/confirm
/// methods against [FakePhoneAuthRepository] — the coverage
/// `onboarding_phone_flow_state_test.dart` explicitly disclosed as missing
/// and deferred to Milestone F5's dedicated test-writing task (#96).
///
/// Every test subscribes to the provider via [ProviderContainer.listen]
/// before driving it. Not a formality: `OnboardingPhoneFlowController` is a
/// plain `@riverpod` (autoDispose) notifier, and a container-level `read`
/// with no active listener doesn't keep an autoDispose provider alive
/// across an `await` — the exact same class of bug this milestone's own
/// `SplashScreen` had (see `TASKS.md`'s F5.95 entries). `listen` with a
/// no-op callback is the documented fix for imperative/test code, same as
/// `SplashScreen.initState`'s `ref.listenManual`.
void main() {
  late FakePhoneAuthRepository fakeRepository;
  late ProviderContainer container;
  late OnboardingPhoneFlowController controller;

  setUp(() {
    fakeRepository = FakePhoneAuthRepository();
    container = ProviderContainer(
      overrides: [
        phoneAuthRepositoryProvider.overrideWithValue(fakeRepository),
      ],
    );
    addTearDown(container.dispose);
    container.listen(onboardingPhoneFlowControllerProvider, (_, __) {});
    controller = container.read(
      onboardingPhoneFlowControllerProvider.notifier,
    );
  });

  OnboardingPhoneFlowState state() =>
      container.read(onboardingPhoneFlowControllerProvider);

  group('sendCode', () {
    test('a successful send transitions to codeSent with the new session',
        () async {
      const session = PhoneVerificationSession(verificationId: 'v1');
      fakeRepository.sendCodeResults.add(const PhoneAuthCodeSent(session));

      await controller.sendCode(_phoneNumber);

      expect(fakeRepository.sendCodeCalls, [_phoneNumber]);
      expect(state().status, OnboardingPhoneFlowStatus.codeSent);
      expect(state().phoneNumber, _phoneNumber);
      expect(state().session, session);
      expect(state().codeSentAt, isNotNull);
    });

    test('Android auto-verification transitions straight to autoVerified',
        () async {
      final credential = fakeUserCredential('uid-1');
      fakeRepository.sendCodeResults.add(PhoneAutoVerified(credential));

      await controller.sendCode(_phoneNumber);

      expect(state().status, OnboardingPhoneFlowStatus.autoVerified);
      expect(state().credential, credential);
    });

    test('a rejected send transitions to sendFailed with the exception',
        () async {
      const exception = PhoneAuthException(
        code: 'invalid-phone-number',
        message: 'That number looks off.',
      );
      fakeRepository.sendCodeResults.add(exception);

      await controller.sendCode(_phoneNumber);

      expect(state().status, OnboardingPhoneFlowStatus.sendFailed);
      expect(state().exception, exception);
    });

    test(
        'resets wrongAttemptCount/lockedUntil/exception from a prior '
        'attempt', () async {
      const badSession = PhoneVerificationSession(verificationId: 'v1');
      fakeRepository.sendCodeResults.add(
        const PhoneAuthCodeSent(badSession),
      );
      await controller.sendCode(_phoneNumber);
      fakeRepository.confirmCodeResults.add(
        const PhoneAuthException(
          code: 'invalid-verification-code',
          message: 'x',
        ),
      );
      await controller.confirmCode('000000');
      expect(state().wrongAttemptCount, 1);

      const freshSession = PhoneVerificationSession(verificationId: 'v2');
      fakeRepository.sendCodeResults.add(
        const PhoneAuthCodeSent(freshSession),
      );
      await controller.sendCode(_phoneNumber);

      expect(state().wrongAttemptCount, 0);
      expect(state().lockedUntil, isNull);
      expect(state().exception, isNull);
      expect(state().session, freshSession);
    });
  });

  group('resendCode', () {
    test(
        "reuses the in-flight phone number and passes the prior session's "
        'resend token', () async {
      const session = PhoneVerificationSession(
        verificationId: 'v1',
        resendToken: 42,
      );
      fakeRepository.sendCodeResults.add(const PhoneAuthCodeSent(session));
      await controller.sendCode(_phoneNumber);

      const nextSession = PhoneVerificationSession(verificationId: 'v2');
      fakeRepository.sendCodeResults.add(
        const PhoneAuthCodeSent(nextSession),
      );
      await controller.resendCode();

      expect(fakeRepository.resendCodeCalls, [
        (phoneNumber: _phoneNumber, resendToken: 42),
      ]);
      expect(state().session, nextSession);
    });

    test('is a no-op with no in-flight phone number', () async {
      await controller.resendCode();

      expect(fakeRepository.resendCodeCalls, isEmpty);
      expect(fakeRepository.sendCodeCalls, isEmpty);
      expect(state().status, OnboardingPhoneFlowStatus.initial);
    });
  });

  group('confirmCode', () {
    Future<void> sendSuccessfully() async {
      const session = PhoneVerificationSession(verificationId: 'v1');
      fakeRepository.sendCodeResults.add(const PhoneAuthCodeSent(session));
      await controller.sendCode(_phoneNumber);
    }

    test('a correct code transitions to confirmed with the credential',
        () async {
      await sendSuccessfully();
      final credential = fakeUserCredential('uid-1');
      fakeRepository.confirmCodeResults.add(credential);

      await controller.confirmCode('123456');

      expect(fakeRepository.confirmCodeCalls, hasLength(1));
      expect(fakeRepository.confirmCodeCalls.single.smsCode, '123456');
      expect(state().status, OnboardingPhoneFlowStatus.confirmed);
      expect(state().credential, credential);
      expect(state().wrongAttemptCount, 0);
    });

    test(
        'a wrong code (attempt 1-4) transitions to confirmFailed without '
        'locking', () async {
      await sendSuccessfully();
      const exception = PhoneAuthException(
        code: 'invalid-verification-code',
        message: 'Wrong code',
      );
      fakeRepository.confirmCodeResults.add(exception);

      await controller.confirmCode('000000');

      expect(state().status, OnboardingPhoneFlowStatus.confirmFailed);
      expect(state().exception, exception);
      expect(state().wrongAttemptCount, 1);
      expect(state().lockedUntil, isNull);
    });

    test('the 5th consecutive wrong code locks the field for ~60s', () async {
      await sendSuccessfully();
      const exception = PhoneAuthException(
        code: 'invalid-verification-code',
        message: 'Wrong code',
      );
      fakeRepository.confirmCodeResults.addAll(List.filled(5, exception));

      for (var attempt = 1; attempt <= 5; attempt++) {
        await controller.confirmCode('000000');
      }

      expect(state().status, OnboardingPhoneFlowStatus.locked);
      expect(state().wrongAttemptCount, 5);
      expect(fakeRepository.confirmCodeCalls, hasLength(5));
      final lockedUntil = state().lockedUntil;
      expect(lockedUntil, isNotNull);
      expect(
        lockedUntil!.difference(DateTime.now()).inSeconds,
        inInclusiveRange(55, 60),
      );
    });

    test('is a no-op while locked out — no repository call is made', () async {
      await sendSuccessfully();
      const exception = PhoneAuthException(
        code: 'invalid-verification-code',
        message: 'Wrong code',
      );
      fakeRepository.confirmCodeResults.addAll(List.filled(5, exception));
      for (var attempt = 1; attempt <= 5; attempt++) {
        await controller.confirmCode('000000');
      }
      expect(state().status, OnboardingPhoneFlowStatus.locked);

      await controller.confirmCode('111111');

      expect(fakeRepository.confirmCodeCalls, hasLength(5));
      expect(state().status, OnboardingPhoneFlowStatus.locked);
    });

    test('is a no-op with no in-flight session', () async {
      await controller.confirmCode('123456');

      expect(fakeRepository.confirmCodeCalls, isEmpty);
      expect(state().status, OnboardingPhoneFlowStatus.initial);
    });
  });

  group('clearConfirmError', () {
    test('drops a non-locked confirm failure back to codeSent', () async {
      const session = PhoneVerificationSession(verificationId: 'v1');
      fakeRepository.sendCodeResults.add(const PhoneAuthCodeSent(session));
      await controller.sendCode(_phoneNumber);
      const exception = PhoneAuthException(code: 'x', message: 'x');
      fakeRepository.confirmCodeResults.add(exception);
      await controller.confirmCode('000000');
      expect(state().status, OnboardingPhoneFlowStatus.confirmFailed);

      controller.clearConfirmError();

      expect(state().status, OnboardingPhoneFlowStatus.codeSent);
      expect(state().exception, isNull);
    });

    test('is a no-op outside confirmFailed', () {
      controller.clearConfirmError();

      expect(state().status, OnboardingPhoneFlowStatus.initial);
    });
  });

  group('reset', () {
    test('discards all in-flight state back to initial', () async {
      const session = PhoneVerificationSession(verificationId: 'v1');
      fakeRepository.sendCodeResults.add(const PhoneAuthCodeSent(session));
      await controller.sendCode(_phoneNumber);
      expect(state().status, OnboardingPhoneFlowStatus.codeSent);

      controller.reset();

      expect(state().status, OnboardingPhoneFlowStatus.initial);
      expect(state().phoneNumber, isNull);
      expect(state().session, isNull);
    });
  });
}
