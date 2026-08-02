import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tablecrew/data/connectivity_repository.dart';
import 'package:tablecrew/data/trust_repository.dart';
import 'package:tablecrew/features/trust/presentation/report_flow_screen.dart';

import '../../../fakes/fake_connectivity_repository.dart';
import '../../../fakes/fake_trust_repository.dart';
import '../../../support/test_router.dart';

/// Widget tests for Screen 27 (Report Flow) — Milestone F6 (Trust & Safety
/// client chunk).
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

  // A bounded stand-in for pumpAndSettle() — same rationale as every other
  // screen test file touching an async controller in this codebase
  // (otp_screen_test.dart et al.): the submitting state's disabled button
  // and a possible SnackBar keep a frame pending indefinitely.
  Future<void> settle(WidgetTester tester) async {
    for (var i = 0; i < 10; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }
  }

  Future<void> pumpScreen(
    WidgetTester tester, {
    String targetType = 'user',
    String targetId = 'bob',
    String targetDisplayName = 'Bob',
  }) async {
    final router = buildTestRouter(
      initialPath: '/report',
      initialName: 'report',
      initialScreen: ReportFlowScreen(
        targetType: targetType,
        targetId: targetId,
        targetDisplayName: targetDisplayName,
      ),
    );
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp.router(routerConfig: router),
      ),
    );
    await settle(tester);
  }

  testWidgets('Submit Report is disabled until a reason is selected', (
    tester,
  ) async {
    await pumpScreen(tester);

    expect(
      tester
          .widget<ElevatedButton>(
            find.widgetWithText(ElevatedButton, 'Submit Report'),
          )
          .onPressed,
      isNull,
    );
  });

  testWidgets(
      'selecting Harassment enables submit and pre-checks the '
      'block toggle', (tester) async {
    await pumpScreen(tester);

    await tester.tap(find.text('Harassment'));
    await tester.pump();

    expect(
      tester
          .widget<ElevatedButton>(
            find.widgetWithText(ElevatedButton, 'Submit Report'),
          )
          .onPressed,
      isNotNull,
    );
    expect(
      tester.widget<CheckboxListTile>(find.byType(CheckboxListTile)).value,
      isTrue,
    );
  });

  testWidgets(
      'selecting a lower-severity reason leaves the block toggle unchecked',
      (tester) async {
    await pumpScreen(tester);

    await tester.tap(find.text('No-show'));
    await tester.pump();

    expect(
      tester.widget<CheckboxListTile>(find.byType(CheckboxListTile)).value,
      isFalse,
    );
  });

  testWidgets(
      'off-platform reason requires details before Submit Report enables',
      (tester) async {
    await pumpScreen(tester);

    await tester.tap(find.text('This happened outside the app'));
    await tester.pump();

    expect(
      tester
          .widget<ElevatedButton>(
            find.widgetWithText(ElevatedButton, 'Submit Report'),
          )
          .onPressed,
      isNull,
      reason: 'details are required for off_platform_stalking',
    );

    await tester.enterText(
      find.widgetWithText(TextField, 'What happened? (required)'),
      'they followed me home from the Table',
    );
    await tester.pump();

    expect(
      tester
          .widget<ElevatedButton>(
            find.widgetWithText(ElevatedButton, 'Submit Report'),
          )
          .onPressed,
      isNotNull,
    );
  });

  testWidgets('no block toggle is shown when reporting a Table', (
    tester,
  ) async {
    await pumpScreen(
      tester,
      targetType: 'table',
      targetId: 't1',
      targetDisplayName: 'Sunday hike',
    );

    expect(find.byType(CheckboxListTile), findsNothing);
  });

  testWidgets(
      'submitting calls reportUser with the selected reason and shows the '
      'confirmation', (tester) async {
    await pumpScreen(tester);

    await tester.tap(find.text('Safety concern'));
    await tester.pump();
    await tester
        .ensureVisible(find.widgetWithText(ElevatedButton, 'Submit Report'));
    await tester.pump();
    await tester.tap(find.widgetWithText(ElevatedButton, 'Submit Report'));
    await settle(tester);

    expect(fakeTrust.reportUserCalls.single.targetUserId, 'bob');
    expect(
      fakeTrust.reportUserCalls.single.reasonCode,
      ReportReasonCode.safetyConcern,
    );
    expect(find.text("Thanks, we've got this"), findsOneWidget);
  });

  testWidgets(
      'submitting with the block toggle checked also calls '
      'blockUser', (tester) async {
    await pumpScreen(tester);

    await tester.tap(find.text('Harassment'));
    await tester.pump();
    await tester
        .ensureVisible(find.widgetWithText(ElevatedButton, 'Submit Report'));
    await tester.pump();
    await tester.tap(find.widgetWithText(ElevatedButton, 'Submit Report'));
    await settle(tester);

    expect(fakeTrust.blockUserCalls, ['bob']);
  });

  testWidgets('offline shows the no-live-connection notice, never submits', (
    tester,
  ) async {
    fakeConnectivity.setOffline(isOffline: true);
    await pumpScreen(tester);

    await tester.tap(find.text('Safety concern'));
    await tester.pump();
    await tester
        .ensureVisible(find.widgetWithText(ElevatedButton, 'Submit Report'));
    await tester.pump();
    await tester.tap(find.widgetWithText(ElevatedButton, 'Submit Report'));
    await settle(tester);

    expect(find.textContaining("You're offline"), findsOneWidget);
    expect(fakeTrust.reportUserCalls, isEmpty);
  });

  testWidgets(
      'the immediate-danger notice is always visible regardless of '
      'connectivity', (tester) async {
    fakeConnectivity.setOffline(isOffline: true);
    await pumpScreen(tester);

    expect(
      find.textContaining('contact local emergency services'),
      findsOneWidget,
    );
  });
}
