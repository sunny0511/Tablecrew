import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tablecrew/app.dart';

void main() {
  // Milestone F3 correction: this test asserted against the Milestone F0
  // placeholder text ("TableCrew — Foundation scaffold (Milestone F0)"),
  // which app.dart stopped rendering the moment Milestone F3's GoRouter
  // route table (core/routing/app_router.dart) replaced its bare `home:`
  // Scaffold with `MaterialApp.router`. Nobody caught the break at the
  // time because this was the first real `flutter test` run since - the
  // Flutter toolchain itself only became available this milestone (see
  // app/pubspec.yaml's dependency-bump comments). Updated to assert
  // against the initial route's real stub screen instead
  // (AppRoutes.splash -> "Splash / Launch Screen", per
  // core/routing/app_router.dart's `_StubScreen`, which renders the title
  // in both its AppBar and body - hence `findsWidgets`, not
  // `findsOneWidget`).
  testWidgets('TableCrewApp builds and shows the initial route',
      (tester) async {
    await tester.pumpWidget(
      const ProviderScope(child: TableCrewApp()),
    );
    await tester.pumpAndSettle();

    expect(find.text('Splash / Launch Screen'), findsWidgets);
  });

  testWidgets('TableCrewApp uses Material 3', (tester) async {
    await tester.pumpWidget(
      const ProviderScope(child: TableCrewApp()),
    );

    final materialApp = tester.widget<MaterialApp>(find.byType(MaterialApp));
    expect(materialApp.theme?.useMaterial3, isTrue);
  });
}
