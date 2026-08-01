# TableCrew Feature Backlog

**Status:** Living document, v1.0
**Owners:** Product & Engineering
**Related docs:** `PRD.md`, `ROADMAP.md`, `SUCCESS_METRICS.md`, `VALUES.md`, `ARCHITECTURE.md`, `SECURITY.md`, `DESIGN_SYSTEM.md`, `LEGAL.md`

---

## How to Read This Document

Features are organized by theme, then prioritized using MoSCoW (Must / Should / Could / Won't for v1, where "v1" means the Phase 0 + Phase 1 horizon defined in `ROADMAP.md`). Every Won't and every Could carries a one-line justification, because an unexplained deprioritization is indistinguishable from an oversight, and this backlog is meant to be legible to any engineer picking up a single row without needing a meeting to understand why it's placed where it is. Must items are launch blockers for the phase noted; Should items are strongly desired and scheduled as immediate fast-follows; Could items are valuable but explicitly deferred; Won't items are deliberately out of scope, with a stated reason, distinct from the longer-form out-of-scope rationale in `PRD.md` §7.

---

## Theme: Tables

| Priority | Feature | Description | Justification |
|---|---|---|---|
| Must (P0) | Table creation flow (≤60s, ≤4 taps) | Core creation form: title, date/time, cap, visibility, location, optional tag/cost/photo. | The entire product's core loop starts here; see `PRD.md` FR-T1–T5. |
| Must (P0) | Table lifecycle state machine | Proposed → Filling → Confirmed → Happened → Rated, plus Cancelled. | Without a defined lifecycle, there is no shared mental model of "is this happening." |
| Must (P0) | Binary RSVP (Join / Can't make it) | No ambiguous "Maybe" state. | Directly evidenced as the #1 organizer pain point in `USER_RESEARCH.md`. |
| Must (P0) | Waitlist with auto-promotion | FIFO waitlist, 30-min accept window on promotion. | Prevents the "silent unfilled waitlist" failure mode common in incumbent tools. |
| Must (P0) | Table duplication ("host again") | Carry forward venue/cap/tag from a past Table. | Directly serves Priya's and Alex's repeat-hosting behavior. |
| Must (P0) | Auto-cancel-suggestion for under-filled Tables | Prompt host to cancel if under 2 confirmed attendees 2h before start, **plus continuous re-check through start time** (not a single checkpoint) so late cancellations after the 2h mark also trigger host notification and one-tap cancel/backfill/proceed options. | Prevents hosts being silently stranded, including the case where a Table clears the 2h check and then loses attendees anyway; see `PRD.md` FR-T14/FR-T14a. |
| Must (P0) | Confirmed-Table cancellation path | A Confirmed Table can still transition to Cancelled up until Happened (host emergency, venue closure with no relocation available). No payment/refund exposure by design, since bill-splitting only ever starts post-Happened. | Closes a lifecycle gap: the original state machine only allowed Cancelled from Proposed/Filling, leaving no defined path for a last-minute Confirmed-Table cancellation. See `PRD.md` FR-T14b. |
| Must (P0) | Host-initiated venue relocate flow (post-Confirmed) | Host changes venue/location on a Confirmed Table without cancelling and recreating it; all attendees get an immediate push + updated card. | Directly covers the venue-lifecycle edge case (partner venue closes permanently, or a Table's venue cancels the reservation last-minute) that had no defined flow; see `PRD.md` FR-T9a. |
| Should (P1) | Cap increase post-Confirmed | Host can raise cap to admit waitlisted members. | High value, low complexity fast-follow once base lifecycle ships. |
| Should (P1) | Location "TBD" with 24h-before confirmation deadline | Supports hosts who want to firm up venue later. | Common real-world hosting pattern surfaced in interviews; not required for MVP correctness. |
| Could | Multi-host / co-host Tables | Two or more people jointly own a Table's admin rights. | Real need for larger Crews but adds meaningful permission-model complexity; deferred to Phase 2 alongside Crew depth work. |
| Could | Table templates library | Pre-built templates beyond simple duplication (e.g., "game night," "potluck"). | Nice onboarding polish, not required to prove the core loop. |
| Deferred (Phase 1) | Recurring Table series (auto-generated weekly instances) | A single host action spawning a repeating series of Tables automatically — `scheduleRecurringTable`, `docs/API_SPEC.md`, `docs/SCREEN_SPECIFICATIONS.md` Screen 26. | **Corrected 2026-08:** this row previously said "Won't (v1)... superseded by" Phase 2's recurring-ritual nudge system — that was wrong and contradicted `PRD.md` FR-T14c and `API_SPEC.md`'s fully-specified `scheduleRecurringTable` endpoint, both of which describe this as a real, planned feature, not a cancelled one. The nudge system (Phase 2, below) is a *different, complementary* mechanism — a proactive prompt asking a Crew if they want to schedule their next gathering — not a superset that makes auto-generated recurring instances unnecessary. This feature is real but deferred out of Foundation into Phase 1, the same treatment bill-splitting already received; see `docs/IMPLEMENTATION_PLAN.md` §2.4. |
| Won't (v1) | Tables above 8 people | Raising the platform-wide hard headcount cap (corrected 2026-08 from an earlier, looser 12-person ceiling). | Changes the product category (event, not small gathering) and the safety model; see `PRD.md` §7. The recommended (not maximum) size still varies by activity per `PRODUCT.md`'s recommendation table — this row is about the hard ceiling, not the common case. |

## Theme: Crews

| Priority | Feature | Description | Justification |
|---|---|---|---|
| Must (P0) | Crew creation, persistent chat, roster (3–20) | Named group with shared chat and shared Table history. | Core object for Alex's persona; see `PRD.md` FR-C1. |
| Must (P0) | Crew-originated Table creation, pre-filled invitees | Any member proposes a Table defaulting to Closed, all-members-invited. | Directly operationalizes the "we just never land on a plan" research finding. |
| Must (P0) | Invite-only Crew joining (link or direct) | No public Crew discovery. | Preserves the privacy boundary between Crews and Discover; see `PRD.md` FR-C5. |
| Should (P1) | Shared Crew history view + "weeks since last Table" indicator | Lightweight dashboard of past Tables and gaps. | Foundation for Phase 2 recurring nudges; valuable even before automation ships. |
| Should (P1) | Organizer role (transferable) | One designated member responsible for recurrence configuration. | Needed ahead of Phase 2 automated nudges, but not needed for Phase 0 launch. |
| Could | Automated recurring-ritual nudges | "It's been 3 weeks, want to get the gang together?" proactive suggestion. | Deliberately Phase 2 per `ROADMAP.md` — needs real retention data to calibrate cadence rather than guessing. |
| Could | Crew-level non-competitive analytics (e.g., longest streak) | Private, Crew-facing-only usage reflection. | Valuable delight feature, explicitly not a public leaderboard; deferred until core recurrence feature ships. |
| Won't (v1) | Cross-Crew merging | Combining two Crews into one. | No evidenced user need, and increases roster-management complexity disproportionate to value. |
| Won't (v1) | Public/discoverable Crews | Making a Crew joinable by strangers. | Would collapse the Crew/Discover privacy boundary that is core to the safety model; permanent, not just a v1 deferral. |

## Theme: Discover

| Priority | Feature | Description | Justification |
|---|---|---|---|
| Must (P1) | Discover browse/search/filter (geo, date, tag) | Bounded, paginated (max 40 results), non-infinite-scroll listing. | Core Phase 1 feature; deliberately not an engagement-maximizing feed, per `VALUES.md`. |
| Must (P1) | Identity verification gate (ID + liveness) | Required before hosting or joining any Open Table. | Non-negotiable safety prerequisite; see `PRD.md` FR-D3/D9. |
| Must (P1) | Address-reveal-on-RSVP | Exact venue address withheld until join confirmed. | Reduces address-harvesting/scouting risk. |
| Must (P1) | Cross-user post-Table ratings (positive-tag model) | "Great conversation / On time / Would meet again" tags only. | Builds marketplace trust without enabling public shaming; negative signal routed to reporting instead. |
| Must (P1) | Simultaneous rating reveal | A rating is hidden from the rated party (and excluded from any visible aggregate) until both directions of a pairing are submitted, or 72 hours pass, whichever first. | Closes a real gaming/retaliation gap in the ratings system — without this, a party could see the other's rating first and retaliate or mirror it; see `PRD.md` FR-T29a. |
| Must (P1) | First-time safety briefing | One-time, skippable-but-encouraged briefing before first Discover join. | Cheap, high-leverage safety intervention validated by interview theme "the scary part is meeting alone." |
| Must (P1) | In-Table emergency/duress response | Quick-exit/duress signal on the live Table screen, locale-aware local emergency number (not hardcoded 911), opt-in "share my location with a trusted contact for this Table." | Nothing previously specified what happens if something goes wrong *during* a Table; a stranger-matching marketplace cannot launch without this. See `PRD.md` FR-D12–D14, `LEGAL.md` §3. |
| Should (P1) | "Prior successful Discover Table required" host-side filter | Opt-in graduated trust filter, not a default gate. | Valuable to risk-averse hosts without suppressing Maya's critical first join. |
| Should (P1) | TableCrew+ priority placement | Subscribers surfaced earlier in ranking ties. | Primary monetization lever; must not become pay-to-win over genuinely better matches. |
| Could | Interest-tag affinity learning | Improve tag-based ranking using accumulated rating/attendance history. | Needs months of real data to be meaningful; scheduled for Phase 2 per `ROADMAP.md`. |
| Could | Group-size-aware smart cap suggestions | Suggest an optimal cap based on tag/venue historical fill data. | Polish feature, not required for a functioning marketplace. |
| Won't (v1) | 1:1 blind-pairing / matching | Algorithmic pairing of two strangers rather than small-group Tables. | Different safety and expectation-setting profile the team is not ready to operate responsibly; see `PRD.md` §7. |
| Won't (v1) | Swipe/photo-primary browsing UI | Tinder-style card-swipe interaction model for Discover. | Directly contradicted by strong qualitative research signal that this UI paradigm feels "creepy by association" for platonic use cases. |

## Theme: Trust & Safety

| Priority | Feature | Description | Justification |
|---|---|---|---|
| Must (P0) | Report/block pipeline (single shared queue) | 2-tap reporting from any surface; unilateral silent blocking. | Foundational infrastructure; live from Phase 0 even before Discover exists, per `PRD.md` FR-T30–33. |
| Must (P0) | Human triage of safety reports, 4-hour SLA | 24/7 staffed review for in-person-safety-classified reports. | Operational, not just technical, commitment central to "Safety is a feature not a department." |
| Must (P1) | Identity verification service integration | Third-party ID + liveness check provider integrated via Cloud Functions. | Hard prerequisite for Discover; see `ARCHITECTURE.md`/`SECURITY.md`. |
| Should (P1) | Reliability signal (internal-only) | Tracks on-time %, late-cancellation rate per user, never shown as a public score. | Powers host rating display and repeat-offender detection without public shaming. |
| Should (P1) | Regional Trust & Safety review coverage | Expand beyond a single review desk as report volume grows with city count. | Scoped for Phase 2 scale-up per `ROADMAP.md`; not needed at 3-city volume. |
| Could | Automated risk-scoring pre-triage assist | ML-assisted flagging to help human reviewers prioritize queue order. | Valuable efficiency gain once report volume justifies the investment; humans remain the decision-makers regardless. |
| Won't (v1) | Public "trust score" numeric display | Showing a single blended numeric trust/safety score on profiles. | Reductive, easily gamed, and in tension with the positive-only public rating philosophy; internal reliability signal serves the real need without the public-shaming risk. |

## Theme: Notifications

| Priority | Feature | Description | Justification |
|---|---|---|---|
| Must (P0) | Push notifications for RSVP/waitlist/lifecycle events | Cloud Messaging-backed, ≤10s p95 delivery. | Core to the coordination value prop; a Table with no timely notifications is a Table nobody hears about. |
| Must (P0) | In-app notification center | Persistent list of Table/Crew updates. | Baseline expectation for any app with async social coordination. |
| Should (P1) | Notification preference controls (per-Crew, per-type mute) | Granular opt-out, not just a global on/off toggle. | Respects attention; a direct implementation of "real connection over engagement metrics" — we do not want to strong-arm re-engagement via notification pressure. |
| Could | Digest/summary notifications (e.g., weekly Crew activity roundup) | Batched, lower-frequency summary option. | Nice-to-have for lower-intensity users; not required to prove core loop. |
| Won't (v1) | Re-engagement "growth" notifications (e.g., "you haven't opened the app in 5 days") | Classic engagement-maximization push patterns. | Directly prohibited by `VALUES.md`'s stance against optimizing for DAU/session length. |

## Theme: Payments / Bill-Splitting

| Priority | Feature | Description | Justification |
|---|---|---|---|
| Must (P1) | Opt-in post-Table bill-splitting (even or custom split) | Host-initiated, Stripe-backed payment requests to attendees. | Directly evidenced hosting-friction reducer; see `PRD.md` FR-T22–25. **Corrected 2026-08:** moved from Must (P0) to Must (P1) — bill-splitting was previously misassigned to Phase 0, contradicting the founder-confirmed build order (`TASKS.md`), which sequences payments after Discover. See `ROADMAP.md` Phase 1 and `CHANGELOG.md`. |
| Must (P1) | Capped reminder cadence (max 2 reminders) | No more than one 48h and one 6h-before-expiry reminder. | Prevents nagging; a direct Hospitality-value trade-off decision. |
| Must (P1) | Bill-split payment dispute & refund flow | In-app flag on a specific payment request; billing-dispute case reviewed within 3 business days; attendee made whole by default if unresolved; repeat-offender hosts lose bill-splitting privileges. | Previously unspecified edge case — what happens when a charge is disputed or a host is unreliable after collecting payment info; see `PRD.md` FR-T25a. |
| Must (P1) | TableCrew+ subscription billing | Stripe subscription, no-service-fee benefit applied automatically. | Primary monetization lever per `PRODUCT.md`. |
| Must (P1) | TableCrew+ conversion trigger (defined upsell moment) | Upsell surfaced at a concrete need moment (hitting free-tier hosting limit, near-cap Open Table where priority placement helps), capped at one surface per session. | Previously absent: no defined free-to-paid conversion trigger existed anywhere in the product spec, a real gap for a subscription-first monetization model; see `PRD.md` FR-D15. |
| Must (P1) | TableCrew+ self-serve cancellation/downgrade | Cancel in ≤2 taps, effective end of billing period, auto-revert to free tier, no retention dark patterns. | Previously absent: no churn/cancellation flow was specified anywhere; see `PRD.md` FR-D16. |
| Should (P2) | Venue partnership commission accounting | Revenue-share tracking for featured/partner venue placements. | Scoped to Phase 3 per `ROADMAP.md`; not needed before venue partnerships exist. |
| Could | In-app tipping for hosts | Optional small tip to a frequent host. | Interesting idea, no clear research demand yet; risks feeling transactional in tension with Hospitality value — needs explicit future research before building. |
| Won't (v1) | TableCrew fee on peer-to-peer bill-splitting | Taking a cut of friends splitting a check. | Explicitly rejected monetization path; see `PRD.md` §3.6 — bill-splitting exists to reduce host friction, not to be a revenue surface. |
| Won't (v1) | Multi-currency host payouts | Cross-currency payment routing to hosts. | Deferred to Phase 3 international/venue-partnership money-movement work; premature before any non-U.S. market exists. |

## Theme: Venue Partnerships

| Priority | Feature | Description | Justification |
|---|---|---|---|
| Should (P3) | Featured Open Table placement for partner venues | Paid, clearly-labeled ("Sponsored") placement boost in **venue-suggestion surfaces only**, capped at no more than 30% of shown results in any single venue-suggestion list, and never appearing in Discover's person-to-person Table matching/ranking. | Second monetization pillar per `PRODUCT.md`; the cap is stated as a concrete number here (rather than left as "a defined share," which is a placeholder) because `VALUES.md`'s "Real connection over engagement metrics" line only has teeth if the cap is an actual, checkable number, not a vague future decision. |
| Must (P3) | Partner venue closure/deactivation handling | When a Featured/partner venue is marked permanently closed, or repeatedly cancels reservations, it is automatically pulled from Featured placement and default venue-suggestion results, and any Table currently scheduled there is flagged for the host relocate-prompt (`PRD.md` FR-T9a). | Previously undefined: a dead or unreliable partner venue would otherwise keep surfacing in suggestions and stranding hosts; this is the direct Featured-Venue-specific instance of the general venue-lifecycle gap closed in the Tables theme above. |
| Should (P3) | Venue partner dashboard (booking visibility, basic analytics) | Lightweight portal for partner venues to see upcoming TableCrew bookings. | Necessary operational tooling to make partnerships viable at scale, not needed for a handful of pilot partners run manually. |
| Could | Venue-side reservation system integration | Direct API integration with venue POS/reservation systems. | High engineering cost for marginal gain versus a manual pilot process; revisit once partner count justifies it. |
| Won't (v1) | Venue advertising / display ads | Traditional paid banner/display advertising from venues. | Explicitly rejected — TableCrew is not ad-supported, per `PRODUCT.md` monetization principles. |

## Theme: Internationalization

| Priority | Feature | Description | Justification |
|---|---|---|---|
| Must (P0) | Externalized strings / locale-ready architecture | No hardcoded English strings anywhere in the client, even at English-only launch. | Retrofitting i18n later is materially more expensive; see `PRD.md` NFR-6. |
| Must (P0) | Locale-aware date/time/currency/distance formatting | Render per device locale, not hardcoded US formats. | Direct implementation of "Global-first not US-first." |
| Must (P0) | Free-form + geocoordinate address model (no US-centric fields) | No assumed ZIP/state fields in the data model. | Prevents an expensive schema migration before Phase 3 expansion; see `DATABASE.md`. |
| Should (P3) | Full translation into first international market's primary language | Complete localized string set, not machine-translated. | Scoped to Phase 3 market entry per `ROADMAP.md`. |
| Could | Right-to-left (RTL) layout support | Full RTL UI adaptation. | Deferred until an RTL-language market is actually on the near-term roadmap, to avoid speculative investment. |
| Won't (v1) | Automatic machine-translation fallback for untranslated markets | Auto-translating UI on the fly for markets without full localization. | Risks a low-quality, potentially unsafe experience (mistranslated safety copy) — full human-reviewed translation is required before any market launch, per the pre-expansion research process in `USER_RESEARCH.md`. |

## Theme: Legal & Compliance-Driven UX

| Priority | Feature | Description | Justification |
|---|---|---|---|
| Must (P0) | 18+ age gate at signup | Self-attested date-of-birth captured at Tier 1 (phone) signup blocks account creation under 18; cross-checked against government-ID date of birth at Tier 2 verification before Discover access is granted. | Closes the previously-open 13-vs-18 question in `TASKS.md`, per `LEGAL.md` §8's recommendation; a materially higher liability/COPPA exposure than most peer products given Discover's in-person stranger-matching. See `PRD.md` NFR-15. |
| Must (P1) | Per-state dating-/social-referral-service disclosure & cancellation-right UI | Feature-flagged, per-state disclosure copy and cancellation-right mechanics surfaced before Discover access or a paid TableCrew+ purchase in any state where `LEGAL.md` §2 review flags the statute as applicable. Discover stays gated off in any state where that review is still pending. | Previously silent gap: `PRD.md`'s legal/non-functional requirements said nothing about state dating-service statutes despite `LEGAL.md` §2 identifying this as a real Phase 1 gating risk. See `PRD.md` NFR-16. |

## Theme: Accessibility

| Priority | Feature | Description | Justification |
|---|---|---|---|
| Must (P0) | WCAG 2.1 AA contrast and touch-target compliance | All core screens meet AA standard. | Launch blocker, not a fast-follow; see `PRD.md` NFR-9. |
| Must (P0) | VoiceOver / TalkBack support for core flows | Create Table, RSVP, chat, rate fully screen-reader operable. | Same as above; directly relevant to Grace's persona and general inclusive design commitment. |
| Must (P0) | No color-only state indication | Lifecycle states use icon + text + color. | Prevents excluding colorblind users from understanding Table status. |
| Should (P0) | Text scaling to 200% without clipping | System font-size settings respected across all core flows. | High-value, testable requirement; see `PRD.md` NFR-11. |
| Could | Full screen-reader support for secondary/admin flows (e.g., Crew settings) | Extend beyond the five core flows to all screens. | Valuable completeness goal; sequenced after core-flow accessibility is airtight. |
| Won't (v1) | Dedicated low-bandwidth/offline-first "lite" client | A stripped-down alternative client for constrained connectivity markets. | Valuable for future global expansion but premature before Phase 3 international markets are chosen; core offline behaviors (`PRD.md` NFR-12–14) cover the near-term need. |
