# Executive Summary

This document summarizes the complete TableCrew company knowledge base assembled in `docs/`, plus `README.md`, `CLAUDE.md`, `TASKS.md`, and `CHANGELOG.md`. It is written for a founder, investor, or new leader who needs the whole picture in ten minutes, with pointers into the underlying documents for depth.

## The company, in three sentences

TableCrew is a mobile app that removes the coordination friction from small, real-world group gatherings — with existing friends or with curated new people — anchored on a single concept: the Table. It exists because loneliness and the difficulty of organizing in-person social life are large, worsening, and well-documented problems (`docs/USER_RESEARCH.md`, `docs/INVESTOR_OVERVIEW.md`), and because no current product spans both "help my existing friend group actually gather" and "help me meet trustworthy new people" in a single, safety-first tool (`docs/PRODUCT.md`). The business monetizes through subscription, venue partnerships, and a later B2B2C offering — deliberately not advertising — and is built to reach global, city-by-city density over a ten-year horizon (`docs/VISION.md`, `docs/INVESTOR_OVERVIEW.md`).

## What exists in this knowledge base

Twenty-four documents in `docs/`, organized into five layers — company foundation (mission, vision, values, product), product definition (requirements, personas, research, roadmap, features, metrics), engineering (architecture, database, API, Firebase, guidelines, security, testing, deployment, CI/CD), design and brand (design system, brand guidelines, copy guidelines), and growth (marketing, SEO, investor overview) — plus four root files that index, operationalize, and log the whole set (`README.md`, `CLAUDE.md`, `TASKS.md`, `CHANGELOG.md`). Every document was written to a single standard: no placeholders, every open question either resolved with a justified recommendation or explicitly flagged as an open decision with its resolution criteria stated. All twenty-eight files now live in this repository (`/Users/sunny/Tablecrew`), ready to push to GitHub.

## The decisions that hold the whole thing together

A small number of decisions recur across nearly every document, and are worth naming explicitly because they are the load-bearing walls of the whole knowledge base:

**Product architecture.** Three concepts — Table (the atomic gathering), Crew (a persistent friend group), Discover (the surface for meeting curated new people) — carry the entire product. Discover is deliberately sequenced after Crew-first functionality (`docs/ROADMAP.md` Phase 0 vs. Phase 1) because it introduces strangers into physical meetups and therefore carries materially higher identity-verification and trust-and-safety requirements (`docs/SECURITY.md`).

**Technical architecture.** Flutter (client) plus Firebase (Firestore, Auth, Cloud Functions, Cloud Messaging, Storage, App Check, Remote Config, Crashlytics) is the deliberate starting architecture for a small founding team, with Riverpod for state management, Typesense for Discover's geo+interest search (chosen over Algolia specifically for capacity-based pricing and an open-source exit path), and Stripe for payments. `docs/ARCHITECTURE.md` names five explicit, concrete triggers for when specific workloads would migrate off pure Firebase — this is treated as a planned evolution, not a hedge.

**Trust and safety as core product, not a bolt-on.** Two-tier identity verification (phone baseline, ID + liveness for anyone hosting or joining Discover), a shared reporting/blocking pipeline, graduated no-show accountability, and an explicit safety-gate checklist that every new feature must pass before launch (`docs/SECURITY.md`, `docs/PRD.md`) are treated as launch-blocking, on the same priority tier as any growth feature — directly enforcing the "Safety is a feature, not a department" value (`docs/VALUES.md`).

**Metrics that resist the industry's default incentives.** The North Star metric is Tables Attended per Active User per Month, not DAU, session time, or any attention-maximizing proxy (`docs/SUCCESS_METRICS.md`) — a direct, deliberate consequence of the "real connection over engagement metrics" value, and a genuine constraint on how product and growth teams are evaluated.

**Brand distinct from the dating-app aesthetic.** A terracotta/ink-charcoal/linen-cream palette (`docs/DESIGN_SYSTEM.md`) and a "Host" brand archetype (`docs/BRAND_GUIDELINES.md`) were chosen specifically to avoid reading as a dating product, because "is this secretly a dating app?" is a recurring, named anxiety across personas, especially Maya and Grace (`docs/USER_PERSONAS.md`).

**Go-to-market is density-first, not breadth-first.** City-by-city launch, sequenced by measurable Discover liquidity thresholds (15-20+ weekly Open Tables, 60%+ fill rate, 25+ rated hosts per city, per `docs/MARKETING.md`), before paid acquisition or broad geographic expansion — because a two-sided Discover marketplace needs local liquidity to work at all, and breadth without density produces a product that fails its core promise.

## Inconsistencies found and resolved during review

The full document set was cross-checked for consistency on the facts most likely to drift when authored across multiple passes: the tech stack (Riverpod, Typesense vs. Algolia, GitHub Actions, Persona as the ID-verification vendor), the brand color palette and typography, city-count figures at each roadmap phase, the North Star metric definition, and no-show/guardrail thresholds. One inconsistency was found and fixed: `docs/PRD.md`'s Discover search requirement (FR-D10) had hedged between Algolia and Typesense pending a decision that `docs/ARCHITECTURE.md` had, in fact, already made and justified in depth (Typesense, chosen for capacity-based pricing and an open-source self-hosting exit path); FR-D10 now states the decision definitively and points to the architectural rationale. No other material contradictions were found — the five parallel authoring passes stayed aligned because each was grounded in the same canonical facts (product mechanics, personas, values, tech stack, monetization) established in `docs/PRODUCT.md`, `docs/VISION.md`, `docs/MISSION.md`, `docs/VALUES.md`, and `docs/USER_PERSONAS.md` before any downstream document was written.

## What is explicitly still open

Per `TASKS.md` and `docs/CHANGELOG.md`: the anchor city for the Phase 0 MVP launch has not been chosen; the age-gating policy (13+ vs. 18+) has not been finalized; the ID-verification vendor (Persona is recommended in `docs/SECURITY.md`) has not been contractually confirmed. These are named explicitly rather than glossed over, consistent with this knowledge base's standard of resolving or flagging every open question rather than leaving silent gaps.

## What happens next

Per this assignment's explicit scope, no application code has been written. The next step, per `TASKS.md`, is standing up the Firebase environments and the Flutter/Cloud Functions monorepo — but only once a founder explicitly instructs that work to begin, per the operating rule set in `CLAUDE.md`.
