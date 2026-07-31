# features/trust/

Screens 27-29 (Report Flow, Block Confirmation, Trusted Contact Setup) per `docs/SCREEN_SPECIFICATIONS.md` — live from day one per `docs/ROADMAP.md`'s explicit rationale that this infrastructure must be pressure-tested on lower-stakes Crew disputes before Discover raises the stakes (see also Recommendation R6). Backed by `docs/API_SPEC.md` §3.4's `reportUser`/`reportTable`/`blockUser`/`triggerDuressSignal`/`createLocationShare`/`revokeLocationShare` (Milestone F4+ Cloud Functions deliverables, not yet built).

Per `docs/ENGINEERING_GUIDELINES.md`'s feature-folder convention (see `features/README.md`), this will hold:

- `presentation/` — the 3 screen widgets. Per `docs/SECURITY.md` and the Live Table Screen's own requirements, anything duress-related that renders here must never be the slow path — see `docs/WIREFRAMES.md`'s note that the duress control "must render before data loads and can never move behind a menu."
- `application/` — Riverpod providers/notifiers for report submission, block state, and per-Table location-share creation/revocation.
- References into `app/lib/data/` for the trust/safety repository, once it and the relevant callables both exist.

**Milestone F3 note:** this directory is a named, empty shell — routes for all 3 screens already exist in `core/routing/app_router.dart`, but no real screen or provider code lands here until whichever Milestone F6/F7 vertical slice needs it, per `docs/IMPLEMENTATION_PLAN.md` and Recommendation R6's "sequence Trust & Safety alongside the core loop, not after it."
