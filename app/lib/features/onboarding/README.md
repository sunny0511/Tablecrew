# features/onboarding/

Screens 1-7 (Splash, Phone Number Entry, OTP Verification, Date of Birth Entry, Profile Setup, Interest Selection, Notification Permission Priming) per `docs/SCREEN_SPECIFICATIONS.md`, backed by `functions/src/users/`'s `validateAge`/`completeAccountSetup` callables (`docs/API_SPEC.md` §3.9).

Per `docs/ENGINEERING_GUIDELINES.md`'s feature-folder convention (see `features/README.md`), this will hold:

- `presentation/` — the 7 screen widgets and their shared onboarding-flow chrome (progress indicator, back/next affordances).
- `application/` — Riverpod providers/notifiers driving each step (form state, the `validateAge`/`completeAccountSetup` call sequence, error handling).
- References into `app/lib/data/` for the repository wrapping those two callables, once that repository exists.

**Status (Milestone F5):** all 7 screens are real, `app_router.dart`-wired implementations, not stubs — `presentation/splash_screen.dart`, `phone_entry_screen.dart`, `otp_screen.dart`, `dob_entry_screen.dart`, `age_ineligible_screen.dart` (Screen 4's hard-stop destination), `profile_setup_screen.dart`, `interests_screen.dart`, `notification_priming_screen.dart`, plus their `application/`/`data/` supporting providers (`OnboardingPhoneFlowController`, `OnboardingProfileDraftController`, `AccountSetupController`, `PhoneAuthRepository`, `PhoneSendRateTracker`). See `TASKS.md`'s F5.95 entries for what's disclosed-but-deferred within each screen (e.g. the interest-tag taxonomy enforcement gap, the skipped non-blocking photo/profanity nudges) and what verification has actually run.
