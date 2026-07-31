import 'package:flutter/material.dart';
import 'package:tablecrew/core/routing/app_router.dart';
import 'package:tablecrew/core/theme/app_theme.dart';

/// Root application widget.
///
/// Milestone F3: theming comes from `TCAppTheme`
/// (`docs/DESIGN_SYSTEM.md`-derived, Recommendation R3), and routing comes
/// from `appRouter` (`core/routing/app_router.dart`) — both Milestone F3
/// deliverables per `docs/IMPLEMENTATION_PLAN.md`. `MaterialApp.router`'s
/// `themeMode` defaults to `ThemeMode.system` already, which is exactly
/// `docs/DESIGN_SYSTEM.md` §1.4's "Dark mode follows the OS-level setting
/// by default" — left unset deliberately (an explicit
/// `themeMode: ThemeMode.system` here would be a redundant-argument lint,
/// not a different behavior). A manual override is still promised by §1.4
/// ("always available in Settings") — that's a later feature milestone's
/// job (F8, Profile/Me and Settings), not this one's.
class TableCrewApp extends StatelessWidget {
  /// Creates the root application widget.
  const TableCrewApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp.router(
      title: 'TableCrew',
      theme: TCAppTheme.light(),
      darkTheme: TCAppTheme.dark(),
      routerConfig: appRouter,
    );
  }
}
