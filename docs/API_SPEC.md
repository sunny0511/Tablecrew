# API_SPEC.md

**Owner:** Engineering
**Status:** Living document — every new/changed callable ships with a corresponding update here in the same PR
**Related:** `ARCHITECTURE.md`, `DATABASE.md`, `FIREBASE.md`, `SECURITY.md`

## 1. Purpose and Scope

TableCrew's server-side API surface is implemented as **Firebase Cloud Functions (Gen 2)**, predominantly as **HTTPS callable functions** invoked from the Flutter client via the `cloud_functions` SDK, plus a small number of plain HTTPS functions for third-party webhooks (Stripe) that cannot use the callable protocol. This document specifies that surface as a clean API contract — request shape, response shape, error cases, and abuse-prevention notes — so a backend engineer can implement or modify any endpoint without reverse-engineering intent from the client, and a client engineer can integrate against it without reading Function source.

For the architectural rule governing *why* something is a callable vs. a Firestore trigger, see `ARCHITECTURE.md` §5.2. This document covers callables (and the Stripe webhook) only; trigger functions are internal plumbing documented alongside the fields they maintain in `DATABASE.md` §4.

## 2. Authentication and Authorization Model

**Transport and identity:** every callable function receives the caller's Firebase Auth ID token automatically via the `cloud_functions` client SDK (the Flutter app never manually attaches tokens; the SDK handles this using the signed-in `FirebaseAuth` user). Inside the function, `context.auth.uid` is the verified caller identity — Cloud Functions verifies the ID token's signature and expiry before the function body ever runs, so **every callable can assume `context.auth` is either null (unauthenticated) or a verified, non-forgeable uid.** There is no separate API-key or session-token scheme to maintain.

**App Check:** every callable additionally requires a valid App Check token (enforced at the function level, `enforceAppCheck: true`), attesting the request originated from a genuine, unmodified instance of the TableCrew app (via Play Integrity on Android, App Attest on iOS) rather than a scripted client hitting our Functions directly. This is our primary defense against automated abuse of the API surface as a whole, layered under the per-endpoint rate limiting described below. Full configuration: `FIREBASE.md` §App Check.

**Authorization pattern:** authentication (who is calling) is uniform across all callables via `context.auth.uid`; authorization (what they're allowed to do) is endpoint-specific business logic implemented in the function body — e.g., `updateTable` checks `context.auth.uid === table.hostId` by reading the target document, `confirmAttendee` checks the caller is the Table's host, `blockUser` has no target-ownership check beyond "acting on your own block list." We do not implement a generic role/permission middleware layer; each function's authorization check is short, explicit, and colocated with the logic it guards, which we've found easier to audit than a generic policy engine at our current endpoint count.

**Standard error contract:** every callable throws a `functions.https.HttpsError` with one of Firebase's standard error codes (`unauthenticated`, `permission-denied`, `not-found`, `failed-precondition`, `resource-exhausted`, `invalid-argument`, `already-exists`, `internal`) plus a machine-readable `details` payload of the shape `{ code: string, message: string }` where `code` is a TableCrew-specific string (e.g., `TABLE_FULL`, `RSVP_ALREADY_EXISTS`) that the client maps to localized, user-facing copy per `COPY_GUIDELINES.md`. `HttpsError`'s built-in code is what drives HTTP-transport-level behavior (retryability, etc.); our nested `details.code` is what drives UI behavior — this two-layer contract is consistent across every endpoint below and is not repeated per-endpoint except where an endpoint has unusual codes.

**Idempotency keys (mandatory on every capacity- or payment-mutating endpoint):** a mobile client on a flaky connection is a normal, frequent condition, not an edge case — a user on the subway retrying `requestSeat` after a timeout, or a payment sheet retry after a dropped response, must never be able to double-book a seat past capacity or double-charge a card. Every endpoint in this document marked **[idempotent]** below requires an `idempotencyKey: string` (client-generated UUID v4, stable across retries of the *same* logical action, distinct per new action) as a request field. The function's first step is an atomic `create()` against `idempotencyKeys/{idempotencyKey}` (`DATABASE.md` §3.9); a duplicate call with the same key returns the original stored response verbatim instead of re-executing business logic. This is layered *underneath* the transactional capacity/payment logic described per-endpoint below (idempotency prevents a retry from being treated as a new request at all; the transaction prevents two genuinely different concurrent requests from over-committing a shared resource) — the two mechanisms solve different problems and both are required. The client SDK wrapper generates and persists the key locally before the first attempt, so a retry (even across an app restart) reuses it rather than minting a new one, which would defeat the purpose.

## 3. Endpoints by Domain

### 3.1 Tables

#### `createTable` **[idempotent]**

Creates a new Table with the caller as host.

- **Request:**
```
{
  title: string,                    // required, 1-100 chars
  description?: string,             // optional, max 1000 chars
  interestTag?: string,             // optional, must be a known tag from the interest-tag taxonomy
  visibility: "open" | "closed",    // required
  location: { geopoint: {lat, lng}, venueId?: string, address: string },
  startTime: ISO8601 string,        // required, must be > now + 1 hour (min lead time)
  capacity: { min: number, max: number },  // required, 2 <= min <= max <= 8 (hard platform-wide ceiling — corrected
                                     // 2026-08 from an earlier 12; see DATABASE.md §3.2, PRODUCT.md)
  crewId?: string,                  // optional, if created on behalf of a Crew
  idempotencyKey: string            // required, see §2 — a retried createTable (double-tap, or the offline-draft
                                     // auto-send described in SCREEN_SPECIFICATIONS.md's Create Table screen) must
                                     // resolve to the single Table created on the first successful attempt, never a duplicate
}
```
- **Response:** `{ tableId: string, status: "proposed" }`
- **Errors:** `invalid-argument` (bad capacity range, startTime too soon, unknown interestTag), `permission-denied` (`crewId` given but caller is not a member), `failed-precondition` (`TRUST_STANDING_RESTRICTED` — caller's `trustSignals.standingStatus` is `restricted`/`banned`, per `DATABASE.md` §3.1), `failed-precondition` (`DUPLICATE_REQUEST_IN_FLIGHT` — same semantics as `requestSeat` below).
- **Server behavior:** validates the payload with hand-rolled field-validation helpers (`functions/src/tables/validation.ts`), the same pattern `completeAccountSetup` (§3.9) established rather than a schema-validation library — no such dependency exists in this codebase, and one function per field keeps each validation rule colocated with the screen-spec citation that justifies it, the same way `functions/src/users/validation.ts` already does. **Correction (2026-08, Milestone F4):** this line previously said "a shared Zod schema," written before any callable existed to establish a real precedent; Milestone F2's `completeAccountSetup` set the actual pattern first, and this line is corrected to match rather than left describing a dependency the codebase never adopted. Reads `users/{uid}` to snapshot `hostDisplayNameSnapshot`/`hostPhotoUrlSnapshot`/`hostVerificationTierSnapshot` (`DATABASE.md` §4) onto the new Table document, writes the Table with `status: "proposed"` and `capacity.confirmedCount: 0`. The idempotency-key check (§2) runs first: unlike a counter-mutating endpoint, a retried `createTable` without deduplication doesn't just mis-count something — it creates a second, fully duplicate Proposed Table, which is exactly the failure mode `SCREEN_SPECIFICATIONS.md`'s Create Table screen relies on this endpoint preventing when it auto-fires the same locally-generated `idempotencyKey` on reconnect after an offline draft.
- **Abuse prevention:** rate-limited to 10 Table creations per user per rolling 24h (checked via a Firestore-backed counter keyed by uid+day) to prevent spam-Table flooding of Discover; App Check required. **Implementation note (2026-08, Milestone F4):** the counter's own read-check-increment is its own small atomic Firestore transaction, run before `createTable`'s main transaction rather than merged into it — this line previously said "incremented in the same transaction," which overstated the coupling. A shared rate-limit helper (`functions/src/shared/rateLimit.ts`) is reused as-is across every endpoint's abuse-prevention check regardless of what that endpoint's own business-logic transaction looks like; correctness only requires the counter itself to be incremented atomically, which a dedicated transaction on the counter document alone already guarantees, independent of the endpoint's separate business transaction.

#### `updateTable`

- **Request:** `{ tableId: string, patch: Partial<{ title, description, interestTag, location, startTime, capacity, visibility }> }`
- **Response:** `{ success: true, updatedFields: string[] }`
- **Errors:** `permission-denied` (caller is not `hostId`), `failed-precondition` (`CANNOT_EDIT_AFTER_CONFIRMED` — capacity/startTime cannot shrink below `confirmedCount` or move once status is `confirmed` or later; hosts must cancel and recreate instead), `not-found`.
- **Abuse prevention:** standard per-user rate limit (60 calls/hour) shared across all Table-mutation endpoints to blunt scripted hammering; App Check required.

#### `requestSeat` **[idempotent]**

The core capacity-invariant-guarding endpoint (`ARCHITECTURE.md` §5.2, §5.4; `DATABASE.md` §4).

- **Request:** `{ tableId: string, idempotencyKey: string }`
- **Response:** `{ rsvpStatus: "confirmed" | "waitlisted" | "requested" }` — `confirmed` for Open Tables with room, `waitlisted` if full, `requested` for Closed Tables (pending host approval).
- **Errors:** `not-found` (Table doesn't exist or is not visible to caller per rules), `failed-precondition` (`TABLE_NOT_ACCEPTING_RSVPS` — status is `happened`/`rated`/`cancelled`), `already-exists` (`RSVP_ALREADY_EXISTS` — caller already has an RSVP on this Table), `failed-precondition` (`SEAT_REQUEST_CONTENTION` — the underlying transaction exhausted its retry budget under heavy concurrent write load on this specific Table document; distinct from `TABLE_FULL` because this means "unknown, try again shortly," not "definitively full" — see `ARCHITECTURE.md` §6 trigger (3) for why this can happen on a viral Table before a sharded-counter migration would be warranted), `failed-precondition` (`DUPLICATE_REQUEST_IN_FLIGHT` — a second call with the same `idempotencyKey` arrived while the first was still executing).
- **Server behavior:** runs inside a Firestore transaction: reads the Table's `capacity.confirmedCount`/`max`, reads/creates the caller's RSVP subdocument, and — for Open Tables — either sets `confirmed` and increments `confirmedCount` atomically, or sets `waitlisted` and increments `waitlistCount`, all within the same transaction so two concurrent callers racing for the last seat cannot both succeed. The client SDK's default transaction retry (bounded, exponential backoff) absorbs ordinary `ABORTED` contention transparently; `SEAT_REQUEST_CONTENTION` is only surfaced once that budget is exhausted. This is the canonical example, referenced from `ARCHITECTURE.md`, of "why this must be a callable and not a client-side Firestore write."
- **Abuse prevention:** rate-limited to 30 requests/hour per user (a user rapid-firing seat requests across many Tables is a signal worth throttling regardless of intent), layered with the device/App-Check-attestation-scoped secondary limit described in §5 to blunt multi-account evasion of the per-user limit; blocked users (per `blockUser`, §3.4) cannot `requestSeat` on a Table hosted by someone who has blocked them — checked via the target host's block list.

#### `confirmAttendee` **[idempotent]**

Host-only action to move a `requested` (Closed Table) or `waitlisted` RSVP to `confirmed`.

- **Request:** `{ tableId: string, targetUserId: string, idempotencyKey: string }`
- **Response:** `{ success: true, newStatus: "confirmed" }`
- **Errors:** `permission-denied` (caller is not `hostId`), `failed-precondition` (`TABLE_FULL` — confirming would exceed `capacity.max`), `not-found` (no RSVP from `targetUserId` on this Table), `failed-precondition` (`SEAT_REQUEST_CONTENTION`, `DUPLICATE_REQUEST_IN_FLIGHT` — same semantics as `requestSeat`).
- **Server behavior:** transactional, symmetric to `requestSeat`'s invariant-guarding logic.
- **Abuse prevention:** standard per-user rate limit shared with other Table-mutation endpoints (60 calls/hour, same family as `updateTable`/`endTableEarly`). **Added 2026-08, Milestone F4:** this endpoint had no stated rate limit at all when originally specified; closed as part of building the shared rate-limiting mechanism §5 names and every other Table-mutation endpoint already documents, rather than leaving one endpoint in the family silently unlimited.

#### `cancelTable`

- **Request:** `{ tableId: string, reason?: string }`
- **Response:** `{ success: true }`
- **Errors:** `permission-denied` (caller is neither `hostId` nor a Crew admin for a Crew-linked Table), `failed-precondition` (`ALREADY_HAPPENED`).
- **Server behavior:** sets `status: "cancelled"`, triggers a notification fan-out (`FIREBASE.md` §Messaging) to all confirmed/waitlisted/requested RSVP holders, and removes the Table from the Typesense index (`ARCHITECTURE.md` §5.5) via the same trigger path used for any status change. Idempotent by construction without a client-supplied key: a retry against an already-`cancelled` Table is a no-op (`success: true`), not an error, since cancelling twice has no additional effect to double-apply.
- **Abuse prevention:** standard per-user rate limit shared with other Table-mutation endpoints (60 calls/hour, same family as `updateTable`/`endTableEarly`/`confirmAttendee`). **Added 2026-08, Milestone F4**, same reasoning as `confirmAttendee` above.

#### `cancelRsvp` **[idempotent]**

- **Request:** `{ tableId: string, idempotencyKey: string }` (caller cancels their own RSVP)
- **Response:** `{ success: true }`
- **Server behavior:** transactionally decrements `confirmedCount`/`waitlistCount` as applicable and, if a confirmed seat opens up, promotes the earliest waitlisted RSVP (also transactional) — this promotion-on-cancel logic is why waitlist promotion is handled here rather than only in the scheduled sweep (`ARCHITECTURE.md` §5.3), which exists purely as a reconciliation safety net. The idempotency key here specifically guards against a retried cancel double-promoting a waitlisted attendee (decrementing the count twice and promoting two people for one freed seat).
- **Abuse prevention:** standard per-user rate limit shared with other Table-mutation endpoints (60 calls/hour, same family as `updateTable`/`endTableEarly`/`confirmAttendee`/`cancelTable`). **Added 2026-08, Milestone F4**, same reasoning as `confirmAttendee` above.

#### `endTableEarly`

Backs the Live Table Screen's host-only "End Table early" control (`SCREEN_SPECIFICATIONS.md` Screen 14) — previously unaddressed in this document, since the Table lifecycle's `confirmed → happened` transition was described only as system-triggered at scheduled end time or via the scheduled reconciliation sweep (`ARCHITECTURE.md` §5.3), with no callable letting a host close a Table's live window before that. ("Mark Table as started," the sibling control on the same screen, requires no backend call: it's a client-only, non-persisted indicator scoped to the host's own device session, since the Table `status` model (`DATABASE.md` §3.2) has no separate "started" state between `confirmed` and `happened` — introducing one would be a schema change with no product requirement beyond a cosmetic label, so it's deliberately left client-side rather than backed by a new endpoint.)

- **Request:** `{ tableId: string }`
- **Response:** `{ success: true }`
- **Errors:** `permission-denied` (caller is not `hostId`), `failed-precondition` (`TABLE_NOT_LIVE` — status is not `confirmed`, i.e., the Table hasn't reached its live window yet or has already reached `happened`/`cancelled`).
- **Server behavior:** sets `status: "happened"` immediately rather than waiting for the scheduled-sweep transition (`ARCHITECTURE.md` §5.3), which unblocks the same downstream behavior a normal scheduled `happened` transition does — `submitRating` becomes callable by attendees, and Bill Split Setup's post-Table entry point becomes reachable. Idempotent by construction without a client-supplied key: calling this against an already-`happened` Table is a no-op returning `success: true`, the same treatment `cancelTable` (above) gives a repeat call.
- **Abuse prevention:** standard per-user rate limit shared with other Table-mutation endpoints (60 calls/hour, same family as `updateTable`).

### 3.2 Crews

#### `createCrew` **[idempotent]**

- **Request:** `{ name: string, photoUrl?: string, initialMemberIds?: string[], idempotencyKey: string }`
- **Response:** `{ crewId: string }`
- **Errors:** `invalid-argument` (`name` empty or over 40 chars, per `SCREEN_SPECIFICATIONS.md` Create Crew), `failed-precondition` (`DUPLICATE_REQUEST_IN_FLIGHT` — same semantics as `requestSeat`, §3.1).
- **Server behavior:** caller becomes `role: "admin"` in `members`; any `initialMemberIds` are added as `role: "member"` immediately (see `addMember` below — **corrected 2026-08, Milestone F4:** this line previously claimed added members go through "invite acceptance, not unilateral addition," but that contradicted `addMember`'s own server-behavior text, which has always described an immediate, direct membership write with no invite/token data model anywhere in `DATABASE.md` to back a real acceptance flow. Resolved in favor of `addMember`'s mechanically-specific description, the only one backed by an actual implementable design — see `addMember`'s own corrected note below for the disclosed gap this leaves). The idempotency key prevents a retried call (a double-tap on "Create Crew," or the offline-draft-then-reconnect flow `SCREEN_SPECIFICATIONS.md` describes for this screen) from creating a second, duplicate Crew with duplicate membership state — a real risk here since a Crew is a persistent social resource other people get added to, not something safe to silently re-create.
- **Abuse prevention:** standard per-user rate limit shared with other Crew-mutation endpoints (60 calls/hour, same family as `updateCrew`). **Added 2026-08, Milestone F4:** this endpoint had no stated rate limit at all when originally specified; closed as part of building the shared rate-limiting mechanism §5 names, rather than leaving one endpoint in the family silently unlimited.

#### `updateCrew`

- **Request:** `{ crewId: string, patch: Partial<{ name, photoUrl }> }`
- **Response:** `{ success: true, updatedFields: string[] }`
- **Errors:** `permission-denied` (caller is not a Crew admin), `invalid-argument` (`name` empty or over 40 chars), `not-found`.
- **Server behavior:** patches `crews/{crewId}`'s `name`/`photoUrl` directly; a rename or photo change fans out via the same denormalization trigger described in `DATABASE.md` §4 that refreshes Crew Card renders elsewhere in the app, so members don't need to re-fetch the Crew document to see an updated name reflected on shared surfaces (Crew Chat header, Crews List). No idempotency key required — a repeated identical patch is naturally idempotent (re-setting the same field values is a no-op difference), the same reasoning `updateTable` (§3.1) already relies on. This endpoint was previously missing entirely: no screen or API-gap tracker had named "editing a Crew" as an open item, but `SCREEN_SPECIFICATIONS.md`'s Crew Detail (Screen 24) and Create Crew (Screen 23) together imply a Crew's name/photo must be changeable after creation, and no endpoint existed to do it.
- **Abuse prevention:** standard per-user rate limit shared with other Crew-mutation endpoints (60 calls/hour), consistent with `updateTable`'s (§3.1) rate-limit treatment.

#### `addMember`

- **Request:** `{ crewId: string, targetUserId: string }` (invite) or `{ crewId: string, inviteToken: string }` (accept)
- **Response:** `{ success: true, memberCount: number }`
- **Errors:** `permission-denied` (caller is not a Crew admin, for the invite form), `failed-precondition` (`CREW_AT_CAPACITY` — Crews have a soft cap enforced here to keep chat/coordination usable, configurable via Remote Config per `FIREBASE.md`), `not-found` (invalid or expired `inviteToken`).
- **Server behavior:** updates `memberIds` and the denormalized `members` map (`DATABASE.md` §3.4, §4) transactionally so both stay in sync. Idempotent by construction without a client-supplied key: both the `memberIds` update and the `members` map update are set-membership writes (`arrayUnion`-equivalent, keyed by uid), so a retried `addMember` call for a target already present is a no-op returning the current `memberCount` rather than a duplicate membership entry or a double-counted capacity check — the same "idempotent by construction" pattern used by `cancelTable` (§3.1). **Disclosed gap, Milestone F4:** only the `targetUserId` (admin-direct-add) path is implemented this milestone. The `inviteToken` (self-accept) path has no backing data model anywhere in `DATABASE.md` — no invite/token subcollection, no issuance endpoint, no expiry schema — so it cannot be built as a real feature without a dedicated design pass (new `DATABASE.md` schema section, an invite-issuance endpoint, and a decision on token lifetime/redemption semantics). Calling `addMember` with `inviteToken` currently throws `not-found` unconditionally, matching the documented error for an invalid token rather than silently accepting a param this implementation can't honor. Because only the admin-direct-add path exists, admin-privileged unilateral addition **is** currently possible — the "not unilateral addition, to avoid unwanted-group-add abuse" protection `createCrew`'s note above used to claim is not actually true of the shipped system yet. Tracked in `TASKS.md` as a follow-up: build the invite-token subsystem properly before any UI exposes Crew member-adding to end users.
- **Abuse prevention:** standard per-user rate limit shared with other Crew-mutation endpoints (60 calls/hour, same family as `updateCrew`/`createCrew`). **Added 2026-08, Milestone F4**, same reasoning as `createCrew` above.

#### `removeMember` / `leaveCrew`

- **Request:** `{ crewId: string, targetUserId?: string }` (omit `targetUserId` to leave; admin-only to remove someone else)
- **Response:** `{ success: true }`
- **Errors:** `permission-denied` (`targetUserId` given but caller is not a Crew admin), `invalid-argument` (`SELF_REMOVE_NOT_ALLOWED` — a caller must use the omit-`targetUserId` leave path to remove themselves, not the admin-remove path, per `SCREEN_SPECIFICATIONS.md` Crew Detail), `not-found` (`targetUserId` is not a current member).
- **Abuse prevention:** standard per-user rate limit shared with other Crew-mutation endpoints (60 calls/hour, same family as `updateCrew`/`createCrew`/`addMember`). **Added 2026-08, Milestone F4**, same reasoning as `createCrew` above.
- **Server behavior:** removes the uid from both `memberIds` and the denormalized `members` map (`DATABASE.md` §3.4) transactionally, symmetric to `addMember`. Idempotent by construction without a client-supplied key: removing a uid that's already absent is a no-op (`arrayRemove`-equivalent) returning `success: true` rather than erroring — consistent with `cancelTable`'s (§3.1) treatment of a repeat call against already-settled state.

#### `scheduleRecurringTable` **[idempotent]**

- **Request:** `{ crewId: string, template: { title, interestTag?, location, capacity, cadence: "weekly"|"biweekly"|"monthly", dayOfWeek: string, timeOfDay: string, startingFrom: ISO8601 }, idempotencyKey: string }`
- **Response:** `{ recurrenceId: string, nextTableId: string }`
- **Errors:** `permission-denied` (caller is not a Crew admin), `invalid-argument` (bad capacity range against the 2-8 platform ceiling, or the recurrence pattern produces no valid future occurrence), `failed-precondition` (`DUPLICATE_REQUEST_IN_FLIGHT` — same semantics as `requestSeat`, §3.1).
- **Server behavior:** persists the recurrence template on the Crew document and immediately creates the next Table instance via the same internal logic as `createTable`; a scheduled function (`ARCHITECTURE.md` §5.3) generates each subsequent occurrence shortly before it's needed (not all at once far in advance, so edits to the template affect not-yet-created future occurrences without a cleanup migration). The idempotency key guards the same failure mode as `createTable`'s (§3.1): a retried call must not persist a second recurrence template and spawn a second, duplicate first-occurrence Table.

### 3.3 Discover

Discover's actual search execution happens **client-side against Typesense** using a scoped, read-only search API key (`ARCHITECTURE.md` §5.5) — not through a Cloud Function — because per-keystroke filter interaction (radius slider, tag chips) needs to feel instant, and a Cloud Function round-trip per filter tweak would add unacceptable latency to the app's most-used screen. The two Discover-related callables exist for operations Typesense cannot or should not perform directly:

#### `searchTables`

A thin Cloud Function wrapper around the Typesense query, used as a fallback path (e.g., web/marketing surfaces without an embedded search key, or if a scoped key needs server-side rotation) — the primary path is direct client-to-Typesense as described above.

- **Request:** `{ geo: { lat, lng, radiusKm }, interestTags?: string[], startTimeAfter?: ISO8601, startTimeBefore?: ISO8601, limit?: number, mode?: "typesense" | "firestore_degraded" }`
- **Response:** `{ results: Array<{ tableId, title, hostDisplayNameSnapshot, distanceKm, startTime, seatsRemaining, interestTag }>, nextCursor?: string, degraded?: boolean }`
- **Errors:** `invalid-argument` (radius outside allowed 1-50km range).
- **Server behavior — Typesense outage fallback (`ARCHITECTURE.md` §5.5):** when `mode: "firestore_degraded"` is passed (or the function's own attempt to reach Typesense times out/errors internally), the function instead serves results from the Firestore composite index (`visibility`, `status`, `startTime` — `DATABASE.md` §5) with a coarse geohash-range prefilter on `location.geopoint` and a simple recency/proximity sort, and sets `degraded: true` on the response so the client can render the "showing basic results" state (`ARCHITECTURE.md` §5.5) rather than presenting degraded results as if they were normal. The Flutter client's direct-to-Typesense path switches to calling `searchTables` with `mode: "firestore_degraded"` automatically once its own client-side circuit breaker trips on repeated Typesense failures.

#### `getMatches`

Returns a personalized set of suggested Open Tables (beyond a raw geo+tag filter) — e.g., weighted by the caller's `interestTags` overlap, verification-tier compatibility preferences, and Crew activity — computed server-side because the ranking weights are considered sensitive business logic we don't want reverse-engineerable from a client-side Typesense query.

- **Request:** `{ limit?: number }` (uses caller's stored `homeLocation`/`interestTags`)
- **Response:** `{ results: Array<{ tableId, matchScore, matchReasons: string[] }> }`
- **Abuse prevention:** rate-limited to 20 calls/hour/user — this endpoint is computationally heavier (queries Typesense server-side plus applies ranking) and is not meant to be polled rapidly.

### 3.4 Trust & Safety

#### `reportUser` / `reportTable`

- **Request:** `{ targetType: "user"|"table", targetId: string, reasonCode: string, details?: string }`
- **Response:** `{ reportId: string }`
- **Errors:** `invalid-argument` (unknown `reasonCode`), `already-exists` if an identical open report from the same reporter against the same target already exists (prevents duplicate-spam of the same report, not a general rate limit).
- **Server behavior:** writes to the top-level `reports` collection (`DATABASE.md` §3.6, never client-readable by design), increments the target's `trustSignals.reportCount`/`reportFlags.openReportCount`, and — if a per-target open-report threshold is crossed (Remote-Config-tunable, `FIREBASE.md` §Remote Config) — automatically sets `reportFlags.isSuppressed: true` on a Table (removing it from Discover pending human review) or flags a user for expedited Trust & Safety queue review. This automatic-suppression threshold is intentionally conservative (biased toward false positives that a reviewer clears quickly) given the safety-sensitive nature of Discover.
- **Abuse prevention:** rate-limited (10 reports/day/user) to deter weaponized mass-reporting of a target, while the duplicate-report check above prevents single-target spam specifically.

#### `blockUser`

- **Request:** `{ targetUserId: string }`
- **Response:** `{ success: true }`
- **Server behavior:** adds `targetUserId` to the caller's private `blockedUserIds` field (not modeled as a top-level collection since it's small, per-user, and privacy-sensitive — never exposed to the blocked party). Enforced across the app: blocked users' Open Tables are excluded from the blocker's Discover results (post-filtered against the block list after Typesense returns candidates, since Typesense itself doesn't know about blocks), and a blocked user cannot `requestSeat` on the blocker's Tables (§3.1) or message them in a shared Crew. Idempotent by construction without a client-supplied key, consistent with `SCREEN_SPECIFICATIONS.md`'s Block Confirmation screen expecting idempotent semantics: adding an already-blocked `targetUserId` is a no-op (`arrayUnion`-equivalent) returning `success: true`, the same pattern used by `addMember`/`removeMember` (§3.2).
- **Errors:** `invalid-argument` (`targetUserId` equals caller).

#### `triggerDuressSignal`

The dedicated, high-priority safety endpoint behind the Live Table Screen's duress-signal action (`SCREEN_SPECIFICATIONS.md` Screen 14; `SECURITY.md` §In-Table Emergency and Duress Response) — tracked as an open gap in `TASKS.md`'s 2026-08 SCREEN_SPECIFICATIONS.md update and formally specified here for the first time, matching the schema `DATABASE.md` §3.3a already defines for `tables/{tableId}/duressSignals/{userId}`. Deliberately **not** modeled as a `reportUser` variant: `reportUser`/`reportTable` above are non-urgent, reviewed on Trust & Safety's normal queue cadence; this endpoint exists specifically because a live-Table emergency cannot wait behind that queue, and it is definitionally SEV1 with no human triage step in front of the page.

- **Request:** `{ tableId: string, location?: { geopoint: {lat, lng} } }` — `location` is optional because the client attaches a best-effort last-known device location only if permission was already granted, but the signal must fire even if location cannot be acquired in time; per `SCREEN_SPECIFICATIONS.md`'s Live Table Screen, this action has zero validation friction by design.
- **Response:** `{ acknowledged: true }`
- **Errors:** none of the caller-facing error codes used elsewhere in this document apply by design — this endpoint never throws `permission-denied`, `failed-precondition`, or a validation error back to the client in a way that would block or delay the signal; a malformed or incomplete payload (e.g., missing `location`) is accepted and processed with whatever data is present. `unauthenticated` is the only condition that can prevent the call from being processed at all (the caller must be a signed-in RSVP holder on the Table), and even that is mitigated client-side by the Live Table Screen's fallback to the device's native emergency-call capability when the request can't complete within its short client-side timeout (`SCREEN_SPECIFICATIONS.md` Screen 14).
- **Server behavior:** writes `tables/{tableId}/duressSignals/{userId}` (`triggeredAt`, `lastKnownLocation`, `status: "open"` — `DATABASE.md` §3.3a), structurally unreadable by any client (Functions-only, mirroring `reports`' unreadability), and in the same transaction creates a paired `reports/{reportId}` document (`targetType: "table"`, `targetId: tableId`, `reasonCode: "safety_concern"`, `severity: "sev1"`, `isDuressSignal: true` — `DATABASE.md` §3.6), writing that report's ID back onto the duress-signal document's `linkedReportId` field so Trust & Safety tooling can navigate between the two. Immediately pages the on-call rotation via the same path as any SEV1 (`SECURITY.md` §Incident Response) — no human triage judgment call gates the page. This endpoint does **not** itself create a location share; if the caller had an active, previously opted-in `locationShares` document for this Table (`createLocationShare` below), that share continues independently and is not toggled by this call, keeping the "notify Trust & Safety" and "share my location" mechanisms decoupled per `SECURITY.md`'s description of them as two distinct things the same UI affordance can do.
- **Abuse prevention:** deliberately **not** rate-limited the way every other endpoint in §5 is — a rate limit on a duress signal would mean a legitimate second emergency during the same Table silently fails to alert anyone, which is a worse outcome than tolerating a low volume of duplicate/false-positive signals. Repeat low-signal usage is a Trust & Safety review-process concern (human pattern review), not an engineering throttle.

#### `createLocationShare` **[idempotent]** / `revokeLocationShare`

Formalizes the per-Table "share my location with a trusted contact" opt-in described in `SECURITY.md` §In-Table Emergency and Duress Response and schematized in `DATABASE.md` §3.3a (`tables/{tableId}/locationShares/{shareId}`), and closes the gap `SCREEN_SPECIFICATIONS.md`'s Trusted Contact Setup screen (Screen 29) originally flagged. Note the deliberate model this reflects, per `SECURITY.md`: this is an **explicit, per-Table opt-in** the user makes each time, never a persistent always-on profile setting — a stale "always share" toggle is itself a privacy risk if forgotten, so there is no `setTrustedContact`-style standing profile CRUD in this API; each share is its own scoped, revocable, auto-expiring document, and Screen 29's UI should present contact selection as part of joining/hosting a specific Table rather than a one-time Settings-level configuration.

- **Request (`createLocationShare`):** `{ tableId: string, contactType: "crew_member" | "external_sms", contactUserId?: string, contactPhoneNumber?: string, idempotencyKey: string }` — exactly one of `contactUserId` (if `contactType` is `crew_member`) or `contactPhoneNumber` (if `external_sms`) must be present. The idempotency key matters here specifically because a retried call without one would both create a second duplicate share document and send the external contact a second, confusing SMS — a real-world side effect on a third party outside the app, not just an internal double-write.
- **Request (`revokeLocationShare`):** `{ shareId: string }` — no idempotency key needed; revoking an already-revoked share is idempotent by construction (setting `revokedAt` on a document that already has it set is a no-op), the same pattern used by `cancelTable`/`blockUser` above.
- **Response (`createLocationShare`):** `{ shareId: string, signedLinkToken: string, expiresAt: ISO8601 string }`
- **Response (`revokeLocationShare`):** `{ success: true }`
- **Errors:** `invalid-argument` (`contactType`/`contactUserId`/`contactPhoneNumber` combination invalid, `contactPhoneNumber` fails E.164 format validation, `contactPhoneNumber` equals the caller's own verified number, `contactUserId` is not a member of a Crew shared with the caller), `failed-precondition` (`TABLE_NOT_LIVE_ELIGIBLE` — a share can only be created for a Table the caller has a `confirmed` RSVP on, per `SECURITY.md`'s scoping to "the duration of that specific Table only"), `permission-denied` (`revokeLocationShare` called by anyone other than the original `sharingUserId`), `not-found` (`shareId` doesn't exist or already expired).
- **Server behavior:** `createLocationShare` writes `tables/{tableId}/locationShares/{shareId}` (`sharingUserId`, `contactType`, `contactUserId`/`contactPhoneHash`, a freshly-generated `signedLinkToken`, `expiresAt` set to the Table's expected `happened` transition or a fixed 6-hour ceiling, whichever comes first — `DATABASE.md` §3.3a) and, for `external_sms`, sends the contact a one-time SMS containing the signed link (the raw phone number is used transiently in Cloud Function memory for that send only, never persisted un-hashed, consistent with `DATABASE.md` §3.1's phone-minimization pattern). The signed link is deliberately **not** a normal authenticated Firestore read — it's an unauthenticated-viewable, token-gated view, since the contact may have no TableCrew account at all. A scheduled/triggered expiry (the same TTL mechanism as `idempotencyKeys`, §3.9) enforces `expiresAt` server-side rather than relying on the client to stop sharing. `revokeLocationShare` sets `revokedAt` immediately, which the signed-link view checks on every read, giving "revocable at any time with immediate effect" real teeth rather than just client-side intent.
- **Abuse prevention:** standard per-user rate limit (10 calls/hour) shared with other low-risk mutation endpoints — generous, since this isn't a high-abuse-risk surface, but present so a compromised account can't be used to blast SMS at arbitrary phone numbers via repeated create/revoke cycling.

### 3.5 Ratings

#### `submitRating` **[idempotent]**

- **Request:** `{ tableId: string, ratedUserId: string, score: number (1-5), tags?: string[], comment?: string, idempotencyKey: string }`
- **Response:** `{ ratingId: string }`
- **Errors:** `failed-precondition` (`NOT_ATTENDED` — caller has no `attended` RSVP on this Table, or Table status is not yet `happened`/`rated`), `already-exists` (`RATING_ALREADY_SUBMITTED` — one rating per rater/ratedUser/table; this reflects a genuinely new submission attempt with a different `idempotencyKey`, not a retry — a retry with the same key returns the original stored response per §2, it does not hit this error), `failed-precondition` (`DUPLICATE_REQUEST_IN_FLIGHT`).
- **Server behavior:** writes the Rating document (`DATABASE.md` §3.5); a Firestore trigger recomputes `ratedUserId`'s `ratingAggregate`; once every attendee/host pair for a Table has rated (or a grace-period scheduled sweep passes), the Table's `status` advances `happened → rated`. The idempotency key closes a gap this document previously left inconsistent with `SCREEN_SPECIFICATIONS.md`'s Post-Table Rating screen, which already assumed `submitRating` carried an `idempotencyKey` for its offline-queue-and-sync behavior — without one, a rating submitted while offline and retried on reconnect would surface a spurious `RATING_ALREADY_SUBMITTED` error instead of quietly confirming the original submission.
- **Abuse prevention:** comments run through the same moderation pipeline as chat/profile text (`FIREBASE.md` §Cloud Storage/moderation notes apply analogously to text via a Cloud Function content-moderation check before persisting).

### 3.6 Payments

#### `createSplitRequest` **[idempotent]**

- **Request:** `{ tableId: string, totalAmountCents: number, currency: string, splitMethod: "even" | "custom", customSplits?: Array<{ userId, amountCents }>, idempotencyKey: string }`
- **Response:** `{ splitRequestId: string, stripePaymentIntentIds: Record<userId, string> }`
- **Errors:** `permission-denied` (caller is not `hostId`), `invalid-argument` (custom splits don't sum to `totalAmountCents`, or include a user without a `confirmed` RSVP), `failed-precondition` (`DUPLICATE_REQUEST_IN_FLIGHT`).
- **Server behavior:** for each confirmed attendee's share, creates a Stripe PaymentIntent (via Stripe Connect, with the venue/host as the eventual payout destination where applicable) and writes a corresponding `splitPaymentStatus: "pending"` onto that user's RSVP document (`DATABASE.md` §3.3) and a `splitRequests/{splitRequestId}` document (`DATABASE.md` §3.8) recording the full split — Firestore holds a **mirror** of Stripe state, never the authoritative record (`ARCHITECTURE.md` §8). The idempotency key here is what prevents a retried call (e.g., a host double-tapping "request payment" on a slow connection) from creating a second, duplicate set of PaymentIntents and charging every attendee twice — without it, this is the single highest-severity double-charge risk in the API surface, since it fans out to N separate Stripe charges per retry, not just one.
- **Abuse prevention:** only the host can initiate, and only against confirmed attendees of a Table that has reached `confirmed` or `happened` status — prevents pre-emptive charging before commitment is real.

#### `confirmPayment` **[idempotent]**

- **Request:** `{ splitRequestId: string, idempotencyKey: string }` — client calls this after completing Stripe's client-side payment confirmation (e.g., 3D Secure) to force an immediate status refresh rather than waiting for the webhook, improving perceived responsiveness; the webhook (below) remains the authoritative source of truth regardless.
- **Response:** `{ status: "paid" | "pending" | "failed" }`
- **Server behavior:** queries the Stripe PaymentIntent status directly and reconciles the mirrored `splitPaymentStatus` field if it's out of date. This endpoint only *reads* Stripe state and writes a mirrored status field it also owns exclusively, so a naive implementation might seem safe to retry without an idempotency key — we require one anyway because "reconcile mirrored status" can race with the webhook handler (below) writing the same field from the other direction; the idempotency record makes repeated client-triggered reconciliation attempts a clean no-op rather than a source of a benign-but-confusing status flap.

#### `flagSplitPaymentDispute` **[idempotent]**

Lets the paying attendee (never the host, per `docs/PRD.md` FR-T25a) flag a specific split-request charge as wrong, unattended, or fraudulent, without silently leaving the request in an unresolved "backend error code only" state (this endpoint was previously missing from this document entirely, and referenced only as a Future Enhancements gap in `docs/SCREEN_SPECIFICATIONS.md` Screen 31 and by name in `docs/DATABASE.md` §3.3/§3.8's `perAttendeeStatus.{uid}.dispute` sub-schema before it existed here as a formal contract).

- **Request:** `{ splitRequestId: string, reasonCode: "incorrect_amount" | "did_not_attend" | "suspected_fraud" | "other", details?: string, idempotencyKey: string }`
- **Response:** `{ success: true, status: "disputed", reviewDueBy: ISO8601 }`
- **Errors:** `permission-denied` (caller is not the payer on this `splitRequestId`, or is the host who created it — a host may not dispute their own request), `failed-precondition` (`ALREADY_PAID_NO_DISPUTE_WINDOW` — the 14-day post-Table dispute window per Screen 31 has elapsed with the charge already `paid` and no dispute opened inside that window), `failed-precondition` (`DISPUTE_ALREADY_OPEN` — a second call against a `splitRequestId`/uid pair that already has an open `dispute` sub-object is a no-op returning the existing dispute's current state, not a new case), `invalid-argument` (unknown `reasonCode`).
- **Server behavior:** writes a `perAttendeeStatus.{uid}.dispute` sub-object (`DATABASE.md` §3.8: `reasonCode`, `details`, `flaggedAt`, `reviewDueBy` = `flaggedAt` + 3 business days, `resolution: null`, `refundIssued: false`, `resolvedBy: null`) onto `splitRequests/{splitRequestId}`, mirrors `splitPaymentStatus` to `"disputed"` on the corresponding RSVP document (`DATABASE.md` §3.3), and pauses any pending payment reminders on that request (`PRD.md` FR-T25a) — all inside one transaction so the pause-reminders side effect can never be left out of sync with the dispute record. A scheduled function (`ARCHITECTURE.md` §5.3) sweeps disputes past their `reviewDueBy` with `resolution` still `null` and, per FR-T25a's "made whole by default" policy, issues a Stripe refund, sets `refundIssued: true`, and marks `resolution: "unsubstantiated"` only in the sense that the *default* outcome favors the payer, not that fraud was disproven. A human Trust & Safety reviewer can instead resolve a dispute earlier (`resolution: "substantiated"` or `"unsubstantiated"`, `resolvedBy` set) via internal tooling, not this callable. A `"substantiated"` resolution increments the host's `trustSignals.substantiatedBillingDisputeCount`; 2+ within a rolling 90-day window suspends that host's bill-splitting privileges pending Trust & Safety review, mirroring the graduated no-show escalation model in `SECURITY.md`.
- **Abuse prevention:** rate-limited to 10 disputes/day/user (shared with the general Trust & Safety rate-limit family, §5), since a dispute — unlike a routine payment retry — triggers real human review capacity.

#### `createCheckoutSession`

Formalizes the subscription checkout/billing-session gap previously left open in `SCREEN_SPECIFICATIONS.md`'s TableCrew+ Subscription screen (Screen 34). Creates a Stripe Checkout session for TableCrew+ subscription purchase — used on platforms/surfaces where Stripe Checkout is the billing path; where the platform's own in-app-purchase billing (App Store/Play Billing) is used instead, subscription state is reconciled via that platform's own server-to-server notification webhook (a separate, platform-specific plain-HTTPS handler analogous to `stripeWebhook` below, whose exact shape is dictated by Apple/Google's contract rather than one this document controls, so it isn't detailed further here) rather than through this callable.

- **Request:** `{ priceId: string, successUrl: string, cancelUrl: string }`
- **Response:** `{ checkoutSessionUrl: string }`
- **Errors:** `already-exists` (`SUBSCRIPTION_ALREADY_ACTIVE` — caller already has an active TableCrew+ subscription; the client should show the manage/cancel state instead of re-offering checkout, per `SCREEN_SPECIFICATIONS.md` Screen 34), `invalid-argument` (unknown `priceId`).
- **Server behavior:** creates (or reuses, if one already exists for this uid) a Stripe Customer object, then a Stripe Checkout Session in subscription mode for the given `priceId`, returning the hosted session URL for the client to open. Subscription state itself (`users/{uid}/private/profile.subscription`, `DATABASE.md` §3.1) is **not** written by this endpoint — it is written exclusively by the `stripeSubscriptionWebhook` handler (below) on `customer.subscription.updated`/`deleted` events, keeping exactly one write path for subscription state, deliberately a separate webhook handler from `stripeWebhook` (which owns split-payment `payment_intent.*`/`charge.refunded` events only) rather than overloading one handler with two unrelated Stripe event families — just as `stripeWebhook` is the sole writer of `splitPaymentStatus` for split payments (`ARCHITECTURE.md` §8's "Stripe is authoritative, Firestore mirrors" principle applies identically here).
- **Abuse prevention:** standard per-user rate limit (10 calls/hour) — checkout-session creation is cheap on our side but each call hits the Stripe API, so this bounds our own Stripe API usage under a scripted-retry scenario.

#### `cancelSubscription` **[idempotent]**

The "Cancel Subscription" control's backing call (`SCREEN_SPECIFICATIONS.md` Screen 34) — specified alongside `createCheckoutSession` since a checkout-session endpoint with no corresponding cancel endpoint would leave that same screen's other primary action unspecified.

- **Request:** `{ idempotencyKey: string }`
- **Response:** `{ status: "cancelled_active_until_period_end", activeUntil: ISO8601 string }`
- **Errors:** `failed-precondition` (`NO_ACTIVE_SUBSCRIPTION`), `failed-precondition` (`DUPLICATE_REQUEST_IN_FLIGHT`).
- **Server behavior:** calls Stripe to cancel the subscription **at period end** (`cancel_at_period_end: true`), never an immediate cancellation, matching `SCREEN_SPECIFICATIONS.md` Screen 34's explicit requirement that the user retains full benefits until the stated date, with no interstitial retention gauntlet in front of this control. The mirrored Firestore subscription-state field is updated by `stripeSubscriptionWebhook` (below) on the resulting Stripe event, not directly by this callable, for the same single-writer reason described under `createCheckoutSession`.

#### Stripe webhook handler (`stripeWebhook`, plain HTTPS function, not callable)

Stripe delivers `payment_intent.succeeded`, `payment_intent.payment_failed`, and `charge.refunded` (among others) to a plain HTTPS Cloud Function endpoint (not a callable, since Stripe cannot attach a Firebase Auth token or App Check attestation). Security is instead enforced via **Stripe webhook signature verification** (the `Stripe-Signature` header validated against our webhook signing secret, stored in Secret Manager, never in source or client config) — any request that fails signature verification is rejected with 400 before any Firestore write occurs. On a verified `payment_intent.succeeded` event, the function looks up the associated split-request/RSVP by the PaymentIntent ID (stored at creation time) and sets `splitPaymentStatus: "paid"`; `payment_intent.payment_failed` sets `"failed"` and triggers a retry-prompt notification to the affected user. The handler is idempotent (keyed by Stripe event ID, deduplicated against a short-lived processed-events collection) since Stripe may redeliver events.

#### Stripe subscription webhook handler (`stripeSubscriptionWebhook`, plain HTTPS function, not callable)

A second, separate plain-HTTPS Stripe webhook endpoint — intentionally not folded into `stripeWebhook` above, since that handler's event family (`payment_intent.*`, `charge.refunded`) is conceptually unrelated to subscription lifecycle events, and keeping them separate means a bug or incident in one event-processing path can't take down the other. Referenced structurally by `DATABASE.md` §3.1's `subscription` field ("written only by the `stripeSubscriptionWebhook` handler") before this document gave it a formal contract.

- Verifies the `Stripe-Signature` header the same way `stripeWebhook` does (§3.6), against the same class of webhook signing secret in Secret Manager (a distinct signing secret per Stripe webhook endpoint, per Stripe's own security model).
- On `customer.subscription.created`/`updated`, writes `users/{uid}/private/profile.subscription` (`tier`, `status`, `stripeCustomerId`, `stripeSubscriptionId`, `currentPeriodEnd`, `cancelAtPeriodEnd` — `DATABASE.md` §3.1) mapped 1:1 from the Stripe Subscription object's own fields, deliberately not inventing any status this document's `status` enum doesn't already mirror from Stripe.
- On `customer.subscription.deleted`, sets `tier: "free"`, `status: "canceled"`.
- Idempotent (keyed by Stripe event ID against the same short-lived processed-events collection `stripeWebhook` uses), since Stripe may redeliver events here too.

### 3.7 Identity Verification

#### `completeIdentityVerification`

Records the outcome of a Tier 2 (ID + liveness) verification attempt after the Persona SDK's client-side capture flow completes (`SCREEN_SPECIFICATIONS.md` Screen 8). This callable was previously referenced only informally — Screen 8 says "the client calls the TableCrew backend to record the verification outcome" without naming it, and `SECURITY.md` states verification status "is enforced server-side in Cloud Functions," which presupposes an endpoint like this exists — but no request/response contract for it appeared anywhere in this document until now. Given Tier 2 verification is the hard gate in front of every Open/Discover Table action, an unspecified endpoint here is a materially higher-severity gap than any of the other five originally tracked, since it underpins the entire Discover trust model, not just one screen.

- **Request:** `{ personaInquiryId: string }` — the client never transmits raw ID images or biometric data to TableCrew's own backend; Persona's SDK handles capture and scoring directly against Persona's own servers, and this callable's only job is to look up the already-completed inquiry by ID and act on its result, consistent with `ARCHITECTURE.md`'s "no TableCrew-built OCR/liveness code" boundary.
- **Response:** `{ verificationTier: "id_verified" | "unverified", outcome: "pass" | "fail" | "manual_review" }`
- **Errors:** `not-found` (`personaInquiryId` doesn't resolve to a completed inquiry for this uid), `failed-precondition` (`DOB_MISMATCH` — the ID's date of birth fails the tolerance cross-check against the self-reported DOB from onboarding, `SCREEN_SPECIFICATIONS.md` Screens 4 and 8; this sets `outcome: "manual_review"` rather than surfacing a hard client-facing error, and flags the account for Trust & Safety review rather than silently retrying), `failed-precondition` (`ALREADY_VERIFIED` — a no-op success if the caller is already `id_verified`, since re-entering this flow after already passing shouldn't be re-processed).
- **Server behavior:** server-side-fetches the inquiry result directly from Persona's API — never trusting a client-supplied pass/fail boolean, since that would be a trivial verification-tier self-elevation bypass, exactly the case `SECURITY.md` §Firestore Security Rules Philosophy calls out ("clients cannot self-elevate verification tier"). On a genuine pass with a clean DOB cross-check, writes `users/{uid}/private/profile.verification` (`verificationTier: "id_verified"`, `idVerified: true`, `verifiedAt`) via the Admin SDK, which the existing `DATABASE.md` §4 denormalization trigger mirrors to the public `verificationTierPublic` field. On fail or a DOB-mismatch manual-review case, the tier stays at its current value (`unverified`/`phone_verified`) and a Trust & Safety review item is created rather than the account silently failing closed with no record anywhere.
- **Abuse prevention:** rate-limited to 5 attempts per rolling 24h per uid — verification attempts are already bottlenecked by Persona's own capture-flow cost, but the limit exists as defense-in-depth against a scripted caller hitting this endpoint directly with fabricated `personaInquiryId` values.

### 3.8 Account Data & Privacy

#### `revokeSessions`

Backs Settings > Security's "sign out everywhere" control (`SECURITY.md` §Authentication: Session Lifecycle, Token Handling, and Device Compromise) — tracked as item 6 in `TASKS.md`'s 2026-07 Security readiness review as needing a formal contract here, now specified. Lets a user invalidate every signed-in session at once after a lost/stolen device or a forgotten sign-out on a shared device, without needing to know which specific device to target (that finer-grained, per-device revoke is explicitly out of scope for v1 per `SECURITY.md`, a follow-on enhancement, not required for the initial fix).

- **Request:** `{}`
- **Response:** `{ success: true, revokedAt: ISO8601 string }`
- **Errors:** none beyond the standard `unauthenticated` case — there is no scenario in which a signed-in caller is not allowed to revoke their own sessions, so no `permission-denied`/`failed-precondition` branch exists here.
- **Server behavior:** calls the Firebase Admin SDK's `revokeRefreshTokens` for `context.auth.uid`, which invalidates every existing refresh token for that uid — every other signed-in device (and the calling device itself) is forced to re-authenticate on its next token refresh. This is deliberately blunt (all-or-nothing) rather than per-device, matching `SECURITY.md`'s stated v1 scope; the client that just called this endpoint should expect its own session to be invalidated shortly after and should re-authenticate rather than treating the call as "revoke everyone else's session but mine."
- **Abuse prevention:** standard per-user rate limit (5 calls/hour) — generous, since this is a self-protective action a legitimately compromised user may need to invoke repeatedly in a short window (e.g., retrying after an unclear result), and there's no meaningful abuse vector in a user revoking their own sessions.

#### `exportUserData` **[idempotent]**

Formalizes the export path already described structurally in `DATABASE.md` §7 ("a companion `exportUserData` callable assembles a JSON bundle...") but, until now, never given an actual request/response contract in this document — closing the gap flagged in `SCREEN_SPECIFICATIONS.md`'s Data Export / Delete Account screen (Screen 36).

- **Request:** `{ idempotencyKey: string }`
- **Response:** `{ exportJobId: string, status: "queued" }`
- **Errors:** `failed-precondition` (`EXPORT_ALREADY_IN_PROGRESS` — only one active export job per user at a time, per `SCREEN_SPECIFICATIONS.md` Screen 36's stated rate limit), `failed-precondition` (`DUPLICATE_REQUEST_IN_FLIGHT`).
- **Server behavior:** enqueues an asynchronous export job rather than assembling it synchronously — the bundle (RSVP history via the `rsvps` collection-group query, Ratings, Crew memberships, `splitRequests`, per `DATABASE.md` §7) can be large enough to exceed a callable's practical response-time budget. A background Cloud Function assembles the JSON bundle exactly as `DATABASE.md` §7 describes, writes it to a Cloud Storage location the user has no direct bucket access to, and generates a signed, time-limited download URL, delivered via a Notification Center entry and/or email per `SCREEN_SPECIFICATIONS.md` Screen 36.
- **Abuse prevention:** the one-active-job-at-a-time precondition above is the primary abuse control, since export assembly is comparatively expensive; a standard per-user rate limit (1 call/hour) is a secondary guard.

#### `deleteAccount` **[idempotent]**

Formalizes the deletion path already described structurally in `DATABASE.md` §7 ("Account deletion (`deleteAccount` callable, detailed in `API_SPEC.md`)") but, until now, not actually detailed here — closing the gap flagged in `SCREEN_SPECIFICATIONS.md`'s Data Export / Delete Account screen (Screen 36). This is the single most irreversible endpoint in the API surface, so every step below is deliberately more conservative than a typical mutating callable.

- **Request:** `{ confirmationPhrase: string, idempotencyKey: string }` — `confirmationPhrase` must exactly match the platform's typed-confirmation string (e.g., `"DELETE"`, localized per `SCREEN_SPECIFICATIONS.md` Screen 36's noted localization consideration); this is re-validated server-side, not merely a client-side gate, since deletion must never be triggerable by a request that skips the confirmation UI.
- **Response:** `{ status: "deletion_scheduled", gracePeriodEndsAt: ISO8601 string }`
- **Errors:** `failed-precondition` (`REAUTHENTICATION_REQUIRED` — this callable requires a freshly-issued ID token per Firebase Auth's reauthentication-recency check; a stale long-lived session is not sufficient authorization for this action, per `SCREEN_SPECIFICATIONS.md` Screen 36), `invalid-argument` (`confirmationPhrase` doesn't match), `failed-precondition` (`DUPLICATE_REQUEST_IN_FLIGHT`).
- **Server behavior:** does not delete anything synchronously on this call. It sets `users/{uid}/private/profile.pendingDeletion: { requestedAt, gracePeriodEndsAt }` (`DATABASE.md` §3.1) and schedules the actual deletion sweep — soft-delete/tombstone of the public profile, hard-delete of the private profile, the denormalized-snapshot sweep across Tables/RSVPs/Crew messages, Cloud Storage photo deletion, anonymization of `splitRequests` entries, and finally Firebase Auth record deletion, in the exact sequence `DATABASE.md` §7 specifies — to run once the grace period (a reasoned 14-day default per `SCREEN_SPECIFICATIONS.md` Screen 36's flagged assumption, pending explicit product/legal confirmation) elapses with no cancellation.
- **Abuse prevention:** the reauthentication requirement above is the primary safeguard against a hijacked-session abuse case (an attacker holding a stolen but not-freshly-reauthenticated session token cannot delete the real owner's account).

#### `cancelPendingDeletion`

- **Request:** `{}`
- **Response:** `{ success: true }`
- **Errors:** `failed-precondition` (`NO_PENDING_DELETION`).
- **Server behavior:** clears `users/{uid}/private/profile.pendingDeletion`, aborting the scheduled sweep before it runs — only meaningful strictly before `gracePeriodEndsAt`; once the sweep has actually executed, the account is gone and there is nothing left to cancel. No idempotency key needed: clearing an already-absent `pendingDeletion` field is a no-op, the same "idempotent by construction" pattern used throughout §3.1-3.2 above.

### 3.9 Account Creation & Signup (Tier 1)

Added in Milestone F2. Both `SCREEN_SPECIFICATIONS.md` Screen 4 (Date of Birth Entry) and Screen 5 (Profile Setup) previously described their server-side behavior only informally — Screen 4 as "a lightweight server-side validation round trip... not one of the seven named business endpoints," Screen 5 as "account/profile document creation... bundled at this step rather than exposed as a separate named endpoint" — the same shape of gap `completeIdentityVerification` (§3.7) and `revokeSessions` (§3.8) closed in earlier passes. Formalized here as two endpoints, matching the two-screen split the product spec already describes: a fast, non-persisting eligibility check the client can call immediately after DOB entry (so a rejected user never wastes time filling out the rest of onboarding), and the actual account-creation write once every field collected across Screens 4-6 is available.

#### `validateAge`

Backs Screen 4's "Continue" round trip. Deliberately read-only and non-persisting — no document is written by this call, and no idempotency key is needed since calling it twice with the same input is trivially safe (it has no side effect to duplicate).

- **Request:** `{ dateOfBirth: string }` — ISO 8601 date (`"YYYY-MM-DD"`), self-reported.
- **Response:** `{ eligible: boolean }`
- **Errors:** `invalid-argument` (`dateOfBirth` is not a well-formed ISO 8601 date, or is in the future).
- **Server behavior:** computes age as of the current server date (never the client's clock, per `SECURITY.md`'s "Age Gating and Minimum Age Enforcement" — client clocks/logic can be manipulated) and returns `eligible: computedAge >= 18`. Does not persist `dateOfBirth` anywhere — that happens only at `completeAccountSetup` below, once the user has actually completed the rest of onboarding. A client that calls this, gets `eligible: true`, and then never completes `completeAccountSetup` (abandons onboarding) leaves no trace of the attempt, which is the intended behavior — this endpoint exists purely to fail fast with a good UX, not to log an audit trail of every DOB a device ever tried.
- **Abuse prevention:** rate-limited to 20 calls/hour/uid — generous, since a legitimate user might retry after a typo, but bounded against a scripted client probing the boundary condition repeatedly.

#### `completeAccountSetup`

Backs the combined write Screens 5 and 6 (Profile Setup, Interest Selection) describe as one atomic account-creation step. This is the **only** path by which `users/{uid}` and `users/{uid}/private/profile` documents are ever created — both documents' Firestore rules require `allow create: if false` as of Milestone F2 (`DATABASE.md` §6), specifically so this callable's validation (most importantly the server-side 18+ re-check, never trusted from `validateAge` having been called earlier) cannot be bypassed by a modified client writing the documents directly.

- **Request:**
```
{
  dateOfBirth: string,          // required, ISO 8601 date - re-validated server-side, never trusted from
                                 // an earlier validateAge call alone (SECURITY.md: "never trusted from
                                 // client state alone")
  displayName: string,          // required, 1-30 chars, per SCREEN_SPECIFICATIONS.md Screen 5
  photoUploadId?: string,       // optional, an id the client generated before uploading the photo to
                                 // users/{uid}/profile/pending/{photoUploadId} (Screen 5's photo upload
                                 // step). Corrected 2026-08, Milestone F5: this field was previously named
                                 // `photoUrl` and took a raw client-supplied Cloud Storage download URL
                                 // directly, which contradicted DATABASE.md §3.1's own "photoUrl ... post-
                                 // moderation" comment and FIREBASE.md §2.5's "never written directly by
                                 // the uploading client" rule -- no moderation pipeline existed yet to
                                 // enforce that when the field was first specified, so nothing was actually
                                 // gating it. Renamed and re-scoped now that DATABASE.md §3.1a's moderation
                                 // pipeline (ADR 0006) exists: the server re-derives the real URL itself
                                 // (see Server behavior) rather than trusting anything the client sends.
  bio?: string | null,          // optional, max 140 chars, per Screen 5
  interestTags: string[],       // required, minimum 3, per SCREEN_SPECIFICATIONS.md Screen 6
  locale: string                // required, BCP-47 locale tag (DATABASE.md §3.1's `locale` field)
}
```
No `idempotencyKey` — deliberately not marked **[idempotent]** in the §2 sense (which would require the general-purpose `idempotencyKeys` store, not yet implemented anywhere in this codebase; it lands in Milestone F4 alongside the first endpoints that genuinely need it, per `functions/src/shared/index.ts`'s scaffold note). This endpoint doesn't need that mechanism: the target document's ID is deterministic (`users/{uid}`, always the caller's own uid), so a retry is naturally, unambiguously idempotent by construction — see Server behavior below — the same "idempotent by construction, no client-supplied key" pattern §3.1-3.2 already use for `cancelTable`/`addMember`/`removeMember`.
- **Response:** `{ uid: string, verificationTierPublic: "phone_verified" }`
- **Errors:** `unauthenticated` (no signed-in Firebase Auth user — should be unreachable in the normal flow, since Tier 1 phone verification per `SECURITY.md` already gates every use of the app before this screen is ever reached, but never assumed), `failed-precondition` (`UNDER_MINIMUM_AGE` — computed age is under 18 as of the server's clock; no account is created, matching `SCREEN_SPECIFICATIONS.md` Screen 4's "if computed age is under 18, no account is created and the user sees the hard-stop screen"), `failed-precondition` (`PHOTO_NOT_APPROVED` — new, Milestone F5: `photoUploadId` was given but `users/{uid}/private/photoModeration/{photoUploadId}` either doesn't exist, doesn't belong to the caller, or has `status` other than `"approved"` — covers a client racing ahead of a still-`"pending"` verdict, retrying a `"flagged"` upload, or sending a fabricated/someone-else's id), `invalid-argument` (`displayName` outside 1-30 chars, `bio` over 140 chars, fewer than 3 `interestTags`, malformed `dateOfBirth`/`locale`).
- **Server behavior:** validates the full payload (hand-rolled field-validation helpers, `functions/src/users/validation.ts` — corrected 2026-08, Milestone F4: this previously said "shared Zod schema, same convention as every other endpoint," but no Zod dependency was ever adopted; this line now matches what actually shipped), re-derives age from `dateOfBirth` against the server clock and rejects before any write if under 18 (this is the actual enforcement point `SECURITY.md`'s age-gating section describes — `validateAge` above is a UX convenience, this check is the real gate). If `photoUploadId` is present, reads (Admin SDK) `users/{uid}/private/photoModeration/{photoUploadId}` and requires `status == "approved"` before proceeding, taking `approvedUrl` from that document as the value it writes to `photoUrl` — the request's `photoUploadId` is only ever used as a lookup key into a document the server itself trusts, never as a source of the URL value directly. Then attempts to `create()` (never `set()`) `users/{uid}` (public) with `displayName`/`photoUrl` (the server-derived URL, or `null` if no `photoUploadId` was given)/`bio`/`interestTags`/`locale`, `verificationTierPublic: "phone_verified"` (Tier 1 is already complete by construction — the caller reached this screen only via completed phone-OTP sign-in), the zero-value `ratingAggregate` defaults, and `deletedAt: null`; and `users/{uid}/private/profile` with `dateOfBirth`, `phoneNumberHash` (SHA-256 of the E.164 number read from the caller's Firebase Auth ID token claims — the raw number is never read from anywhere else and never persisted, per `DATABASE.md` §3.1), `residencyRegion` (derived server-side from the phone number's country calling code — see the implementation note below), `verification: { phoneVerified: true, idVerified: false, verificationTier: "phone_verified", verifiedAt: now }`, and the zero-value defaults for `trustSignals`/`blockedUserIds`/`notificationPrefs`/`subscription`/`fcmTokens`/`crewMemberships` specified in `DATABASE.md` §3.1. **Idempotent-by-construction behavior:** if `users/{uid}` already exists (a genuine retry after a dropped response — the caller can only ever `create()` their own uid's document, so there is no ambiguity about whose retry this is), the function does not error; it reads back the existing document and returns its current `{uid, verificationTierPublic}` as a success, on the reasoning that a retry of this one-time action should resolve to "your account exists, proceed" rather than surface a confusing error — this endpoint never overwrites an already-created account's fields, so the *original* successful call's data always wins.
- **Implementation note on `residencyRegion`:** derived from the E.164 phone number's country calling code via a small, explicitly-scoped lookup table, defaulting to `"IN"` for any unrecognized prefix — a reasoned, disclosed placeholder appropriate for Foundation/Phase 0's single-market (Hyderabad, India) scope per `ROADMAP.md`, not a claim of exhaustive international coverage. Revisit this table as international expansion (`SECURITY.md`'s Data Privacy Compliance section) adds markets.
- **Abuse prevention:** rate-limited to 5 calls/hour/uid, consistent with `SECURITY.md`'s Abuse Prevention section naming "account creation" as a rate-limited sensitive action; layered with the same App-Check/device-attestation secondary limit (§5) as every other endpoint.

## 4. Versioning Strategy

We version the callable API **implicitly through additive-only evolution plus an explicit client minimum-version gate**, rather than URL/path versioning (which callables don't naturally support the way REST does):

- **Additive changes** (new optional request fields, new response fields, new error codes) ship without a version bump — every callable's request/response validation (hand-rolled field-validation helpers per `functions/src/*/validation.ts`, not a schema library — see §3.9's `completeAccountSetup` correction note) treats new fields as optional with defaults, and clients on older app versions simply don't send/read the new fields. This is the overwhelming majority of API evolution.
- **Breaking changes** (removing a field, changing a field's type or required-ness, changing an endpoint's fundamental behavior) are avoided wherever a non-breaking alternative exists (e.g., add `capacityV2` alongside `capacity` and migrate readers, rather than mutating `capacity`'s shape in place). When truly unavoidable, we ship the new behavior as a **new callable name** (e.g., `createTableV2`) rather than mutating an existing one in place, and gate the old callable's continued availability to a deprecation window enforced by Remote-Config-driven minimum supported app version (`FIREBASE.md` §Remote Config, cross-ref `DEPLOYMENT.md` staged rollout process) — the app itself checks a Remote Config `minimumSupportedVersion` value at launch and forces an update prompt before a client old enough to call the removed endpoint could do so.
- **Rationale:** given Flutter/mobile release cycles have inherent client-update lag (app store review, users delaying updates), "deprecate with a forced-upgrade floor" is more reliable than "assume all clients update instantly," which is why the minimum-version gate — not just documentation of a deprecation — is the actual enforcement mechanism.
- **How long the old callable actually has to stay alive — a concrete floor, not just a mechanism:** a forced-upgrade prompt only fires when a user *opens the app*; a user who doesn't open TableCrew for two months is not gated by anything until the moment they do, so "we have a minimum-version gate" is not by itself a guarantee that old-callable traffic disappears on any particular calendar schedule. We therefore commit to two concrete rules, not just the mechanism: (1) a breaking change's **old callable is kept fully functional for a minimum of 90 days** after the new one ships, regardless of observed traffic, to outlast the realistic long tail of app-store-review latency plus users who update infrequently; and (2) before actually removing the old callable at or after that floor, we check **live version-distribution telemetry** (from Analytics/App Check, `FIREBASE.md` §2.9) for the percentage of active clients still on a pre-deprecation version — if that share is still non-trivial (a threshold we set per-change based on the severity of breaking that cohort, not a single blanket number), we extend the window and/or tighten the `minimumSupportedVersion` gate further rather than removing the endpoint on schedule regardless of who's still calling it. The calendar floor and the telemetry check are both required: the floor alone doesn't account for a change that happens to hit an unusually slow-updating cohort, and the telemetry check alone (with no floor) would let an eager engineer remove a callable two weeks after shipping the replacement just because "the numbers look low so far."

## 5. Rate Limiting and Abuse Prevention (Cross-Cutting)

In addition to the per-endpoint notes above, every callable shares these baseline protections:

- **App Check enforcement** on all callables (§2) blocks non-genuine-client traffic before business logic runs.
- **Per-user, per-endpoint-family rate limits** implemented via a Firestore-backed sliding-window counter (a lightweight internal collection keyed by `{uid}_{endpointFamily}_{windowBucket}`, TTL-cleaned), checked at the top of each function body before any other work — chosen over a separate rate-limiting service (e.g., Redis-backed) because our volumes don't yet justify the operational overhead of another datastore, and Firestore's per-document write throughput is more than sufficient for counter increments at our current scale (revisit under `ARCHITECTURE.md` §6 trigger (3) if a specific counter becomes hot).
- **Per-account limits alone are not sufficient defense-in-depth, and we don't treat them as such:** a user willing to create multiple accounts can trivially reset any purely per-uid counter (`requestSeat` spam, `reportUser` spam) by signing up again, and phone-number-based signup friction (`SECURITY.md` Tier 1) raises the cost of doing this but doesn't eliminate it, especially for a motivated abuser with access to multiple numbers. We therefore layer a **secondary limit keyed by App Check attestation / device install identity** (the same signal already used to distinguish genuine app instances, §2, `FIREBASE.md` §2.6) alongside the per-uid limit on every rate-limited endpoint: a burst of `requestSeat` or `reportUser` calls from the *same device attestation* across multiple different `uid`s in a short window is throttled and flagged for the fake-account-detection velocity signal described in `SECURITY.md` §Abuse Prevention, independent of whether any single account individually stays under its own per-uid limit. This closes the specific gap where per-account rate limiting alone is defeated by cheap multi-account creation.
- **Firebase Auth's own abuse protections** (phone auth SMS-pumping defenses, anomaly detection) cover the authentication layer itself, upstream of any callable.
- **Structured audit logging:** every callable logs a structured Cloud Logging entry (`{uid, endpoint, targetIds, outcome}`) on both success and rejection, which feeds the Trust & Safety review tooling and lets us retroactively tighten a rate limit or add a new abuse heuristic without redeploying instrumentation from scratch.

## 6. Cross-References

- Why specific operations must be callables vs. triggers: `ARCHITECTURE.md` §5.2.
- Document schemas and fields referenced throughout (e.g., `capacity.confirmedCount`, `trustSignals`, `splitPaymentStatus`, `subscription`, `pendingDeletion`, `duressSignals`, `locationShares`): `DATABASE.md` §3-4.
- Security rules that structurally deny client-direct writes to invariant-guarded fields, forcing traffic through these callables: `DATABASE.md` §6, `SECURITY.md`.
- Push notification triggers driven by these endpoints (RSVP confirmations, Table cancellation alerts, payment failures): `FIREBASE.md` §Cloud Messaging.
- Identity-verification tiering and re-verification policy underlying `completeIdentityVerification` (§3.7): `SECURITY.md` §Identity Verification Tiers.
- Duress/emergency response process and the per-Table location-share model underlying `triggerDuressSignal`/`createLocationShare`/`revokeLocationShare` (§3.4): `SECURITY.md` §In-Table Emergency and Duress Response.
- Data retention, anonymization, and deletion-sweep sequencing underlying `exportUserData`/`deleteAccount`/`cancelPendingDeletion` (§3.8): `DATABASE.md` §7.
- Age-gating enforcement and the `dateOfBirth` field underlying `validateAge`/`completeAccountSetup` (§3.9): `SECURITY.md` §Age Gating and Minimum Age Enforcement, `DATABASE.md` §3.1/§6.

## 7. Gap-Closure Note (2026-08 API Readiness Pass)

This pass formally specified the five endpoints originally tracked as open gaps in `TASKS.md`'s "Update — 2026-08 SCREEN_SPECIFICATIONS.md" entry, plus a sixth (`revokeSessions`) added to that same tracker by a concurrent 2026-07 Security readiness pass: duress signal (`triggerDuressSignal`, §3.4), split-payment dispute (landed as `flagSplitPaymentDispute`, §3.6, via a concurrent pass), account export/deletion (`exportUserData`/`deleteAccount`/`cancelPendingDeletion`, §3.8), subscription checkout/billing (`createCheckoutSession`/`cancelSubscription`/`stripeSubscriptionWebhook`, §3.6), trusted-contact/location-sharing (`createLocationShare`/`revokeLocationShare`, §3.4 — note this landed as a per-Table opt-in rather than the persistent-profile "trusted contact" CRUD originally imagined in `SCREEN_SPECIFICATIONS.md` Screen 29, reconciled against the concurrently-specified `SECURITY.md` §In-Table Emergency and Duress Response and `DATABASE.md` §3.3a models, which deliberately reject a standing "always share" toggle as its own privacy risk — `SCREEN_SPECIFICATIONS.md` Screen 29 was subsequently rewritten to match this shape in the 2026-08 architecture readiness synthesis pass, per `docs/ARCHITECTURE_READINESS_REVIEW.md` §3a), and session revocation (`revokeSessions`, §3.8).

Also closed, surfaced by systematically cross-referencing every screen in `SCREEN_SPECIFICATIONS.md` against this document rather than only the five previously-tracked items: a missing `completeIdentityVerification` endpoint (§3.7) underpinning the entire Tier 2/Discover trust gate (a materially higher-severity gap than any of the five above, since it wasn't even informally named anywhere until now); a missing `updateCrew` endpoint (§3.2) for editing a Crew's name/photo, which no document anywhere had previously named; a missing `endTableEarly` endpoint (§3.1) for the Live Table Screen's host-only early-end control; a stale `capacity.max` ceiling of 12 in `createTable`'s request schema that had been corrected to 8 everywhere else in the knowledge base (`DATABASE.md`, `PRODUCT.md`, `SCREEN_SPECIFICATIONS.md`) but never propagated here; and missing `idempotencyKey` fields on `createTable`, `createCrew`, `scheduleRecurringTable`, and `submitRating` — all four already assumed by `SCREEN_SPECIFICATIONS.md`'s own offline-behavior sections to carry one, which this document had never actually specified. See `TASKS.md` and `CHANGELOG.md` for the full list and disposition.
