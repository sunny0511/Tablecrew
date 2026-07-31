import 'package:firebase_auth/firebase_auth.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'auth_state.g.dart';

/// Cross-cutting auth-state stream, per docs/ENGINEERING_GUIDELINES.md's
/// "State Management: Riverpod" section: "Providers are scoped to the
/// feature that owns them; only genuinely cross-cutting state (current
/// user, auth state, feature flags from Remote Config) lives in core/."
///
/// Milestone F2 scope note: this provider exposes raw Firebase Auth
/// sign-in state only — is there a signed-in user, and what is their uid.
/// It deliberately does NOT yet determine whether that user has completed
/// onboarding (i.e., whether a `users/{uid}` Firestore profile document
/// exists, per `completeAccountSetup`, docs/API_SPEC.md §3.9). That
/// "profile complete vs. mid-onboarding" check needs the Firestore
/// repository layer (`app/lib/data/`), which per that directory's own
/// scaffold note lands starting with the feature milestones that need it
/// — wiring a one-off Firestore read in here instead would bypass the
/// repository pattern this codebase otherwise commits to. Screen 1
/// (Splash)'s full unauthenticated → mid-onboarding → fully-onboarded
/// routing logic (docs/SCREEN_SPECIFICATIONS.md Screen 1) is therefore
/// Milestone F5's job, built on top of this provider plus the data layer,
/// not this milestone's.
///
/// Unverified in this environment: no Flutter SDK has been available in
/// this build environment (same disclosed limitation as every other Dart
/// file in this repository since Milestone F0). In particular, the
/// generated `auth_state.g.dart` companion file this `part` directive
/// requires does not exist yet — it must be produced by running
/// `flutter pub run build_runner build` (or `build_runner watch`) once a
/// real Flutter toolchain is available, the same one-time step every
/// `@riverpod`-annotated file in this codebase will need.
@riverpod
Stream<User?> authStateChanges(AuthStateChangesRef ref) {
  return FirebaseAuth.instance.authStateChanges();
}

/// Convenience derived provider: is there currently a signed-in user at all
/// (Tier 1 phone verification complete), independent of onboarding
/// completeness — see the scope note on [authStateChanges] above.
@riverpod
bool isSignedIn(IsSignedInRef ref) {
  return ref.watch(authStateChangesProvider).valueOrNull != null;
}

/// Convenience derived provider: the current signed-in user's uid, or null
/// if signed out. Reading this instead of the full [User] object keeps most
/// call sites decoupled from the firebase_auth package directly.
@riverpod
String? currentUid(CurrentUidRef ref) {
  return ref.watch(authStateChangesProvider).valueOrNull?.uid;
}
