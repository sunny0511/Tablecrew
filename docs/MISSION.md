# Mission

## Statement

**Make it effortless for anyone, anywhere, to build real friendships around a table.**

## Why this is our mission

TableCrew exists because the mechanics of modern life have made a simple thing hard: getting a small group of people to sit down together. Group chats stall on "who's free when." Apps optimize for scrolling, not showing up. The result is a generation that is more digitally connected and more socially isolated than any before it. The U.S. Surgeon General's 2023 advisory on loneliness, replicated by public health bodies in the UK, Japan, and Australia, named weak social connection a mortality risk comparable to smoking. This is not a niche problem. It is a global, structural one, and it will not fix itself.

We chose the table as our unit of connection deliberately. A table is the oldest, most cross-cultural piece of social technology humans have: a bounded, physical, face-to-face space where a small group commits to being present with each other for a fixed stretch of time. It scales from two people to twelve. It works in Lagos, Lisbon, and Los Angeles. It requires no translation. Every other design decision in this company — product, brand, business model — is downstream of that one anchor.

"Anyone, anywhere" is not aspirational filler; it is a constraint we design against from day one. It means TableCrew must work as well for a 24-year-old expat in Berlin who knows no one as it does for a retiree in Ohio, and that our roadmap (see `ROADMAP.md`) sequences internationalization and accessibility far earlier than a typical consumer app would.

"Effortless" is the product mandate. Our competitors are not just other apps; they are the group chat, the shared spreadsheet, and the sheer inertia of staying home. Every feature we ship is judged against one question: does this remove a step between "I want to see people" and "I am sitting at a table with them"? This standard is the throughline connecting `PRD.md`, `FEATURES.md`, and `SUCCESS_METRICS.md`.

## A tension we hold openly, not silently

"Anyone, anywhere" is in direct tension with one real product requirement: `SECURITY.md` requires a government-issued ID plus a selfie liveness check before a person can host or join a Discover Table, because introducing strangers into a physical meetup without strong identity verification is a safety risk we are not willing to take (see `VALUES.md`, "Safety is a feature, not a department"). That requirement is not free — a meaningful share of the global population lacks a government-issued photo ID, lacks a smartphone capable of a liveness check, or lives in a market where our verification vendor does not operate, and undocumented immigrants, refugees, and unbanked populations are disproportionately affected. Flagging this plainly: as written, the product does not yet serve "anyone, anywhere" for the Discover surface, and pretending otherwise would be dishonest.

We resolve this by scoping the promise, not by lowering the safety bar. The Crew-first product (creating a Crew, hosting or joining a Closed Table with people you already know) requires only phone-number verification and is genuinely open to anyone with a mobile phone number, regardless of documentation status — this is where "anyone, anywhere" holds today. Discover, the stranger-matching surface, carries a stricter, deliberately narrower promise: "anyone who can pass identity verification, in any market our verification vendor supports." `SECURITY.md` §2 and `ROADMAP.md` Phase 3 track vendor and market coverage expansion as a first-class metric, and `TASKS.md` carries an open item to evaluate a secondary, non-document verification path (e.g., community vouching by an existing verified user, video-call verification) for markets or populations formal-ID verification currently excludes, without weakening the safety bar for Discover as a whole.

## What the mission rules out

A mission is only useful if it says no to things. This one rules out:

- **Engagement-maximizing design.** We do not build features whose primary purpose is to keep people on their phone longer. Time-in-app is not a north star metric for us; see `SUCCESS_METRICS.md` for the metrics that replace it.
- **Anonymous or purely digital interaction as an end state.** TableCrew can start a connection online, but the product is not finished until two or more people have been physically or verifially co-present (in-person by default; verified video tables are a narrow, explicit exception documented in `PRD.md`).
- **Scale before trust.** We will slow our growth curve in any market where we cannot yet guarantee baseline safety standards (see `SECURITY.md` and `VALUES.md`, "Safety Is a Feature, Not a Department").

## How the mission connects to the rest of the knowledge base

- `VISION.md` describes the world that exists if this mission is fulfilled at global scale.
- `VALUES.md` describes the operating principles we use to pursue it without compromising it.
- `PRODUCT.md` and `PRD.md` translate it into a specific product.
- `SUCCESS_METRICS.md` defines how we will know, quantitatively, whether we are living up to it.

This mission statement is reviewed by the founding team every 12 months, at minimum. Any proposed change requires updating this document and a written rationale appended to `CHANGELOG.md`.
