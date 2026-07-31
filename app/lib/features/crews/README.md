# features/crews/

Screens 22-25 (Crews List, Create Crew, Crew Detail, Crew Chat) per `docs/SCREEN_SPECIFICATIONS.md` — the retention-critical persistent-friend-group layer, backed by `docs/API_SPEC.md` §3.2's `createCrew`/`addMember`/`removeMember`/`leaveCrew`/`updateCrew` (Milestone F4's Cloud Functions deliverable, not yet built).

Per `docs/ENGINEERING_GUIDELINES.md`'s feature-folder convention (see `features/README.md`), this will hold:

- `presentation/` — the 4 screen widgets, including Crew Chat's own offline message queue (independent of a Crew Detail's own freshness, per `docs/SCREEN_SPECIFICATIONS.md` Screen 24's offline-behavior note).
- `application/` — Riverpod providers/notifiers for Crew membership/creation state, built on the `OfflineMutationQueue` (`core/offline/`, Recommendation R1) the same way `features/tables/` will.
- References into `app/lib/data/` for the Crew repository, once it and Milestone F4's callables both exist.

**Milestone F3 note:** this directory is a named, empty shell — routes for all 4 screens (nested under `/crews/:crewId` where applicable) already exist in `core/routing/app_router.dart`, but no real screen or provider code lands here until Milestone F6 ("Feature: Crew management"), per `docs/IMPLEMENTATION_PLAN.md`.

**Explicitly not here:** Screen 26 (Recurring Table Schedule Setup) — "recurring-ritual automation" is out of Foundation/Phase 0 scope entirely (`docs/IMPLEMENTATION_PLAN.md` section 1), so it has no route and no planned home in this directory yet either.
