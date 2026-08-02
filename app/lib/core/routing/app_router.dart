import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:tablecrew/features/onboarding/presentation/age_ineligible_screen.dart';
import 'package:tablecrew/features/onboarding/presentation/dob_entry_screen.dart';
import 'package:tablecrew/features/onboarding/presentation/interests_screen.dart';
import 'package:tablecrew/features/onboarding/presentation/notification_priming_screen.dart';
import 'package:tablecrew/features/onboarding/presentation/otp_screen.dart';
import 'package:tablecrew/features/onboarding/presentation/phone_entry_screen.dart';
import 'package:tablecrew/features/onboarding/presentation/profile_setup_screen.dart';
import 'package:tablecrew/features/onboarding/presentation/splash_screen.dart';
import 'package:tablecrew/features/tables/presentation/home_screen.dart';

/// TableCrew's GoRouter route table — Milestone F3 ("Client foundation")
/// deliverable per `docs/IMPLEMENTATION_PLAN.md`.
///
/// Scope, precisely: this covers every screen `docs/SCREEN_SPECIFICATIONS.md`
/// specifies that also falls inside Foundation/Phase 0's scope, per
/// `docs/IMPLEMENTATION_PLAN.md` section 1's scope list. Every route
/// originally rendered a stub placeholder — Recommendation R7 explicitly
/// warned against building ahead of a milestone's actual dependencies (real
/// data, a real repository layer) existing. This file's job is the *route
/// table shape* — paths, names, param passing — not screen content.
///
/// **Status (Milestone F5, in progress):** most Foundation-scope routes
/// have since been replaced with real screens, feature-by-feature, per
/// `_StubScreen`'s "deleted route-by-route as each real screen replaces
/// it" convention below — see each feature's own README for exactly which
/// of its screens are real vs. still stubbed. Every route not yet replaced
/// still renders `_StubScreen`.
///
/// **Deliberately excluded** (per `docs/IMPLEMENTATION_PLAN.md` section 1's
/// "Explicitly not in Foundation scope" list, and Recommendation R7's
/// "do not scaffold Discover-adjacent code paths during Foundation"):
/// Screen 8 (Tier 2 Identity Verification), Screens 18-21 (Discover Feed/
/// Filters/Table Preview/First-Time Safety Briefing — all Discover-only),
/// Screen 26 (Recurring Table Schedule Setup — "recurring-ritual
/// automation"), Screens 30-31 (Bill Split Setup / Split Request Detail —
/// bill-splitting/payments), Screen 34 (TableCrew+ Subscription — billing).
/// These routes do not exist in this table at all, rather than existing as
/// disabled/hidden stubs — adding even a dormant route for them would be
/// exactly the "wiring the dormant branch now... adds real complexity and
/// test surface" R7 warns against.
///
/// **Navigation shell structure (tab bar, nested shell routes) is NOT
/// decided here.** This is a flat route table, not a `ShellRoute`/bottom-
/// nav structure — that's a real UX decision (which screens share a
/// persistent tab bar, e.g. Home/Crews/Profile) that belongs with whichever
/// milestone actually builds Home's real navigation chrome (F5+), informed
/// by a working Home screen, not guessed at here ahead of it.
final GoRouter appRouter = GoRouter(
  initialLocation: AppRoutes.splash,
  routes: [
    // Milestone F5: real screens, replacing the F3 stubs — per this file's
    // own "deleted route-by-route as each real screen replaces it"
    // convention (see _StubScreen's doc comment below).
    GoRoute(
      path: AppRoutes.splash,
      name: 'splash',
      pageBuilder: (context, state) => _screenPage(const SplashScreen(), state),
    ),
    GoRoute(
      path: AppRoutes.phoneEntry,
      name: 'phone-entry',
      pageBuilder: (context, state) =>
          _screenPage(const PhoneEntryScreen(), state),
    ),
    GoRoute(
      path: AppRoutes.otp,
      name: 'otp',
      pageBuilder: (context, state) => _screenPage(const OtpScreen(), state),
    ),
    GoRoute(
      path: AppRoutes.dob,
      name: 'dob',
      pageBuilder: (context, state) =>
          _screenPage(const DobEntryScreen(), state),
    ),
    GoRoute(
      path: AppRoutes.ageIneligible,
      name: 'age-ineligible',
      pageBuilder: (context, state) =>
          _screenPage(const AgeIneligibleScreen(), state),
    ),
    GoRoute(
      path: AppRoutes.profileSetup,
      name: 'profile-setup',
      pageBuilder: (context, state) =>
          _screenPage(const ProfileSetupScreen(), state),
    ),
    GoRoute(
      path: AppRoutes.interests,
      name: 'interests',
      pageBuilder: (context, state) =>
          _screenPage(const InterestsScreen(), state),
    ),
    GoRoute(
      path: AppRoutes.notificationPriming,
      name: 'notification-priming',
      pageBuilder: (context, state) =>
          _screenPage(const NotificationPrimingScreen(), state),
    ),
    // Milestone F6: real Home screen, replacing the F3 stub — same
    // route-by-route replacement convention as the F5 onboarding screens
    // above.
    GoRoute(
      path: AppRoutes.home,
      name: 'home',
      pageBuilder: (context, state) => _screenPage(const HomeScreen(), state),
    ),
    _stubRoute(
      AppRoutes.createTable,
      name: 'create-table',
      title: 'Create Table',
    ),
    GoRoute(
      path: AppRoutes.tableDetail,
      name: 'table-detail',
      pageBuilder: (context, state) => _stubPage(
        'Table Detail',
        state,
        extraLabel: 'tableId: ${state.pathParameters['tableId']}',
      ),
      routes: [
        _stubRoute(
          'venue-picker',
          name: 'venue-picker',
          title: 'Venue Picker',
        ),
        _stubRoute('invite', name: 'invite', title: 'Invite & Share Sheet'),
        _stubRoute('live', name: 'live-table', title: 'Live Table Screen'),
        _stubRoute('chat', name: 'table-chat', title: 'Table Chat'),
        _stubRoute('waitlist', name: 'waitlist', title: 'Waitlist Screen'),
        _stubRoute(
          'rate',
          name: 'post-table-rating',
          title: 'Post-Table Rating',
        ),
      ],
    ),
    _stubRoute(AppRoutes.crews, name: 'crews', title: 'Crews List'),
    _stubRoute(AppRoutes.createCrew, name: 'create-crew', title: 'Create Crew'),
    GoRoute(
      path: AppRoutes.crewDetail,
      name: 'crew-detail',
      pageBuilder: (context, state) => _stubPage(
        'Crew Detail',
        state,
        extraLabel: 'crewId: ${state.pathParameters['crewId']}',
      ),
      routes: [
        _stubRoute('chat', name: 'crew-chat', title: 'Crew Chat'),
      ],
    ),
    _stubRoute(AppRoutes.report, name: 'report', title: 'Report Flow'),
    _stubRoute(AppRoutes.block, name: 'block', title: 'Block Confirmation'),
    _stubRoute(
      AppRoutes.trustedContact,
      name: 'trusted-contact',
      title: 'Trusted Contact Setup',
    ),
    _stubRoute(AppRoutes.profile, name: 'profile', title: 'Profile / Me'),
    _stubRoute(AppRoutes.settings, name: 'settings', title: 'Settings'),
    _stubRoute(
      AppRoutes.notificationCenter,
      name: 'notification-center',
      title: 'Notification Center',
    ),
    _stubRoute(
      AppRoutes.dataExport,
      name: 'data-export',
      title: 'Data Export / Delete Account',
    ),
  ],
);

/// Route paths, centralized so a call site never hand-types a path string.
/// Named per the screen's role rather than its `docs/SCREEN_SPECIFICATIONS.md`
/// number, since numbers are a documentation convenience, not a stable
/// product identifier.
abstract final class AppRoutes {
  /// Screen 1.
  static const splash = '/splash';

  /// Screen 2.
  static const phoneEntry = '/phone-entry';

  /// Screen 3.
  static const otp = '/otp';

  /// Screen 4.
  static const dob = '/dob';

  /// Screen 4's hard-stop under-18 destination — not itself a numbered
  /// screen in `docs/SCREEN_SPECIFICATIONS.md` (it's described inline as
  /// Screen 4's "hard-stop" exit point), so it gets a name rather than a
  /// spec-number comment.
  static const ageIneligible = '/age-ineligible';

  /// Screen 5.
  static const profileSetup = '/profile-setup';

  /// Screen 6.
  static const interests = '/interests';

  /// Screen 7.
  static const notificationPriming = '/notification-priming';

  /// Screen 9.
  static const home = '/home';

  /// Screen 10.
  static const createTable = '/tables/create';

  /// Screen 13 (Table Detail) and its day-of/social sub-routes — Screen 11
  /// (Venue Picker), 12 (Invite & Share Sheet), 14 (Live Table Screen), 15
  /// (Table Chat), 16 (Waitlist Screen), 17 (Post-Table Rating) — all nest
  /// under this one dynamic segment, matching `docs/DATABASE.md`'s
  /// Table-centric data model.
  static const tableDetail = '/tables/:tableId';

  /// Screen 22.
  static const crews = '/crews';

  /// Screen 23.
  static const createCrew = '/crews/create';

  /// Screen 24 (Crew Detail) and Screen 25 (Crew Chat) nest under this
  /// dynamic segment.
  static const crewDetail = '/crews/:crewId';

  /// Screen 27.
  static const report = '/report';

  /// Screen 28.
  static const block = '/block';

  /// Screen 29.
  static const trustedContact = '/trusted-contact';

  /// Screen 32.
  static const profile = '/profile';

  /// Screen 33.
  static const settings = '/settings';

  /// Screen 35.
  static const notificationCenter = '/notification-center';

  /// Screen 36.
  static const dataExport = '/account/data-export';
}

/// Builds a [GoRoute] whose page is a [_StubScreen], with the
/// "unhurried" fade+slide transition `core/theme/app_theme.dart` documents
/// as GoRouter's responsibility (`docs/DESIGN_SYSTEM.md` §8: 250-350ms,
/// ease-in-out).
GoRoute _stubRoute(
  String path, {
  required String name,
  required String title,
}) {
  return GoRoute(
    path: path,
    name: name,
    pageBuilder: (context, state) => _stubPage(title, state),
  );
}

/// Builds a real screen's page with the same "unhurried" fade+slide
/// transition [_stubPage] uses, so a stub's replacement doesn't change the
/// route's motion — only [_stubPage]'s child-selection logic (a
/// placeholder) differs from this (a real, caller-supplied [child]).
CustomTransitionPage<void> _screenPage(Widget child, GoRouterState state) {
  return CustomTransitionPage<void>(
    key: state.pageKey,
    child: child,
    transitionsBuilder: (context, animation, secondaryAnimation, child) {
      final curved =
          CurvedAnimation(parent: animation, curve: Curves.easeInOut);
      return FadeTransition(
        opacity: curved,
        child: SlideTransition(
          position: Tween<Offset>(
            begin: const Offset(0.05, 0),
            end: Offset.zero,
          ).animate(curved),
          child: child,
        ),
      );
    },
  );
}

CustomTransitionPage<void> _stubPage(
  String screenTitle,
  GoRouterState state, {
  String? extraLabel,
}) {
  // transitionDuration/reverseTransitionDuration are left at
  // CustomTransitionPage's own default (300ms) rather than passed
  // explicitly — it already lands inside docs/DESIGN_SYSTEM.md §8's
  // 250-350ms "standard screen transitions" range, so there's nothing to
  // override; an explicit value here would just be a redundant-argument
  // lint for a number that happens to already match.
  return CustomTransitionPage<void>(
    key: state.pageKey,
    child: _StubScreen(title: screenTitle, subtitle: extraLabel),
    transitionsBuilder: (context, animation, secondaryAnimation, child) {
      final curved =
          CurvedAnimation(parent: animation, curve: Curves.easeInOut);
      return FadeTransition(
        opacity: curved,
        child: SlideTransition(
          position: Tween<Offset>(
            begin: const Offset(0.05, 0),
            end: Offset.zero,
          ).animate(curved),
          child: child,
        ),
      );
    },
  );
}

/// Placeholder screen rendered by every route in this table, since no real
/// screen widget exists yet for any Foundation-scope screen (that's F5+'s
/// job, built feature-by-feature against this same route table). Deleted
/// route-by-route as each real screen replaces it — never all at once.
class _StubScreen extends StatelessWidget {
  const _StubScreen({required this.title, this.subtitle});

  final String title;
  final String? subtitle;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(title)),
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(title, style: Theme.of(context).textTheme.headlineMedium),
            if (subtitle != null) ...[
              const SizedBox(height: 8),
              Text(subtitle!, style: Theme.of(context).textTheme.bodyMedium),
            ],
          ],
        ),
      ),
    );
  }
}
