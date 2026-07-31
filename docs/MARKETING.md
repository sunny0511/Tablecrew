# TableCrew Marketing Strategy

## 1. Purpose of This Document

This document is the operating strategy for how TableCrew acquires, activates, and retains users. It translates the product facts in `PRODUCT.md`, the phased build-out in `ROADMAP.md`, and the persona work in `USER_PERSONAS.md` into a go-to-market plan: how we launch cities, which channels we invest in and in what order, what we say to whom, and how we keep Tables and Crews alive after the first gathering.

The throughline is stated in `VALUES.md`: TableCrew is not an ad-supported attention business. We do not optimize marketing for session length or DAU/MAU. We optimize for a single outcome — **did a real gathering happen, and did the people who attended want to do it again.** Every channel and mechanic below is judged against that bar.

---

## 2. Positioning Statement

**For** people who want more real friendships and recurring social plans but are stalled by the effort of organizing them, **TableCrew** is a platform that turns "we should get dinner sometime" into a Table that actually happens — **unlike** group chats, generic event apps, or dating-style matching apps, TableCrew is purpose-built around small, recurring, real-world gatherings, with safety and trust treated as core infrastructure rather than an afterthought. The mobile app is the primary current surface people experience this through, not the definition of the company (`docs/PRODUCT.md`).

Master brand line: **"Real Conversations. Real Connections."** — corrected 2026-08 to match the line now carried in `README.md`; this supersedes the earlier "Pull up a chair." line, which may still be usable as a secondary campaign-level line (e.g., a specific city-launch or referral-campaign moment) but is no longer the master brand line referenced elsewhere in this document or in `BRAND_GUIDELINES.md`, which should be read alongside this update. Paired with a locally adapted functional tagline where needed (see Section 8).

### 2.1 Messaging Framework by Persona

Each persona (full detail in `USER_PERSONAS.md`) gets a distinct primary message, proof point, and call-to-action, while the underlying product is the same.

**Maya, 27, New-to-City Professional (primary beachhead)**
- Core message: "You don't need to already know people to have a standing Tuesday dinner."
- Proof point: Discover matching is curated (small group, screened, recurring-friendly) rather than a swipe deck.
- Emotional job: replace the anxiety of "how do I meet people as an adult" with a low-stakes, structured first step.
- CTA: "Find your first Table this week."

**Alex, 31, Friend-Group Organizer (primary beachhead)**
- Core message: "Stop being the group's unpaid event planner."
- Proof point: headcount caps, RSVP lifecycle (Proposed → Filling → Confirmed), and Crew scheduling remove the 40-text-thread problem of picking a date.
- Emotional job: relieve organizer fatigue and get credit for keeping the friend group alive.
- CTA: "Start a Crew and let TableCrew chase the RSVPs."

**Priya, 34, Serial Host (Discover supply-side)**
- Core message: "You're already the person who makes gatherings happen — get discovered by people who want exactly that."
- Proof point: a "Featured Host" badge and enhanced profile visibility in Discover for TableCrew+ hosts, plus hosting reputation/rating carried across Tables. Note: consistent with `VALUES.md`'s explicit rule that Discover matching is never paid-for-priority (per FR-D4/FR-D5 in `PRD.md`), this is a visibility/credibility perk, not a paid override of the matching algorithm — a TableCrew+ host's Table can look more complete and trustworthy to a browsing user, but it is never ranked ahead of a better-fit Table for that specific user's stated interests, schedule, or location.
- Emotional job: validate an identity ("I'm a host") and reduce the admin overhead of repeated hosting.
- CTA: "Open your next Table to new faces."

**Devon, 38, Remote-First Employee (expansion)**
- Core message: "Your job stopped supplying your social life. TableCrew brings the office kitchen back."
- Proof point: recurring rituals (e.g., a standing monthly Table), Crew-based scheduling that respects a fuller adult calendar, and eventually TableCrew for Teams for employers who want to sponsor this directly.
- Emotional job: replace incidental workplace socializing lost to remote work.
- CTA: "Put a recurring Table on your calendar."

**Grace, 58, Empty-Nester (long-horizon, proves all-ages vision)**
- Core message: "The table doesn't get quieter just because the house did."
- Proof point: Closed Tables with existing friends work exactly the same as they do for a 27-year-old; Discover is opt-in, not required.
- Emotional job: dignity — this is a tool for staying socially active, not a "lonely seniors" product.
- CTA: "Bring your circle back to a regular table."

---

## 3. Launch Strategy: City-by-City, Density-First

### 3.1 The core argument

TableCrew's Discover surface — the "meet curated new people" half of the product — only works if there is enough local supply of Open Tables in a given city, in a given week, for a match to be plausible. A Discover feed with three Open Tables in a metro area of two million people is not a broken feature, it's an empty room. Closed Tables (existing friend groups) don't have this problem as acutely because the "supply" is the user's own social graph, but the product's differentiated, defensible half — Discover — is a two-sided local marketplace, and two-sided local marketplaces die from thin liquidity long before they die from lack of national brand awareness.

This is why `ROADMAP.md` sequences Phase 0 as a single city, Crew-only (no Discover, because Discover isn't viable at MVP density), Phase 1 as three cities with Discover introduced, and Phase 2 as scaling density in those markets before adding many more cities. `VISION.md`'s ten-year picture is deliberately phrased as density in 300+ metro areas, not presence in 300+ metro areas — the goal was never geographic coverage for its own sake, it was "warm, trusted tables in every neighborhood," which is a density claim, not a distribution claim.

**A national or broad-market launch would actively work against this.** Spreading the same marketing budget and community-ops headcount across 20 cities at 5% of the density needed for Discover to feel alive produces 20 markets that all feel empty, versus 1-3 markets that feel like something is actually happening. Word-of-mouth (our primary channel, see Section 4) also compounds locally: a Table that happened in a specific neighborhood restaurant is a story that spreads through that neighborhood's social graph, not through an undifferentiated national feed. Density concentrates word-of-mouth into a self-reinforcing loop; dilution starves it.

### 3.2 What "density-ready" means operationally

We define a city as launch-ready for Discover (i.e., graduated from Phase 0/Crew-only behavior to Phase 1 behavior) when it can sustain:
- At least 15-20 new Open Tables proposed per week within a 5-mile urban core, so a Discover user opening the app on a given day sees at least 3-5 joinable Tables within their availability window.
- A Table fill rate (proposed → confirmed) above 60%, indicating real demand rather than dead listings.
- At least 25 rated hosts, so new Discover users see credible host history rather than all-new, unrated profiles.

These thresholds are directional (derived from marketplace-liquidity norms in comparable local two-sided markets, e.g., early Airbnb neighborhood-level supply targets and early Meetup group-density benchmarks), and will be recalibrated using Phase 0/1 telemetry defined in `SUCCESS_METRICS.md`. The point is structural, not the exact numbers: Discover should not be switched on for a city until it clears a liquidity bar, and marketing spend in a city should scale with the same curve — light awareness spend pre-liquidity, heavier acquisition spend only once supply can absorb new demand without producing an empty-feed first impression.

### 3.3 Launch sequencing logic

Phase 0's single MVP city is chosen for founder proximity and dense, walkable neighborhood structure (small-group dining venues within short travel distance — this is a physical-world product, and geography matters more than population size alone). Phase 1's three cities are chosen using the same filter: a mix that validates the model across (a) a dense urban core similar to the MVP city, (b) a suburban/car-dependent metro to stress-test whether the density model holds outside walkable cores, and (c) one market with a meaningfully different demographic mix (skewing more toward Devon/Grace personas) to validate the all-ages thesis early rather than late. This mirrors the logic Airbnb, Bumble BFF, and early Meetup all used: prove the mechanic in one place, generalize the playbook, then repeat with a community manager embedded in each new city rather than a purely digital, self-serve launch (playbook detailed in Section 9).

### 3.4 Seasonality and climate-driven demand variation

Not every Table format has stable, year-round demand. Outdoor-adjacent or activity-specific interest tags (e.g., a "Sunday hike" Crew, a farmers-market meetup, patio-dining-season Tables) plausibly see real seasonal drop-off in markets with harsh winters or extreme summer heat, and this is not currently modeled anywhere in this document's density thresholds (Section 3.2) or the traction milestones in `INVESTOR_OVERVIEW.md`. Two consequences follow: (1) a city's Discover density (Section 3.2's 15-20+ weekly Open Tables threshold) could plausibly dip below the self-sustaining bar in an off-season month even after a city has genuinely "graduated" to Phase 1 behavior, which the current density-gating logic does not explicitly account for as an ongoing (rather than just launch-time) check; (2) city-selection criteria (Section 3.3) do not currently weight climate or the local viability of indoor-vs-outdoor gathering formats at all.

*Mitigation:* (a) the interest-tag taxonomy (`FEATURES.md`) should maintain genuine diversity across indoor formats (dinners, board games, coffee, museum visits) and outdoor/seasonal formats, so a city's aggregate Discover liquidity does not depend disproportionately on a single season-sensitive format; (b) city-selection criteria in Section 3.3 should add a light climate/seasonality screen — e.g., deprioritizing markets where the viable outdoor gathering season is under 4-5 months, unless indoor-format supply is independently strong enough to sustain the density threshold alone; (c) density metrics in Section 3.2 should be tracked and re-evaluated on a rolling basis rather than treated as a one-time launch gate, since a city that clears the bar in June is not guaranteed to hold it in January. This is currently an acknowledged gap rather than a fully solved problem — it should be validated against actual Phase 0/1 seasonal telemetry per `SUCCESS_METRICS.md` once a full-year cohort exists in at least one cold-winter market.

---

## 4. Acquisition Channels, Ranked

Channels are ranked by priority for Phase 0-2. This ordering is deliberate and sequential, not simultaneous — each channel is added once the previous one has enough signal to justify the next investment.

### 4.1 Priority 1 — Referral and word-of-mouth loops

**Why this is primary, not just "also important":** TableCrew asks users to do something with real social and physical-safety stakes — show up to a table with people, some of whom (in Discover) may be strangers. Trust transfers person-to-person far more efficiently than it transfers through an ad impression. A referral from a friend who already attended a Table carries an implicit safety and quality vouch that no amount of paid creative can replicate. This is also the channel most consistent with the "real connection over engagement metrics" value: a referral program rewards a completed real-world gathering, not a click.

Mechanic recommendation is detailed in Section 5. Expected contribution: referral/organic word-of-mouth should be the single largest source of new users in every city by the time that city reaches self-sustaining density (Section 9), consistent with how Bumble BFF and Meetup's early city cohorts grew.

### 4.2 Priority 2 — Local community and venue partnerships

Venue partners (per `PRODUCT.md`'s monetization model) are not just a revenue line — they are a distribution channel. A restaurant that has hosted five successful TableCrew Tables has a direct incentive to display a table-tent card, mention TableCrew to walk-in guests asking about slow weeknights, or feature TableCrew in their own newsletter/Instagram. This is high-trust, hyper-local distribution that reaches exactly the geographically-relevant audience density-first launch requires, and it costs TableCrew community-ops time rather than working against unit economics the way paid media does. We also partner with adjacent local community organizations (run clubs, newcomer/expat associations, alumni chapters, coworking spaces used by Devon-persona remote workers) for co-hosted "seed Tables" during city launch — covered in Section 9.

**A note of realism on venue sales friction.** The above describes venue partnerships at their best-case, steady-state operating point once relationships exist; getting there is not frictionless, and we should not model or present it as a clean line item. Independent restaurants are a fragmented, low-tech, owner-operator-run industry with thin net margins (commonly single digits), and many venues already pay commission to one or more third-party reservation or delivery platforms — a new commission ask competes for a limited slice of already-thin margin, and the decision typically runs through a single hard-to-reach owner-operator rather than a scalable, self-serve signup flow reachable by a sales deck or a cold email. This means venue partnership counts (e.g., the "8-12 venue partnerships" target in Section 9's launch playbook) should be read as a realistic output of sustained, in-person, community-manager-led relationship-building over weeks to months per venue, not a metric that scales the way a digital acquisition channel does. We treat venue-partnership revenue growth (`INVESTOR_OVERVIEW.md` Section 4) as gated by this sales-cycle reality, not as a frictionless function of city density alone.

### 4.3 Priority 3 — Targeted local content and community-manager-led launches

This is the Airbnb/Bumble BFF/early-Meetup playbook: a named community manager owns a city, personally recruits the first 20-30 hosts, personally attends or checks in on early Tables, and produces hyper-local content ("best small-group dinner spots in [neighborhood]," "how [City]'s newcomers are building a social life") that ranks for local intent and gives the community manager's own outreach (DMs, local Facebook/Nextdoor groups, subreddit AMAs, campus and employer partnerships) something concrete to point to. This channel is deliberately labor-intensive and low-CAC-per-quality-user rather than scalable-by-default; it is what turns the first 100 users in a city into a community rather than a user list. Content produced here also compounds into organic search value described in `SEO.md`.

### 4.4 Priority 4 (secondary, later-stage) — Paid acquisition

Paid channels (performance social, App Store search ads, out-of-home in launched neighborhoods) are introduced only after a city has cleared the density threshold in Section 3.2 and after LTV/CAC from organic channels is understood well enough to set a rational paid CAC ceiling. Practically, this means paid spend does not start on Day 1 of a city launch; it starts once a city is already showing organic pull, and its role is to accelerate a city past the liquidity threshold faster or to sustain steady-state growth in a mature city, not to manufacture demand in an empty market. Introducing paid spend before organic word-of-mouth has proven the product's core trust loop would also risk the exact failure mode the "real connection over engagement metrics" value warns against: paying for installs that never convert into an attended Table just to post a vanity growth number. We estimate paid channels become a rational lever starting mid-Phase 1 to Phase 2, once at least one city has reached self-sustaining density and we have 2+ full quarters of retention/attendance data to underwrite a CAC payback model (this should be revisited against actuals captured in `SUCCESS_METRICS.md`).

---

## 5. Referral Program Mechanic

**Recommendation: reward is triggered by attendance, not by signup or invite-send.**

Mechanic: when an existing user ("host-referrer") invites someone to TableCrew and that invitee **attends and is rated at an actual Table** (not merely creates an account, not merely RSVPs), both parties receive a reward. We recommend a dual reward structure:
- The inviter receives either (a) one free month of TableCrew+ or (b) a "Featured Host" visibility boost for their next hosted Table (their choice) — the visibility boost is specifically attractive to Priya-persona serial hosts, while the free month is more attractive to Maya/Alex-persona casual users, so offering a choice lets the incentive self-select by persona rather than over-indexing on one reward type. (As with the TableCrew+ perk in Section 2.1, this boost affects how prominently a host's Table is presented — badge, higher position among comparably-matched options — not the underlying match-quality ranking Discover uses to decide which Table is actually the best fit for a given user; per `VALUES.md`, matching itself is never paid-for-priority.)
- The invitee receives a discount on their first TableCrew+ trial period, activated only after their first attended Table, reinforcing that the product's value is realized at the table, not at signup.

**Why tie the reward to attendance instead of signup:** an invite-triggered or signup-triggered reward optimizes for exactly the vanity behavior `VALUES.md` explicitly rejects — it would pay out for invite-spam and dormant accounts, the same failure pattern that made social-network referral programs (and their fraud/spam side effects) notorious. An attendance-triggered reward only pays out when the thing the mission actually cares about happens: two people shared a real table. It also naturally self-polices safety — a referral chain that produces no-shows or bad experiences produces no reward, so there is no incentive to invite people indiscriminately. Finally, it aligns the referral program with the same north-star metric philosophy used in `SUCCESS_METRICS.md` (Tables Happened / Tables Rated as the primary success signal, not installs or invites sent).

Estimated economics: assuming a TableCrew+ monthly price point in the $9-12 range (final pricing owned by `PRODUCT.md`/finance), a free month reward costs roughly $9-12 in forgone subscription revenue per successful referral — materially cheaper than a typical paid-social CAC for a lifestyle/social app (commonly $15-40+ per install before accounting for the fact that most paid installs never attend a real-world event at all). This makes the referral program not just more trust-aligned but also more capital-efficient than paid acquisition at this stage.

---

## 6. Brand Campaign Ideas by Persona

- **Maya (New-to-City):** "New in [City]" campaign timed to seasonal moving spikes (post-graduation in June, post-New Year job changes in January) — local out-of-home and social creative near apartment complexes, transit hubs, and coworking spaces, paired with a "first Table free" or discounted-trial offer for verified new movers.
- **Alex (Organizer):** "Retire as group planner" campaign — comedic, relatable creative depicting the exhausting group-chat scheduling spiral, distributed through the exact channels organizers already use to complain about this (Instagram/TikTok short-form, targeted at friend-group-adjacent humor accounts), ending on a CTA to start a Crew.
- **Priya (Serial Host):** "Hosts of [City]" campaign — a recurring local content/PR series profiling real Priya-persona hosts and their Tables (partnering with venues from Section 4.2), functioning simultaneously as brand storytelling, venue-partner marketing, and top-of-funnel Discover supply recruitment.
- **Devon (Remote-First):** "Bring back the office kitchen" campaign, distributed through employer/coworking partnerships and positioned as a precursor to the Phase 4 TableCrew for Teams offering — seeding future B2B2C demand years ahead of that product's launch.
- **Grace (Empty-Nester):** "The table doesn't get quieter" campaign — warmer, longer-form storytelling (long-form video, community newspaper/newsletter placements) rather than short-form social, reflecting this persona's media consumption habits and the long-horizon nature of this segment per `USER_PERSONAS.md`.

---

## 7. Retention and Lifecycle Marketing

Acquisition gets someone to their first Table; lifecycle marketing is what turns a single Table into the recurring social life described in the mission statement. This is where `FEATURES.md`'s recurring ritual functionality becomes a marketing surface, not just a product feature.

- **Dormant Crew re-engagement:** if a Crew has not proposed a new Table within its established cadence (e.g., a Crew with a monthly rhythm goes 6 weeks quiet), TableCrew sends a nudge to the Crew's most active organizer — not a generic "come back" push, but a specific one referencing the group and the last Table's rating/highlight ("It's been a while since [Crew name] got together — want to lock in your next one?"). This uses the same underlying signal (recurring ritual cadence) that the product team uses to power the ritual feature itself, so marketing and product are working off one shared data model rather than a separate marketing-only heuristic.
- **Post-Table follow-up loop:** after every rated Table, attendees receive a single prompt — rate the Table, and (if applicable) a one-tap "propose the next one" action pre-filled with the same group. This is the highest-leverage retention moment in the entire lifecycle, because intent to repeat is highest immediately after a good experience.
- **Seasonal ritual prompts:** proactive suggestions timed to natural recurrence points (monthly, "first Sunday" patterns, holiday-adjacent gatherings) rather than arbitrary push notifications, keeping the cadence feeling like a helpful reminder of a standing plan rather than an engagement-bait notification.
- **Winback for lapsed individuals (not just Crews):** a user who attended one Table and never returned gets a lightweight, low-frequency nudge surfacing either (a) their existing Crew's next Table or (b) a curated Discover Table matching their original stated interests — capped in frequency to avoid the exact notification-spam pattern the "real connection over engagement metrics" value warns against.

Lifecycle marketing is deliberately restrained in frequency. Because the product's core metric is Tables Happened rather than app opens, we would rather under-notify and preserve trust in our notifications than chase daily-active-use the way an ad-supported app would.

---

## 8. Localization of Messaging (Global-First)

Consistent with the Global-first value in `VALUES.md`, the master brand line "Real Conversations. Real Connections." and the underlying mission are not US-centric concepts and travel well linguistically and culturally (communal eating and "having a seat at the table" are near-universal idioms) — this matters concretely now that Hyderabad, India is the Phase 0 home market (`ROADMAP.md`), not a later international adaptation. Functional taglines and campaign creative (Section 6) are localized per market — not just translated, but adapted to local dining and gathering norms (e.g., emphasis on tea/coffee-based gatherings in some markets, different default group sizes or meal timing in others) — with local community managers (Section 9) responsible for flagging where global creative needs local adaptation before a city launch, including, for Hyderabad specifically, Telugu- and Hindi-language creative alongside English, not English-only.

---

## 9. City-Launch Playbook: 0 to Self-Sustaining Density

This is the repeatable operating sequence for taking a new city from zero presence to the density threshold defined in Section 3.2, at which point Discover is switched on and paid acquisition (Section 4.4) becomes a rational lever.

**Weeks 1-4 — Seed the host base.** A named community manager is hired or assigned to the city before any consumer marketing begins. Their first job is recruiting 20-30 "seed hosts" — recruited directly (personal outreach, local community org partnerships per Section 4.2, warm intros from other cities' top hosts) rather than through broad advertising. Seed hosts are given white-glove onboarding, direct access to the community manager, and often an incentive (e.g., TableCrew+ free for the launch period) to propose their first 2-3 Tables.

**Weeks 3-8 — Prove Closed Tables work (Crew-only, matching Phase 0/1 product behavior).** Marketing focus is entirely on Alex/Maya-persona friend groups already living in the city: get existing friend groups onto the app to replace their group-chat coordination with a Crew. This validates the core mechanic without needing Discover liquidity at all, and produces the first wave of rated Tables and host reputations that Discover will later depend on.

**Weeks 6-12 — Layer in local content and venue partnerships.** Community manager produces the hyper-local content described in Section 4.3, secures the first 8-12 venue partnerships, and begins running co-hosted seed Tables with local community organizations to widen the initial host and attendee base beyond the community manager's personal network.

**Week 10 onward — Monitor density threshold, then flip on Discover.** Once the metrics in Section 3.2 are cleared (15-20+ weekly proposed Open Tables, 60%+ fill rate, 25+ rated hosts), Discover is enabled for the city. This is a deliberate, metrics-gated switch, not a calendar-driven one — a city that is slower to build host density delays its Discover launch rather than launching into a thin feed.

**Month 3 onward — Referral flywheel takes over, paid spend becomes rational.** With a base of attended, rated Tables in place, the attendance-triggered referral mechanic (Section 5) begins compounding, and the city has enough retention/attendance data to set a defensible paid CAC ceiling if a paid push is warranted to accelerate growth or backfill a specific underdense neighborhood.

**Ongoing — "Self-sustaining" defined.** A city is considered self-sustaining when new Table proposals from users outside the original seed-host cohort exceed 50% of weekly proposed Tables, and organic/referral signups exceed paid signups by at least 3:1 — at which point community-manager headcount for that city can shift from full-time build-out to lighter-touch maintenance, freeing that role (or a successor) to seed the next city on the `ROADMAP.md` sequence.
