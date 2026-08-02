import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tablecrew/data/connectivity_repository.dart';
import 'package:tablecrew/data/user_profile_repository.dart';
import 'package:tablecrew/features/onboarding/application/onboarding_profile_draft_controller.dart';
import 'package:tablecrew/features/onboarding/presentation/interests_screen.dart';

import '../../../fakes/fake_connectivity_repository.dart';
import '../../../fakes/fake_user_profile_repository.dart';
import '../../../support/test_router.dart';

/// Widget tests for Screen 6 (Interest Selection), task #96e.
///
/// Each test stages the Screens 4-5 half of the draft (date of birth,
/// display name) directly through [OnboardingProfileDraftController] —
/// the exact state a user arriving at this screen would have — since
/// `AccountSetupController._attempt` reads the whole draft and fails its
/// defensive missing-fields guard otherwise.
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

    container.read(onboardingProfileDraftControllerProvider.notifier)
      ..setDateOfBirth(DateTime(2000, 5))
      ..setProfileFields(displayName: 'Ada');
  });

  Future<void> pumpScreen(WidgetTester tester) async {
    final router = buildTestRouter(
      initialPath: '/interests',
      initialName: 'interests',
      initialScreen: const InterestsScreen(),
      destinations: const {
        'notification-priming': '/notification-priming',
        'profile-setup': '/profile-setup',
        'age-ineligible': '/age-ineligible',
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

  Future<void> selectThreeChips(WidgetTester tester) async {
    for (final label in ['Coffee', 'Lunch', 'Dinner']) {
      await tester.tap(find.widgetWithText(FilterChip, label));
      await tester.pump();
    }
  }

  ElevatedButton continueButton(WidgetTester tester) {
    return tester.widget<ElevatedButton>(
      find.widgetWithText(ElevatedButton, 'Continue'),
    );
  }

  testWidgets('Continue stays disabled until 3 chips are selected', (
    tester,
  ) async {
    await pumpScreen(tester);

    expect(continueButton(tester).onPressed, isNull);
    expect(find.textContaining('Pick at least 3'), findsWidgets);

    await selectThreeChips(tester);

    expect(find.text('3 selected'), findsOneWidget);
    expect(continueButton(tester).onPressed, isNotNull);
  });

  testWidgets(
      'a successful submit sends the staged draft and routes to '
      'notification-priming', (tester) async {
    await pumpScreen(tester);
    await selectThreeChips(tester);

    await tester.tap(find.widgetWithText(ElevatedButton, 'Continue'));
    await tester.pumpAndSettle();

    expect(find.text('route:notification-priming'), findsOneWidget);
    final call = userProfileRepository.completeAccountSetupCalls.single;
    expect(call.displayName, 'Ada');
    expect(call.interestTags, unorderedEquals(['coffee', 'lunch', 'dinner']));
  });

  testWidgets('PHOTO_NOT_APPROVED reroutes back to profile-setup', (
    tester,
  ) async {
    userProfileRepository.completeAccountSetupError =
        const OnboardingCallableException(
      code: 'PHOTO_NOT_APPROVED',
      message: 'Your photo needs another look.',
    );
    await pumpScreen(tester);
    await selectThreeChips(tester);

    await tester.tap(find.widgetWithText(ElevatedButton, 'Continue'));
    await tester.pumpAndSettle();

    expect(find.text('route:profile-setup'), findsOneWidget);
  });

  testWidgets('UNDER_MINIMUM_AGE reroutes to the age-ineligible hard-stop', (
    tester,
  ) async {
    userProfileRepository.completeAccountSetupError =
        const OnboardingCallableException(
      code: 'UNDER_MINIMUM_AGE',
      message: "You're not old enough yet.",
    );
    await pumpScreen(tester);
    await selectThreeChips(tester);

    await tester.tap(find.widgetWithText(ElevatedButton, 'Continue'));
    await tester.pumpAndSettle();

    expect(find.text('route:age-ineligible'), findsOneWidget);
  });

  testWidgets(
      'any other failure stays on this screen with an inline notice and a '
      're-enabled Continue', (tester) async {
    userProfileRepository.completeAccountSetupError =
        const OnboardingCallableException(
      code: 'internal',
      message: 'Something went wrong on our end.',
    );
    await pumpScreen(tester);
    await selectThreeChips(tester);

    await tester.tap(find.widgetWithText(ElevatedButton, 'Continue'));
    await tester.pumpAndSettle();

    expect(find.text('route:profile-setup'), findsNothing);
    expect(find.text('route:age-ineligible'), findsNothing);
    expect(find.text('Something went wrong on our end.'), findsOneWidget);
    expect(continueButton(tester).onPressed, isNotNull);
  });
}
