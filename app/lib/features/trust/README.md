# features/trust/

Screens 27-28 (Report Flow, Block Confirmation) per `docs/SCREEN_SPECIFICATIONS.md` — real as of Milestone F6's Trust & Safety client chunk, backed by `functions/src/trust/index.ts`'s `reportUser`/`reportTable`/`blockUser` callables (the same milestone's backend chunk). Screen 29 (Trusted Contact Setup) and its backing `createLocationShare`/`revokeLocationShare` endpoints remain deliberately deferred — see `functions/src/trust/index.ts`'s header and `TASKS.md`'s Milestone F6 fourth-chunk entry for the two real, disclosed reasons (a request-contract gap in `revokeLocationShare` and an undecided SMS vendor for `createLocationShare`'s `external_sms` path).

Per `docs/ENGINEERING_GUIDELINES.md`'s feature-folder convention (see `features/README.md`):

- `presentation/` — `report_flow_screen.dart`, `block_confirmation_screen.dart`. Both are routed `GoRoute` pages (`core/routing/app_router.dart`'s `report`/`block` routes), reached via plain query parameters rather than a path segment, since the target can be a user uid or a Table id and there's no one dynamic resource this pair always nests under.
- `application/` — `report_flow_controller.dart`, `block_confirmation_controller.dart`. Both plain `@riverpod` (autoDispose), not `keepAlive`: neither screen's Offline Behavior queues-and-retries (both are "blocked entirely offline" per their own specs), so there's no background retry to keep alive across navigation.
- `app/lib/data/trust_repository.dart` — the repository these controllers call, over the Cloud Functions callables above.

Reachable today from Table Detail's attendee-row overflow menu (`features/tables/presentation/table_detail_screen.dart`'s `_AttendeeRow`), hidden on the current user's own row. Other entry points `docs/SCREEN_SPECIFICATIONS.md` names (Discover Table Preview, Crew Detail's roster, Crew Chat, the Live Table Screen's roster) don't have a built screen to reach it from yet — Discover is Milestone F7, Crew Detail/Chat and the Live Table Screen are F8 — and should wire the same `report`/`block` routes once they exist, rather than duplicating the flow.

**Per `docs/ENGINEERING_GUIDELINES.md`'s Pull Request Review Process, any PR touching this directory or the Discover/reporting/blocking path requires two approvals, at least one from an engineer who has previously worked on this surface.**
