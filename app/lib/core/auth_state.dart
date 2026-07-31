import 'package:firebase_auth/firebase_auth.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'auth_state.g.dart';

// Milestone F3 correction: written Milestone F2 against Riverpod 2.x
// code-gen conventions, where each `@riverpod`-annotated function got its
// own generated per-provider `Ref` subclass (e.g. `AuthStateChangesRef`).
// The founder's first real `flutter analyze` (Riverpod 3.3.2, Milestone F3
// — see app/pubspec.yaml's dependency comments for why the version jumped)
// failed with "Undefined class 'AuthStateChangesRef'" etc.: Riverpod 3.x
// dropped the per-provider named Ref subclasses in favor of one shared
// generic `Ref` type for every `@riverpod` function, regardless of which
// provider it annotates. Updated the three signatures below accordingly.
//
// A second real `flutter analyze` pass (after regenerating auth_state.g.dart
// via `dart run build_runner build`) found a second Riverpod 3.x breaking
// change: `AsyncValue.valueOrNull` was removed — `.value` now has the same
// "returns null on error" behavior `.valueOrNull` used to provide, per
// Riverpod's own 3.0 migration guide. Both call sites below updated
// `.valueOrNull` -> `.value` accordingly.

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
/// Milestone F3: a real Flutter toolchain (3.44.8) is now available and
/// `flutter analyze` has run against this file for real — see the
/// Riverpod 3.x correction note above. The generated `auth_state.g.dart`
/// companion file this `part` directive requires still needs a
/// `dart run build_runner build` pass to exist; see this milestone's
/// verification notes in TASKS.md for whether that's been run yet.
@riverpod
Stream<User?> authStateChanges(Ref ref) {
  return FirebaseAuth.instance.authStateChanges();
}

/// Convenience derived provider: is there currently a signed-in user at all
/// (Tier 1 phone verification complete), independent of onboarding
/// completeness — see the scope note on [authStateChanges] above.
@riverpod
bool isSignedIn(Ref ref) {
  return ref.watch(authStateChangesProvider).value != null;
}

/// Convenience derived provider: the current signed-in user's uid, or null
/// if signed out. Reading this instead of the full [User] object keeps most
/// call sites decoupled from the firebase_auth package directly.
@riverpod
String? currentUid(Ref ref) {
  return ref.watch(authStateChangesProvider).value?.uid;
}
