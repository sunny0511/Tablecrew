# User Personas

These personas are synthesized from the research methodology and findings in `USER_RESEARCH.md`. They exist to keep product decisions grounded in specific people rather than an abstract "user." Every persona includes what they need, what they're skeptical of, and which primary journey (from `PRODUCT.md`) serves them first — because a feature that serves persona A well can actively fail persona C, and we need that tension visible.

We rank personas in priority order for the first 18 months (see `ROADMAP.md`, Phase 1–2). This ordering is a real prioritization decision, not a list of equally weighted segments.

## Persona 1 (primary beachhead): Maya, the New-to-City Professional

- **Age/stage:** 27, relocated 4 months ago for a job, in a mid-size city where she knows almost no one outside work.
- **Goal:** Build a real social life outside her coworkers within her first year, without the vulnerability of showing up alone to a large public event.
- **Primary journey:** Discover-first (Journey 2 in `PRODUCT.md`) initially, converting to Crew-first once she's found 2–3 people she clicks with.
- **What she needs:** small group size (large Meetup-style events feel exposing), credible signals that other attendees are safe and similarly motivated, and a low-commitment first step (she will not pay before attending a first Table).
- **What she's skeptical of:** that this is "just a dating app in disguise" or that the other attendees will be a sales pitch in disguise (MLM recruiting, networking-with-an-agenda). Product and copy must make platonic, no-agenda intent explicit and structurally enforced (see `COPY_GUIDELINES.md` and `TRUST` sections of `SECURITY.md`).
- **Success looks like:** attends 1 Discover Table in her first two weeks, attends a second within a month, and has formed at least one recurring Crew by month three.

## Persona 2 (primary beachhead): Alex, the Friend-Group Organizer

- **Age/stage:** 31, has an established friend group of 6–10 people scattered across a metro area, is the de facto planner ("the friend who always sends the group chat poll").
- **Goal:** Reduce the personal labor cost of being the group's planner, and increase how often the group actually gets together.
- **Primary journey:** Crew-first (Journey 1), recurring-ritual journey (Journey 3) once a Crew is established.
- **What she needs:** fast Table creation (under 60 seconds from open-app to sent-invite), reliable RSVP tracking that doesn't require chasing people over text, and a bill-splitting integration so "who owes what" stops being her unpaid job.
- **What she's skeptical of:** another app her friends won't bother downloading. Cross-platform, low-friction invite acceptance (a non-user can RSVP from a link without creating an account first) is a hard requirement, detailed in `PRD.md`.
- **Success looks like:** her existing friend group's gathering frequency measurably increases after adopting TableCrew, and she creates at least one recurring/repeating Table setup.

## Persona 3 (secondary, scales the network effect): Priya, the Serial Host

- **Age/stage:** 34, extroverted, already the person in her social orbit who organizes dinners and game nights, enjoys meeting new people through hosting.
- **Goal:** Host more often, for a slightly wider circle than her existing friends, ideally with some of the logistical/financial burden of hosting offset.
- **Primary journey:** Open-Table hosting (a hybrid of Journeys 1 and 2 — she hosts, but opens seats to Discover).
- **What she needs:** tools to manage a slightly larger and less-known guest list confidently (see-more-context on attendees before confirming, no-show accountability, an easy way to cap and waitlist), and eventually the venue-partnership perks in `PRODUCT.md` (e.g., discounted host rates at partner restaurants).
- **What she's skeptical of:** being left responsible (socially or financially) for strangers who don't show up or behave badly. No-show accountability and reporting tools (`SECURITY.md`) are non-negotiable for retaining this persona, since she is disproportionately valuable — Serial Hosts create a large share of all Open Tables and are the supply side of the Discover marketplace.
- **Success looks like:** hosts at least 2 Open Tables per month and reports high satisfaction with attendee quality and no-show rates.

## Persona 4 (expansion): Devon, the Remote-First Employee

- **Age/stage:** 38, works fully remotely for a company with no local office, has been at the same company two years and has never met most coworkers in person, feels the loss of incidental workplace social contact.
- **Goal:** Recreate some of the low-stakes social contact that an office used to provide, ideally including actual coworkers when traveling for on-sites, but mostly through a general local social outlet.
- **Primary journey:** Discover-first, with eventual relevance to the `TableCrew for Teams` B2B2C product described in `INVESTOR_OVERVIEW.md`.
- **What he needs:** flexibility around timing (evenings and weekends, since he has no fixed "after-work" window shared with a physical office cohort) and interest-based matching that doesn't assume he's only looking to meet people his exact age.
- **What he's skeptical of:** whether it's worth the effort given he's not actively unhappy, just quietly under-socialized. Marketing messaging for this persona is explored in `MARKETING.md`.
- **Success looks like:** becomes an intermittent but consistent user (1–2 Tables a month) rather than a high-frequency one; this persona's value is in volume across a large addressable population, not depth per user.

## Persona 5 (long-horizon expansion): Grace, the Empty-Nester Rebuilding a Social Life

- **Age/stage:** 58, children recently left home, divorced or widowed within the last several years, finds that her social circle was built around her family life and has shrunk.
- **Goal:** Rebuild an independent social identity and a reliable circle of friends for this new life stage.
- **Primary journey:** Discover-first, strongly favoring interest-based and affinity-based Tables (hiking, book clubs, cooking) over generic "meet people" framing.
- **What she needs:** an interface and onboarding that does not assume smartphone-native fluency, larger text and simpler navigation options (see accessibility requirements in `DESIGN_SYSTEM.md`), and a brand tone that reads as warm and safe rather than youth-coded or "dating-app adjacent."
- **What she's skeptical of:** that the app is "for young people" and she'll feel out of place; that it is secretly a dating product. Explicit non-romantic framing and age-diverse marketing imagery (`BRAND_GUIDELINES.md`) matter disproportionately for this persona.
- **Success looks like:** this persona is not a Year 1 acquisition priority (see `ROADMAP.md`) but is a critical proof point for the platform's global, all-ages vision (`VISION.md`) by Year 3.

## How these personas are used

- `PRD.md` requirements each cite which persona(s) they primarily serve.
- `ROADMAP.md` sequences features by which personas are being unlocked in each phase.
- `USER_RESEARCH.md` documents the interviews, surveys, and behavioral data these personas are built from, and is the place to go to challenge or update a persona — personas are hypotheses, not settled fact, and are revisited every two quarters.
