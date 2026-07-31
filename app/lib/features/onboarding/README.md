# features/onboarding/

Screens 1-7 (Splash, Phone Number Entry, OTP Verification, Date of Birth Entry, Profile Setup, Interest Selection, Notification Permission Priming) per `docs/SCREEN_SPECIFICATIONS.md`, backed by `functions/src/users/`'s `validateAge`/`completeAccountSetup` callables (`docs/API_SPEC.md` §3.9).

Per `docs/ENGINEERING_GUIDELINES.md`'s feature-folder convention (see `features/README.md`), this will hold:

- `presentation/` — the 7 screen widgets and their shared onboarding-flow chrome (progress indicator, back/next affordances).
- `application/` — Riverpod providers/notifiers driving each step (form state, the `validateAge`/`completeAccountSetup` call sequence, error handling).
- References into `app/lib/data/` for the repository wrapping those two callables, once that repository exists.

**Milestone F3 note:** this directory is a named, empty shell — routes for all 7 screens already exist in `core/routing/app_router.dart` (pointing at stub placeholders), but no real screen or provider code lands here until Milestone F5 ("Feature: Onboarding"), per `docs/IMPLEMENTATION_PLAN.md`. Building real onboarding logic now, ahead of `app/lib/data/`'s repository layer existing, would mean hand-rolling a one-off Functions client wrapper here that Milestone F5 would then have to reconcile with whatever repository pattern gets established — see Recommendation R7 on not building ahead of a milestone's actual dependencies.
