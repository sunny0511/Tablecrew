import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:tablecrew/data/connectivity_repository.dart';
import 'package:tablecrew/data/user_profile_repository.dart';
import 'package:tablecrew/features/onboarding/application/onboarding_phone_flow_controller.dart';
import 'package:tablecrew/features/onboarding/data/phone_auth_repository.dart';
import 'package:tablecrew/features/onboarding/presentation/otp_screen.dart';

import '../../../fakes/fake_connectivity_repository.dart';
import '../../../fakes/fake_phone_auth_repository.dart';
import '../../../fakes/fake_user_profile_repository.dart';
import '../../../support/test_router.dart';

/// Widget tests for Screen 3 (OTP Verification), task #96e.
///
/// Every test seeds [OnboardingPhoneFlowController] by driving a real
/// `sendCode` through it (via [FakePhoneAuthRepository]) before pumping
/// [OtpScreen] — never by hand-constructing an
/// `OnboardingPhoneFlowState`, which would drift from whatever
/// `OnboardingPhoneFlowController.sendCode` actually produces. Uses
/// [UncontrolledProviderScope] over a hand-built [ProviderContainer]
/// (matching `account_setup_controller_test.dart`'s pattern) so the seed
/// step and the pumped widget share the same provider state.
const _e164Number = '+12025551234';
const _session = PhoneVerificationSession(verificationId: 'v1');

void main() {
  late FakePhoneAuthRepository phoneAuthRepository;
  late FakeConnectivityRepository connectivity;
  late FakeUserProfileRepository userProfileRepository;
  late ProviderContainer container;

  setUp(() {
    phoneAuthRepository = FakePhoneAuthRepository();
    connectivity = FakeConnectivityRepository();
    userProfileRepository = FakeUserProfileRepository();
    container = ProviderContainer(
      overrides: [
        phoneAuthRepositoryProvider.overrideWithValue(phoneAuthRepository),
        connectivityRepositoryProvider.overrideWithValue(connectivity),
        userProfileRepositoryProvider.overrideWithValue(userProfileRepository),
      ],
    );
    addTearDown(container.dispose);
    addTearDown(connectivity.dispose);
    addTearDown(userProfileRepository.dispose);
  });

  Future<void> seedCodeSent() async {
    phoneAuthRepository.sendCodeResults.add(const PhoneAuthCodeSent(_session));
    await container
        .read(onboardingPhoneFlowControllerProvider.notifier)
        .sendCode(_e164Number);
  }

  /// A bounded stand-in for `pumpAndSettle()`: `OtpScreen`'s countdown
  /// `Timer.periodic` calls `setState` once a second for as long as the
  /// screen is mounted, which means a new frame is perpetually scheduled
  /// and `pumpAndSettle()` (which waits for *no* pending frames) never
  /// returns — a real timeout, confirmed against this file's first run.
  /// Advancing a fixed, generous amount of virtual time instead still lets
  /// async work (repository calls, GoRouter's page transition, and
  /// Riverpod's own zero-duration provider-dispose bookkeeping timer from
  /// `seedCodeSent`'s bare `container.read` call) resolve, without waiting
  /// on a condition this screen structurally never meets.
  Future<void> settle(WidgetTester tester) async {
    for (var i = 0; i < 10; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }
  }

  Future<void> pumpScreen(WidgetTester tester) async {
    final router = buildTestRouter(
      initialPath: '/otp',
      initialName: 'otp',
      initialScreen: const OtpScreen(),
      destinations: const {'dob': '/dob', 'home': '/home'},
    );
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp.router(routerConfig: router),
      ),
    );
    await settle(tester);
  }

  Future<void> enterCode(WidgetTester tester, String code) async {
    await tester.enterText(find.byType(EditableText), code);
    await tester.pump();
  }

  testWidgets('shows the masked phone number once a code has been sent', (
    tester,
  ) async {
    await seedCodeSent();
    await pumpScreen(tester);

    expect(find.textContaining('•• ••34'), findsOneWidget);
  });

  testWidgets('a correct code routes to dob when no profile exists for the uid',
      (tester) async {
    await seedCodeSent();
    phoneAuthRepository.confirmCodeResults.add(fakeUserCredential('uid-new'));
    await pumpScreen(tester);

    await enterCode(tester, '123456');
    await settle(tester);

    expect(
      phoneAuthRepository.confirmCodeCalls.single.smsCode,
      '123456',
    );
    expect(find.text('route:dob'), findsOneWidget);
  });

  testWidgets(
      'a correct code routes to home when a profile already exists for '
      'the uid', (tester) async {
    await seedCodeSent();
    userProfileRepository.completedProfiles['uid-existing'] = true;
    phoneAuthRepository.confirmCodeResults.add(
      fakeUserCredential('uid-existing'),
    );
    await pumpScreen(tester);

    await enterCode(tester, '123456');
    await settle(tester);

    expect(find.text('route:home'), findsOneWidget);
  });

  testWidgets('a wrong code shows an inline error and stays on screen', (
    tester,
  ) async {
    await seedCodeSent();
    phoneAuthRepository.confirmCodeResults.add(
      const PhoneAuthException(
        code: 'invalid-verification-code',
        message: 'Wrong code',
      ),
    );
    await pumpScreen(tester);

    await enterCode(tester, '000000');
    await settle(tester);

    expect(find.text("That code didn't match — try again."), findsOneWidget);
    expect(find.text('route:dob'), findsNothing);
  });

  testWidgets('locks the field out after 5 consecutive wrong attempts', (
    tester,
  ) async {
    await seedCodeSent();
    await pumpScreen(tester);

    for (var attempt = 0; attempt < 5; attempt++) {
      phoneAuthRepository.confirmCodeResults.add(
        const PhoneAuthException(
          code: 'invalid-verification-code',
          message: 'Wrong code',
        ),
      );
      await enterCode(tester, '00000$attempt');
      await settle(tester);
    }

    expect(find.textContaining('Too many attempts'), findsOneWidget);
    final pinField = tester.widget<EditableText>(find.byType(EditableText));
    expect(
      pinField.readOnly,
      isTrue,
      reason: "Pinput's enabled:!isLocked flips its EditableText to "
          'readOnly once locked out',
    );
  });

  testWidgets(
      'offline at confirm time shows a retry notice, then confirms once '
      'reconnected', (tester) async {
    connectivity.setOffline(isOffline: true);
    await seedCodeSent();
    phoneAuthRepository.confirmCodeResults.add(fakeUserCredential('uid-new'));
    await pumpScreen(tester);

    await enterCode(tester, '123456');
    await tester.pump();

    expect(
      find.text("You're offline — we'll retry automatically."),
      findsOneWidget,
    );
    expect(phoneAuthRepository.confirmCodeCalls, isEmpty);

    connectivity.setOffline(isOffline: false);
    await settle(tester);

    expect(phoneAuthRepository.confirmCodeCalls, hasLength(1));
    expect(find.text('route:dob'), findsOneWidget);

    // _waitForReconnectThenConfirm's 60s failsafe Timer isn't cancelled by
    // the early-reconnect path above (only the stream subscription is) —
    // it stays pending, harmlessly, until it fires and no-ops on its own
    // `mounted`/deadline check. Advancing past it lets this test end
    // clean rather than tripping flutter_test's "no pending timers" check.
    await tester.pump(const Duration(seconds: 61));
  });

  testWidgets('Resend code disables right after a fresh send (cooldown)', (
    tester,
  ) async {
    await seedCodeSent();
    await pumpScreen(tester);

    final resendButton = tester.widget<TextButton>(
      find.widgetWithText(TextButton, 'Resend code (wait)'),
    );
    expect(resendButton.onPressed, isNull);
  });

  testWidgets('Edit number pops back to the previous screen', (tester) async {
    await seedCodeSent();
    final router = GoRouter(
      initialLocation: '/phone-entry',
      routes: [
        GoRoute(
          path: '/phone-entry',
          name: 'phone-entry',
          builder: (context, state) => const RouteMarker('phone-entry'),
        ),
        GoRoute(
          path: '/otp',
          name: 'otp',
          builder: (context, state) => const OtpScreen(),
        ),
      ],
    );
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp.router(routerConfig: router),
      ),
    );
    await settle(tester);
    unawaited(router.pushNamed('otp'));
    await settle(tester);

    await tester.tap(find.widgetWithText(TextButton, 'Edit number'));
    await settle(tester);

    expect(find.text('route:phone-entry'), findsOneWidget);
  });
}
