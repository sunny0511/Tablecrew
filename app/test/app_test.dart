import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tablecrew/app.dart';
import 'package:tablecrew/core/auth_state.dart';

void main() {
  // Milestone F5 correction: `authStateChangesProvider` wraps
  // `FirebaseAuth.instance.authStateChanges()`, which throws
  // (`[core/no-app]`) the moment it's read in a plain widget test — no
  // environment building this codebase has ever run
  // `Firebase.initializeApp` inside `flutter test`. Overridden below with a
  // stream that resolves once, to a definite "signed out" value, rather
  // than left unoverridden (which crashes) or overridden with a stream
  // that never emits (Riverpod throws "disposed during loading state, yet
  // no value could be emitted" for an autoDispose provider torn down
  // mid-loading, regardless of whether it would have eventually resolved —
  // confirmed against real `flutter test` output, not assumed). Built as a
  // local variable inside `main`, not a top-level property or a function
  // with a spelled-out return type: Riverpod's override type isn't
  // resolvable by name under this file's current imports (a real,
  // confirmed `flutter analyze` compile error from an earlier attempt at
  // spelling it as `Override`), and a `final` local variable lets Dart
  // infer the type instead of requiring it be named at all.
  final overrides = [
    authStateChangesProvider.overrideWith((ref) => Stream<User?>.value(null)),
  ];

  // Milestone F3 correction: this test originally asserted against the
  // Milestone F0 placeholder text, then (Milestone F3) against
  // `core/routing/app_router.dart`'s Splash stub screen's title. Milestone
  // F5 replaced that stub with a real `SplashScreen`, which — for a
  // signed-out user, the case exercised here via `overrides` above —
  // resolves its routing and navigates to Phone Number Entry well within
  // `pumpAndSettle`'s window. Asserting against Phone Number Entry's own
  // headline both confirms the initial route rendered *and* that Splash's
  // routing logic actually ran end to end, a strictly stronger check than
  // the old stub-title assertion. Phone Number Entry itself was chosen
  // deliberately: unlike the other real onboarding screens, it makes no
  // `connectivity_plus` platform-channel call from `initState`/`build` (see
  // `phone_entry_screen.dart`), so it renders cleanly with no further
  // plugin mocking needed — the other real screens' plugin calls
  // (`connectivity_plus`, `image_picker`, `permission_handler`) need that
  // mocking infrastructure, which is Milestone F5's dedicated widget-test
  // task (#96), not this general app-level smoke test's job.
  testWidgets('TableCrewApp builds and shows the initial route',
      (tester) async {
    await tester.pumpWidget(
      ProviderScope(overrides: overrides, child: const TableCrewApp()),
    );
    await tester.pumpAndSettle();

    expect(find.text("What's your number?"), findsOneWidget);
  });

  testWidgets('TableCrewApp uses Material 3', (tester) async {
    await tester.pumpWidget(
      ProviderScope(overrides: overrides, child: const TableCrewApp()),
    );
    await tester.pumpAndSettle();

    final materialApp = tester.widget<MaterialApp>(find.byType(MaterialApp));
    expect(materialApp.theme?.useMaterial3, isTrue);
  });
}
