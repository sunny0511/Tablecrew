# core/

Cross-cutting concerns: theming, environment config, error handling, the analytics wrapper, and any genuinely cross-feature Riverpod state (current user, auth state, feature flags from Remote Config) — per `docs/ENGINEERING_GUIDELINES.md`'s "State Management: Riverpod" section.

**Milestone F2:** `auth_state.dart` lands here — a thin `@riverpod` provider wrapping `FirebaseAuth.instance.authStateChanges()`, plus `isSignedIn`/`currentUid` convenience derived providers. Scoped deliberately narrow: raw Firebase Auth sign-in state only, not "has this user finished onboarding" (that needs the Firestore repository layer in `app/lib/data/`, still empty — see that directory's own README). Unverified like every Dart file in this repo so far: no Flutter toolchain has been available to run `flutter pub get` or `build_runner` (the generated `auth_state.g.dart` companion file doesn't exist yet).

**Scaffold note (Milestone F0), remaining open:** the theme/tokens still land in Milestone F3 ("Client foundation").
