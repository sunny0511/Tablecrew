# features/tables/

Screens 9-17 (Home/My Tables, Create Table, Venue Picker, Invite & Share Sheet, Table Detail, Live Table Screen, Table Chat, Waitlist Screen, Post-Table Rating) per `docs/SCREEN_SPECIFICATIONS.md` — the single most important vertical in `docs/PRD.md`, backed by `docs/API_SPEC.md` §3.1's `createTable`/`updateTable`/`requestSeat`/`confirmAttendee`/`cancelTable`/`cancelRsvp`/`endTableEarly` (Milestone F4's Cloud Functions deliverable, not yet built).

Per `docs/ENGINEERING_GUIDELINES.md`'s feature-folder convention (see `features/README.md`), this will hold:

- `presentation/` — the 9 screen widgets, including the Live Table Screen's duress affordance (`docs/SECURITY.md`) and Table Chat's offline message queue.
- `application/` — Riverpod providers/notifiers for Table creation/RSVP/waitlist state, built on top of the `OfflineMutationQueue` (`core/offline/`, Recommendation R1) for every idempotent mutation.
- References into `app/lib/data/` for the Table/RSVP repository, once that repository and Milestone F4's callables both exist.

**Milestone F3 note:** this directory is a named, empty shell — routes for all 9 screens (nested under `/tables/:tableId` where applicable) already exist in `core/routing/app_router.dart`, but no real screen or provider code lands here until Milestone F6 ("Feature: Create Table, RSVP, Invites") and F7 (Live Table/Chat/Waitlist/Rating), per `docs/IMPLEMENTATION_PLAN.md`. It has nothing to call yet — Milestone F4's Table/Crew Cloud Functions land first.
