# Product Overview

This is the canonical, single-page description of what TableCrew is. Every other document in this repository — technical, design, or go-to-market — should be consistent with what is written here. If you find a contradiction, this document wins unless it has been explicitly superseded and that supersession is noted in `CHANGELOG.md`.

## One-line description

TableCrew is a platform that helps people build meaningful real-world relationships through small, intentional gatherings over coffee, lunch, and dinner — turning "we should get dinner sometime" into an actual, attended, small-group gathering, with your existing friends or with curated new people, in under a minute of setup.

*Corrected 2026-08: earlier drafts of this and other documents described TableCrew as "a mobile app." That undersells what the company is: TableCrew is the platform — the product experience, the trust and safety infrastructure, the host and venue relationships, the brand — of which a mobile app (built in Flutter, per the "Platform and technical approach" section below) is the primary current surface, not the definition of the company. A future web companion, a host-facing dashboard, or other surfaces are product decisions the platform framing deliberately leaves open; they are not precluded by an accidental "we are a mobile app" framing. Every document in this repository should describe TableCrew this way going forward.*

## The problem

Organizing a small, real-world group gathering has high coordination friction: finding a time that works for 4–8 people, picking a place everyone can agree on, tracking who's actually coming, splitting the bill, and doing it all again next month. This friction is why so many "let's hang out" group chats never produce an actual hangout. Layered on top of this is a separate, larger problem: for people who have recently moved, changed life stage, or simply let their social circle shrink (a majority of adults, per the research in `USER_RESEARCH.md`), there is no low-stakes, structured way to meet 4–8 new people in person around a shared interest. Existing tools solve pieces of this — messaging apps solve communication, Meetup solves large-group public events, dating apps solve one-on-one romantic matching, OpenTable solves the restaurant booking — but none solve the specific job of "help me have a small, real, recurring in-person social life," for either existing friends or new ones.

## The core concept: Tables

A **Table** is the core unit of the product: a specific small-group gathering, with a host, a time, a place, a headcount cap, and an optional theme or interest tag (e.g., "first-time ramen spot," "board games," "new-in-town welcome dinner," "Sunday hike"). Every Table has a lifecycle: **Proposed → Filling → Confirmed → Happened → Rated**. A Table can be:

*Corrected 2026-08: earlier drafts specified a single rigid default headcount (e.g., "4–8, configurable 2–12") for every Table regardless of what it was for. That's too blunt an instrument — a coffee catch-up, a founder dinner, a mentorship conversation, and a group hike are not the same social shape, and forcing them through one default number either over-fills intimate formats or under-fills group ones. The platform-wide hard bounds are **2 to 8 people** (see `FEATURES.md` for why 8 is the ceiling — past that, the product is closer to an "event" than a small gathering, which changes the safety model per `PRD.md` §7), but the *recommended* size is activity-dependent and surfaced as a smart default, not a fixed rule, when a host picks an interest tag:

| Activity type | Recommended size | Why |
|---|---|---|
| Coffee / casual catch-up | 2–4 | Conversational intimacy matters more than headcount; this is often the lowest-commitment, easiest-to-fill format, especially for a first Discover join. |
| Mentorship | 2–3 | Near-1:1 or one-mentor-to-a-couple format; a mentorship conversation degrades past a small handful of people. |
| Lunch | 3–5 | A mid-length, mid-commitment format that works well slightly larger than coffee but still short enough to stay intimate. |
| Founder dinners / professional roundtables | 4–6 | Curated, higher-trust, conversation-quality-over-headcount format — closer to Priya's Serial Host use case than a casual meetup. |
| Dinner (general) | 4–6 | The anchor format the product was originally designed around; large enough for good group energy, small enough that everyone can be part of one conversation. |
| Board games / hobby nights | 4–8 | These formats often benefit from more players (many games need 4+ to be good), so the recommended size sits at the top of the range. |
| Hiking / outdoor activity | 4–8 | Group logistics and safety (per `SECURITY.md`) favor more people, though hosts can flex smaller for a more casual pace. |

This table is a starting point for the interest-tag taxonomy in `FEATURES.md`'s Discover matching section and the smart-default behavior in `PRD.md` FR-T2, not an exhaustive or final list — new interest tags should get a recommended size assigned using the same reasoning (conversation quality and format norms, not an arbitrary number) rather than defaulting to the generic dinner range out of convenience.

- **Closed**, visible only to people the host invites (typically an existing friend group), or
- **Open**, visible to TableCrew's Discover surface, where people outside the host's existing network can request a seat.

This single object — the Table — is the atomic unit that every feature in `FEATURES.md` is built around, and its data model is defined precisely in `DATABASE.md`.

## The second core concept: Crews

A **Crew** is a persistent, named group of people (a friend group, a book club, a former-roommates group) who create Tables together repeatedly. Crews exist because most real social life is recurring, not one-off, and rebuilding the guest list from scratch every time is exactly the friction we are removing. A Crew has its own lightweight chat, its own Table history, and its own recurring-Table scheduling (e.g., "second Tuesday of every month").

## The third core concept: Discover

**Discover** is the surface where a user finds Open Tables near them that match their stated interests, schedule, and location, or requests that TableCrew match them into one. This is how TableCrew delivers on the "meet new people" half of the mission, and it is the more operationally sensitive half of the product — it is where `SECURITY.md`'s verification and moderation requirements apply most heavily, because it is where two people who don't already know each other are being introduced into a physical, in-person setting.

## Primary user journeys

1. **Host a Table with people I know** (Crew-first journey): open app → "New Table" → pick a Crew or ad hoc invite list → pick time/place (with smart suggestions) → send → track RSVPs → show up. This is the lowest-friction, highest-frequency journey and the one we optimize onboarding around first (see `ROADMAP.md`, Phase 1).
2. **Join a Table with people I don't know yet** (Discover-first journey): open app → Discover → filter by interest/time/distance → request a seat → host or algorithm confirms → show up. This journey carries the identity-verification and safety requirements detailed in `SECURITY.md` and is intentionally gated more heavily than journey 1.
3. **Recurring Crew ritual**: a Crew with an established cadence gets an automated prompt ("Your Sunday Hike Crew hasn't met in 3 weeks — want to schedule one?"). This is the retention-critical journey; see `SUCCESS_METRICS.md`.

Full journey maps, edge cases, and acceptance criteria live in `PRD.md`. The complete, prioritized feature list lives in `FEATURES.md`.

## Who it's for

Detailed personas are in `USER_PERSONAS.md`, grounded in the research in `USER_RESEARCH.md`. In summary, our beachhead is adults aged 24–40 who have recently changed cities, jobs, or life stage (new-to-city professionals, expats, recent graduates, new parents re-entering social life) in dense urban areas, expanding over time to a general-purpose social-life tool for any adult, and eventually to community organizations, universities, and employers as institutional customers (see `INVESTOR_OVERVIEW.md`).

## How TableCrew makes money

A three-part model, detailed in `INVESTOR_OVERVIEW.md`:

1. **TableCrew+ subscription** (consumer, primary revenue driver at maturity): unlimited hosted Tables, priority Discover matching, no per-booking service fee, advanced Crew scheduling tools.
2. **Venue partnerships**: referral and booking commissions from restaurants and venues that receive TableCrew-driven reservations, plus a "Featured Venue" placement product.
3. **TableCrew for Teams** (B2B2C, introduced Year 3+): a paid product for employers and universities to run structured small-group social connection programs for remote/hybrid teams and incoming cohorts.

We deliberately do not run a third-party advertising business (see `VALUES.md`, "Real connection over engagement metrics").

## Why this, why now

Three converging trends make this the right time to build TableCrew, elaborated in `INVESTOR_OVERVIEW.md`: (1) loneliness has been named a public health priority by governments on four continents, creating both consumer demand and, longer-term, institutional/insurer willingness to pay; (2) remote and hybrid work has permanently reduced incidental workplace socializing, pushing the burden of building a social life onto deliberate, off-work effort; (3) the generation now aging into peak social-app usage (Gen Z and young Millennials) has shown a consistent, measurable preference shift away from large public social platforms toward smaller, higher-trust group spaces (private groups, close-friends lists, Discord servers) — TableCrew is that shift applied to the physical world.

Existing products optimize for digital engagement. TableCrew optimizes for offline engagement. Our goal is not to maximize notifications, likes, or screen time. Our goal is to maximize the number of meaningful conversations that happen after the phone is put away. That inversion — building a company whose product is genuinely finished doing its job the moment someone sits down at a table — is the whole bet, and it is why the metrics in `SUCCESS_METRICS.md`, not a conventional engagement dashboard, are what this company is actually run on.

## How We Measure Success

The success of TableCrew is measured by Tables Attended per Active User per Month — not by daily active users, screen time, or content consumption. That single sentence is deliberately the loudest thing in this document about metrics, because it is the one fact every team, from product to marketing to fundraising, needs to internalize before anything else: if a number isn't downstream of real people actually attending real Tables, it isn't how this company keeps score. Full metric definitions, guardrails, and phase targets are in `SUCCESS_METRICS.md`.

## What We Will Not Build

TableCrew intentionally avoids:

- Infinite scrolling feeds
- Public follower counts
- Viral sharing mechanics
- Popularity contests
- Anonymous participation
- Endless direct messaging
- Engagement algorithms designed to maximize screen time

If a feature makes TableCrew feel more like a social media platform than a conversation platform, it should be reconsidered. This list is the negative space of the Product Decision Test above — it names, concretely, the category of feature that fails question 5 ("would we still build it if it didn't increase screen time?") almost by construction, so that a team member doesn't have to rediscover that judgment from first principles every time one of these ideas resurfaces, and it usually does, because every one of these mechanics is a proven engagement lever elsewhere. That they work elsewhere is exactly why they don't belong here (see `VALUES.md`, "Real connection over engagement metrics").

## Platform and technical approach, in brief

The platform's primary current surface ships as a single cross-platform mobile app built in Flutter, backed by Firebase (Firestore, Auth, Cloud Functions, Cloud Messaging, Storage), chosen specifically for a small founding engineering team's need to ship fast across iOS and Android without maintaining separate native codebases or a bespoke backend on day one. This is a deliberate starting surface, not a permanent definition of the platform's boundaries — see `ARCHITECTURE.md` for how additional surfaces (e.g., a web companion or host/venue-partner dashboard) would extend the same Firestore-backed data model rather than requiring a rebuild. The full justification and the explicit plan for what changes as we scale are in `ARCHITECTURE.md`, `DATABASE.md`, and `FIREBASE.md`.

## Product Principles

Every feature should reinforce these principles.

### Conversation over Content

Success is measured by conversations that happen in the real world, not by time spent in the app.

---

### Trust before Growth

No growth initiative should compromise user safety or community trust.

---

### Quality over Quantity

A single meaningful dinner is more valuable than ten superficial interactions.

---

### Community before Scale

We expand only when an existing city has developed a healthy, sustainable community.

---

### Simplicity Wins

Scheduling dinner with friends should feel easier than creating a group chat.

These five principles are the plain-language, all-hands version of the six values in `VALUES.md` — same commitments, phrased so that anyone on the team, not just the people who wrote the values doc, can hold a feature up against them in a hallway conversation. Where the two documents overlap, `VALUES.md` is the more detailed, more binding version (it states what each principle costs us); these principles are the fast, memorable version people should actually be able to recall unprompted.

## Product Decision Test

Before approving any new feature, ask:

1. Does it increase meaningful real-world conversations?
2. Does it reduce friction?
3. Does it strengthen trust?
4. Does it help communities grow?
5. Would we still build it if it didn't increase screen time?

If the answer to any of these is "no," the feature should not be built. This is the practical, feature-by-feature application of the mission and values stated in `MISSION.md` and `VALUES.md` — anyone proposing a feature should be able to answer all five questions in the feature's own spec (see the "Values check" convention in `PRD.md`), not just assert that the feature sounds good.

## Document map

- Strategy: `VISION.md`, `MISSION.md`, `VALUES.md`, `ROADMAP.md`, `INVESTOR_OVERVIEW.md`
- Users: `USER_PERSONAS.md`, `USER_RESEARCH.md`
- Product definition: `PRD.md`, `FEATURES.md`, `SUCCESS_METRICS.md`
- Engineering: `ARCHITECTURE.md`, `DATABASE.md`, `API_SPEC.md`, `FIREBASE.md`, `ENGINEERING_GUIDELINES.md`, `SECURITY.md`, `TESTING.md`, `DEPLOYMENT.md`, `CI_CD.md`
- Design and brand: `DESIGN_SYSTEM.md`, `BRAND_GUIDELINES.md`, `COPY_GUIDELINES.md`
- Growth: `MARKETING.md`, `SEO.md`
- Company: `README.md`, `CLAUDE.md`, `TASKS.md`, `CHANGELOG.md`
