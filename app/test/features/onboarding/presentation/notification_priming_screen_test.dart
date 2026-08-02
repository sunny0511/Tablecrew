import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:permission_handler_platform_interface/permission_handler_platform_interface.dart';
import 'package:tablecrew/features/onboarding/presentation/notification_priming_screen.dart';

import '../../../fakes/fake_permission_handler_platform.dart';
import '../../../support/test_router.dart';

/// Widget tests for Screen 7 (Notification Permission Priming), task #96e.
///
/// No `ProviderScope`: this is the one onboarding screen with no Riverpod
/// dependency at all (a plain [StatelessWidget] whose only external call
/// is `permission_handler`'s OS dialog), so its tests only need the
/// platform-interface fake.
void main() {
  late FakePermissionHandlerPlatform permissionHandler;

  setUp(() {
    permissionHandler = FakePermissionHandlerPlatform();
    PermissionHandlerPlatform.instance = permissionHandler;
  });

  Future<void> pumpScreen(WidgetTester tester) async {
    final router = buildTestRouter(
      initialPath: '/notification-priming',
      initialName: 'notification-priming',
      initialScreen: const NotificationPrimingScreen(),
      destinations: const {'home': '/home'},
    );
    await tester.pumpWidget(MaterialApp.router(routerConfig: router));
    await tester.pumpAndSettle();
  }

  testWidgets('renders the priming copy with both choices', (tester) async {
    await pumpScreen(tester);

    expect(find.text("Don't miss your Table"), findsOneWidget);
    expect(find.text('Turn on notifications'), findsOneWidget);
    expect(find.text('Not now'), findsOneWidget);
  });

  testWidgets(
      'Turn on notifications requests the OS permission, then routes home '
      'regardless of grant', (tester) async {
    permissionHandler.nextStatus = PermissionStatus.denied;
    await pumpScreen(tester);

    await tester.tap(find.text('Turn on notifications'));
    await tester.pumpAndSettle();

    expect(permissionHandler.calls.single, [Permission.notification]);
    expect(
      find.text('route:home'),
      findsOneWidget,
      reason: 'Exit Points: unconditionally Home even when denied',
    );
  });

  testWidgets('Not now skips the OS dialog entirely and routes home', (
    tester,
  ) async {
    await pumpScreen(tester);

    await tester.tap(find.text('Not now'));
    await tester.pumpAndSettle();

    expect(permissionHandler.calls, isEmpty);
    expect(find.text('route:home'), findsOneWidget);
  });
}
