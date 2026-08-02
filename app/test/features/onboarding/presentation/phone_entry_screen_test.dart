import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tablecrew/data/connectivity_repository.dart';
import 'package:tablecrew/features/onboarding/data/phone_auth_repository.dart';
import 'package:tablecrew/features/onboarding/presentation/phone_entry_screen.dart';

import '../../../fakes/fake_connectivity_repository.dart';
import '../../../fakes/fake_phone_auth_repository.dart';
import '../../../support/test_router.dart';

/// Widget tests for Screen 2 (Phone Number Entry),
/// `docs/SCREEN_SPECIFICATIONS.md`, task #96e.
///
/// A US number is used throughout since `intl_phone_field`'s bundled
/// country data (`countries.dart`) pins US numbers to exactly 10 digits —
/// `2025551234` is a plausible, non-real DC-area-code number, entered
/// whole via [WidgetTester.enterText] rather than keystroke-by-keystroke,
/// which avoids `PhoneNumber.isValidNumber()`'s partial-length
/// `NumberTooShortException` path entirely (a real digit-by-digit typing
/// simulation would trip it on every keystroke before the 10th).
const _validNumber = '2025551234';
const _e164Number = '+12025551234';

void main() {
  late FakeConnectivityRepository connectivity;
  late FakePhoneAuthRepository phoneAuthRepository;

  setUp(() async {
    connectivity = FakeConnectivityRepository();
    phoneAuthRepository = FakePhoneAuthRepository();
    addTearDown(connectivity.dispose);
    SharedPreferences.setMockInitialValues({});
  });

  Future<void> pumpScreen(WidgetTester tester) async {
    final router = buildTestRouter(
      initialPath: '/phone-entry',
      initialName: 'phone-entry',
      initialScreen: const PhoneEntryScreen(),
      destinations: const {'otp': '/otp'},
    );
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          connectivityRepositoryProvider.overrideWithValue(connectivity),
          phoneAuthRepositoryProvider.overrideWithValue(phoneAuthRepository),
        ],
        child: MaterialApp.router(routerConfig: router),
      ),
    );
    await tester.pumpAndSettle();
  }

  ElevatedButton sendCodeButton(WidgetTester tester) {
    return tester.widget<ElevatedButton>(
      find.widgetWithText(ElevatedButton, 'Send Code'),
    );
  }

  testWidgets('renders the headline with Send Code disabled', (
    tester,
  ) async {
    await pumpScreen(tester);

    expect(find.text("What's your number?"), findsOneWidget);
    expect(sendCodeButton(tester).onPressed, isNull);
  });

  testWidgets('entering a valid number enables Send Code', (tester) async {
    await pumpScreen(tester);

    await tester.enterText(find.byType(TextFormField), _validNumber);
    await tester.pump();

    expect(sendCodeButton(tester).onPressed, isNotNull);
  });

  testWidgets(
      'tapping Send Code while online sends the code and navigates to OTP',
      (tester) async {
    phoneAuthRepository.sendCodeResults.add(
      const PhoneAuthCodeSent(PhoneVerificationSession(verificationId: 'v1')),
    );
    await pumpScreen(tester);

    await tester.enterText(find.byType(TextFormField), _validNumber);
    await tester.pump();
    await tester.tap(find.widgetWithText(ElevatedButton, 'Send Code'));
    await tester.pumpAndSettle();

    expect(phoneAuthRepository.sendCodeCalls, [_e164Number]);
    expect(find.text('route:otp'), findsOneWidget);
  });

  testWidgets(
      'offline at send time shows a retry notice, then auto-sends once '
      'reconnected', (tester) async {
    connectivity = FakeConnectivityRepository(initiallyOffline: true);
    phoneAuthRepository.sendCodeResults.add(
      const PhoneAuthCodeSent(PhoneVerificationSession(verificationId: 'v1')),
    );
    await pumpScreen(tester);

    await tester.enterText(find.byType(TextFormField), _validNumber);
    await tester.pump();
    await tester.tap(find.widgetWithText(ElevatedButton, 'Send Code'));
    await tester.pump();

    expect(
      find.text("You're offline — we'll retry automatically."),
      findsOneWidget,
    );
    expect(phoneAuthRepository.sendCodeCalls, isEmpty);

    connectivity.setOffline(isOffline: false);
    await tester.pumpAndSettle();

    expect(phoneAuthRepository.sendCodeCalls, [_e164Number]);
    expect(find.text('route:otp'), findsOneWidget);
  });

  testWidgets(
      'rate-limited after 5 recent attempts shows a cooldown notice '
      'without sending', (tester) async {
    SharedPreferences.setMockInitialValues({
      'phone_send_attempts_$_e164Number': List.generate(
        5,
        (_) => DateTime.now().toIso8601String(),
      ),
    });
    await pumpScreen(tester);

    await tester.enterText(find.byType(TextFormField), _validNumber);
    await tester.pump();
    await tester.tap(find.widgetWithText(ElevatedButton, 'Send Code'));
    await tester.pump();

    expect(find.textContaining('Too many attempts'), findsOneWidget);
    expect(phoneAuthRepository.sendCodeCalls, isEmpty);
  });

  testWidgets('a send failure surfaces an inline error and stays on screen',
      (tester) async {
    phoneAuthRepository.sendCodeResults.add(
      const PhoneAuthException(
        code: 'invalid-phone-number',
        message: "That number doesn't look right.",
      ),
    );
    await pumpScreen(tester);

    await tester.enterText(find.byType(TextFormField), _validNumber);
    await tester.pump();
    await tester.tap(find.widgetWithText(ElevatedButton, 'Send Code'));
    await tester.pumpAndSettle();

    expect(find.text("That number doesn't look right."), findsOneWidget);
    expect(find.text('route:otp'), findsNothing);
  });
}
