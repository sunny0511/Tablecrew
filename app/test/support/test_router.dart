import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

/// A destination stand-in for a route this test doesn't otherwise care
/// about — renders its own [name] as plain text so a widget test can
/// assert arrival via `find.text('route:$name')` without pulling in that
/// destination screen's real widget tree (and its own plugin/provider
/// requirements, which this test's `ProviderScope` overrides don't set up).
class RouteMarker extends StatelessWidget {
  /// Creates a marker screen for the named route [name].
  const RouteMarker(this.name, {super.key});

  /// The GoRouter route name this marker stands in for.
  final String name;

  @override
  Widget build(BuildContext context) {
    return Scaffold(body: Center(child: Text('route:$name')));
  }
}

/// Builds a minimal [GoRouter] for a single onboarding screen's widget
/// test: `initialPath`/`initialName` renders the real [initialScreen]
/// under test; every entry in [destinations] (name -> path) renders a
/// [RouteMarker], so any `context.go(Named)`/`pushNamed`/`pop` the screen
/// performs can be asserted by text alone. Mirrors
/// `core/routing/app_router.dart`'s real route names/paths for the routes
/// it reuses, so a screen's real `context.goNamed('x')` call resolves
/// against the same name here.
GoRouter buildTestRouter({
  required String initialPath,
  required String initialName,
  required Widget initialScreen,
  Map<String, String> destinations = const {},
}) {
  return GoRouter(
    initialLocation: initialPath,
    routes: [
      GoRoute(
        path: initialPath,
        name: initialName,
        builder: (context, state) => initialScreen,
      ),
      for (final entry in destinations.entries)
        GoRoute(
          path: entry.value,
          name: entry.key,
          builder: (context, state) => RouteMarker(entry.key),
        ),
    ],
  );
}
