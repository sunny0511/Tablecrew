import 'package:flutter/material.dart';

/// Root application widget.
///
/// Scaffold note (Milestone F0): this is a minimal placeholder — a bare
/// [MaterialApp] with Material 3 enabled and no custom theme, routing, or
/// providers wired in yet. Per docs/IMPLEMENTATION_PLAN.md Milestone F3
/// ("Client foundation"), this will be replaced with the full
/// docs/DESIGN_SYSTEM.md-derived [ThemeData] and a [GoRouter] route table
/// covering the Foundation-scope screens in docs/SCREEN_SPECIFICATIONS.md.
/// Building that out now, ahead of F1/F2's auth and data-layer work, would
/// mean theming and routing screens that don't have real data behind them
/// yet — see Recommendation R7 in docs/IMPLEMENTATION_PLAN.md on not
/// building ahead of a milestone's actual dependencies.
class TableCrewApp extends StatelessWidget {
  /// Creates the root application widget.
  const TableCrewApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'TableCrew',
      theme: ThemeData(useMaterial3: true),
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
