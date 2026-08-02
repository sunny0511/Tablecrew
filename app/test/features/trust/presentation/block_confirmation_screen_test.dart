import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tablecrew/data/connectivity_repository.dart';
import 'package:tablecrew/data/trust_repository.dart';
import 'package:tablecrew/features/trust/presentation/block_confirmation_screen.dart';

import '../../../fakes/fake_connectivity_repository.dart';
import '../../../fakes/fake_trust_repository.dart';

/// Widget tests for Screen 28 (Block Confirmation) — Milestone F6 (Trust &
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

  Future<void> settle(WidgetTester tester) async {
    for (var i = 0; i < 10; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }
  }

  // Screen 28 calls `Navigator.of(context).pop()` on both its Cancel and
  // successful-Block exit points, matching how it's actually reached in
  // the app (always pushed on top of another screen — Table Detail's
  // attendee-row overflow here) — so this pushes it onto a real base
  // route via a plain Navigator, rather than making it the *only* route
  // in the stack (which made `pop()` crash with "you have popped the
  // last page off of the stack" the first time this test ran for real).
  Future<void> pumpScreen(
    WidgetTester tester, {
    String targetUserId = 'bob',
    String targetDisplayName = 'Bob',
    bool sharesCrew = false,
  }) async {
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp(
          home: Builder(
            builder: (context) => Scaffold(
              body: Center(
                child: ElevatedButton(
                  onPressed: () => Navigator.of(context).push(
                    MaterialPageRoute<void>(
                      builder: (_) => BlockConfirmationScreen(
                        targetUserId: targetUserId,
                        targetDisplayName: targetDisplayName,
                        sharesCrew: sharesCrew,
                      ),
                    ),
                  ),
                  child: const Text('open'),
                ),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('open'));
    await settle(tester);
  }

  testWidgets('shows the target name and no shared-Crew sentence by default',
      (tester) async {
    await pumpScreen(tester);

    expect(find.text('Block Bob?'), findsOneWidget);
    expect(find.textContaining('share a Crew'), findsNothing);
  });

  testWidgets('sharesCrew shows the additional shared-Crew sentence', (
    tester,
  ) async {
    await pumpScreen(tester, sharesCrew: true);

    expect(find.textContaining('share a Crew'), findsOneWidget);
  });

  testWidgets('Cancel pops without calling blockUser', (tester) async {
    await pumpScreen(tester);

    await tester.tap(find.widgetWithText(TextButton, 'Cancel'));
    await tester.pump();

    expect(fakeTrust.blockUserCalls, isEmpty);
  });

  testWidgets('Block calls blockUser and shows a confirmation SnackBar', (
    tester,
  ) async {
    await pumpScreen(tester);

    await tester.tap(find.widgetWithText(ElevatedButton, 'Block'));
    await settle(tester);

    expect(fakeTrust.blockUserCalls, ['bob']);
    expect(find.text("Blocked. They won't be notified."), findsOneWidget);
  });

  testWidgets('offline shows the no-live-connection notice, never blocks', (
    tester,
  ) async {
    fakeConnectivity.setOffline(isOffline: true);
    await pumpScreen(tester);

    await tester.tap(find.widgetWithText(ElevatedButton, 'Block'));
    await settle(tester);

    expect(find.textContaining("can't be done offline"), findsOneWidget);
    expect(fakeTrust.blockUserCalls, isEmpty);
  });
}
