import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tablecrew/features/onboarding/data/phone_auth_repository.dart';
import 'package:tablecrew/features/onboarding/presentation/age_ineligible_screen.dart';

import '../../../fakes/fake_phone_auth_repository.dart';
import '../../../support/test_router.dart';

/// Widget tests for Screen 4's under-18 hard-stop destination, task #96e.
void main() {
  late FakePhoneAuthRepository phoneAuthRepository;

  setUp(() {
    phoneAuthRepository = FakePhoneAuthRepository();
  });

  Future<void> pumpScreen(WidgetTester tester) async {
    final router = buildTestRouter(
      initialPath: '/age-ineligible',
      initialName: 'age-ineligible',
      initialScreen: const AgeIneligibleScreen(),
      destinations: const {'phone-entry': '/phone-entry'},
    );
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          phoneAuthRepositoryProvider.overrideWithValue(phoneAuthRepository),
        ],
        child: MaterialApp.router(routerConfig: router),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('renders the policy copy with both exits and no back button', (
    tester,
  ) async {
    await pumpScreen(tester);

    expect(find.text('TableCrew is for adults 18 and up'), findsOneWidget);
    expect(find.text('Sign out'), findsOneWidget);
    expect(find.text('Delete my account'), findsOneWidget);
    expect(find.byType(BackButton), findsNothing);
  });

  testWidgets('Sign out signs out and routes to phone-entry', (tester) async {
    await pumpScreen(tester);

    await tester.tap(find.text('Sign out'));
    await tester.pumpAndSettle();

    expect(phoneAuthRepository.signOutCallCount, 1);
    expect(phoneAuthRepository.deleteAccountCallCount, 0);
    expect(find.text('route:phone-entry'), findsOneWidget);
  });

  testWidgets('Delete my account deletes and routes to phone-entry', (
    tester,
  ) async {
    await pumpScreen(tester);

    await tester.tap(find.text('Delete my account'));
    await tester.pumpAndSettle();

    expect(phoneAuthRepository.deleteAccountCallCount, 1);
    expect(phoneAuthRepository.signOutCallCount, 0);
    expect(find.text('route:phone-entry'), findsOneWidget);
  });
}
