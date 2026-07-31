# TableCrew Copy Guidelines

## Purpose

This document is the UX writing style guide for every piece of text inside the TableCrew product: buttons, labels, empty states, error messages, push notifications, onboarding, settings, and privacy copy. Where `BRAND_GUIDELINES.md` defines who TableCrew is and `DESIGN_SYSTEM.md` defines how the product looks, this document defines exactly what the product says, word by word, so that any writer, designer, or engineer typing a string into the app produces copy that is indistinguishable in tone from copy written by anyone else on the team.

The single test every string in this product must pass: **would a good host say this to a guest at their table?** A good host doesn't guilt a guest for leaving early, doesn't manufacture fake scarcity to pressure a decision, and doesn't bury the house rules in fine print. That standard is the practical, sentence-level expression of the value stated in `VALUES.md`: "hospitality is a design principle, not a vibe."

---

## 1. Tone of Voice Principles for UI Copy

- **Warm, not effusive.** Default to plain, kind phrasing. Reserve exclamation points for genuinely celebratory, rare moments (a user's first hosted Table completing successfully) — never for routine confirmations, reminders, or system messages. A string like "Table created." is preferable to "Table created!!! 🎉" for a routine action.
- **Clear before clever.** Every string should be understandable on first read by someone quickly glancing at their phone. If a pun, wordmark reference (e.g., a "seat at the table" idiom), or clever turn of phrase would slow comprehension or requires native-English cultural fluency to land, cut it. Clarity always outranks cleverness — this is doubly true given the global-first requirement in section 6.
- **Brief.** UI copy is written for scanning, not reading. Prefer the shortest sentence that is still warm and complete. A button label is 1–3 words. A confirmation toast is one short sentence. A modal explanation is at most two sentences.
- **Never guilt-trippy.** Copy must never imply the user owes the app, the host, or their friends an action. We do not write "Your friends are waiting on you" or "Don't leave them hanging" — these frame ordinary non-response as a moral failing. Instead we state facts neutrally and let the user decide ("The host is still waiting to hear from a few people, including you.").
- **No manufactured urgency or dark-pattern scarcity language.** Per `VALUES.md`'s "real connection over engagement metrics," we never write "Only 2 spots left!!", "Hurry, this Table is filling up fast!", or countdown-style language designed to provoke anxiety-driven action. If a Table genuinely has few seats remaining, we state it plainly and once: "2 seats left." No exclamation points, no bold-red emphasis, no repetition.
- **No corporate distancing language.** We do not write "Your request has been received and will be processed" — we write "Got your request — the host will confirm soon." Passive, bureaucratic phrasing is banned from user-facing copy; use active voice and name who is doing what.

---

## 2. Terminology Glossary

Precise, consistent nouns matter enormously in a product whose core anxiety is "what actually is this app." The table below is the single source of truth; no synonym substitutions are permitted in shipped copy without a documented update to this glossary.

| Concept | Term to use | Term to avoid | Why |
|---|---|---|---|
| A single gathering | **Table** | "Event," "Meetup," "Session" | "Event" is generic and calendar-flavored; "Meetup" collides with a specific competitor's brand; "Table" is the product's own noun and reinforces the etymology in `BRAND_GUIDELINES.md` every time a user reads it |
| A persistent friend group | **Crew** | "Group," "Circle," "Squad" | "Group" is too generic and appears in a dozen other app contexts (chat groups, calendar groups); "Circle" is already strongly associated with Google+/contact-management features; "Squad" skews younger/slangier than fits Devon or Grace; "Crew" is specific to this product and signals small, trusted, and enduring |
| The surface for meeting curated new people | **Discover** | "Explore," "Browse," "Feed" | "Feed" specifically must never be used — it is the exact word that signals infinite-scroll, engagement-optimized social media and dating-app browsing, which is the category we are distancing from; "Discover" frames the action as finding a good fit, not consuming content |
| Confirmed attendance | **Going** | "Attending," "Confirmed," "Yes" | "Going" is the shortest, plainest, most universally-understood confirmation word in English and translates simply into most languages without needing a formal register shift |
| A pending request to join a Closed Table | **Requested** | "Pending," "Applied," "Asked to Join" | "Requested" is a precise, neutral verb-noun that describes exactly what happened without implying judgment (unlike "Applied," which sounds like a job application with a pass/fail outcome) |
| Waiting for a seat to open | **Waitlisted** | "In Queue," "On Hold" | "Waitlisted" is a familiar, low-anxiety word borrowed from restaurants and events — users already know what it means and know it's provisional, not a rejection |
| A user declining or leaving an RSVP | **Not Going** | "Declined," "Rejected," "Cancelled" | "Declined" and "Rejected" carry formal/negative connotations disproportionate to a simple no; "Cancelled" is reserved exclusively for the host cancelling the whole Table (see `DESIGN_SYSTEM.md` color mapping); "Not Going" is the plainest possible phrase for a personal choice |
| The person who set up a Table | **Host** | "Organizer," "Creator," "Admin" | "Host" reinforces the brand archetype in `BRAND_GUIDELINES.md` and carries a warm, hospitality-coded connotation that "Admin" (bureaucratic) or "Organizer" (task-manager-coded) do not |
| A Table visible to anyone on Discover | **Open** | "Public" | "Public" carries a slightly exposed, broadcast connotation (as in "public post"); "Open" better matches the physical metaphor of an open seat at a table |
| A Table visible only to those invited | **Closed** | "Private" | "Private" is not wrong but is used inconsistently across every other app (private account, private message, private group); "Closed" pairs cleanly and specifically with "Open" as a matched pair unique to Tables |

---

## 3. Empty States and Error Messages

Empty states and errors are the moments a hospitality-first product is most tested, because they are exactly the moments a lesser product goes cold, technical, or blaming. Every empty state and error string follows the same three-part shape where space allows: **name what's true, remove any blame, offer the next warm step.**

**Example — no Tables yet (new user, empty Discover-adjacent home screen):**
> "Nothing on your table yet. When you join or host a Table, it'll show up here."
> [Host a Table]  [Explore Discover]

**Example — Crew with no upcoming Tables:**
> "The Downtown Crew doesn't have anything on the calendar. Want to be the one who gets it started?"
> [Plan a Table]

**Example — network error submitting an RSVP:**
> "That didn't quite make it through. Want to try again?"
> [Try Again]

(Note: no error code, no "Error 500," no technical detail surfaced to the user — technical detail is logged silently for engineering per `ENGINEERING_GUIDELINES.md` / `SECURITY.md`, never shown in the UI.)

**Example — a Requested join was declined by the host:**
> "The host wasn't able to fit everyone in this time. This one didn't work out, but there are other Tables open near you."
> [See Open Tables]

(Note: framed around Table capacity, never around the user personally — no "You weren't chosen" language, which would read as a social rejection rather than a logistics constraint.)

**Example — form validation (missing required field):**
> "Just need a time for this Table before you can send the invites."

(Note: states the missing requirement plainly and names why it matters, rather than a bare "Field required.")

---

## 4. Push Notification Copy Philosophy

Push notifications are the highest-risk copy surface for violating "real connection over engagement metrics," because notification copy is the most common place consumer apps deploy dark patterns — manufactured urgency, guilt, social pressure, or vague curiosity-gap bait ("You won't believe who just...") designed purely to drive opens.

TableCrew's notification philosophy: **every notification must be genuinely useful to the recipient in that moment, phrased as plainly as the information itself, and worth the interruption on its own merits — never phrased to manufacture an open.** Concretely:

- **No fake urgency.** We never write "Hurry!" or "Don't miss out!" in a push notification. If a deadline is real (an RSVP cutoff, a Table starting soon), we state the deadline plainly.
- **No curiosity-gap baiting.** We never withhold the actual content of a notification to force an open ("Someone just did something interesting…"). The notification body always contains the actual information.
- **No guilt-based re-engagement.** We never frame a lapsed user's absence as letting people down. Re-engagement copy is framed as an invitation back, not a debt owed.
- **Frequency respect.** Per `VALUES.md`, notification defaults favor the user's attention over the company's growth metrics — reminder notifications are capped (e.g., a single RSVP reminder, not an escalating sequence), and every notification category is individually toggleable in Settings, not bundled into an all-or-nothing switch.

**RSVP reminder (day before a Table):**
> "Coffee & Conversation is tomorrow at 6:00 PM. See you there?"

**Day-of nudge (a few hours before):**
> "Coffee & Conversation starts at 6:00 PM today at Blue Bottle on 5th. Here's the address."

**Host reminder to confirm a Requested guest:**
> "3 people have asked to join your Table this Saturday. Take a look when you get a chance."

**Crew re-engagement prompt (no urgency, no guilt):**
> "It's been a while since the Downtown Crew got together. Want to set something up?"

**What we explicitly do not send:** notifications announcing another user's activity purely to drive curiosity ("Someone new joined Discover near you — see who!"), streak-based guilt notifications ("Don't break your hosting streak!"), or social-comparison notifications ("Your friend hosted 3 Tables this month"). None of these serve the recipient; all of them serve engagement metrics at the recipient's expense.

---

## 5. Privacy and Consent Copy Philosophy

Per `VALUES.md`'s data-respect principle, every privacy- or consent-related string in TableCrew is written in plain language, states exactly what will happen, and never buries a meaningful choice inside a wall of legal text or a pre-checked box.

Principles:

- **State the mechanism, not just the policy.** Instead of "We may share data with third parties as described in our Privacy Policy," a settings screen states the actual behavior: "Your last name and photo are only visible to people in your Crews and Tables you've joined. People on Discover see your first name, photo, and a short bio — nothing else."
- **No pre-checked opt-ins for anything beyond strictly necessary functionality.** Any optional data use (e.g., using contacts to suggest Crew members, location for nearby Discover results) is opt-in, off by default, and explained in one plain sentence at the moment it's requested — not disclosed only in a settings menu the user may never open.
- **Permission requests explain the "why" in the same breath as the "what."** Example, requesting location access: "TableCrew uses your location to show Tables happening near you. We don't share your exact location with other users." This is shown before the OS-level permission prompt fires, so the system dialog is never the user's first encounter with why the permission is being asked.
- **Consent copy is revisitable, not one-time.** Every consent given (contacts access, location, notification categories) is visible and changeable in one place in Settings, described in the same plain language as when it was first requested — not just a system-settings deep link with no in-app explanation.
- **No dark-pattern friction on the "no" or "off" path.** Declining an optional permission or turning off a data-sharing setting takes exactly as many taps as accepting it. We never add confirmation dialogs, guilt copy ("Are you sure? You'll miss out on personalized Tables"), or extra steps designed to make the privacy-protective choice harder to complete than the data-sharing choice.

**Example — requesting contacts access:**
> "See which of your contacts are already on TableCrew? We'll only check for matches — we never message your contacts or store your address book."
> [Not Now]  [Check Contacts]

(Note: "Not Now" is listed first and given equal visual weight, per `DESIGN_SYSTEM.md` secondary-button treatment — not a subtle grey "skip" link overshadowed by a bold "Allow" button.)

---

## 6. Localization Guidance

TableCrew is global-first, not US-first (`VALUES.md`), and copy must be written so that translation preserves meaning and warmth rather than becoming confusing or accidentally comedic in another language. Guidance for anyone writing user-facing strings:

- **Avoid idioms and wordplay.** Phrases like "the more the merrier," "break bread," or puns on "Table" and "Crew" (e.g., "Crew-nion," "let's Table this") may charm an English-speaking copywriter but frequently fail to translate, either becoming meaningless or requiring a translator to invent an unrelated local idiom that drifts from brand voice. Write the literal meaning instead: not "Let's break bread together" but "Share a meal together."
- **Avoid culturally specific references.** Don't reference US-specific institutions, holidays, or customs (Thanksgiving, Super Bowl Sunday, a specific US restaurant chain) as example use cases in onboarding copy or marketing; use universal or explicitly localizable placeholders instead ("a holiday gathering," "a weekly dinner").
- **Keep sentence structure simple.** Prefer subject-verb-object sentences over nested clauses, conditionals, or passive constructions — simple sentence structure is dramatically easier to translate accurately and mechanically checkable by translators without native-level English fluency. "The host will confirm your spot soon" translates more reliably than "Once the host has had a chance to review it, your spot should be confirmed shortly."
- **Avoid gendered defaults and culturally loaded honorifics.** Copy should not assume gendered pronouns for a generic host or guest ("he'll let you know") and should avoid honorific assumptions (Mr./Mrs./Ms.) that don't map cleanly across cultures — use names or role terms ("the host," "your Crew") instead.
- **Numbers, dates, and units must be locale-formatted, not hardcoded in copy strings.** Any string containing a date, time, or headcount must use locale-aware formatting variables (handled at the engineering layer per `ENGINEERING_GUIDELINES.md`) rather than embedding a US-format date or 12-hour time directly into a translated string.
- **Keep terminology glossary terms (section 2) consistent across languages.** Each core term (Table, Crew, Discover, Going, Requested, Waitlisted, Host, Open, Closed) should be translated once, deliberately, and used identically everywhere in every locale — translators should be given this glossary directly rather than translating each instance of the word independently, which risks the same English concept being rendered three different ways in one translated build.
- **Test copy length in context.** Many languages (German, Finnish, Russian) run 20–35% longer than English for equivalent meaning; UI copy should be written with headroom for expansion rather than packed to the pixel edge of a button or chip, consistent with the generous spacing principles in `DESIGN_SYSTEM.md`.

### 6.1 Bill-Splitting and "Who Pays" Copy — Do Not Hardcode One Cultural Norm

Alex's persona need (`USER_PERSONAS.md`) for a bill-splitting integration, and the general RSVP/logistics copy around a Table, must not silently assume the Dutch-split ("everyone pays their own share, split evenly, at the table, in front of each other") norm that is common in the U.S. and parts of Northern Europe but is unusual, mildly awkward, or actively face-threatening in many other dining cultures — for example, host-pays-and-is-quietly-reimbursed-later norms common in parts of East Asia and Latin America, or the expectation in some cultures that the person who invited pays outright with no reimbursement at all. Copy that says "Split evenly with everyone at the table" as a hardcoded default framing risks embarrassing a host or guest operating under a different norm, in front of the exact group of near-strangers the product is trying to make feel comfortable.

Concrete rules:

- **Never hardcode a single payment-norm assumption into copy.** Do not write strings like "Everyone pays their own way" or "Split the bill evenly" as if that were the universal default. Instead, describe the *mechanism* neutrally and let the host choose the framing: "The host has set up bill-splitting for this Table — here's your share," which works whether the underlying norm is even-split, host-covers, or a custom amount the host entered.
- **Let the host's chosen split method drive the copy, not the other way around.** If the host selects "even split," "host covers, no repayment requested," or "custom amounts," the confirmation and reminder copy should reflect exactly that choice back to guests plainly, rather than the app editorializing about what's "normal" or "fair."
- **Avoid copy that implies non-payment or repayment is a social failure.** Payment-reminder copy follows the same never-guilt-trippy standard as section 1 — "A reminder: your share for Coffee & Conversation is $12" not "Don't forget to pay the host back!"
- **Do not assume repayment must be public or in-app.** Some hosts and guests will settle privately (cash, a separate payment app, or simply as a personal favor) outside TableCrew entirely; copy describing bill-splitting as a feature must present it as optional tooling for the host who wants it, never as an implied obligation that a Table isn't "complete" until in-app settlement happens.

This guidance should be treated as binding on whoever writes the bill-splitting copy specified in `PRD.md` — the copy work is not done until it has been checked against a non-Western dining/payment norm, not just proofread for tone.

---

## 7. Sponsored Venue Placement Labeling

Per `VALUES.md` §3, TableCrew sells "Featured Venue" placement to restaurants on venue-selection surfaces (e.g., "suggested venues for your Table"). This is a paid placement product, and the value's promise that it is "always labeled 'Sponsored'" is only real if the label copy, placement, and visual treatment are specified concretely enough that no designer or engineer has to improvise it under deadline pressure. This section is that specification.

- **Exact label copy:** the word **"Sponsored"** (English; see the terminology glossary standard in section 2 for how this term should be handled consistently once translated — it should be translated once, deliberately, and used identically everywhere, the same discipline applied to Table/Crew/Discover). Do not substitute "Ad," "Promoted," "Partner," or "Featured" alone without the word "Sponsored" — "Featured Venue" is the internal/marketing product name (see `PRODUCT.md`), but the user-facing label on the placement itself must say "Sponsored," since that is the plainest, most widely understood disclosure term across regulatory regimes and the least euphemistic option available.
- **Placement rule:** the "Sponsored" label always appears immediately adjacent to the venue name it labels — directly above, or inline before, the venue name in the same visual block — never in a footer, tooltip, "i" info-icon disclosure, or anywhere requiring an extra tap to discover. A user should never be able to see a venue suggestion without also seeing, in the same glance, that it's sponsored.
- **Visual treatment (cross-reference `DESIGN_SYSTEM.md`):** the label is rendered as a small caption-style chip or text tag using `type.caption` (12px, per `DESIGN_SYSTEM.md` section 2.2), in Ink Charcoal Muted (`color.ink.700`) text on a Warm Grey (`color.neutral.200`) background — visually consistent with the rest of the metadata language of the system, but never smaller than the surrounding metadata text (e.g., never smaller than a timestamp or headcount label on the same card), never lower-contrast than the 4.5:1 minimum required for body text elsewhere in the system, and never styled to visually recede (no reduced opacity, no near-background color-on-color treatment) relative to the venue name it labels. "Legally present but practically invisible" is treated as a disclosure failure, not a clever compromise.
- **Never subtle by design intent.** Because the commercial incentive is to make sponsorship as unobtrusive as possible while the hospitality/trust incentive is the opposite, any future redesign of the venue-suggestion card that shrinks, recolors, or repositions the "Sponsored" label to be less noticeable than it is today requires the same design review as a change to the RSVP status chips (`DESIGN_SYSTEM.md` section 1.3) — it is not a routine visual tweak.
- **Cap enforcement is a product/eng concern, not a copy concern** (see `VALUES.md` §3 for the cap on sponsored share of results and `PRD.md` FR-D4/FR-D5 for the rule that sponsorship never affects Discover's person-matching); this section only governs the label's wording and visual prominence once a sponsored venue is shown.

---

## 8. Alcohol-Related Copy and Tagging Guardrail

Per `LEGAL.md` §4, copy, marketing, and interest-tag taxonomy (`FEATURES.md`) that centers or gamifies alcohol consumption creates a liability exposure distinct from — and avoidable unlike — the dram-shop exposure that sits with a licensed venue. This is a standing constraint on anyone writing copy or proposing tags for TableCrew, not a one-time cleanup.

- **Neutral, incidental framing only.** Alcohol may be mentioned as one incidental element of a dining occasion ("dinner, drinks optional," "wine paired with the tasting menu") but must never be the organizing theme, achievement, or draw of a Table's copy, tag, or notification. Acceptable: a Table description that says "Dinner at Blue Bottle — drinks optional." Not acceptable: framing that makes alcohol the point ("Wine Night 🍷," "Bar Crawl," "Bottomless Mimosas Table").
- **No gamified alcohol tags, badges, or streaks.** Interest-tag taxonomy (owned by `FEATURES.md`) must not include a "drinks" achievement badge, a drinking-themed streak, or any tag that reads as tracking or rewarding how much a user drinks. If a beverage-related tag is needed at all, it should be framed around the venue/occasion type ("wine bar," "brewery," "coffee shop") the same way "hiking" or "book club" tags describe an activity, not around the act of drinking itself.
- **No "bar crawl" or drinking-quantity framing anywhere in-product or in marketing.** This applies equally to `MARKETING.md` campaign copy and in-app Table titles/descriptions suggested by templates — a suggested-Table-title feature should never surface "Bar Crawl" or similarly drinking-quantity-coded template options.
- **Push and empty-state copy follows the same rule.** A notification or empty state nudging a user toward an alcohol-centric Table (e.g., "Happy hour Tables near you!") is treated the same as any other manufactured-urgency or engagement-bait pattern prohibited in sections 1 and 4 above — it is not a special exception because alcohol marketing is a familiar genre elsewhere.

This guardrail should be checked against any new Table-template, tag, or campaign copy before it ships, the same way privacy copy (section 5) is checked before shipping.
