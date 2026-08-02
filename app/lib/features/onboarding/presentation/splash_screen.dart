import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:tablecrew/core/auth_state.dart';
import 'package:tablecrew/core/routing/app_router.dart';
import 'package:tablecrew/core/theme/color_tokens.dart';
import 'package:tablecrew/core/theme/spacing_tokens.dart';
import 'package:tablecrew/core/theme/type_tokens.dart';
import 'package:tablecrew/data/user_profile_repository.dart';
import 'package:tablecrew/widgets/skeleton_pulse.dart';

const _skeletonDelay = Duration(milliseconds: 800);
const _routingTimeout = Duration(seconds: 5);
const _fadeInDuration = Duration(milliseconds: 400);

/// Screen 1 (Splash / Launch Screen), `docs/SCREEN_SPECIFICATIONS.md`.
///
/// **Scope note.** The spec's Purpose/Exit Points describe five possible
/// destinations, two of which this milestone (F5, "Screens 1, 4-7") does
/// not build the machinery for and therefore never routes to:
/// - Deep-link resolution (Table/Crew invite links) — no deep-link
///   package is integrated anywhere in this codebase yet; that's a
///   distinct, not-yet-scheduled piece of work, not an F5 deliverable.
/// - Identity Verification (Screen 8) — explicitly out of Foundation
///   scope per `core/routing/app_router.dart`'s own "Deliberately
///   excluded" list; no route for it exists to send a user to.
///
/// What this screen does route on, per the spec's remaining routing rule
/// ("unauthenticated -> Phone Number Entry; authenticated but
/// mid-onboarding -> resume at the correct step; authenticated and
/// complete -> Home"): no signed-in user -> [AppRoutes.phoneEntry];
/// signed in with a `users/{uid}` doc -> [AppRoutes.home]; signed in
/// without one -> [AppRoutes.dob]. The "resume at the correct step" half
/// of that rule is Date of Birth specifically, not whichever of Screens
/// 4-7 the user was last on — see this milestone's kickoff notes
/// (TASKS.md) for why: `completeAccountSetup` is one combined write
/// fired only at the end of Screen 6, so there is no server-observable
/// "mid-onboarding at step X" state to resume into; only "has a
/// completed profile" vs. not.
///
/// The spec also asks for offline-capable routing for returning users
/// ("a valid cached auth session routes straight to Home using cached
/// data"). This is inherited from the platform rather than hand-rolled:
/// `FirebaseAuth.authStateChanges` replays the SDK's locally persisted
/// session with no network call, and
/// `UserProfileRepository.hasCompletedProfile`'s plain `Firestore.get()`
/// already falls back to Firestore's local persistence cache when
/// offline (the SDK default `Source.serverAndCache` behavior) — nothing
/// here needs to special-case connectivity itself.
///
/// Added Milestone F5.
class SplashScreen extends ConsumerStatefulWidget {
  /// Creates the Splash / Launch screen.
  const SplashScreen({super.key});

  @override
  ConsumerState<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends ConsumerState<SplashScreen> {
  bool _showSkeleton = false;
  Timer? _skeletonTimer;
  ProviderSubscription<AsyncValue<User?>>? _authSubscription;

  @override
  void initState() {
    super.initState();
    // Loading States: "If auth/session resolution finishes in under
    // 800ms, no loading indicator appears at all."
    _skeletonTimer = Timer(_skeletonDelay, () {
      if (mounted) setState(() => _showSkeleton = true);
    });
    // `ref.read(authStateChangesProvider.future)` alone doesn't count as a
    // keep-alive listener for this autoDispose provider — nothing else in
    // the widget tree watches it, so without a real subscription Riverpod
    // can (and, confirmed via a real `flutter test` run, reliably does)
    // dispose it mid-flight before the read resolves, throwing "provider
    // was disposed during loading state, yet no value could be emitted."
    // `listenManual` is Riverpod's documented mechanism for holding a
    // provider alive from imperative code like `initState` rather than
    // `build`; closed in `dispose` once this screen no longer needs it.
    _authSubscription = ref.listenManual(authStateChangesProvider, (_, __) {});
    unawaited(_route());
  }

  @override
  void dispose() {
    _skeletonTimer?.cancel();
    _authSubscription?.close();
    super.dispose();
  }

  Future<void> _route() async {
    // Loading States: "A hard 5-second timeout routes to Phone Number
    // Entry while a cached-session check keeps retrying in the
    // background." The background retry half isn't meaningful here —
    // once this widget has navigated away there's nothing left for a
    // retry to hand its result to — so this only implements the timeout
    // half: fail open to Phone Number Entry rather than hang forever.
    final destination = await _resolveDestination().timeout(
      _routingTimeout,
      onTimeout: () => AppRoutes.phoneEntry,
    );
    if (!mounted) return;
    context.go(destination);
  }

  Future<String> _resolveDestination() async {
    // `core/auth_state.dart`'s own scope note names this exact provider as
    // Screen 1's job to build on top of — using it here rather than a
    // second, onboarding-local auth-state read.
    final user = await ref.read(authStateChangesProvider.future);
    if (user == null) return AppRoutes.phoneEntry;

    final profileRepository = ref.read(userProfileRepositoryProvider);
    final hasProfile = await profileRepository.hasCompletedProfile(user.uid);
    return hasProfile ? AppRoutes.home : AppRoutes.dob;
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final reducedMotion = MediaQuery.disableAnimationsOf(context);

    return Scaffold(
      // UI Components: "Full-bleed Card Cream background" — deliberately
      // not the app's default `scaffoldBackgroundColor` (Linen Cream,
      // `TCColors.neutral0`), a distinct token per `docs/DESIGN_SYSTEM.md`
      // §1.2.
      backgroundColor: isDark ? TCColors.darkSurface : TCColors.neutral50,
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Accessibility Notes: "Wordmark is exposed to screen readers
            // as a single 'TableCrew, loading' label rather than a
            // decorative image."
            Semantics(
              label: 'TableCrew, loading',
              child: ExcludeSemantics(
                child: AnimatedOpacity(
                  opacity: 1,
                  duration: reducedMotion ? Duration.zero : _fadeInDuration,
                  curve: Curves.easeInOut,
                  child: Text(
                    'TableCrew',
                    style: TCTextStyles.displayLg.copyWith(
                      color: isDark
                          ? TCColors.darkOnSurface
                          : TCColors.ink900,
                    ),
                  ),
                ),
              ),
            ),
            if (_showSkeleton) ...[
              const SizedBox(height: TCSpacing.xl),
              const SkeletonPulse(width: 120, height: 4),
            ],
          ],
        ),
      ),
    );
  }
}
