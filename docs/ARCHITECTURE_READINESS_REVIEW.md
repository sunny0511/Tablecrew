# Architecture Readiness Review

**Purpose:** confirm the TableCrew knowledge base is actually ready to build against — not just internally consistent by construction, but complete across the seven dimensions a real architecture review checks before Phase 0 engineering starts. **Date:** 2026-08, immediately following documentation v1.0 approval. **Method:** five parallel reviews, each covering one dimension (or a closely related pair), each instructed to find real gaps and fix them directly in the documents rather than merely list them, followed by a synthesis pass that reconciled the one significant cross-cutting contradiction the parallel reviews surfaced between each other. This document is the compiled record, organized by the seven dimensions requested: Product, Data, APIs, Security, Analytics, Notifications, Offline behavior, and Error states.

Unlike the earlier `docs/SERIES_A_DILIGENCE_REVIEW.md` (which asked "would this survive investor scrutiny?"), this review asks a narrower, more mechanical question: "if an engineer opened this repository tomorrow and started building Phase 0, would they hit a documented gap, a contradiction between two docs, or a silent assumption?" Every finding below is a concrete instance of one of those three failure modes.

## 1. Product: `PRODUCT.md`, `PRD.md`, `FEATURES.md`, and `ROADMAP.md` alignment

**Overall: aligned, with two real drifts found and fixed.**

- **Stale 12-person headcount ceiling.** The 2026-08 Series A pass corrected the Table headcount model to a hard 2–8 range everywhere *except* two places this review found: `PRD.md` FR-T17 (post-Confirmed capacity increase "up to the hard max of 12") and `PRD.md` §7's out-of-scope line ("Group Tables above 12 people"). Both said 12 while `FEATURES.md` and `DATABASE.md` had already been corrected to 8 — a genuine cross-document drift that a prior pass should have caught but didn't. Fixed: both `PRD.md` lines now read 8, with a note cross-referencing `PRODUCT.md`. The same stale "12" was also found and fixed in `ARCHITECTURE.md` §6 (a capacity-trigger example), since it's downstream of the same schema.
- **Internal contradiction on the reliability signal.** `PRD.md` FR-T13 said the on-time%/cancellation-rate reliability signal is "internal only, never shown as a public score," while FR-T28 two paragraphs later said it "is shown on their public host profile" — a direct contradiction within the same document. `FEATURES.md`'s Trust & Safety theme and its "Won't: public trust-score numeric display" row both side with FR-T13, and `DATABASE.md`'s `ratingAggregate` schema has no field for on-time%/cancellation-rate, confirming the public-display version was never actually implemented elsewhere. Fixed: FR-T28 now states only the aggregate star rating is public; the reliability signal stays internal-only.

No other contradictions in phasing, terminology, or platform framing were found — the prior Series A and India-first passes had already propagated those correctly.

## 2. Data: `DATABASE.md` entity/feature bidirectional coverage

**Several real gaps found — features with no data model, and referenced structures that didn't actually exist in the schema.** All fixed directly in `DATABASE.md` (plus `ARCHITECTURE.md`, `PRD.md` where the gap was really a cross-document one):

- **TableCrew+ subscription had zero fields anywhere** despite being a named Must-have feature (`FEATURES.md` Must-P1, `PRD.md` FR-D5/D15/D16). Added a `subscription` map to `users/{userId}/private/profile` (tier, status, Stripe IDs, `currentPeriodEnd`, `cancelAtPeriodEnd`), Functions-only writable.
- **Bill-split disputes (FR-T25a, a named Phase 0 launch item) had no dispute data model at all** — the `splitPaymentStatus` enum didn't even include `"disputed"`. Added the enum value, a `perAttendeeStatus.{uid}.dispute` sub-structure, and a `substantiatedBillingDisputeCount` field on `trustSignals` to back the "2+ substantiated disputes loses bill-splitting privileges" rule.
- **Simultaneous-reveal ratings (FR-T29a) were undermined by the schema itself** — the illustrative security rule let a rated party read a rating the instant it was created, the opposite of "simultaneous reveal." Added `pairKey`/`revealState`/`revealedAt` fields and fixed the rule.
- **Duress signal and location-sharing subcollections were referenced by `SECURITY.md` but never schematized.** Added `tables/{tableId}/duressSignals/{userId}` and `tables/{tableId}/locationShares/{shareId}`, both with locked-down, Functions-only rules.
- **Reports were missing the `off_platform_stalking` reason code** that `SECURITY.md` claimed already existed in `DATABASE.md`'s enum, plus a `severity` field and `isDuressSignal` flag needed for the SEV1 surge-detection trigger `SECURITY.md` describes. Added all three, plus a supporting index.
- **Table fields promised by FR-T3/FR-D2 but absent from the schema:** cost band, cover photo, dietary/accessibility notes, and TBD-location confirmation fields. Added `costBand`, `coverPhotoUrl`, `accessibilityNotes`, `location.isTBD`/`location.tbdConfirmBy`.
- **Notification preferences were coarser than the feature promised** — `FEATURES.md` wants per-Crew, per-type mute; the schema only supported per-category. Expanded to `{categories: map, mutedCrewIds: array}` (later further refined in the Analytics & Notifications pass — see §6).

No orphaned entities were found (every collection in `DATABASE.md` traces to a real feature).

## 3. APIs: every user action has a defined endpoint with auth, authorization, validation, error handling, and idempotency

**This was the largest single gap area.** Six previously-tracked gaps, plus several more found by this pass, are now formally closed in `docs/API_SPEC.md`:

- **`triggerDuressSignal`** (§3.4) — the Live Table Screen's duress action, deliberately *not* routed through `reportUser`, since a live emergency can't wait behind the normal report queue. Reconciled to write to the `duressSignals` subcollection added in §2 above, plus a paired SEV1 `reports` document.
- **`flagSplitPaymentDispute`** (§3.6) — closes the previously backend-error-code-only payment-dispute gap, matching the `dispute` sub-schema added to `DATABASE.md`.
- **`exportUserData` / `deleteAccount` / `cancelPendingDeletion`** (§3.8) — the GDPR/CCPA-style rights `SECURITY.md` and `VALUES.md` already promised now have real endpoints, including the grace-period-cancel path that was implied but never named.
- **`createCheckoutSession` / `cancelSubscription` / `stripeSubscriptionWebhook`** (§3.6) — TableCrew+ had no billing contract at all before this pass.
- **`createLocationShare` / `revokeLocationShare`** (§3.4) — closes the trusted-contact gap, but landed as a **per-Table opt-in**, not a persistent saved-contact CRUD (see the reconciliation note in §3a below — this is the one place the parallel reviews disagreed with each other and needed a synthesis fix).
- **`revokeSessions`** (§3.8) — surfaced fresh during the Security-readiness pass (see §4), not one of the original five; lets a user invalidate every signed-in session (lost/stolen device).
- **`completeIdentityVerification`** (§3.7) — arguably the most severe individual finding: no endpoint anywhere recorded the outcome of Persona verification, despite the entire Tier 2/Discover trust gate depending on one existing. It wasn't even informally named before this pass.
- **`updateCrew`** (§3.2) and **`endTableEarly`** (§3.1) — editing a Crew's name/photo and the Live Table Screen's host-only early-end control both had no backing endpoint.
- **Corrections to existing endpoints:** `createTable`'s capacity ceiling was still hardcoded to 12 (see §1); fixed to 8. Missing `idempotencyKey` requirements were added to `createTable`, `createCrew`, `scheduleRecurringTable`, and `submitRating` — all four already assumed idempotent by `SCREEN_SPECIFICATIONS.md`'s own offline-behavior sections, but never actually specified as such in `API_SPEC.md`. Missing error-handling/idempotency notes were filled in for `createCrew`, `removeMember`/`leaveCrew`, `addMember`, and `blockUser`.

Confirmed correct, no changes needed: seat-request withdrawal (already `cancelRsvp`), and no over-applied idempotency on read-only endpoints (`searchTables`/`getMatches`).

### 3a. Reconciliation: the location-share model contradicted the original Trusted Contact Setup screen

The API-readiness pass and the Security-readiness pass (running in parallel) independently converged on the same design for location sharing: a per-Table, explicit, revocable opt-in (`createLocationShare`/`revokeLocationShare`), never a persistent "always share with X" profile setting — because a forgotten standing toggle is itself a privacy risk. But `docs/SCREEN_SPECIFICATIONS.md` Screen 29 ("Trusted Contact Setup") still described the *old* model: a single saved contact, edited once in Settings, with a default-on/off auto-share toggle. That's a real, user-facing contradiction between what the API now does and what the screen spec told Design/Engineering to build.

**Fixed in this synthesis pass:** Screen 29 was rewritten to match the per-Table model exactly — it now renders in two modes (an in-Table create/revoke flow when opened with a specific Table in context, and a no-Table explainer/active-shares-list mode when opened from Settings or the Safety Briefing), with its API Calls, Validation Rules, Offline Behavior, and Analytics Events fields all updated to match `createLocationShare`/`revokeLocationShare`'s actual request shape and error set. The corresponding wireframe in `docs/WIREFRAMES.md` was redrawn to show all three resulting states (in-Table default, in-Table active-share, explainer mode), and the stale `trusted_contact_added`/`trusted_contact_removed`/`trusted_contact_toggle_changed` analytics events were renamed to `location_share_created`/`location_share_revoked` in `docs/FIREBASE.md` (the toggle-changed event was retired outright, since there's no longer a standing toggle to change). `docs/SCREEN_SPECIFICATIONS.md`'s own "API Gaps Surfaced" rollup section, which still described five gaps as "open" after all five (plus more) had actually been closed, was also rewritten to reflect the resolved state.

This is the one place where running five reviews in parallel against shared documents produced a real, if narrow, disagreement between two of them — worth naming explicitly rather than letting the synthesis quietly paper over it, since it's a useful data point on where parallel-review methodology needs a reconciliation step.

## 4. Security: authentication, authorization, moderation, reporting, privacy, and verification

**All six sub-areas were checked against `SECURITY.md`, `LEGAL.md`, `DATABASE.md`, and the relevant screens; five had real gaps, now fixed.**

- **Authentication:** token refresh and device-compromise handling were completely undocumented — no revocation mechanism existed for a lost/stolen device. Added a new `SECURITY.md` section covering session lifecycle, the new `revokeSessions` endpoint (Settings > Security), and a human-reviewed support fallback for a fully inaccessible device.
- **Authorization:** largely already consistent (per-endpoint ownership checks in `API_SPEC.md` matched `DATABASE.md`'s rules sketch). Two real gaps fixed: what happens to a banned host's existing Tables (now specified — Open/Discover Tables auto-suppressed and cancelled, Crew-only generally untouched), and a real contradiction between "blocking suppresses messaging" (`SECURITY.md`) and an explicitly-flagged-as-unresolved assumption in Screen 28 that shared-Crew messaging would continue unaffected by a block (resolved: membership persists, messaging between the two blocked parties is suppressed everywhere, including shared Crew chat).
- **Moderation:** the largest gap in this section — `DATABASE.md` already defined a `trustSignals.standingStatus` enum (`good`/`warned`/`restricted`/`banned`) with nothing narrating what actually moves an account between those states, no general appeals process (except for no-show disputes specifically), and no stated review-turnaround SLA. Added a full escalation-ladder-and-appeals section to `SECURITY.md`, including an honest admission that a "different reviewer handles the appeal" target can't yet be guaranteed at founding-team headcount — tracked as an open item rather than promised.
- **Reporting:** already thoroughly documented; one real timing gap found and fixed — a report filed while a user's Tier 2 verification was still processing asynchronously had no defined resolution order, which could have let verification be granted before a concurrent report was reviewed.
- **Privacy:** the retention/deletion model itself (including the 7-year financial-ledger exception) was already consistent. Found and fixed a real naming contradiction (`SECURITY.md` called the export/deletion callables `requestDataExport`/`requestAccountDeletion`; `DATABASE.md` called them `exportUserData`/`deleteAccount` — now reconciled to the latter everywhere) and a stale Algolia/Typesense reference inconsistent with `ARCHITECTURE.md`'s settled Typesense-only decision. India's DPDP Act specifics (consent-manager mechanics, breach-notification timelines) remain explicitly open pending real counsel review — not silently resolved, since that's a genuine legal judgment call, not a documentation gap.
- **Verification:** Tier 1/Tier 2 gating logic was already clear and consistent. Persona's India/Aadhaar coverage was already flagged as open in `LEGAL.md`/`TASKS.md`; this pass added a direct cross-reference to that open item inside `SECURITY.md` itself, since a reader of `SECURITY.md` alone previously had no way to know that assumption wasn't yet confirmed.

## 5. Analytics: every major user action has an event definition

**Real gap: `SCREEN_SPECIFICATIONS.md` had already introduced roughly 25 new, correctly-named events screen-by-screen, but the canonical event table in `docs/FIREBASE.md` — the one document `SUCCESS_METRICS.md` §5 points to as proof every metric is "traceable to a specific, named event" — was never updated to match.** Fixed by adding 16 missing rows to `FIREBASE.md`'s canonical table, covering Table cancellation, Crew creation/membership changes, subscription start/cancel, location sharing (renamed per §3a above), bill-split request/payment/dispute, the duress signal, and data export/account deletion.

Two genuine bugs surfaced along the way: Table cancellation had no event at all, not even in its own screen's spec, despite `cancelTable` being a documented action on that same screen (fixed: added `table_cancelled` everywhere it was missing); and the duress signal was entirely absent from `SUCCESS_METRICS.md` despite being a fully-specified SEV1 flow in `SECURITY.md` (fixed: added a Duress Signal Rate trend metric, deliberately not framed as a numeric guardrail, since every occurrence is already an automatic SEV1 regardless of rate).

## 6. Notifications: push notifications and reminder triggers are specified

**Real gap, and a structural one, not just a missing-row problem:** notification content was scattered across `PRD.md`, `FIREBASE.md`, `DATABASE.md`, and `SCREEN_SPECIFICATIONS.md`, and three of those documents implied **three different, non-matching category taxonomies** (3 categories in one place, 5 differently-named keys in another, a 4-group filter set in the Notification Center screen). None of them lined up with each other.

**Fixed:** `FIREBASE.md` §2.4 was rewritten as the single source of truth, reconciling every scattered trigger (from `PRD.md` FR-T8/T9a/T14a/T16/T24/T25a, `SECURITY.md`'s duress flow, and the relevant screens) into one taxonomy keyed to `DATABASE.md`'s actual field names, each with trigger condition, timing, and mute policy stated explicitly. Three previously-unspecified gaps were closed in the same pass: quiet-hours/timezone handling (non-critical categories defer to device-local daytime hours; Safety notifications never defer), chat-notification batching cadence (one push per 2-minute window), and delivery-failure/retry/TTL behavior. Safety notifications were also made structurally un-mutable — `DATABASE.md`'s `notificationPrefs.categories` map has no key for Safety at all, which is what makes the Notification Center's "Safety can't be fully muted" claim true by construction rather than just a UI-level promise that could be bypassed. A previously-unspecified subscription-renewal-reminder policy (3 days before renewal, annual plans only) was also decided and documented as a new decision, not inherited from anywhere.

## 7. Offline behavior and error states

**Offline behavior: strong overall, one real inconsistency found and fixed.** All 36 screens already had non-hand-wavy Offline Behavior specs, following a clear three-tier convention (cache-and-read-only for display screens; local-draft-plus-queue-with-idempotency for retryable actions; block-entirely-offline for payment/safety/identity-irreversible actions). Payment screens and the core Table-creation/RSVP journey — the flows Hyderabad's real-world connectivity conditions make first-class concerns, not edge cases — were already handled safely (idempotency keys throughout, no double-charge risk). The one real bug: Discover Table Preview blocked `requestSeat` entirely offline while Table Detail's identical action queued optimistically — the same endpoint, contradictory treatment, and `PRD.md` NFR-14 makes clear which behavior is actually mandated. Fixed by aligning Discover Table Preview to Table Detail's queue-and-sync pattern.

**Error states: four real "backend-code-only, no UI treatment" gaps found and fixed.** `SEAT_REQUEST_CONTENTION` was a defined `API_SPEC.md` error with no surfaced UI treatment anywhere — added explicit handling to both screens that call `requestSeat`. Identity Verification had no recovery path for a generic Persona failure (only the DOB-mismatch case was handled) — added a capped retry flow with a support fallback. The Live Table Screen never addressed a host cancelling while attendees were already en route — added a specified real-time transition with a mandatory cancellation reason, while keeping the safety affordance reachable throughout. The payment status chip vocabulary was missing a "Failed" state despite the underlying webhook being able to set it — added, with a retry action. A new FR-T14c was added to `PRD.md` for a previously-undocumented edge case: a single occurrence of a recurring Table series failing to reach quorum doesn't cancel the whole series.

## Summary: what changed and where

| Dimension | Verdict before this review | Real gaps found | Status now |
|---|---|---|---|
| Product alignment | Mostly aligned | 2 (stale headcount ceiling, reliability-signal contradiction) | Fixed |
| Data/feature coverage | Several silent gaps | 7 (subscription, disputes, ratings reveal, duress/location schema, reports fields, Table fields, notification prefs) | Fixed |
| APIs | Largest gap area | 9+ (6 previously tracked, 3 newly found), plus 1 cross-review contradiction | Fixed and reconciled |
| Security | Mostly documented | 5 of 6 sub-areas had a real gap | Fixed; 2 items explicitly left open (DPDP specifics, Persona India coverage) pending real legal/vendor confirmation |
| Analytics | Structurally incomplete | 16 missing canonical events, 2 outright bugs | Fixed |
| Notifications | Scattered and self-contradictory | 3 mismatched taxonomies, 3 unspecified behaviors | Consolidated and fixed |
| Offline behavior | Strong | 1 real inconsistency | Fixed |
| Error states | Mostly covered | 4 backend-only gaps | Fixed |

## Open items carried forward (not silently resolved, tracked in `TASKS.md`)

- India DPDP Act consent-manager mechanics and breach-notification timelines — requires real counsel review.
- Persona's Aadhaar/India-ID coverage — requires direct vendor confirmation.
- Moderation appeals' "different reviewer" target — not guaranteed at current team size; tracked as an aspiration, not a promise.
- The 14-day account-deletion grace period and the 3-attempts/24h identity-verification retry cap are reasoned defaults, flagged for Trust & Safety/legal sign-off before launch, not unilaterally finalized.

## Documents touched in this review

`PRD.md`, `ARCHITECTURE.md`, `DATABASE.md`, `API_SPEC.md`, `SECURITY.md`, `FIREBASE.md`, `SUCCESS_METRICS.md`, `SCREEN_SPECIFICATIONS.md`, `WIREFRAMES.md`, `TASKS.md`, `CHANGELOG.md`.
