import 'package:flutter_test/flutter_test.dart';
import 'package:tablecrew/features/onboarding/application/onboarding_phone_flow_controller.dart';
import 'package:tablecrew/features/onboarding/data/phone_auth_repository.dart';

/// Unit tests for [OnboardingPhoneFlowState.copyWith]'s "clear vs. leave
/// unchanged" semantics — the one piece of Screens 2-3's flow state that's
/// pure data logic, independent of Firebase Auth or Riverpod's async
/// machinery.
///
/// Deliberately not covered here: [OnboardingPhoneFlowController]'s actual
/// send/resend/confirm methods, which call through to
/// [PhoneAuthRepository]'s real Firebase Auth SDK calls — exercising those
/// would need a hand-written fake or a mockito mock of
/// [PhoneAuthRepository], neither of which exists yet. Disclosed as an open
/// gap for Milestone F5's dedicated test-writing task (#96), the same
/// treatment this codebase gives every other verified-vs-not boundary
/// (e.g. the Cloud Vision integration, TASKS.md).
void main() {
  group('OnboardingPhoneFlowState', () {
    test('initial state has status.initial and no payload fields', () {
      const state = OnboardingPhoneFlowState.initial();
      expect(state.status, OnboardingPhoneFlowStatus.initial);
      expect(state.phoneNumber, isNull);
      expect(state.session, isNull);
      expect(state.exception, isNull);
      expect(state.wrongAttemptCount, 0);
      expect(state.lockedUntil, isNull);
    });

    test('copyWith replaces only the given fields', () {
      const initial = OnboardingPhoneFlowState.initial();
      final next = initial.copyWith(
        status: OnboardingPhoneFlowStatus.sending,
        phoneNumber: '+919876543210',
      );

      expect(next.status, OnboardingPhoneFlowStatus.sending);
      expect(next.phoneNumber, '+919876543210');
      expect(next.wrongAttemptCount, 0);
    });

    test('exception persists across an unrelated copyWith by default', () {
      const exception = PhoneAuthException(
        code: 'invalid-verification-code',
        message: 'Wrong code',
      );
      final withError = const OnboardingPhoneFlowState.initial().copyWith(
        exception: exception,
      );
      final next = withError.copyWith(
        status: OnboardingPhoneFlowStatus.confirming,
      );

      expect(next.exception, exception);
    });

    test('clearException: true drops the exception regardless of the '
        'exception parameter', () {
      const exception = PhoneAuthException(code: 'x', message: 'x');
      final withError = const OnboardingPhoneFlowState.initial().copyWith(
        exception: exception,
      );
      final cleared = withError.copyWith(clearException: true);

      expect(cleared.exception, isNull);
    });

    test('clearLockedUntil: true drops lockedUntil', () {
      final lockedUntil = DateTime(2026);
      final locked = const OnboardingPhoneFlowState.initial().copyWith(
        status: OnboardingPhoneFlowStatus.locked,
        lockedUntil: lockedUntil,
      );
      final cleared = locked.copyWith(clearLockedUntil: true);

      expect(cleared.lockedUntil, isNull);
    });

    test('wrongAttemptCount of 0 is applied, not treated as "unchanged"',
        () {
      final withAttempts = const OnboardingPhoneFlowState.initial().copyWith(
        wrongAttemptCount: 3,
      );
      final reset = withAttempts.copyWith(wrongAttemptCount: 0);

      expect(reset.wrongAttemptCount, 0);
    });
  });
}
