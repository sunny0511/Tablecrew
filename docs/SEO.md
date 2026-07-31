# TableCrew SEO & ASO Strategy

## 1. Purpose and Scope

This document covers organic discoverability across two distinct surfaces that require different tactics but one shared strategy:

1. **Web search (traditional SEO)** — a lightweight marketing website and blog that establishes topical authority on loneliness, adult friendship, and local social activity, and converts search traffic into app installs.
2. **App Store / Play Store search (ASO)** — the primary discovery surface for the product itself, since the platform's flagship current surface is a mobile app and most of the actual product experience never lives on the web.

Both surfaces exist to complement, not duplicate, the acquisition channels in `MARKETING.md`. SEO/ASO is a compounding, low-marginal-cost channel that pays off over quarters, not days — it is not a substitute for the referral loop or city-launch community-ops work that drives near-term density in a new market, but it is what makes TableCrew discoverable to the large pool of people actively searching for a solution to loneliness or friendship-building *before* they've ever heard of TableCrew as a brand.

---

## 2. Content Strategy: Marketing Website and Blog

### 2.1 Why content, and why this angle specifically

`USER_RESEARCH.md` establishes that loneliness and adult friendship-formation difficulty are well-documented, actively-searched problems, not a niche concern TableCrew invented. People type real queries into Google about this: "how to make friends as an adult," "why is it so hard to make friends after 30," "things to do with new friends in [city]," "how to get my friend group to hang out more." This is high-intent, top-of-funnel search behavior with genuine informational need — exactly the kind of query where a thin, SEO-farmed content page fails and a genuinely useful, well-written page ranks and earns trust. Because the underlying problem (loneliness, friendship friction) is stable and non-seasonal, content built here has a long shelf life and compounds instead of decaying the way a paid campaign does the moment spend stops.

### 2.2 Content pillars

**Pillar A — City + activity landing pages.** Programmatic-but-genuinely-useful pages structured as "[Activity] with new friends in [City]" (e.g., "Dinner parties with new friends in Austin," "Weekend brunches with new friends in Manchester") and "Things to do with new friends in [City]." These pages serve dual purposes: they rank for high-intent local queries, and they double as functional landing pages that showcase real (anonymized/aggregated) Table activity in that city once a city has launched, giving the page genuine local specificity instead of generic template text. Pre-launch cities get a lighter-weight version of this page focused on the loneliness/friendship informational angle plus a waitlist signup, avoiding the SEO risk of thin, low-value pages competing for the same city+activity keywords before there's real local content to fill them.

**Pillar B — Long-form authority content on loneliness and adult friendship.** Deeper, well-researched pieces that cite the same research base as `USER_RESEARCH.md` (e.g., the U.S. Surgeon General's 2023 loneliness advisory, sociological research on adult friendship decay after major life transitions like graduation, relocation, or parenthood). Examples: "Why adult friendships get harder after 30, according to the research," "The loneliness epidemic, explained," "How many friends do you actually need? What the research says." This content is not written as disguised app marketing — it is written to genuinely answer the query, with TableCrew mentioned as one practical next step rather than the entire premise of the article. This is what builds the topical authority (backlinks, dwell time, return visits) that search engines reward, and it is consistent with the "real connection over engagement metrics" value: the content has to be honest and useful on its own merits, not just bait.

**Pillar C — Host and Table storytelling.** Real (consented, lightly anonymized where appropriate) stories from hosts and Crews, republished from the local content work described in `MARKETING.md` Section 4.3 and Section 6's "Hosts of [City]" campaign. This content serves SEO (fresh, unique, locally-specific content signals), brand trust (social proof, safety reassurance), and cross-promotion of the referral loop simultaneously.

**Pillar D — Practical/how-to content adjacent to hosting.** "How to host a dinner party for people you just met," "icebreaker questions that actually work," "how to split a restaurant bill for a group" — lower-competition, high-utility queries that build a broader net of organic entry points beyond the core loneliness angle, and naturally target Priya-persona (Serial Host) search intent.

### 2.3 Prioritization and cadence

Pillar B (authority content) is prioritized first because it requires no live city data and starts building domain authority and backlinks from day one, well before Phase 0 launch. Pillar A (city pages) is built out in lockstep with `ROADMAP.md`'s city sequencing — a city page only goes live in its full form when that city has launched, so the page always reflects genuine local activity rather than a placeholder. Pillars C and D are ongoing content operations, roughly 2-4 pieces per month once a content function is staffed, scaling with the number of active cities.

---

## 3. Technical SEO

Given TableCrew is fundamentally a mobile app with a lightweight marketing site (not a content-heavy web product), technical SEO investment is deliberately scoped to a short list of high-leverage basics rather than a large web engineering investment:

- **Site speed:** the marketing site is built as a static/statically-generated site (not a full client-side app shell) so that city and blog pages achieve fast Largest Contentful Paint and pass Core Web Vitals thresholds without dedicated backend infrastructure — consistent with keeping the web presence lightweight per the company's actual product focus (mobile app, not web app).
- **Structured data / schema.org:** public-facing, Discover-adjacent pages (e.g., a city's public Table-type listings, if surfaced on the web at all) use `Event` schema markup where a real, publicly-visible gathering type is being described, enabling rich results in search (dates, location, attendee-type context) and improving click-through from search. Blog content uses `Article`/`FAQPage` schema where relevant (e.g., FAQ-style loneliness content) to qualify for expanded SERP features. Schema is applied conservatively and only to genuinely public content — Closed Tables and any content with real user PII are never exposed to structured data or public indexing, which is a hard rule shared with `SECURITY.md`.
- **Sitemap strategy:** a segmented sitemap structure (separate sitemaps for city+activity pages, blog/authority content, and static marketing pages) submitted via Search Console/Bing Webmaster Tools, with pre-launch city placeholder pages excluded from the sitemap until they carry real content (per Section 2.2) to avoid diluting crawl budget and quality signals with thin pages.
- **Canonical and duplicate-content hygiene:** the city+activity page template (Pillar A) is the highest duplicate-content risk in this strategy since it's structurally repeated across cities; each page requires genuinely unique local detail (real venues, real activity types, real host quotes) rather than a swapped city name over identical boilerplate, both for user value and to avoid a thin-content penalty risk.
- **Mobile-first indexing readiness:** trivially satisfied given the company's mobile-first identity, but explicitly verified as part of site QA since Google indexes the mobile rendering of the site by default.

---

## 4. App Store Optimization (ASO)

Because TableCrew's actual product lives entirely on-device, App Store and Google Play search are arguably a higher-leverage organic surface than the web for bottom-of-funnel conversion — a user who searches "make new friends app" or "dinner with strangers app" in the App Store has near-maximal intent.

### 4.1 Keyword strategy

Primary keyword clusters to target across the App Store's keyword field (iOS) and Play Store listing/metadata (Android):
- **Core intent:** "make friends app," "meet new people app," "friend finder," "adult friends."
- **Occasion/format intent:** "dinner with strangers," "group dinner app," "supper club app," "social dining."
- **Persona/context intent:** "new city friends," "moved to new city app," "friend group planning app," "group hangout planner."
- **Competitor-adjacent (used carefully, see Section 6):** terms describing the category (e.g., "social dinner matching") rather than direct competitor brand names, both for App Store policy compliance and because brand-name keyword-riding produces low-quality installs that hurt retention metrics we actually care about.

Keyword selection is validated iteratively using each store's search-suggestion/autosuggest data and post-launch conversion-rate data by keyword (available via App Store Connect and Play Console), not guessed once and left static — the keyword field is revisited at least quarterly and after every major feature launch (e.g., once Discover ships in Phase 1, "meet new people" cluster terms get materially more weight in the listing).

### 4.2 Ratings and review velocity

Ratings/review count and recency are a first-order App Store and Play Store ranking input, and for a trust-sensitive social product they are also a first-order *conversion* input — a prospective user deciding whether to trust a stranger-facing social app with real-world meetups will check reviews before installing, arguably more than for a typical utility app. Our approach:
- In-app rating prompts are triggered contextually after a positive signal (e.g., immediately after a user rates a Table highly), not on a generic timer or app-open counter — this both respects the "real connection over engagement metrics" value (no engagement-bait prompts) and produces higher-quality, higher-scoring reviews because the prompt lands at a genuine high point.
- Community managers (per `MARKETING.md` Section 9) are explicitly tasked with encouraging satisfied seed hosts to leave reviews during city launch, since early review volume/velocity in a new city or new store territory matters disproportionately for that market's initial store ranking.
- Negative reviews related to safety or trust concerns are treated as a Tier-1 signal routed to the trust & safety function described in `SECURITY.md`, not merely a reputation-management issue — the review itself is often the first signal of a product or moderation gap.

### 4.3 Localized store listings

Consistent with the Global-first value, store listings (title, subtitle/short description, keyword field, screenshots, preview video) are localized per target market rather than shipped as a single English listing with machine-translated text bolted on. Localization includes: translated and culturally-adapted keyword clusters (the literal translation of "dinner with strangers" is not always the highest-intent local query — this requires local keyword research per market, not just translation), locally relevant screenshot content (showing recognizable local venue types/settings rather than a single US-coded visual identity), and pricing/subscription display in local currency and norms. Localized listings are prioritized in the same sequence as `ROADMAP.md`'s Phase 3 international expansion — built ahead of a market's launch, not retrofitted after.

### 4.4 Screenshot and preview video strategy

Store listing creative is built around the same persona messaging framework as `MARKETING.md` rather than generic product-tour screenshots: the first 2-3 screenshots (the ones that actually drive conversion, since most users don't scroll the full set) lead with the emotional outcome — a real, warm-looking table of people who look like plausible real friends, not stock-photo-perfect models — followed by functional screenshots showing the mechanics that build trust and reduce perceived friction (host profiles/ratings, RSVP/headcount clarity, Crew scheduling). The preview video (autoplaying on both stores) is built as a 15-20 second narrative arc mirroring the Alex-persona core message from `MARKETING.md` ("stop being the group's unpaid event planner") since organizer-persona pain is the most universally recognizable hook across all five personas, with persona-specific variants tested via store listing A/B experimentation (both App Store Connect and Play Console support this natively) before a broader international or paid-campaign push.

### 4.5 Category classification and policy risk

Because TableCrew arranges in-person meetings between people who don't already know each other (Discover), Apple and Google apply materially more scrutiny to this product category than to a typical utility or content app — comparable to, though not identical to, the review bar applied to dating apps. This shows up concretely as: age-rating questionnaires that ask directly about user-to-user contact and meetup facilitation, requirements or strong recommendations around in-app reporting/blocking tools before a listing is approved, and in some cases explicit store-policy language governing apps that facilitate ongoing relationships or in-person meetups between strangers. This is a distribution risk, not just a keyword-strategy footnote to the ASO plan above: an unfavorable category classification, a failed or delayed app review, or a policy reinterpretation could delay a launch, force late-stage store-listing or product changes, or in an adverse scenario result in extended review holds or removal — a materially higher-stakes failure mode for TableCrew than for most apps pursuing an ASO strategy, since TableCrew has no meaningful web-based distribution alternative (Section 1).

*Mitigation:* the identity verification, reporting, and incident-response infrastructure already required by `SECURITY.md` for Discover (ID + selfie liveness verification, a 10-second reporting flow, an incident-response workflow) is substantially the same infrastructure both stores look for when reviewing apps in this category, which means ASO/store-listing work should be sequenced *after*, not ahead of, confirming category classification and required safety disclosures with both platforms ahead of each new market's Discover launch — treating store policy compliance as a gating input to the ASO plan rather than an independent, purely-keyword-driven workstream. See `INVESTOR_OVERVIEW.md` Section 9 for this risk's treatment at the company/distribution level.

---

## 5. Measurement Approach

Organic search (web) and ASO (store search) are measured and reported separately from the acquisition channels in `MARKETING.md`, using two primary metrics:

1. **Organic install share:** the percentage of total new installs attributable to unpaid App Store/Play Store search and unpaid web-to-app referral, tracked via store-provided source attribution (App Store Connect's "App Store Search" source, Play Console's acquisition reports) and UTM-tagged links from web content to app store/deep links. This is reported as a share of total installs specifically so it is read in context alongside referral and paid shares from `MARKETING.md`, rather than as an isolated absolute number that can't be compared against the rest of the funnel.
2. **Organic web-to-app conversion rate:** of website visitors arriving via unpaid search, the percentage who click through to an app store listing or app deep link, and (where measurable via deferred deep linking) the percentage who subsequently complete signup and attend a first Table. This closes the loop from top-of-funnel informational search content (Pillar B) through to the outcome the whole company is judged on per `SUCCESS_METRICS.md` — a real Table happening — rather than stopping measurement at a superficial click or pageview metric.

**How this complements, rather than duplicates, `MARKETING.md`:** SEO/ASO is explicitly the "always-on, compounding" layer underneath the more active, hands-on channels in `MARKETING.md`. Referral loops and community-manager-led city launches drive the initial density and trust signal in any given market; SEO/ASO content and store presence then serve the much larger pool of people who are already searching for a solution to loneliness or friend-making but haven't yet been reached by word-of-mouth or local community-ops. We explicitly do not count organic search/ASO installs toward city-launch density targets (Section 3.2 of `MARKETING.md`) in early-phase cities, since that channel's payoff curve is slower and less locally-concentrated than the referral and community-ops channels that density-first launch depends on — SEO/ASO is a multi-quarter compounding investment layered on top of, not a substitute for, the city-by-city playbook.
