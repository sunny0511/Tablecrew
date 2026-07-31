# TableCrew Roadmap

**Status:** Living document, v1.0
**Owners:** Product & Leadership
**Related docs:** `PRD.md`, `FEATURES.md`, `SUCCESS_METRICS.md`, `USER_PERSONAS.md`, `USER_RESEARCH.md`, `VALUES.md`, `PRODUCT.md`, `VISION.md`

---

## Sequencing Philosophy

Before the phases: two sequencing decisions run through this entire roadmap and are worth stating explicitly, because they will look conservative next to what a growth-at-all-costs competitor would do, and that is intentional.

**Why Crew-first before Discover-first.** Discover — matching strangers into small groups — is the more differentiated, more press-worthy, and more safety-sensitive half of the product. It is tempting to lead with it. We don't, for two reasons grounded in `USER_RESEARCH.md`. First, the single most evidenced finding in our research is Alex's problem ("I have people, we just never land on a plan"), not Maya's — meaning the Crew-first loop has the shortest path to a working, valuable product with the least novel trust infrastructure required. Second, Discover requires identity verification, a Trust & Safety triage operation staffed 24/7, and a report/block pipeline proven under real load before we can respectably put a stranger meetup marketplace in front of the public — building that safety backbone against a live Crew-first user base lets us pressure-test the reporting pipeline on lower-stakes etiquette disputes before it has to handle in-person-safety-critical Discover reports. Shipping Discover before that infrastructure is proven would be a direct violation of "Safety is a feature not a department."

**Why density-first over broad geographic coverage.** A Table needs a critical mass of nearby, active users to reliably fill; a product that is thinly spread across 50 cities with a handful of users each produces mostly empty, unfilled, demoralizing Tables — the worst possible first impression, and one that is very hard to win a user back from. We instead concentrate all early growth spend and manual host-recruitment effort into a single city (Phase 0) and then a small cluster of cities (Phase 1) chosen specifically for the demographic density of Maya- and Alex-type users identified in `USER_RESEARCH.md`, expanding geography only once we have evidence that density, not exposure, is the binding constraint on activation.

---

## Phase 0 — MVP: Single City, Crew-First Only

**Timeframe:** Months 0–4 (target: launch by end of Q4 following kickoff)

**Anchor city (decided 2026-08, closing the open item previously tracked in `TASKS.md`): Hyderabad, India.** This is a deliberate India-first launch, not a U.S. pilot followed by an India expansion — see the note at the end of Phase 3 below, which corrects this roadmap's original framing now that the home market is set. Hyderabad was chosen for the density-first reasons this roadmap already argues for in the abstract (a large, English-proficient-and-multilingual, relocation-heavy tech-worker population with exactly the "new-to-city professional" and "friend group that never lands on a plan" profiles `USER_RESEARCH.md` identifies) rather than because it is the largest Indian metro by population — consistent with the density-first, not-biggest-market logic already used for Phase 1 city selection below.

**Goal:** Prove that Crews and Tables, on their own, without any stranger-matching feature, get real friend groups to gather more often and more easily than a group chat does. Phase 0 deliberately does not attempt to prove the harder, more novel Discover thesis yet — it proves the foundational coordination thesis first.

**Target persona unlocked:** Alex (Friend-Group Organizer), primarily; Priya begins using the product in her Crew-hosting capacity even though Discover (her true supply-side surface) doesn't exist yet.

**Key features shipped** (see `FEATURES.md` for full backlog detail): Table creation and lifecycle (Proposed→Filling→Confirmed→Happened→Rated) for Closed Tables only; Crew creation and persistent chat; binary RSVP; waitlist; per-Table ephemeral chat; post-Table ratings (host-facing "would sit again," no cross-user rating yet since Crew members already know each other); basic push notifications; core Trust & Safety reporting/blocking pipeline (live from day one even though Discover doesn't exist, because Closed-Table disputes still need a path, and because we want the pipeline pressure-tested before Phase 1 raises the stakes).

**Explicitly not shipped yet:** Discover surface, identity verification, Open Tables, bill-splitting/payments, venue partnerships, recurring-ritual automation (Crews exist and have history, but the proactive "it's been 3 weeks, want to get the gang together?" nudge is Phase 2). *Corrected 2026-08 (architecture readiness/implementation-planning pass): bill-splitting was previously listed as a Phase 0 feature here, contradicting the founder-confirmed build order in `TASKS.md`, which sequences payments after Discover. The founder's build order is authoritative; bill-splitting now ships in Phase 1 (below), alongside the introduction of monetization more broadly. See `CHANGELOG.md`.*

**Success gate to advance to Phase 1** (see `SUCCESS_METRICS.md` for full definitions): sustained North Star metric (Tables Attended per Active User per Month) ≥ 1.2 across a stable single-city cohort for 4 consecutive weeks; ≥ 40% of users who attend a first Table attend a second within 60 days; crash-free session rate ≥ 99.5%; no unresolved P0 Trust & Safety incidents. We do not advance on vanity metrics like total downloads or DAU — consistent with `VALUES.md`'s rejection of engagement-maximization as a success framework.

**Why this sequencing:** A single city lets us hand-hold early Crews (founder-led onboarding, manual host encouragement) at a level of intimacy that would be operationally impossible across multiple markets, and it lets us fully validate the coordination thesis (Crews > group chats) before spending any effort on the harder trust-and-safety-laden Discover problem.

---

## Phase 1 — 3-City Launch, Discover Introduced

**Timeframe:** Months 5–11

**Goal:** Introduce Discover — the stranger-matching, Open Table marketplace — in a small, dense multi-city footprint, and prove it can operate safely at real (if modest) volume before any broader scale-up.

**Target personas unlocked:** Maya (New-to-City Professional) becomes fully served for the first time; Priya gains her primary supply-side surface (hosting Open Tables, building a public host rating); Devon begins to be served as a secondary beneficiary of Discover in dense professional metros.

**Key features shipped:** Identity verification (ID + liveness check) as a hosting/joining gate for Open Tables; Discover browse/search/filter surface (Typesense-backed, per `ARCHITECTURE.md`); Open Table visibility and address-reveal-on-RSVP; cross-user post-Table ratings (positive-tag model); the 24/7 human Trust & Safety triage operation, staffed and drilled against a 4-hour SLA before real Discover traffic is admitted; TableCrew+ subscription tier launches (priority Discover placement, no service fee, unlimited hosted Tables) as the first monetization surface; **bill-splitting** (peer-to-peer, single-currency, opt-in per Table — moved here from an earlier, incorrect Phase 0 placement, since it's naturally sequenced alongside Discover/monetization per the founder-confirmed build order in `TASKS.md`, and both a UPI-capable India payment rail and the Stripe/India merchant-account question need to be resolved before it ships regardless of exact timing within this phase).

**City selection criteria:** the second and third cities are chosen using the density-first logic above — cities scoring highest on relocation rate, professional-population density, and interest-tag diversity from `USER_RESEARCH.md`'s screening criteria, not simply the largest metros by population. Given the Hyderabad anchor above, Phase 1's next two cities are drawn from the same-country expansion sequence — Bangalore and Pune are the leading candidates on this screening logic (both are large, high-relocation-rate tech-worker hubs), with Chennai, Mumbai, and Delhi as the subsequent Phase 2 wave before any international market is considered; final city 2/3 selection is confirmed against live Phase 0 data, not fixed in advance of it.

**Success gate to advance to Phase 2:** Discover no-show rate and report rate within the guardrail bands defined in `SUCCESS_METRICS.md`, sustained for 8 consecutive weeks across all three cities; North Star metric holds or improves versus the Phase 0 baseline (i.e., introducing Discover does not cannibalize Crew engagement); TableCrew+ conversion reaches the Phase 1 target defined in `SUCCESS_METRICS.md`, establishing monetization viability before we scale further; zero unresolved P0 safety incidents and the 4-hour triage SLA met at ≥ 98% compliance.

**Why this sequencing:** We deliberately hold Discover to three cities — not one, to prove the safety and matching model isn't a single-market fluke, and not ten, to keep the Trust & Safety operation's headcount and review load manageable while we learn what "normal" report volume and severity actually look like in production, something no amount of pre-launch planning can substitute for.

---

## Phase 2 — Crew Depth + Recurring Rituals, Scale to 25 Cities

**Timeframe:** Months 12–20

**Goal:** Deepen the Crew experience with automated recurring-ritual nudges (turning "we should do this again" into a proactive product feature) and scale geographic footprint from 3 to roughly 25 cities, now that both halves of the core product (Crew-first and Discover-first) are proven independently.

**Target personas unlocked:** Devon becomes a fully first-class persona as recurring rituals directly solve the "no natural trigger to meet up" problem central to his research profile; Grace's long-horizon validation work begins here — Phase 2 is when we run the dedicated 55+ research wave referenced in `USER_RESEARCH.md` §7 and begin deliberately testing whether the product generalizes to her needs, ahead of any dedicated feature investment for her segment.

**Key features shipped:** Automated Crew recurrence nudges (configurable cadence, e.g., "suggest a new Table 3 weeks after the last one," per `FEATURES.md`); Crew-level analytics ("your Crew's longest streak," used sparingly and never as a public leaderboard, per the Values Check pattern in `PRD.md`); expanded interest-tag taxonomy and improved Discover matching quality using a full 6+ months of rating/attendance data; localization infrastructure exercised for the first time in non-English-majority U.S. metro pockets as a rehearsal for Phase 3; continued Trust & Safety scaling (regional review coverage, not just a single 24/7 desk, as report volume grows with city count).

**Success gate to advance to Phase 3:** North Star metric sustained ≥ target across the full 25-city footprint (not just the original 3); recurring-ritual adoption reaches the Phase 2 target in `SUCCESS_METRICS.md` (a meaningful share of active Crews using automated nudges, with nudge-driven Tables showing attendance quality on par with organically-initiated ones); host-side supply health metrics (active hosts per city, host retention) hold steady through the 3-city-to-25-city scale-up, proving the operational model (host recruitment, Trust & Safety staffing) scales roughly linearly rather than breaking down; TableCrew+ revenue run-rate reaches the threshold set in `INVESTOR_OVERVIEW.md` financial planning as the gate for justifying international investment.

**Why this sequencing:** 25 cities is chosen deliberately as "many, but not global" — enough to prove the operating model scales operationally (support, safety, host recruitment) without yet taking on the added complexity of cross-border payments, localization, and jurisdiction-specific safety/legal requirements that Phase 3 introduces. Recurring rituals are sequenced here, not earlier, because they only make sense once we have real Crew retention data to know what cadence to suggest — building this on Phase 0 assumptions instead of Phase 1/2 behavioral data would mean guessing.

---

## Phase 3 — International Expansion + Venue Partnerships

**Timeframe:** Months 21–32

*Corrected 2026-08: this phase's original framing assumed a U.S.-first home market ("expand beyond the U.S. for the first time"), written before the Phase 0 anchor city was fixed. The home market is Hyderabad, India (see Phase 0), so "international expansion" here means the first market entry outside India, not outside the U.S. — the United States is, if anything, itself a later international market for this company, not the default first one. This correction should be read alongside `LEGAL.md`, `INVESTOR_OVERVIEW.md`, and `SECURITY.md`, none of which have yet been fully re-threaded for an India-first home market; see `CHANGELOG.md`'s 2026-08 entry and `TASKS.md` for the tracked follow-up.*

**Goal:** Expand beyond India for the first time, and introduce venue partnerships (commissions, featured placements) as the second monetization pillar, now that the core product has been validated across enough Indian markets and personas to justify the added operational complexity of both moves at once being sequenced deliberately apart from each other in practice (venue partnerships pilot domestically first, before being extended internationally).

**Target personas unlocked:** No new named persona — this phase is about proving Grace, Devon, Maya, Alex, and Priya all generalize outside a U.S. context, directly serving the "Global-first not US-first" value by putting real investment behind it rather than treating it as a slogan.

**Key features shipped:** Venue partnership program (featured Table placements at partner restaurants/venues, commission-based revenue share, piloted in 2–3 Phase 2 U.S. cities before international rollout); full multi-currency support for bill-splitting and TableCrew+ pricing; first international market entry (a single country, chosen via the pre-expansion market research process defined in `USER_RESEARCH.md` §7, likely an English-language or high-English-proficiency market first to reduce compounding risk before tackling full translation); localized Trust & Safety operating procedures accounting for jurisdiction-specific legal requirements (data residency, identity verification method differences, local emergency-service integration guidance).

**Success gate to advance to Phase 4:** first international market hits the same North Star and safety guardrail thresholds required of a mature U.S. city within 6 months of launch (proving the model, not just the U.S. cultural context, is what's working); venue partnership revenue reaches a defined percentage of total revenue per `INVESTOR_OVERVIEW.md`, validating it as a real second pillar rather than a rounding error; no jurisdiction-specific safety or legal incidents that would indicate the localized T&S process is under-built.

**Why this sequencing:** Venue partnerships are introduced before Phase 4's B2B2C product deliberately, because they are the more organic, closer-to-core-user extension of the existing marketplace (a restaurant wanting Tables filled is a direct extension of Priya's and Maya's existing behavior), whereas Teams is a genuinely different go-to-market motion (enterprise/university sales) that we do not want to attempt before the core consumer product is running profitably in more than one country.

---

## Phase 4 — TableCrew for Teams (B2B2C)

**Timeframe:** Year 3+ (Months 33+)

**Goal:** Launch "TableCrew for Teams," a B2B2C product sold to employers and universities who want to subsidize or sponsor real-world small-group gathering for their employees/students (e.g., a company pays for a quota of monthly Tables for distributed or hybrid teams; a university sponsors Tables for incoming students during orientation season).

**Target personas unlocked:** Devon most directly (employer-sponsored Tables are close to a perfect solution to his research profile), plus an entirely new institutional buyer persona (HR/People Ops lead, university student-life administrator) that will be documented as an addition to `USER_PERSONAS.md` once Phase 4 planning formally begins, following the same research methodology in `USER_RESEARCH.md`.

**Key features shipped:** Organization admin console (seat management, usage reporting, budget caps per employee/student, all built on top of the existing Table/Crew data model rather than a parallel system); employer/university billing and invoicing distinct from consumer Stripe subscriptions; privacy-preserving usage analytics for organization admins (aggregate participation, never individual attendance details, directly reflecting "Respect data like it's someone's actual life" — an employer should never be able to see which specific employees did or didn't show up).

**Success gate:** this is the final phase in the current roadmap horizon; success here is measured against `INVESTOR_OVERVIEW.md` long-range financial targets rather than a "next phase" gate, and a Phase 5 roadmap will be scoped once Teams has at least two full sales cycles of real data.

**Why this sequencing:** Teams is sequenced last, deliberately, because it is the phase most likely to create pressure toward engagement-metric optimization (an employer paying for the product will want utilization numbers) and toward diluting the safety-first, consumer-trust-first culture the company needs to have fully internalized before taking on institutional buyers whose incentives are not perfectly aligned with individual users' wellbeing. Shipping Teams before Phases 0–3 have proven the consumer product and its values can hold under real growth pressure would risk building the B2B2C layer on top of a foundation that hasn't yet demonstrated it can resist becoming an engagement-maximizing product.

---

## Legal and Regulatory Readiness Gates

**Added 2026-08 during Series A diligence.** Each phase above has a legal/regulatory precondition, detailed in `docs/LEGAL.md`, that is a real gate alongside the product/metrics gates already defined: Phase 0 cannot launch without a signed ToS/Privacy Policy and bound general-liability/participant-injury insurance (`LEGAL.md` §1, §3); Phase 1 cannot launch Discover in a given state without a dating-/social-referral-service statute review for that state (`LEGAL.md` §2); Phase 3 cannot enter the EU without a resourced Digital Services Act compliance workstream and a per-jurisdiction data-protection checklist (`LEGAL.md` §6, §7), and cannot enter any jurisdiction with a data-localization requirement Firebase's regional configuration cannot satisfy (`ARCHITECTURE.md` §7). These are listed here, not just in `LEGAL.md`, because a roadmap gate that only lives in a legal-specific document is exactly the kind of gate that gets missed in a product planning cycle.
