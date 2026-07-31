# TableCrew Product Requirements Document (PRD)

**Status:** Living document, v1.0
**Owners:** Product & Engineering
**Related docs:** `PRODUCT.md`, `VISION.md`, `MISSION.md`, `VALUES.md`, `USER_PERSONAS.md`, `USER_RESEARCH.md`, `ROADMAP.md`, `FEATURES.md`, `SUCCESS_METRICS.md`, `ARCHITECTURE.md`, `DATABASE.md`, `API_SPEC.md`, `FIREBASE.md`, `DESIGN_SYSTEM.md`, `SECURITY.md`, `TESTING.md`, `LEGAL.md`

---

## 1. Overview and Objective

TableCrew exists to make it effortless for anyone, anywhere, to build real friendships around a table, working toward a world where no one eats alone. This PRD defines what we are building in the current release horizon (Phase 0 and Phase 1 of `ROADMAP.md`) to serve that mission, and it is the binding source of truth for functional and non-functional requirements across the three core objects of the product: **Tables**, **Crews**, and **Discover**.

The objective of the first shippable product is narrow and deliberate: prove that a stranger-optional, structured small-group gathering product can get real people to show up, more than once, without turning into either a scheduling utility (like a shared calendar) or an engagement-maximizing social feed. Every requirement below is evaluated against two questions: does it get someone to an actual table with actual people, and does it respect that person's time, safety, and attention while doing so.

This PRD covers the requirements needed to serve the first two primary user journeys end-to-end (Host a Table with people I know; Join a Table with people I don't know yet) and lays the functional groundwork for the third (Recurring Crew ritual), which reaches full depth in Phase 2 per `ROADMAP.md`.

## 2. Personas Served

Requirements below are tagged against the five personas defined in `USER_PERSONAS.md`:

- **Maya (27, New-to-City Professional)** — primary beachhead, Discover-first
- **Alex (31, Friend-Group Organizer)** — primary beachhead, Crew-first
- **Priya (34, Serial Host)** — secondary, Discover supply side
- **Devon (38, Remote-First Employee)** — expansion
- **Grace (58, Empty-Nester Rebuilding a Social Life)** — long-horizon

Every functional requirement section states, explicitly, which personas it primarily serves, because a requirement that serves no named persona is a requirement we should not build yet.

## 3. Functional Requirements — Tables

A Table is the atomic unit of the product: a specific gathering with a host, time, place, headcount cap (hard bounds 2–8 platform-wide, with a *recommended* size that varies by activity/interest tag rather than one fixed default — see `PRODUCT.md`'s recommendation table, e.g., coffee/mentorship skew toward 2–4, dinner/founder-dinner formats toward 4–6, board games/hiking toward the 4–8 ceiling), an optional interest tag, a visibility setting (Closed/invite-only or Open/visible on Discover), and a lifecycle status: **Proposed → Filling → Confirmed → Happened → Rated** (with a **Cancelled** terminal state reachable from Proposed, Filling, **or Confirmed** — a Confirmed Table can still be cancelled up until the Happened transition, e.g., a venue closure or host emergency; see FR-T14b for why this carries no payment/refund exposure).

### 3.1 Table Creation

**Serves:** Alex, Priya, Maya, Devon, Grace (universal — every journey begins or ends at a Table).

- FR-T1: A host must be able to create a Proposed Table in **under 60 seconds and 4 taps** from the home screen tap target to a published Table, assuming a saved default venue or "I'll pick a place later" option is used. This is a hard usability budget validated in `TESTING.md` usability passes each release.
- FR-T2: Table creation requires: title (auto-suggested from interest tag, e.g., "Sunday Brunch"), date/time, headcount cap (adjustable 2–8 via stepper, not free text; the stepper's starting position is a smart default driven by the selected interest tag per `PRODUCT.md`'s recommendation table — e.g., defaulting to 3 for a Coffee tag, 5 for a Dinner tag, 6 for a Board Games tag — rather than one fixed number for every Table), visibility (Closed default for Crew-originated Tables, Open default for Discover-originated Tables), and location. Location may be a saved venue, a pin dropped on a map, or "TBD, will confirm 24h before" (max one open location per host at a time, to prevent low-commitment spam Tables).
- FR-T3: Optional fields: interest tag (single-select from a curated taxonomy — see `FEATURES.md` Discover matching), cost estimate band ($ / $$ / $$$), dietary/accessibility notes, cover photo.
- FR-T4: A host may duplicate a past Table (carrying forward venue, cap, tag) to support recurring hosting in under 3 taps. This directly serves Priya's repeat-hosting workflow and Alex's Crew rituals.
- FR-T5: Draft Tables auto-save; a host can back out at any point without losing input.

### 3.2 Invitation

**Serves:** Alex (Crew-first invite flow), Priya (broadcast to followers + Open listing), Maya (receiving invites into unfamiliar groups).

- FR-T6: A Closed Table can be filled by: inviting specific contacts/Crew members, sharing a private invite link (expires in 72 hours or at Table cap, whichever first), or both.
- FR-T7: An Open Table is automatically listed on Discover once Proposed, subject to Trust & Safety eligibility (see `SECURITY.md` — host must have verified identity per FR-D9 before an Open Table is listed).
- FR-T8: Invitees receive a push notification and in-app card with host, time, place (exact address only after RSVP-yes for Open Tables with new-to-network attendees; see 3.6 Safety), cap, and current fill count (e.g., "4 of 6 joined").
- FR-T9: A host can convert a Closed Table to Open (to fill remaining seats) at any point before Confirmed, and can convert Open to Closed only if zero non-Crew members have joined.
- FR-T9a: **Venue relocate flow (post-Confirmed).** A host can change a Confirmed Table's venue/location without cancelling and recreating the Table — covering the common real-world case of a venue closing permanently or cancelling the reservation last-minute. Changing the venue on a Confirmed Table triggers an immediate push notification and an updated in-app card to every confirmed attendee (not a passive chat message easily missed), and the change is logged on the Table's history. If the host cannot find a substitute venue in time, FR-T14b's Confirmed-Table cancellation path applies instead.

### 3.3 RSVP

**Serves:** all personas.

- FR-T10: RSVP options are binary — **Join** or **Can't make it** — with no ambiguous "Maybe" state, because ambiguous RSVPs are a leading cause of the flake culture TableCrew is designed to eliminate (validated in `USER_RESEARCH.md`).
- FR-T11: Joining a Table with open seats is an immediate confirmation, not a request, for Closed Tables among mutual Crew members. For Open Tables involving previously-unconnected members, join is instant but reversible by the host only in the case of a Trust & Safety flag (FR-D11), never as a routine "host approval" gate — approval gates create rejection experiences that conflict with the Hospitality value in `VALUES.md`.
- FR-T12: A Table moves Proposed → Filling on first non-host join, and Filling → Confirmed automatically when it reaches its headcount cap, or manually by the host at any fill level ≥ 2 total attendees, no later than 2 hours before start time.
- FR-T13: Attendees can change Join → Can't make it up until 4 hours before start time without penalty; cancellations inside that window are logged against the user's reliability signal (internal only, never shown as a public "score" — see Values Check below).
- FR-T14: If a Table fails to reach at least 2 confirmed attendees (host + 1) by 2 hours before start time, it is auto-suggested for cancellation with one tap; it does not silently expire and strand a host.
- FR-T14a: **Continuous viability re-check, not a single checkpoint.** FR-T14's 2-hour check is necessary but not sufficient — a Table that clears the 2-hour check can still lose attendees afterward (FR-T13 permits logged-but-allowed cancellations up to start time). TableCrew therefore re-evaluates viability continuously between the 2-hour checkpoint and start time: if a Confirmed Table's attendee count drops below the 2-confirmed-attendee viability floor (host + 1) at any point in that window, the host is immediately push-notified (not just shown an in-app badge) and offered one-tap options to (a) cancel, (b) for Open Tables, reopen the remaining seats to the waitlist/Discover to backfill, or (c) proceed anyway with fewer attendees. A Table that drops to host-only attendance inside the final hour before start additionally auto-surfaces the same one-tap cancellation prompt as FR-T14, since a host arriving alone at a venue is exactly the silent-stranding failure this requirement exists to prevent.
- FR-T14b: **Confirmed-Table cancellation carries no TableCrew-mediated payment exposure by design.** Because bill-splitting (§3.6) is only ever initiated by the host *after* a Table transitions to Happened, a Table cancelled from Confirmed (FR-T9a, FR-T14a, or a Trust & Safety-mandated cancellation) by definition has no outstanding TableCrew-facilitated payment requests to unwind or refund — there is no pre-event payment or deposit flow in v1. This is stated explicitly here, rather than left implicit, because it is the load-bearing fact that keeps Table cancellation simple: if a host has separately collected money from attendees outside the app before a cancellation, that arrangement is entirely outside TableCrew's product surface, and Table-creation copy must make this explicit ("TableCrew never requires or facilitates payment before a Table happens") so attendees are not misled about what protection the platform does or doesn't provide.
- FR-T14c: **A single recurring-series occurrence failing viability does not cancel the series.** Each Table instance generated from a recurring schedule (`scheduleRecurringTable`, `docs/SCREEN_SPECIFICATIONS.md` Screen 26) is a normal Table document subject to FR-T14/FR-T14a like any other, including the one-tap cancel-suggestion if it can't reach the 2-confirmed-attendee viability floor. Cancelling, auto-suggesting, or proceeding-anyway on one occurrence has no effect on the recurring template or on any not-yet-created future occurrence — the scheduled function that fans out each new instance (`ARCHITECTURE.md` §5.3) reads only the Crew's recurrence template, not the outcome of prior instances, so a single skipped or under-attended Thursday dinner never silently unwinds "every Thursday" going forward. The only notification fan-out on a per-occurrence cancellation is scoped to that occurrence's own invitee list, not the whole Crew, to avoid implying the series itself ended.

### 3.4 Waitlist

**Serves:** Priya (high-demand serial hosting), Maya, Devon (Discover volume management).

- FR-T15: Once a Table reaches its cap, further joins go to a waitlist, ordered FIFO, capped at 2x the Table's headcount cap.
- FR-T16: A waitlisted user is promoted automatically within 15 minutes of a cancellation, with a 30-minute accept window before the offer passes to the next person, to avoid the classic "silent no-response waitlist" failure mode.
- FR-T17: Hosts may increase the cap post-Confirmed (up to the platform-wide hard max of 8 — corrected 2026-08 from an earlier, looser 12-person ceiling; see `PRODUCT.md`'s headcount correction and `FEATURES.md`'s "Tables above 8 people" row) to admit waitlisted members directly, with a single confirmation step warning about venue capacity.

### 3.5 Chat

**Serves:** Alex and Crew members (persistent chat), Maya/Priya (per-Table logistics chat).

- FR-T18: Every Table gets an ephemeral group chat automatically created at Proposed and auto-archived (read-only) 48 hours after the Table's Happened timestamp. Ephemeral-by-default is deliberate: it keeps chat scoped to logistics ("running 10 min late") rather than becoming a second messaging app competing for attention, consistent with the "real connection over engagement metrics" value.
- FR-T19: Every Crew has one persistent chat thread that survives across all Tables that Crew creates, distinct from per-Table ephemeral chats.
- FR-T20: Chat supports text, a location-pin share, image attachments (max 5 per message, Firebase Storage-backed, per `FIREBASE.md`), and a "running late" quick-action that broadcasts an ETA update to the Table without opening the chat.
- FR-T21: All chat content is moderated by the same reporting pipeline as profiles (FR-D11) and is retained for 90 days for Trust & Safety investigation purposes even after archive, per the data-retention policy in `SECURITY.md`.

### 3.6 Bill-Splitting

**Serves:** all personas, weighted most heavily toward Priya (frequent host, wants low-friction cost recovery) and Maya (new to a city, price-sensitive).

- FR-T22: Bill-splitting is opt-in per Table, initiated by the host post-Happened, never required to use TableCrew.
- FR-T23: Host enters a total bill amount and chooses an even split or itemized/custom split across confirmed attendees; TableCrew computes each person's share and generates one payment request per attendee via the integrated Stripe flow (per `ARCHITECTURE.md`).
- FR-T24: Payment requests expire after 7 days if unpaid; unpaid requests generate exactly one reminder at 48 hours and one at 6 hours before expiry — no more, to avoid nagging (Values Check: Hospitality, not extraction).
- FR-T25: TableCrew takes no fee on peer-to-peer bill-splitting; this is explicitly not a monetization surface (see Section 9 and `PRD.md` §9 out-of-scope). Monetization flows only through TableCrew+ subscription, venue commissions, and B2B2C — never a cut of friends splitting a check.
- FR-T25a: **Payment disputes and refunds.** An attendee can flag a specific bill-split payment request in-app (incorrect amount, charged for a Table they did not attend, suspected host-side fraud). Flagging a request immediately (a) pauses further reminders on that request, and (b) opens a billing-dispute case reviewed by support within 3 business days, using the Table's roster, chat log, and post-Table attendance check-off (`SECURITY.md`'s No-Show Accountability records) as the evidentiary basis. Stated policy: if a dispute is not resolved within the review window, the attendee is made whole by default (Stripe refund) rather than the burden defaulting to the payer, consistent with Hospitality over extraction. A host who is the subject of 2+ substantiated billing disputes in a rolling 90-day window loses bill-splitting privileges pending Trust & Safety review, mirroring the graduated no-show escalation model in `SECURITY.md`.

### 3.7 Ratings and Reviews (Post-Table)

**Serves:** Priya and the Discover marketplace's supply-side trust; Maya's safety confidence.

- FR-T26: 12 hours after a Table's scheduled end time, all confirmed attendees receive one (and only one) prompt to rate the Table: a 1–5 star "Would you sit at this table again?" score plus optional free-text.
- FR-T27: For Open/Discover-originated Tables, attendees additionally rate each other on three lightweight, non-punitive tags: "Great conversation," "On time," "Would meet again" (positive-framed only — no punitive-only tags exist in v1, to avoid weaponized rating; negative signal is captured exclusively through the separate reporting flow, FR-D11, not through star ratings).
- FR-T28: A host's aggregate star rating (FR-T26/FR-T29) is shown on their public host profile for Open Tables only; Crew-internal Closed Tables carry no public rating surface, since trust among existing friends does not need to be marketized. The underlying reliability signal (on-time %, cancellation rate) that feeds repeat-offender detection and Discover ranking is **internal-only and never displayed as a public number or score** — consistent with FR-T13's framing above and `FEATURES.md`'s Trust & Safety theme ("Reliability signal (internal-only)") and the explicit "Won't (v1): public 'trust score' numeric display" row, which exists precisely because a raw on-time/cancellation-rate figure is a reductive, easily-gamed public shaming surface. *Corrected 2026-08: an earlier draft of this requirement said the reliability signal itself was shown publicly, directly contradicting FR-T13 two paragraphs above and `FEATURES.md`'s "Won't" row — this was a stale artifact of an early draft that the Series A diligence pass should have caught but didn't; `DATABASE.md`'s `ratingAggregate` schema was never given fields for on-time%/cancellation-rate in the first place, which is itself evidence the public-display version was never actually implemented in the data model.*
- FR-T29: Ratings are averaged over a rolling 90-day, minimum-5-Table window before being displayed publicly, to prevent a single bad night (or single troll review) from defining a host.
- FR-T29a: **Simultaneous reveal (anti-retaliation and anti-gaming).** An individual's submitted rating (host "would sit again" score, or cross-user positive tags) is never shown to the rated party, and never contributes to any visible aggregate, until either (a) both directions of that specific pairing's rating have been submitted, or (b) 72 hours have elapsed since the Table's rating window opened — whichever comes first. This closes the two most obvious gaming vectors: a host or attendee seeing the other party's rating first and retaliating with a lower score (impossible here, since negative punitive tags don't exist per FR-T27, but the "would sit again" star score is still gameable this way) or waiting to copy/mirror a rating they've already seen. Suspected coordinated rating manipulation (fake 5-star rings, review-bombing of a specific host) is detected using the same velocity- and behavioral-signal approach described in `SECURITY.md`'s Abuse Prevention section and routed to Trust & Safety review — this is a detection-and-escalation problem, not one an algorithm resolves unilaterally.

### 3.8 Reporting and Blocking

**Serves:** Maya (primary safety beneficiary), Priya (protecting serial-host reputation from bad actors), all Discover participants.

- FR-T30: Any user can report another user or a specific Table at any time, pre- or post-event, in 2 taps from any surface where that user/Table appears, with no requirement to justify the report before it is filed (justification is optional, collected on a second, skippable screen).
- FR-T31: Reporting a user automatically blocks mutual visibility going forward pending review; the reported user is never shown who filed the report.
- FR-T32: Blocking is unilateral, immediate, and silent — a blocked user cannot see the blocker's Open Tables in Discover, cannot invite them, and is automatically removed from any Filling (not-yet-Confirmed) shared Table.
- FR-T33: Reports involving in-person safety (not just etiquette/no-show complaints) are triaged by a human Trust & Safety reviewer within 4 hours, 24/7, per `SECURITY.md`; this is a hard operational SLA, not an aspiration, because it is the backbone of the "Safety is a feature not a department" value.

## 4. Functional Requirements — Crews

**Serves:** Alex (primary), Devon (distributed friend groups), Grace (rebuilding a stable social circle).

- FR-C1: A Crew is a named, persistent group of 3–20 members with a shared avatar/name, a persistent chat (FR-T19), and a shared Table history.
- FR-C2: Any Crew member can propose a new Table on behalf of the Crew; it defaults to Closed visibility and pre-fills invitees to all Crew members, with per-Table opt-out.
- FR-C3: A Crew has one designated organizer role (transferable) responsible for recurring-ritual configuration (Phase 2 depth, see `ROADMAP.md`), but table creation rights are shared across all members by default — Crews are not hierarchical by design, reflecting how real friend groups actually operate.
- FR-C4: Crews maintain a lightweight shared history view: past Tables, attendance streaks, and a "it's been N weeks since we last got a table" indicator, which is the foundation for the Phase 2 recurring-nudge feature.
- FR-C5: Joining a Crew requires an invite from an existing member (link or direct); Crews are never publicly discoverable/joinable by strangers — that is what Discover is for. This separation is intentional and load-bearing: conflating the two would erode the safety model for both.

## 5. Functional Requirements — Discover

**Serves:** Maya (primary), Priya (supply side), Devon.

- FR-D1: Discover surfaces Open Tables filtered by city/geo-radius (default 8 miles, adjustable), date range (default next 14 days), and interest tag.
- FR-D2: Each Discover card shows: host first name + verified badge, host rating (if ≥ 5 rated Tables), interest tag, approximate neighborhood (exact address withheld until join), time, current fill (e.g., "3/6"), and cost band.
- FR-D3: A user must complete identity verification (government ID + selfie liveness check, per `SECURITY.md`) before they can either host an Open Table or join their first Open Table. Verification is one-time, not per-Table.
- FR-D4: Matching/ranking of Discover results considers: recency of posting, interest-tag affinity to the user's stated interests, geo-proximity, fill urgency (near-cap Tables surfaced to help them complete), and — critically — is never optimized for session time or scroll depth. There is no infinite feed; Discover is a bounded, paginated list capped at 40 results per query, refreshed on pull-to-refresh, not an algorithmic feed with autoplay-style engagement loops. This is a direct, deliberate implementation of the "real connection over engagement metrics" value.
- FR-D5: TableCrew+ subscribers receive priority placement (surfaced earlier in ties, not fake-boosted above better matches) and no service fee on any paid Discover Table (see `PRD.md` §9 and monetization notes below).
- FR-D6: A first-time Discover joiner sees a one-time, skippable but strongly encouraged safety briefing (public-place default for first meeting, tell-a-friend-where-you're-going prompt, report/block explainer) before their first join is confirmed.
- FR-D7: Exact venue address for Open Tables is revealed only after RSVP-yes, not before, to reduce address harvesting/scouting risk while still letting the neighborhood inform the decision to join.
- FR-D8: A Discover host can set a "new-to-Discover" filter requiring joiners to have attended at least 1 prior Open Table successfully (no reports, not a no-show) before joining theirs — an opt-in graduated-trust mechanism for hosts who want it, not a default gate that would suppress Maya's (the target persona's) very first join.
- FR-D9: Hosting an Open Table requires the stricter of the two verification tiers (ID + liveness, FR-D3) — there is no path to host on Discover with lesser verification, since hosts set the location and bear disproportionate trust weight.
- FR-D10: Typesense (selected over Algolia; see `ARCHITECTURE.md` §5.5 for the full cost and self-hosting rationale) powers Discover search/filtering with a p95 query latency target of 300ms.
- FR-D11: The reporting/blocking pipeline (FR-T30–33) is Discover's primary safety backbone and is shared, not duplicate, infrastructure with Crew/Table reporting — one report queue, one Trust & Safety review process, regardless of surface.

**Emergency and duress response during a live Table.** Nothing above addresses what happens if something goes wrong *during* a Table itself — someone feels unsafe, a medical issue arises, a fight breaks out. This is a missing-feature gap this PRD closes directly (see `LEGAL.md` §3 and `SECURITY.md` for the liability and incident-response context):

- FR-D12: The live Table screen (shown from check-in through the Table's Happened transition) surfaces a quick-exit/duress signal reachable in at most 2 taps, consistent with `SECURITY.md`'s reporting tap-count standard, and fully operable via VoiceOver/TalkBack (per NFR-9) — a safety feature that only works for sighted users defeats its own purpose. Triggering it opens a private in-app safety menu (discreet-exit guidance, one-tap report/block, and a direct real-time alert to Trust & Safety) without notifying other attendees that it was triggered. A duress signal is always classified and triaged as a SEV1 incident per `SECURITY.md`'s Incident Response severities, not routed through the standard 4-hour triage queue.
- FR-D13: The live Table screen displays the correct local emergency number for the Table's actual location (e.g., 112 in the EU, 999 in the UK, 911 in the US), sourced from a maintained country/locale emergency-number mapping — never hardcoded to a single country's number, which would actively mislead a user relying on it outside the U.S. and directly contradict the "anyone, anywhere" mission constraint.
- FR-D14: An opt-in **"share my location with a trusted contact for this Table"** feature: before or during a Table, a user may select one contact — an in-app Crew member, or someone outside the app via an SMS-shared link — to receive a live location share scoped to that specific Table only. The share auto-expires at the Table's Happened transition or after a fixed 6-hour ceiling, whichever comes first, and never persists as an always-on location share. Off by default, opt-in per Table, consistent with `VALUES.md`'s "Respect data like it's someone's actual life."

**TableCrew+ subscription — minimal v1 product requirements.** The commercial modeling for TableCrew+ lives in `INVESTOR_OVERVIEW.md`, but two product-level gaps must not be left unspecified, since a subscription with no defined upsell moment and no defined cancellation path is not a shippable feature:

- FR-D15: The primary in-app upsell surface for TableCrew+ appears at a defined, non-arbitrary trigger point — a free-tier user hitting a concrete need moment (e.g., attempting to host beyond the free tier's Table-per-month allowance, or viewing a near-cap Open Table where priority placement would meaningfully improve fill speed) — rather than a time-based nag. No more than one upsell surface is shown per session, mirroring the capped, non-nagging cadence already established for bill-split reminders (FR-T24).
- FR-D16: Self-serve cancellation/downgrade from account settings in at most 2 taps, effective at the end of the current paid billing period (never an immediate loss of already-paid days), with automatic reversion to free-tier limits and no forced re-onboarding. No retention dark patterns — confirm-shaming copy, a hidden or multi-step-obscured cancellation flow, or a non-dismissible retention-offer interstitial — per `VALUES.md`'s Hospitality principle. Stripe subscription webhooks drive this state change server-side (per `ARCHITECTURE.md`), never a client-only flag.

## 6. Non-Functional Requirements

### 6.1 Performance

- NFR-1: Cold app start to interactive home screen: ≤ 2.5s on a mid-tier device (e.g., iPhone 12 / Pixel 6 equivalent) on 4G.
- NFR-2: Table creation flow (FR-T1): ≤ 60 seconds, ≤ 4 taps to publish, measured via Firebase Analytics funnel (see `FIREBASE.md`).
- NFR-3: Discover query p95 latency: ≤ 300ms (FR-D10); p99 ≤ 800ms.
- NFR-4: Push notification delivery (RSVP updates, waitlist promotion): ≤ 10s p95 from server event to device receipt via Cloud Messaging.
- NFR-5: Chat message delivery: ≤ 1s p95 within an active session.

### 6.2 Internationalization

- NFR-6: All user-facing strings are externalized for localization from v1 (no hardcoded English strings), per `COPY_GUIDELINES.md`, even though Phase 0/1 ship English-only, because retrofitting i18n after Phase 2's international expansion (`ROADMAP.md`) is materially more expensive than building it in from day one. This is a direct expression of the "Global-first not US-first" value.
- NFR-7: Date/time, currency (for bill-splitting and TableCrew+ pricing), and distance units render per device locale, not hardcoded US formats.
- NFR-8: The interest-tag taxonomy and city/geo data model must not assume US-style addressing (ZIP codes, state fields) — addresses are stored as free-form + geocoordinates, per `DATABASE.md`.

### 6.3 Accessibility

- NFR-9: All screens meet WCAG 2.1 AA contrast and touch-target-size standards; full VoiceOver/TalkBack support for the core flows (create Table, RSVP, chat, rate) is a launch blocker, not a fast-follow.
- NFR-10: All flows are operable without relying on color alone (e.g., Table lifecycle states use icon + text + color, not color alone) — directly relevant to Grace's persona and to broader inclusive design commitments.
- NFR-11: Text scales to at least 200% via system font-size settings without clipping or truncation in any core flow.

### 6.4 Offline Behavior

- NFR-12: A user who loses connectivity mid-flow (e.g., composing a Table, mid-RSVP) never silently loses input; Firestore's offline persistence (per `FIREBASE.md`) queues writes and syncs on reconnect with a visible "will send when back online" indicator.
- NFR-13: Previously loaded Table details, Crew rosters, and chat history remain viewable read-only offline.
- NFR-14: RSVP and check-in actions taken offline are honored with their original client timestamp once synced, not the reconnect timestamp, to preserve fair waitlist ordering (FR-T16).

### 6.5 Legal, Eligibility, and Regulatory Requirements

- NFR-15: **Minimum age is 18, platform-wide, enforced at signup.** Account creation requires self-attested date of birth at Tier 1 (phone) verification, blocking signup outright for a stated age under 18. This is cross-checked, not just self-attested, at Tier 2 (ID + liveness) verification before a user can host or join any Open Table (`SECURITY.md` Tier 2): if the government ID's date of birth is inconsistent with the 18+ requirement, verification fails and the account is flagged for review rather than silently granted Discover access. This closes the age-gating decision that `LEGAL.md` §8 recommends and that was previously left open in `TASKS.md` — a lower age tier is not a partial feature to build toward, it is explicitly ruled out platform-wide, including for Closed/Crew-only use, because the operational cost of a parallel minors-safe system (parental consent, COPPA-compliant data handling) is not justified given Discover's in-person stranger-matching risk profile.
- NFR-16: **Per-state dating-/social-referral-service disclosure and cancellation-right UI is a configurable requirement, not a silent gap.** Per `LEGAL.md` §2, some U.S. states (e.g., New York under GBL §394-c, and similarly-postured statutes in California, New Jersey, and Texas) may classify Discover as a regulated "dating service" or "social referral service," requiring specific disclosures and cancellation rights before a paid membership is sold. TableCrew's Discover onboarding and TableCrew+ purchase flow must support a per-state feature flag that, when enabled for a given launch state, surfaces the required disclosure copy and cancellation-right mechanics before Discover access or a paid subscription is completed in that state. Where legal review for a given state is still pending, Discover does not go live in that state (this is the product-level enforcement of the gate already named in `ROADMAP.md`'s Legal and Regulatory Readiness Gates section) — the default is off/blocked, not on/unreviewed.

## 7. Explicit Out-of-Scope for v1

The following are deliberately excluded from Phase 0/1 scope, with rationale, to keep the team focused on proving the core loop rather than building a general-purpose social platform:

- **Public user profiles/feeds independent of Tables.** TableCrew is not building a scrollable profile-and-post social network; identity exists to support trust in Tables, not to be browsed for its own sake. Building this would directly contradict the "real connection over engagement metrics" value.
- **In-app video calling.** Out of scope because TableCrew's entire premise is in-person gathering; investing in a video layer would dilute focus and implicitly compete with the core behavior we're trying to build.
- **Group Tables above 8 people.** The platform-wide hard headcount ceiling is 2–8 (corrected 2026-08 from an earlier, looser 12-person ceiling — see `PRODUCT.md`'s headcount correction and `FEATURES.md`'s "Tables above 8 people" Won't row); this out-of-scope entry is stated here in its corrected form so this section doesn't independently drift from the ceiling actually enforced elsewhere in this document (FR-T2, FR-T17) and in `DATABASE.md`'s `capacity.max`. The product is deliberately optimized for small, conversational group sizes; large-event hosting is a different product with different safety and logistics needs, better served by other tools.
- **Automated AI-matched "blind date"-style 1:1 pairing.** v1 Discover is small-group only; 1:1 pairing introduces a materially different safety and expectation-setting surface that we are not ready to operate responsibly at launch.
- **Native web app / desktop client.** Mobile-only (Flutter iOS/Android) for v1; the core behaviors (RSVP on the go, push notifications, location) are mobile-native use cases, and a web client would fragment a small founding engineering team's focus (see `ARCHITECTURE.md`).
- **In-app ticketed/paid events beyond bill-splitting.** Full ticketing (tiered pricing, resale, box-office features) is a B2B2C-adjacent capability reserved for the Phase 4 Teams product and venue-partnership work in `ROADMAP.md`, not v1. (Bill-splitting itself ships in Phase 1, not Phase 0 — see Section 8.)
- **Public host "leaderboards" or gamified streak displays.** Ratings exist for trust, not competition; leaderboard/gamification mechanics are explicitly withheld because they optimize for the wrong thing relative to our values.
- **Cross-Crew merging or Crew discovery/marketplace.** Crews are private by design (FR-C5); making them discoverable is out of scope indefinitely, not just for v1, unless a future explicit product decision reverses that.
- **Multi-currency Stripe payouts to hosts.** Bill-splitting (Phase 1, not Phase 0 — see Section 8) is peer-to-peer reimbursement only, single currency per Table; host payouts/commissions (venue partnership money movement) are Phase 3 scope per `ROADMAP.md`.

## 8. Launch and Acceptance Criteria

Phase 0 (single-city MVP, Crew-first) is ready to launch when all of the following are true:

1. FR-T1–T33 (including FR-T9a, FR-T14a, FR-T14b, FR-T14c, FR-T29a) and FR-C1–C5 are implemented and pass `TESTING.md` acceptance suites, **except FR-T22–FR-T25a (bill-splitting)**, which are Phase 1 requirements, not Phase 0 launch blockers (Discover requirements FR-D1–D16 are likewise Phase 1, not launch blockers for Phase 0). *Corrected 2026-08: bill-splitting was previously bundled into this Phase 0 launch-blocker list, contradicting the founder-confirmed build order in `TASKS.md`, which sequences payments after Discover. Moved to align with `ROADMAP.md`'s corrected Phase 1 feature list — see `CHANGELOG.md`.*
2. NFR-1 through NFR-15 are met, measured on the target device matrix in `TESTING.md`. NFR-15 (18+ age gate) is a Phase 0 blocker, not Phase 1, since it governs account creation platform-wide, not just Discover access.
3. A closed beta cohort of at least 50 real users across at least 10 independent Crews has completed at least 2 full Table lifecycles (Proposed through Rated) each, with a post-Table satisfaction ("would sit at this table again") rate ≥ 80%.
4. Crash-free session rate ≥ 99.5% (Crashlytics, per `FIREBASE.md`) across the beta cohort for two consecutive weeks.
5. Trust & Safety reporting pipeline (FR-T30–33) is live and staffed, even though Phase 0 is Crew-first and lower-risk, because Closed-Table etiquette disputes still require a functioning path even without bill-splitting or Discover yet live.
6. No P0/P1 defects open in the release tracker (`TASKS.md`).

**Note on how this relates to `ROADMAP.md`'s Phase 0→1 success gate and `TASKS.md`'s Phase 0 "definition of done":** these are three distinct checkpoints across Phase 0's timeline, not three competing definitions of the same moment — an ambiguity a 2026-08 review found and this note resolves. In chronological order: **(a)** `TASKS.md`'s "at least 3 Crews each attend 2+ Tables within 6 weeks" is the earliest smoke-test milestone — proof the core loop works at all, reached well before closed beta ends; **(b)** this section's item 3 (50 users, 10 Crews, 2 full lifecycles, 80% satisfaction) is the closed-beta exit criterion — proof the product is ready to open beyond an invite-only cohort; **(c)** `ROADMAP.md`'s Phase 0 success gate (North Star metric ≥ 1.2 sustained 4 weeks, 40% second-Table-within-60-days, crash-free ≥ 99.5%, no unresolved P0 incidents) is the actual advancement gate to Phase 1 — proof the product sustains engagement past the beta cohort's honeymoon period, over a longer window, before Discover and multi-city expansion are introduced. Reaching (a) does not mean (b) or (c) are met, and reaching (b) does not mean (c) is met — they are sequential, not redundant.

Phase 1 (Discover introduction, 3-city launch) additionally requires:

1. FR-D1–D16 fully implemented and independently security-reviewed per `SECURITY.md`, with identity verification (FR-D3, FR-D9) live and enforced with zero known bypass paths. This explicitly includes the in-Table emergency/duress features (FR-D12–D14), which are launch blockers for Discover, not fast-follows — a stranger-matching surface without a duress signal or locale-correct emergency number is not safe to launch, per `LEGAL.md` §3.
2. The 4-hour Trust & Safety triage SLA (FR-T33) demonstrated in a dry run with simulated reports before real Discover traffic is admitted, including at least one simulated SEV1 duress-signal drill (FR-D12).
3. Discover no-show rate and report rate baselines established and within the guardrails defined in `SUCCESS_METRICS.md` during a limited-market soft launch before the full 3-city rollout.
4. NFR-16 (per-state dating-/social-referral-service disclosure UI) is confirmed enabled for every Phase 1 launch state where `LEGAL.md` §2 review has flagged it as applicable, and Discover remains gated off in any state where that review is still pending.

## 9. Values Check

Each requirement area above is evaluated against `VALUES.md`. Summary by area:

- **Tables (creation, RSVP, waitlist):** Upholds *Hospitality as design principle* (binary RSVP, no penalty-laden Maybe state, auto-cancel-suggestion rather than silent stranding) and *Bias toward shipping with rollback plans* (cap increases, visibility toggles are all reversible actions with guardrails, not one-way doors). Trade-off accepted: the strict 4-hour late-cancellation logging (FR-T13) adds minor friction for legitimately last-minute cancellers in exchange for protecting the group's trust in RSVPs holding.
- **Crews:** Upholds *Real connection over engagement metrics* — Crew chat is not engineered for daily-active engagement, and there is no push-notification pressure to open the Crew chat absent an actual pending Table decision. Trade-off accepted: no Crew discovery/growth loop (FR-C5) means Crews cannot be a viral acquisition engine, which we accept because privacy of an existing friend group outweighs growth convenience.
- **Discover:** Upholds *Safety is a feature not a department* most directly — mandatory verification before hosting/joining (FR-D3/D9), address-reveal-on-RSVP (FR-D7), and the 4-hour human triage SLA (FR-T33) are all costed, staffed commitments, not marketing claims. Trade-off accepted: mandatory ID verification adds meaningful friction to Maya's first-use funnel; we accept lower top-of-funnel conversion in exchange for a materially safer marketplace, consistent with *Safety is a feature not a department*.
- **Emergency/duress response (FR-D12–D14):** The most direct possible expression of *Safety is a feature not a department* — a duress signal, a correct local emergency number, and an opt-in trusted-contact location share are the product's answer to "what if it goes wrong in person," not just before or after. Trade-off accepted: the trusted-contact location share is opt-in and auto-expiring rather than always-on, per *Respect data like it's someone's actual life* — we accept that some users won't enable it in exchange for not building a default location-tracking feature that would itself be a privacy risk.
- **Bill-splitting:** Upholds *Respect data like it's someone's actual life* — payment data flows through Stripe (not stored raw by us) and reminder cadence is capped (FR-T24) rather than optimized for collection-rate maximization. The dispute/refund policy (FR-T25a) upholds *Hospitality as design principle* by defaulting to making the attendee whole rather than defaulting to the platform's convenience.
- **Ratings/Reviews:** Upholds *Hospitality as design principle* via positive-only tags (FR-T27) and a rolling-window minimum-sample display (FR-T29) that prevents a single incident from becoming a permanent scarlet letter, while *Safety is a feature not a department* is served by keeping negative signal exclusively in the reporting channel rather than public shaming. Simultaneous reveal (FR-T29a) is a direct extension of this same principle into the gaming/retaliation threat model, not a new value trade-off.
- **TableCrew+ conversion and cancellation (FR-D15/D16):** Upholds *Hospitality is a design principle, not a vibe* — the upsell trigger is tied to a genuine need moment rather than a nag, and cancellation is self-serve with no retention dark patterns, even though a more aggressive cancellation flow would likely reduce churn in the short term. Trade-off accepted: some recoverable churn is left on the table in exchange for not building a coercive cancellation flow.
- **Internationalization/Accessibility:** Directly implements *Global-first not US-first* (NFR-6–8) and general inclusive-design responsibility (NFR-9–11), accepted as a Phase 0 cost (slower initial ship, more upfront localization plumbing) in exchange for not re-architecting during Phase 3 international expansion. FR-D13's locale-aware emergency number (never hardcoded to 911) is a direct, load-bearing instance of this value, not a nice-to-have — a safety feature that only works in one country is a contradiction of "anyone, anywhere," not a detail.
- **Age gate and per-state legal UI (NFR-15/16):** Upholds *Safety is a feature not a department* — setting the floor at 18 platform-wide closes a real liability and COPPA exposure rather than maximizing addressable market. Trade-off accepted, and named honestly: this narrows "anyone, anywhere" (see `MISSION.md`'s own acknowledgment of that tension) further still, on age rather than documentation status — a cost we accept because the alternative (a lower-age tier for Crew-only use) would require Trust & Safety infrastructure not budgeted anywhere in this knowledge base.
