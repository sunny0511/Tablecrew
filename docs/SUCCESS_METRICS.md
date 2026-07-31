# TableCrew Success Metrics

**Status:** Living document, v1.0
**Owners:** Product & Data
**Related docs:** `PRD.md`, `ROADMAP.md`, `FEATURES.md`, `VALUES.md`, `USER_RESEARCH.md`, `ARCHITECTURE.md`, `FIREBASE.md`, `INVESTOR_OVERVIEW.md`

---

## 1. North Star Metric

**Tables Attended per Active User per Month (TAAU).**

Definition: for each user active in a given calendar month (defined as having opened the app at least once), count the number of distinct Tables they attended (checked in as Happened, not merely RSVP'd) that month, then average across all active users.

### Why TAAU, and not DAU or session time

The obvious, industry-default North Star candidates for a mobile social app are Daily Active Users and average session time. We explicitly reject both, and the reasoning is not incidental — it is a direct load-bearing consequence of `VALUES.md`'s "Real connection over engagement metrics" principle, which states plainly that we do not optimize for session length or DAU/MAU. Optimizing for DAU would reward building reasons to open the app that have nothing to do with gathering around a table — a notification feed, a scrollable Discover surface with infinite content, streaks and badges — precisely the mechanics our own research (`USER_RESEARCH.md`) found target users are actively suspicious of and fatigued by. Optimizing for session time is worse still: the ideal TableCrew session is short (open the app, RSVP or check a detail, close it) because the point of the product is to get people to close the app and go sit at a real table with real people. A product whose success metric rewards long in-app sessions is a product whose incentives point away from its own mission.

TAAU instead measures the one outcome that is inseparable from the mission itself: are people actually, physically, sitting down with other people, and is that happening at a healthy, repeatable cadence (the "per month" cadence is deliberate — it captures recurrence, not just a single successful onboarding event). A user who attends zero Tables in a month contributes a zero to this metric regardless of how much time they spent browsing Discover, which is exactly the discipline we want: browsing without attending is not success.

TAAU is not a perfect metric — it can be gamed at the margin by encouraging attendance at low-quality Tables, which is why it is never read in isolation from the guardrail metrics in Section 4 (in particular, no-show rate and post-Table rating quality), which together prevent "just get people to any Table" from becoming a perverse incentive.

## 2. North Star Targets by Phase

Per `ROADMAP.md` phase definitions:

| Phase | TAAU Target | Notes |
|---|---|---|
| Phase 0 (single city, Crew-first) | ≥ 1.2 | Sustained for 4 consecutive weeks across a stable cohort; the Phase 0→1 success gate in `ROADMAP.md`. |
| Phase 1 (3-city, Discover introduced) | ≥ 1.5 | Must hold or improve versus Phase 0 baseline — Discover must not cannibalize Crew-driven attendance. |
| Phase 2 (25-city, recurring rituals) | ≥ 2.0 | Recurring-ritual nudges are explicitly expected to be the primary driver of this increase. |
| Phase 3 (international + venues) | ≥ 2.0 sustained in first international market within 6 months of launch | Proves the model transfers, not just the U.S. cultural context. |
| Phase 4 (Teams B2B2C) | Tracked separately per organization cohort | Employer/university-sponsored usage is measured against its own baseline, not blended into consumer TAAU, since the purchasing motive differs. |

## 3. Supporting Metrics by Funnel Stage

### 3.1 Acquisition

- **Cost per Verified Signup** — paid/organic blended acquisition cost, measured through standard mobile attribution plus Firebase Analytics install-to-signup conversion. Tracked, but deliberately not the primary metric leadership optimizes for in Phase 0/1, since cheap signups that never attend a Table are a vanity outcome.
- **Signup → First Table Proposed or Joined (7-day conversion)** — percentage of new signups who either create or join at least one Table within 7 days. Target: ≥ 45% by end of Phase 1. This is the earliest meaningful signal that acquisition is bringing in the right kind of user (someone with genuine intent to gather), not just app-store browsers.
- **Organic share of signups** — percentage of signups attributable to referral/word-of-mouth versus paid channels, tracked via Firebase Analytics attribution and in-app invite-link tracking. A social-coordination product with a healthy core loop should show a rising organic share over time (a Crew invite is itself a growth loop); a persistently low organic share would be an early warning that the product isn't naturally spreading through real social graphs the way the thesis assumes.

### 3.2 Activation

- **First Table Attended (not just RSVP'd) within 14 days of signup** — target ≥ 35% by end of Phase 0, ≥ 42% by end of Phase 1. This is measured via the Happened lifecycle transition, not the RSVP action, because RSVP-without-attendance is not activation — it's an intention, and our research found intentions are exactly what fail to convert to real gatherings today.
- **Time-to-First-Table** — median elapsed time from signup to first Happened Table. Target: ≤ 9 days by end of Phase 1. Faster time-to-value correlates strongly with retention in early cohort data patterns typical of coordination products, and matches the qualitative finding that momentum (not deliberation) is what gets a first gathering to actually happen.
- **Second Table Attended within 60 days of first** — target ≥ 40% by end of Phase 0 (this is also the explicit Phase 0→1 launch/success gate defined in `PRD.md` §8 and `ROADMAP.md`). This is arguably the single most important activation metric in the entire document, because a product that gets someone to one Table but not a second has not yet proven it builds recurring social life — it has only proven it can run a single event, which Meetup and Eventbrite already do.

### 3.3 Retention

- **8-Week Retained Attendance Rate** — percentage of a signup cohort that has attended at least one Table in each of weeks 5–8 following signup (a rolling-window measure, not just "still opened the app"). Target: ≥ 25% by end of Phase 1, ≥ 32% by end of Phase 2 as recurring rituals mature.
- **Crew Persistence Rate** — percentage of Crews that create at least one new Table within any rolling 6-week window, measured continuously. Target: ≥ 55% by end of Phase 2. This is the direct, measurable expression of whether Crews are becoming a genuine recurring ritual or a one-time novelty.
- **Monthly TAAU distribution (not just mean)** — we track the full distribution, not only the mean North Star figure, specifically watching the share of active users at TAAU = 0 (attended nothing this month despite opening the app). A rising zero-TAAU share is an early churn-risk signal well before it shows up in raw retention curves.

### 3.4 Host-Side Supply Health

Discover is a marketplace, and a marketplace's health is inseparable from the health of its supply side (hosts), not just its demand side (joiners) — this section exists because a common failure mode in this product category is measuring only whether people can find something to join, while quietly running out of people willing to host.

- **Active Hosts per City per Month** — count of unique users who created and confirmed at least one Table (Open or Closed) in the trailing 30 days, per city. Tracked per city, not just in aggregate, because Phase 1/2's multi-city expansion could hide a struggling individual market inside a healthy blended number.
- **Host Repeat Rate** — percentage of hosts who host a second Table within 45 days of their first. Target: ≥ 50% by end of Phase 1. Priya's persona is defined by repeat hosting; if this number is weak, the supply side of Discover will not scale regardless of demand-side growth.
- **Open Table Fill Rate** — percentage of Open Tables that reach Confirmed status (not just Proposed/Filling) before their start time. Target: ≥ 70% by end of Phase 1, rising to ≥ 78% by end of Phase 2 as matching quality improves. A chronically low fill rate is the leading indicator of host churn — nothing discourages a host faster than an empty table.
- **Host Rating Trend** — the rolling 90-day aggregate host rating distribution across the marketplace (not any single host's score, but the shape of the whole distribution). A healthy marketplace should show the bulk of active hosts clustering in a positive band; a bimodal distribution (many very high, a growing tail very low) would indicate a host-quality problem that needs intervention.

### 3.5 Safety and Trust Health

Safety metrics are treated as a first-class, permanently-tracked category, not an incident log reviewed only when something goes wrong, in direct service of "Safety is a feature not a department."

- **Report Rate** — reports filed per 1,000 Tables attended, tracked separately for Closed (Crew) and Open (Discover) Tables, since their baseline risk profiles differ substantially. Tracked as a guardrail (Section 4), not a target to minimize by suppressing reporting — a rising report rate driven by more people confidently using the report feature is a different (better) signal than one driven by more actual incidents, and we investigate rate changes qualitatively before reacting to the number alone.
- **Triage SLA Compliance** — percentage of in-person-safety-classified reports triaged by a human reviewer within the 4-hour SLA defined in `PRD.md` FR-T33. Target: ≥ 98% by the time any Discover traffic goes live, tracked continuously thereafter as an operational health metric, not just a launch gate.
- **Verification Completion Rate** — percentage of users who start identity verification (FR-D3) who complete it successfully. Tracked to catch verification-flow friction or fraud-detection false-positive problems early, since a broken verification funnel would silently suppress Discover's entire supply and demand side.
- **No-Show Rate** — percentage of confirmed RSVPs who do not check in to a Table they committed to. This is simultaneously a safety-adjacent metric (repeated no-shows erode the trust the whole system depends on) and a product-quality metric, and is one of the two guardrail metrics explicitly named in the assignment brief for this document (see Section 4).
- **Duress Signal Rate** — count of `duress_signal_triggered` events (`FIREBASE.md` §2.9) per 10,000 Tables attended, tracked as a permanent trend line rather than a guardrail with a numeric ceiling: `SECURITY.md`'s In-Table Emergency and Duress Response already treats every single occurrence as an automatic SEV1 with a 15-minute acknowledgment target regardless of volume, so there is no "acceptable rate" to tolerate the way there is for report rate or no-show rate — the point of tracking this metric is capacity planning (does Trust & Safety on-call staffing keep pace with volume, per `SECURITY.md`'s surge-staffing protocol) and trend detection (a rising rate, even with every individual case handled correctly, is itself a signal worth investigating), not a threshold to stay under. This metric did not exist before this document's `FIREBASE.md`-cross-referenced audit added the underlying event to the canonical analytics table — a duress signal was previously a fully-specified product and engineering flow with no corresponding metric anywhere, which is exactly the kind of gap Section 5's "traceable to a specific, named event" standard exists to catch.

### 3.6 Monetization: TableCrew+ Conversion and Retention

This subsection did not previously exist, which was itself a gap: `ROADMAP.md`'s Phase 1→2 success gate refers to "TableCrew+ conversion reaches the Phase 1 target defined in `SUCCESS_METRICS.md`" — a target that this document did not actually define anywhere. That is now fixed.

- **Free-to-Paid Conversion Rate** — percentage of active users (per the North Star definition's "opened the app at least once" cohort) who convert to a paid TableCrew+ subscription within 60 days of their conversion-trigger moment (`PRD.md` FR-D15 defines the trigger: hitting the free-tier hosting allowance, or viewing a near-cap Open Table where priority placement would help). Computed from the `subscription_started` event (`FIREBASE.md` §2.9). Target: **≥ 8% by end of Phase 1**, rising to **≥ 12% by end of Phase 2** as Discover matching quality and recurring-ritual value (both increasing the value of priority placement and unlimited hosting) mature. This is the number `ROADMAP.md`'s Phase 1 gate refers to.
- **30-Day Post-Trigger Conversion Latency** — median time from a user first encountering the FR-D15 upsell trigger to completing a paid conversion (or explicitly dismissing it), i.e. to a `subscription_started` event. Tracked to confirm the upsell moment is well-targeted rather than nagging users who need multiple exposures before converting, or converting so fast it suggests the trigger fires on genuine need rather than an arbitrary timer.
- **Voluntary Cancellation Rate (monthly)** — percentage of active TableCrew+ subscribers who cancel in a given month via the self-serve flow (`PRD.md` FR-D16), computed from the `subscription_cancelled` event (`FIREBASE.md` §2.9). Tracked as a guardrail-adjacent health metric, not just a revenue number: because FR-D16 explicitly prohibits retention dark patterns, this number is expected to be a truer signal of product-market fit for the paid tier than a cancellation rate suppressed by a hard-to-find cancel button would be. A rising rate is investigated for root cause (value gap vs. price sensitivity vs. a specific broken subscriber benefit) before any change to the cancellation flow itself is considered, since making cancellation harder is explicitly out of bounds per `VALUES.md`.
- **Win-Back Rate** — percentage of voluntarily-cancelled subscribers who re-subscribe within 90 days, computed by joining a `subscription_cancelled` event against a later `subscription_started` event for the same user within that window (`FIREBASE.md` §2.9) — neither underlying event was actually defined in `FIREBASE.md`'s canonical table until this audit, which meant this metric had no concrete way to be computed despite being named here. That gap is now closed. A meaningful win-back rate is evidence that cancellation friction isn't being used as a growth lever elsewhere in the funnel (i.e., people who leave can and do come back on their own terms).

## 4. Guardrail Metrics

Guardrails are metrics that must not regress as we push the North Star and supporting metrics upward — they exist specifically to prevent the North Star from being gamed or pursued in a way that violates `VALUES.md`. Any release or growth initiative that improves TAAU while regressing a guardrail below its stated threshold is treated as a net failure, not a net win, and is escalated for review before shipping further in that direction.

**A note on why some numbers below look inconsistent with `ROADMAP.md`/`PRD.md` at first glance, and are not:** a guardrail threshold in this section is deliberately set as a permanent, ongoing *floor* — the level below which we treat a metric as a production incident, forever, at any scale. A phase-gate target in `ROADMAP.md` or a launch-acceptance criterion in `PRD.md` §8 can legitimately be a stricter, higher bar than the floor here, because a closed beta or a pre-launch dry run is expected to demonstrate a cleaner result than the ongoing floor we're willing to tolerate once real, larger-scale production traffic (with all the edge cases a beta cannot surface) is live. Concretely: `PRD.md` §8 and `ROADMAP.md`'s Phase 0 gate require crash-free session rate **≥ 99.5%** to be demonstrated in the pre-launch beta cohort before Phase 0 ships; the guardrail below sets the ongoing floor at **≥ 99.3%**, intentionally slightly more permissive, so that ordinary post-launch variance at real scale doesn't trigger a false-alarm guardrail breach the day after a clean beta. If this gap is ever read as a silent drift rather than a deliberate design choice, it isn't — it's this paragraph.

| Guardrail | Threshold | Why it must not regress |
|---|---|---|
| No-show rate (confirmed RSVP → did not attend) | Must stay ≤ 12% for Closed Tables, ≤ 15% for Open Tables | A rising no-show rate driven by growth pressure (e.g., pushing users into more Tables than they meaningfully intend to attend) would directly undermine the trust the entire RSVP model depends on. |
| Report rate (safety-classified reports per 1,000 Open Table attendances) | Must stay ≤ 3 per 1,000, investigated qualitatively above 2 per 1,000 | A rising rate of genuine safety incidents (as distinct from rising reporting confidence, which is monitored separately via report resolution outcomes) would be a direct failure of the safety model that no amount of North Star growth justifies tolerating. |
| Triage SLA compliance | Must not fall below 95% in any rolling 30-day window | A slipping SLA under growth pressure is an early warning that Trust & Safety staffing hasn't kept pace with volume — a leading indicator, not a lagging one, and treated with the urgency of a production outage. |
| Crash-free session rate | Must stay ≥ 99.3% | A product whose core promise is "show up for real people at a real time" cannot tolerate reliability regressions; a crash during RSVP or check-in has real-world consequences (a stranded host, a missed Table) beyond a typical app bug. |
| TableCrew+ non-paying user experience parity | Free-tier users must not see degraded core-flow performance (Table creation, RSVP, chat) relative to subscribers — only the stated subscriber benefits (priority placement, no service fee, unlimited hosted Tables) may differ | Ensures monetization pressure never creates an artificially degraded free experience to coerce upgrades, consistent with treating TableCrew+ as a value-add, not a paywall on core functionality. |
| Zero-TAAU share of active users | Must not exceed 35% of the monthly active cohort | Caps how large the "opens the app but never actually gathers" segment is allowed to grow to before it signals the product is drifting toward engagement without connection — the exact failure mode the North Star metric is designed to prevent. |

## 5. Measurement Infrastructure

All metrics in this document are computed from event-level data captured via Firebase Analytics at the client and server (Cloud Functions) layer, exported nightly to BigQuery for the cohort, funnel, and distribution analysis described above (per `FIREBASE.md` and `ARCHITECTURE.md`). Lifecycle-state transitions (Proposed/Filling/Confirmed/Happened/Rated), RSVP actions, report/block events, and verification completions are all first-class logged events with dedicated BigQuery tables, not inferred from proxy signals, so that every metric in this document is traceable to a specific, named event rather than a heuristic estimate. Crash-free session rate is sourced directly from Crashlytics. Dashboards for the North Star metric, all Section 3 supporting metrics, and all Section 4 guardrails are reviewed weekly by Product and Engineering leadership, with the full guardrail table specifically reviewed before any release that materially changes the Table creation, RSVP, Discover matching, or Trust & Safety flows — ensuring guardrail review is a release-process gate, not merely a retrospective dashboard.
