# 0005: Identity verification vendor — Persona over Stripe Identity

**Status:** Accepted (backfilled 2026-08, Milestone F0 — decision itself predates this ADR; see `docs/SECURITY.md`'s "Identity Verification Tiers" section)

## Context

Tier 2 identity verification (government ID + selfie liveness, required for hosting/joining Open/Discover Tables) needs a vendor that does verification precisely — not a background check, a real legal distinction per `docs/LEGAL.md` §5 — and one whose coverage genuinely extends to the Hyderabad/India anchor market, not just a U.S.-first assumption. This decision is **not** in Foundation's critical path (Tier 2 verification is Phase 1 scope, since Discover is out of scope for Phase 0), but it's backfilled as an ADR now because it was already decided and justified in prose before this milestone, and the Functions `trust/` domain directory scaffolded in Milestone F0 is where `completeIdentityVerification` (Phase 1) will eventually live.

## Decision

Use Persona (ID + selfie liveness SDK) as the Tier 2 identity-verification vendor.

## Consequences

**Makes easier:** a purpose-built identity-verification product (not a payments company's bolt-on identity feature) with an SDK that handles the ID-capture + liveness-check flow end to end, keeping this genuinely safety-critical surface out of hand-rolled, easy-to-get-subtly-wrong territory.

**Makes harder — and this is the most important open item this ADR surfaces, not just a footnote:** Persona's Aadhaar/India-ID document-type coverage has **not yet been confirmed directly with the vendor** as of this writing. This is tracked as a genuinely open, needs-a-human item in `TASKS.md` and `docs/ARCHITECTURE_READINESS_REVIEW.md` — not a silent assumption — and it does not block Foundation's engineering work (Tier 2 verification is Phase 1), but it must be resolved, with a named backup India-specific KYC vendor identified if coverage proves inadequate, before Phase 1 work on Discover begins.

## Alternatives Considered

- **Stripe Identity.** Attractive for a team already integrating Stripe for payments (one fewer vendor relationship), but identity verification is a secondary product for a payments company, not its core competency — and choosing it wouldn't have resolved the India/Aadhaar coverage question any more definitively than Persona did, while adding a closer coupling between "we verify who you are" and "we process your money," two concerns `docs/VALUES.md` and `docs/LEGAL.md` §5 treat as deliberately, legally distinct.
