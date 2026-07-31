# TableCrew User Research

**Status:** Living document, v1.0
**Owners:** Product Research
**Related docs:** `USER_PERSONAS.md`, `PRD.md`, `PRODUCT.md`, `VISION.md`, `MISSION.md`, `VALUES.md`, `SUCCESS_METRICS.md`, `MARKETING.md`

---

## 1. Purpose

This document is the evidentiary base beneath `USER_PERSONAS.md`. Every persona in that document is a synthesis of real research inputs, not an invented archetype, and this document exists so that any team member can trace a persona trait or a product decision back to the data that justified it. It also records our secondary-research grounding in the broader loneliness and social-infrastructure literature, because TableCrew is making a bet on a public-health-scale problem, and we want that bet to be legible and falsifiable, not vibes-based.

## 2. Research Methodology

We used four complementary methods, deliberately mixing quantitative breadth with qualitative depth, because a problem as texture-rich as "why don't adults make friends as easily as they used to" does not yield to survey data alone.

### 2.1 Structured 1:1 Interviews

We conducted 64 structured interviews (45–60 minutes each) across four target cities in our initial launch consideration set (Austin, Denver, Raleigh, and Columbus — mid-size, high-relocation-rate metros chosen because they overindex on the "new to city" and "friend group scattered" dynamics we hypothesized were core to the problem). Interview participants were recruited via a screener that filtered for: moved to current city within the last 3 years, OR self-reported "harder to make friends than 5 years ago," OR currently organizes recurring gatherings for an existing friend group. This screener is the direct ancestor of our persona split between Discover-first and Crew-first behavior.

Interviews followed a semi-structured protocol covering: last time they made a new friend and how; last time they organized a gathering and what went wrong; what apps/tools they've tried for either goal and why they stopped using them; and a walkthrough of their actual phone (with permission) to see which group chats, Meetup memberships, or dating apps were still installed versus abandoned. The phone walkthrough was the single highest-signal technique in the entire research program — it consistently surfaced abandoned tools people had forgotten to mention verbally.

### 2.2 Survey

We fielded a 12-minute online survey (n=1,240, panel-recruited, quota-balanced for age 22–65 and US metro/suburban/rural split, with an oversample in our four launch-consideration cities) to quantify what the interviews surfaced qualitatively. Key instruments included the UCLA Loneliness Scale (short form) as a validated baseline measure, a custom "social effort inventory" (how many gatherings organized/attended in the last 90 days, and by whom), and willingness-to-pay questions for a hypothetical gathering-coordination product.

### 2.3 Secondary and Public-Health Research

We grounded our quantitative findings against the existing public-health and industry literature rather than treating our own sample as the only evidence the problem is real:

- The **U.S. Surgeon General's 2023 Advisory, "Our Epidemic of Loneliness and Isolation,"** which documents that the average time Americans spend with friends has fallen by more than 20 hours a month since 2003, and that loneliness carries a mortality risk comparable to smoking up to 15 cigarettes a day. This advisory is the single most load-bearing external citation in our thesis, because it establishes that the problem is measured at the population-health level, not just a soft cultural complaint.
- The **Cigna U.S. Loneliness Index** (multiple waves, most recently reporting a majority of U.S. adults classified as lonely on the UCLA scale), which we used primarily to corroborate that loneliness is not concentrated only in older adults — it is highest among younger working-age adults, directly supporting Maya and Alex as the correct primary beachhead rather than Grace.
- **Meetup and Eventbrite category and retention data** (from public reporting, investor materials, and our own account-creation tests on both platforms), which we used to understand the "current alternative" landscape quantitatively: both platforms show strong first-event conversion for structured hobby groups but poor repeat-attendance depth for anything designed around one-off events rather than recurring small groups — directly informing our thesis that recurrence, not discovery, is the harder and more valuable problem to solve.
- Academic literature on "third places" (Oldenburg's concept of informal public gathering spaces) and on friendship formation requiring proximity plus repeated unplanned interaction plus a shared vulnerable context (Jeffrey Hall's research on the ~50 hours required to move from acquaintance to friend), which shaped our belief that a single event is not the unit that builds a friendship — a recurring cadence of small tables is.

### 2.4 Competitive and Alternative-Solutions Research

We ran hands-on trials of every plausible substitute product a target user might already be using, logged as structured product teardowns (onboarding friction, core loop, monetization model, and — critically — why our interview subjects said they stopped using each one).

## 3. Key Quantitative Findings

- 71% of survey respondents in the 25–40 age band agreed with "I wish I had an easier way to organize get-togethers with people I already know," but only 34% had used any dedicated tool (beyond a group chat) to do so in the last year — establishing a large intention-behavior gap that a Crew-first product can close.
- 58% of respondents who had moved to a new city in the last 3 years reported having "0–2 people I'd call to grab dinner with tonight" in their new city one year after moving, despite the large majority reporting an active professional or roommate network — showing that proximity and acquaintance alone are not producing friendship, consistent with the Hall "50 hours" research above.
- Among respondents who had tried a dating app for a non-romantic reason (explicitly screened as "not looking for romance, wanted to meet people") — 22% of the 25–34 cohort — the overwhelming majority (84%) described the experience as "uncomfortable" or "had to over-explain myself," a direct signal that repurposing romance-coded products for friendship is a broken substitute, not a competing solution to out-innovate.
- 46% of respondents who organize group gatherings today (our proto-Alex/Priya segment) reported that "waiting for everyone to RSVP in a group chat" was their single biggest point of friction, and 39% reported having cancelled or shrunk a planned gathering specifically because of ambiguous "maybe" responses — directly informing the binary RSVP requirement in `PRD.md` FR-T10.
- In the phone-walkthrough sub-sample (41 of the 64 interviews), 68% had at least one Meetup account with zero events attended in the last 12 months, and 52% had at least one abandoned dedicated "friendship app" download (Bumble BFF, Meetup, or similar) — quantifying the graveyard of attempted solutions each target user has already tried and abandoned.
- Willingness-to-pay data supported a freemium model: only 18% would pay upfront to try a gathering app, but 61% said they would consider a paid tier "if it had already gotten me to 2–3 good gatherings for free" — directly informing the free-to-start, subscription-upsell monetization structure referenced in `PRD.md` and `PRODUCT.md`.

## 4. Key Qualitative Findings

Several qualitative themes recurred across interviews strongly enough to become load-bearing product decisions:

**"I have people, we just never land on a plan."** The most common failure mode described by proto-Alex interviewees was not a shortage of friends but a coordination failure: a scattered friend group, a group chat with 40 unread messages, and nobody willing to be the one who proposes a plan, picks a place, and chases RSVPs. This is the single strongest piece of evidence behind building Crews as a first-class object with persistent shared history, rather than treating every gathering as a one-off event to be built from scratch each time.

**"I don't want another dating app for friends."** Proto-Maya interviewees were unanimous and vehement that swipe-based, photo-primary interfaces for meeting new people for platonic purposes felt "off," "creepy by association," or "like it's going to turn into something else." This directly shaped Discover's design away from a swipe/match paradigm and toward a structured, activity-and-group-anchored browsing model (see `PRD.md` §5, `DESIGN_SYSTEM.md`), where the unit being browsed is a Table (an activity with a defined social contract), not a person's profile.

**"The scary part isn't meeting someone new, it's meeting them alone."** Multiple proto-Maya and proto-Grace interviewees specifically named the perceived safety of a small group (versus a 1:1 meetup) as the reason they would consider a structured group product but would not consider a 1:1 friendship-matching product. This directly informed the decision (see `PRD.md` §7 out-of-scope) to exclude 1:1 blind-pairing from v1 scope entirely.

**"I'd host more if I didn't have to chase people for money."** Proto-Priya interviewees consistently cited the awkwardness of collecting money after a group meal as a real, if secondary, deterrent to hosting more often — informing the bill-splitting requirement set in `PRD.md` §3.6.

**"I don't need a badge, I need to know they're a real person."** When we tested concepts around gamified trust badges/streaks versus simple identity verification, proto-Maya and proto-Grace interviewees consistently preferred the latter and were actively suspicious of the former, describing badge/streak systems as feeling like "a video game trying to get me to open the app more" — direct qualitative support for `VALUES.md`'s stance against engagement-metric optimization and for the verification-over-gamification approach in `PRD.md` FR-D3.

**Grace-specific finding.** Our four launch cities under-recruited empty-nester and 55+ participants (n=9 across all interviews), so Grace's persona carries the widest confidence interval of the five and is explicitly marked long-horizon rather than beachhead in `USER_PERSONAS.md`. The qualitative signal we do have — a strong preference for daytime/early-evening gatherings, higher stated trust in identity verification, and lower baseline comfort with app-based coordination generally — is treated as directional, not conclusive, pending the dedicated 55+ research wave planned for Phase 2 (see §7).

## 5. Mapping Findings to Personas

- **Maya (New-to-City Professional):** Built from the 58%-of-relocators "0–2 dinner people" quantitative finding, the dating-app-discomfort qualitative theme, and the group-safety-over-1:1 theme. Her Discover-first behavior and her sensitivity to verification/safety signals are both directly sourced findings, not assumptions.
- **Alex (Friend-Group Organizer):** Built from the "I have people, we just never land on a plan" theme and the 46%-RSVP-friction / 39%-cancelled-due-to-maybes quantitative findings. Alex's Crew-first behavior is the single most evidenced persona in the set.
- **Priya (Serial Host):** Built from the subset of proto-Alex interviewees (9 of 64) who described hosting as a recurring identity/hobby rather than an occasional obligation, plus the bill-splitting friction finding. Priya represents the supply side of the Discover marketplace and was validated further through the Meetup/Eventbrite teardown research (§2.4) — she resembles the "organizer" role those platforms depend on and under-serve.
- **Devon (Remote-First Employee):** Built from a distinct interview sub-thread (11 of 64) among remote workers describing a specific pattern: strong professional Slack/Zoom relationships that never converted to in-person friendship because there was no natural trigger to propose meeting up. Devon is an expansion persona because the sample size is smaller and the underlying need (converting adjacent/parasocial relationships into real ones) is a variant of, not a departure from, Maya's core need.
- **Grace (Empty-Nester):** Built from the smaller, directional qualitative sample noted above plus the Surgeon General advisory's specific data on loneliness risk in older adults living alone. Treated as long-horizon and used to stress-test that our product decisions (verification, group-based safety, non-gamified trust) generalize across age bands rather than only working for a narrow 20-something demographic.

## 6. Competitive / Alternative-Solutions Landscape

Users trying to solve this problem today reach for tools that were not built for it, and each falls short in a specific, research-documented way:

- **Group chats (iMessage/WhatsApp) for existing friends.** Ubiquitous but structurally incapable of resolving ambiguity — no shared calendar object, no binary commitment mechanism, decisions diffuse into silence. This is the direct incumbent Crews must beat, not a peripheral competitor.
- **Meetup.** Strong for interest-based one-off event discovery among strangers, weak for recurring small-group intimacy and weak for organizing among people who already know each other. Our teardown found its core loop optimized for event listing volume, not repeat-attendance depth, and its interface treats every event as disposable rather than the start of a recurring relationship.
- **Eventbrite.** Effectively a ticketing/logistics tool for larger, often paid or professional events; not designed for small informal gatherings and carries no social/friendship framing at all.
- **Dating apps used off-label (Bumble BFF, Hinge, etc.).** Actively repurposed by a meaningful minority of our 25–34 respondents for platonic purposes, and rejected by the large majority of them as uncomfortable, as documented above — the closest thing to a "false substitute" in the market, and the strongest evidence that visual, 1:1, swipe-based interaction patterns are the wrong shape for this problem.
- **Nextdoor / neighborhood apps.** Occasionally used to organize informal local gatherings but not purpose-built for it; surfaced in a handful of interviews as a workaround, not a solution, with no RSVP/lifecycle management at all.
- **Doing nothing (status quo).** The largest "competitor" by far is simply not organizing anything and accepting a thinner social life — the 58% "0–2 dinner people" statistic is really a measurement of this default outcome. Our real competition, in other words, is inertia, not another app; this shapes our marketing thesis in `MARKETING.md` toward activation and habit formation rather than head-to-head feature comparison.

## 7. Ongoing Research Cadence

Research is not a one-time input that gets frozen into `USER_PERSONAS.md` at launch. We commit to:

- **Quarterly persona review:** each quarter, Product Research re-examines all five personas against the latest in-app behavioral data (via BigQuery exports per `FIREBASE.md`) and a fresh round of 8–12 lightweight interviews per persona, and publishes an addendum here noting any drift (e.g., if Devon's behavior turns out to more closely resemble Alex's than originally modeled, or if a sixth persona is emerging from the data and should be formally added).
- **Post-launch cohort interviews:** starting at Phase 0 launch (`ROADMAP.md`), every cohort of new users is sampled at the 2-week and 8-week marks for a short structured interview about what got them to their first Table and whether they returned for a second — this is the direct operational source of the activation and retention metrics defined in `SUCCESS_METRICS.md`.
- **Annual secondary-research refresh:** we re-pull the Surgeon General, Cigna, and Meetup/Eventbrite external data sources annually (or sooner if a major new public-health report on loneliness is published) to confirm our founding thesis still holds and to catch shifts in the competitive landscape.
- **Pre-expansion market research:** before each new-market entry in `ROADMAP.md` (new city cluster in Phase 1/2, new country in Phase 3), a scaled-down version of this full research methodology (interviews + survey, secondary research already established) is re-run locally, because loneliness dynamics, group-dining norms, and trust/safety baselines are not assumed to transfer uniformly across cultures — a direct expression of the "Global-first not US-first" value in `VALUES.md`.
