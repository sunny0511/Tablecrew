import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'app.dart';

/// Entry point. Wraps the app in a [ProviderScope] so Riverpod providers
/// are available app-wide, per docs/ENGINEERING_GUIDELINES.md's state
/// management conventions.
///
/// Scaffold note (Milestone F0): no Firebase initialization, theming, or
/// routing happens here yet — see Milestone F1 (Firebase Auth) and
/// Milestone F3 (Client foundation: theme + GoRouter) in
/// docs/IMPLEMENTATION_PLAN.md.
void main() {
  runApp(const ProviderScope(child: TableCrewApp()));
}
