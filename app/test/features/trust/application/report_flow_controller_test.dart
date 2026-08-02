import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tablecrew/data/connectivity_repository.dart';
import 'package:tablecrew/data/trust_repository.dart';
import 'package:tablecrew/features/trust/application/report_flow_controller.dart';

import '../../../fakes/fake_connectivity_repository.dart';
import '../../../fakes/fake_trust_repository.dart';

/// Unit tests for [ReportFlowController] — Milestone F6 (Trust & Safety
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

  ReportFlowController controller(String targetRef) {
    container.listen(reportFlowControllerProvider(targetRef), (_, __) {});
    return container.read(reportFlowControllerProvider(targetRef).notifier);
  }

  ReportFlowState state(String targetRef) =>
      container.read(reportFlowControllerProvider(targetRef));

  test('a "user:" targetRef calls reportUser, not reportTable', () async {
    await controller('user:bob').submit(
      reasonCode: ReportReasonCode.harassment,
      alsoBlock: false,
    );

    expect(state('user:bob').status, ReportFlowStatus.succeeded);
    expect(fakeTrust.reportUserCalls.single.targetUserId, 'bob');
    expect(fakeTrust.reportTableCalls, isEmpty);
  });

  test('a "table:" targetRef calls reportTable, not reportUser', () async {
    await controller('table:t1').submit(
      reasonCode: ReportReasonCode.safetyConcern,
      alsoBlock: false,
    );

    expect(state('table:t1').status, ReportFlowStatus.succeeded);
    expect(fakeTrust.reportTableCalls.single.targetTableId, 't1');
    expect(fakeTrust.reportUserCalls, isEmpty);
  });

  test('alsoBlock also calls blockUser for a user target', () async {
    await controller('user:carol').submit(
      reasonCode: ReportReasonCode.offPlatform,
      details: 'they followed me home',
      alsoBlock: true,
    );

    expect(fakeTrust.blockUserCalls, ['carol']);
  });

  test(
      'alsoBlock is never sent to blockUser for a table target, even if '
      'somehow true', () async {
    await controller('table:t2').submit(
      reasonCode: ReportReasonCode.safetyConcern,
      alsoBlock: true,
    );

    expect(fakeTrust.blockUserCalls, isEmpty);
  });

  test('offline fails immediately with no queued retry — never sent', () async {
    fakeConnectivity.setOffline(isOffline: true);

    await controller('user:dave').submit(
      reasonCode: ReportReasonCode.harassment,
      alsoBlock: false,
    );

    expect(state('user:dave').status, ReportFlowStatus.failed);
    expect(fakeTrust.reportUserCalls, isEmpty);
  });

  test('a duplicate-report error surfaces its code (already-exists)', () async {
    fakeTrust.reportError = const TrustCallableException(
      code: 'already-exists',
      message: 'An open report from you against this target already exists.',
    );

    await controller('user:eve').submit(
      reasonCode: ReportReasonCode.harassment,
      alsoBlock: false,
    );

    expect(state('user:eve').status, ReportFlowStatus.failed);
    expect(state('user:eve').errorCode, 'already-exists');
  });
}
