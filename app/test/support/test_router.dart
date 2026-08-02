import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

/// A destination stand-in for a route this test doesn't otherwise care
/// about — renders its own [name] as plain text so a widget test can
/// assert arrival via `find.text('route:$name')` without pulling in that
/// destination screen's real widget tree (and its own plugin/provider
/// requirements, which this test's `ProviderScope` overrides don't set up).
///
/// If the destination was reached with a non-empty query string, it's
/// appended after a `?` (e.g. `route:report?targetType=user&targetId=bob`)
/// so a test can assert exactly which query parameters a screen navigated
/// with — a destination reached with no query string renders unchanged
/// (`route:$name`, no trailing `?`), so this is backward compatible with
/// every existing `find.text('route:$name')` assertion.
class RouteMarker extends StatelessWidget {
  /// Creates a marker screen for the named route [name], with the
  /// optional [query] string it was reached with.
  const RouteMarker(this.name, {this.query = '', super.key});

  /// The GoRouter route name this marker stands in for.
  final String name;

  /// The reaching route's query string (`GoRouterState.uri.query`), or
  /// empty if none.
  final String query;

  @override
  Widget build(BuildContext context) {
    final label = query.isEmpty ? 'route:$name' : 'route:$name?$query';
    return Scaffold(body: Center(child: Text(label)));
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
          builder: (context, state) =>
              RouteMarker(entry.key, query: state.uri.query),
        ),
    ],
  );
}
