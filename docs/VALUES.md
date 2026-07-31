# Values

These are the six operating principles that govern how TableCrew builds product, hires, and makes decisions under ambiguity. Values are only meaningful if they cost something when followed — each one below includes what we give up to honor it.

## 1. Hospitality is a design principle, not a vibe

We treat every user as a guest, and every design decision as an act of hosting. Concretely: default settings favor the user's comfort and consent over our growth metrics (opt-in over opt-out for anything social or public-facing), error states are written with the warmth of an apologetic host rather than a terse system, and onboarding is paced like a good dinner party host would pace introductions — a few people at a time, not a flood.

**What this costs us:** slower viral loops. We forgo aggressive contact-list scraping, dark-pattern invite flows, and notification tactics that plenty of competitors use to grow faster. See `COPY_GUIDELINES.md` and `DESIGN_SYSTEM.md` for how this shows up concretely, and `MARKETING.md` for how we grow without them.

## 2. Safety is a feature, not a department

Trust and safety is resourced and shipped as core product, on the same release cadence as growth features, not bolted on after a launch. Every meetup format we ship answers, before launch, four questions: how do we verify identity, how do we handle a no-show or bad actor, how do we make reporting a 10-second action, and how do we make the harm-response loop faster than the harm can repeat. See `SECURITY.md` for the concrete mechanisms and `PRD.md` for how safety requirements gate feature launch.

**What this costs us:** slower feature velocity, and we will delay or narrow the geographic rollout of any feature (e.g., stranger-matched Tables in a new country) until local safety requirements are met, even when that means losing a growth window to a faster-moving, less careful competitor.

## 3. Real connection over engagement metrics

We optimize for people leaving the app to go sit at a table, not for time spent inside it. Product and growth teams are not compensated on session length, DAU/MAU ratio maximization in isolation, or infinite-scroll-style engagement; they are compensated on Tables Attended, repeat attendance, and the health metrics in `SUCCESS_METRICS.md`.

**What this costs us:** ad-model monetization is largely off the table (see `INVESTOR_OVERVIEW.md` for why we monetize via subscription and venue partnerships instead), and some investor pressure to report vanity engagement numbers will be met with a harder, less flattering set of metrics instead.

**Where this draws the line, precisely, because "no ads" is not self-enforcing:** we do sell "Featured Venue" placement to restaurants (`PRODUCT.md`), which is a paid placement product and needs to be named honestly as a close cousin of advertising, not waved away as something else. The distinction we hold ourselves to is behavioral, not semantic: we do not sell third-party behavioral advertising, we do not sell user data or attention to advertisers, and — the rule that actually has teeth — a Featured Venue placement may never appear inside Discover's person-to-person Table matching or affect which Tables or people a user is shown or ranked against (per FR-D4/FR-D5 in `PRD.md`, matching is never paid-for-priority). Featured placement is scoped narrowly to venue-selection surfaces (e.g., "suggested venues for your Table"), is always labeled "Sponsored" per `COPY_GUIDELINES.md`, and is capped so it cannot crowd out organic venue suggestions past a defined share of results. If this line ever gets proposed to move — sponsored placement bleeding into Discover's people-matching — that is a values violation, not a growth optimization, and should be treated as such by whoever is asked to ship it.

## 4. Global-first, not U.S.-first-then-ported

We design for the fact that our earliest and largest addressable population is people who feel disconnected because they are new to a place — expats, immigrants, relocators, students abroad — a population that is inherently international. Internationalization (language, currency, cultural norms around hosting and dining, right-to-left layout support), accessibility, and data residency requirements are designed in from `ARCHITECTURE.md` and `DATABASE.md` decisions onward, not retrofitted.

**What this costs us:** more upfront engineering cost per feature, and a slower initial ship for features that would be simpler if we assumed one language, one currency, one legal regime.

## 5. Bias toward shipping, with a rollback plan

We favor small, reversible bets shipped quickly over long planning cycles for large, irreversible ones. Every feature ships behind a flag with an explicit rollback plan and an owner (see `ENGINEERING_GUIDELINES.md` and `DEPLOYMENT.md`). We are comfortable being wrong quickly and cheaply; we are not comfortable being wrong slowly and expensively.

**What this costs us:** we sometimes ship a version 1 of something that is visibly rough, and we accept the brand risk of that roughness in exchange for the learning speed.

## 6. Respect data like it's someone's actual life, because it is

Location history, dining preferences, who someone chose to spend an evening with — this is sensitive, intimate data, more so than most consumer apps handle. We collect the minimum necessary, we are legible about what we collect and why (see `COPY_GUIDELINES.md` for how we write privacy-facing copy), and we give users real, working deletion and export tools, not compliance theater. See `SECURITY.md` for the technical implementation of this principle.

**What this costs us:** we forgo some personalization and monetization value that competitors extract from broader data collection and third-party data sharing.

**One honest limit on "real deletion":** payment and tax law (and Stripe's own merchant obligations) require us to retain transaction and invoice records for a statutory period (typically 7 years) even after a user requests account deletion — genuinely "real, working deletion" here means deleting or irreversibly anonymizing personal data (profile, messages, RSVPs, location history) immediately, while retaining the minimum financial ledger required by law with personal identifiers stripped or tokenized wherever the retained record does not legally require them. `SECURITY.md` and `DATABASE.md` specify exactly what is deleted, what is retained, and why, so this exception is documented and bounded rather than a loophole that swallows the promise.

## How these values are enforced

Every PRD (`PRD.md` template) includes a "Values check" section where the author states, in writing, which of these six values the feature interacts with and how. Every quarterly retro reviews one values trade-off the company actually made, documented in `CHANGELOG.md`, so the values stay falsifiable rather than decorative.
