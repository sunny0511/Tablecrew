import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tablecrew/data/connectivity_repository.dart';
import 'package:tablecrew/data/user_profile_repository.dart';
import 'package:tablecrew/features/onboarding/application/onboarding_profile_draft_controller.dart';
import 'package:tablecrew/features/onboarding/presentation/dob_entry_screen.dart';

import '../../../fakes/fake_connectivity_repository.dart';
import '../../../fakes/fake_user_profile_repository.dart';
import '../../../support/test_router.dart';

/// Widget tests for Screen 4 (Date of Birth Entry / Age Gate), task #96e.
///
/// The date is picked through the real [showDatePicker] dialog the screen
/// opens — "OK" confirms the dialog's initial date (18 years ago today,
/// the screen's own `defaultAdultDate`), which is all these tests need:
/// which *specific* date was picked doesn't matter, since eligibility is
/// decided by [FakeUserProfileRepository.validateAgeResult], not
/// client-side date math (mirroring the real screen's server-side
/// `validateAge` contract).
void main() {
  late FakeConnectivityRepository connectivity;
  late FakeUserProfileRepository userProfileRepository;
  late ProviderContainer container;

  setUp(() {
    connectivity = FakeConnectivityRepository();
    userProfileRepository = FakeUserProfileRepository();
    container = ProviderContainer(
      overrides: [
        connectivityRepositoryProvider.overrideWithValue(connectivity),
        userProfileRepositoryProvider.overrideWithValue(userProfileRepository),
      ],
    );
    addTearDown(container.dispose);
    addTearDown(connectivity.dispose);
    addTearDown(userProfileRepository.dispose);
  });

  Future<void> pumpScreen(WidgetTester tester) async {
    final router = buildTestRouter(
      initialPath: '/dob',
      initialName: 'dob',
      initialScreen: const DobEntryScreen(),
      destinations: const {
        'age-ineligible': '/age-ineligible',
        'profile-setup': '/profile-setup',
      },
    );
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp.router(routerConfig: router),
      ),
    );
    await tester.pumpAndSettle();
  }

  Future<void> pickDefaultDate(WidgetTester tester) async {
    await tester.tap(find.text('Select date of birth'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('OK'));
    await tester.pumpAndSettle();
  }

  ElevatedButton continueButton(WidgetTester tester) {
    return tester.widget<ElevatedButton>(
      find.widgetWithText(ElevatedButton, 'Continue'),
    );
  }

  testWidgets('Continue stays disabled until a date is picked', (
    tester,
  ) async {
    await pumpScreen(tester);

    expect(find.text("When's your birthday?"), findsOneWidget);
    expect(continueButton(tester).onPressed, isNull);

    await pickDefaultDate(tester);

    expect(find.text('Select date of birth'), findsNothing);
    expect(continueButton(tester).onPressed, isNotNull);
  });

  testWidgets('an eligible date stages the draft and routes to profile-setup', (
    tester,
  ) async {
    await pumpScreen(tester);
    await pickDefaultDate(tester);

    await tester.tap(find.widgetWithText(ElevatedButton, 'Continue'));
    await tester.pumpAndSettle();

    expect(find.text('route:profile-setup'), findsOneWidget);
    expect(
      container.read(onboardingProfileDraftControllerProvider).dateOfBirth,
      isNotNull,
      reason: 'Continue must stage the accepted date into the shared draft',
    );
  });

  testWidgets('an ineligible date routes to the age-ineligible hard-stop', (
    tester,
  ) async {
    userProfileRepository.validateAgeResult = false;
    await pumpScreen(tester);
    await pickDefaultDate(tester);

    await tester.tap(find.widgetWithText(ElevatedButton, 'Continue'));
    await tester.pumpAndSettle();

    expect(find.text('route:age-ineligible'), findsOneWidget);
    expect(
      container.read(onboardingProfileDraftControllerProvider).dateOfBirth,
      isNull,
      reason: 'an ineligible date must not be staged into the draft',
    );
  });

  testWidgets('offline shows a notice and disables Continue', (tester) async {
    connectivity = FakeConnectivityRepository(initiallyOffline: true);
    container = ProviderContainer(
      overrides: [
        connectivityRepositoryProvider.overrideWithValue(connectivity),
        userProfileRepositoryProvider.overrideWithValue(userProfileRepository),
      ],
    );
    addTearDown(container.dispose);
    await pumpScreen(tester);
    await pickDefaultDate(tester);

    expect(
      find.text('We need a connection to verify your age.'),
      findsOneWidget,
    );
    expect(continueButton(tester).onPressed, isNull);

    connectivity.setOffline(isOffline: false);
    await tester.pumpAndSettle();

    expect(
      find.text('We need a connection to verify your age.'),
      findsNothing,
    );
    expect(continueButton(tester).onPressed, isNotNull);
  });
}
