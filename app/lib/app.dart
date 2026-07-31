import 'package:flutter/material.dart';
import 'package:tablecrew/core/theme/app_theme.dart';

/// Root application widget.
///
/// Milestone F3 update: theming now comes from `TCAppTheme`
/// (`docs/DESIGN_SYSTEM.md`-derived, Recommendation R3) instead of a bare
/// Material default. `MaterialApp`'s `themeMode` defaults to
/// `ThemeMode.system` already, which is exactly §1.4's "Dark mode follows
/// the OS-level setting by default" — left unset deliberately (an explicit
/// `themeMode: ThemeMode.system` here would be a redundant-argument lint,
/// not a different behavior). A manual override is still promised by §1.4
/// ("always available in Settings") — that's a later feature milestone's
/// job (F8, Profile/Me and Settings), not this one's.
///
/// Routing is still a bare placeholder — the real GoRouter route table
/// (this same milestone's other deliverable) replaces `home:` below in a
/// follow-up commit, once the route table exists to wire in.
class TableCrewApp extends StatelessWidget {
  /// Creates the root application widget.
  const TableCrewApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'TableCrew',
      theme: TCAppTheme.light(),
      darkTheme: TCAppTheme.dark(),
      home: const _ScaffoldPlaceholder(),
    );
  }
}

/// Temporary placeholder home screen, proving the app shell builds and
/// runs. Deleted once Milestone F3 lands the real navigation shell.
class _ScaffoldPlaceholder extends StatelessWidget {
  const _ScaffoldPlaceholder();

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      body: Center(
        child: Text('TableCrew — Foundation scaffold (Milestone F0)'),
      ),
    );
  }
}
