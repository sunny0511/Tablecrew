# 0002: Discover search — Typesense over Algolia

**Status:** Accepted (backfilled 2026-08, Milestone F0 — decision itself predates this ADR; see `docs/ARCHITECTURE.md` §5.5)

## Context

Firestore's native query model can't efficiently serve Discover's actual query shape — geo-radius search combined with multi-field filtering (activity tag, date/time window, headcount range) and relevance ranking — without either denormalizing heavily or bolting on a purpose-built search index. This decision is not in Foundation's critical path (Discover is out of scope for Phase 0), but it's pinned now because `docs/ARCHITECTURE.md`, `docs/FIREBASE.md`, and `docs/API_SPEC.md` all already assume it, and the Functions `discover/` domain directory scaffolded in Milestone F0 exists to eventually hold this integration.

## Decision

Use Typesense (Typesense Cloud, capacity-based pricing) as the purpose-built search/matching index for Discover, synced from Firestore via a backfill/reconciliation Cloud Function, with Firestore itself as the fallback in a graceful-degradation mode if Typesense Cloud is unreachable.

## Consequences

**Makes easier:** capacity-based pricing scales predictably with index size and query volume rather than per-record/per-operation billing that can spike unexpectedly at scale; Typesense is open-source, giving a genuine self-hosted exit path if a future cost or vendor-lock-in concern arises, which a fully proprietary managed service wouldn't offer; the index requires no independent backup strategy for data-loss purposes since it's cheaply rebuildable from Firestore, simplifying disaster-recovery planning (`docs/ARCHITECTURE.md` §8).

**Makes harder:** running a search index outside Firestore adds a second system to keep in sync (the backfill/reconciliation trigger) and a second thing that can fail independently — this sandbox's own Milestone F0 verification pass found that local/CI emulation of Typesense has no documented story yet (flagged in `docs/IMPLEMENTATION_PLAN.md` §2.2 as a real, non-blocking gap to resolve before Phase 1 Discover work begins, likely via Typesense's official Docker image as a local/CI service container).

## Alternatives Considered

- **Algolia.** A strong, more mature managed search product, but its per-operation/per-record pricing model scales less predictably than Typesense's capacity-based model for a product whose search volume is hard to forecast pre-launch, and it offers no open-source self-hosted path if we ever wanted one.
- **Firestore native queries only (no dedicated search index).** Rejected outright, not just deprioritized — Firestore's query model fundamentally can't do combined geo-radius + multi-field-filter + relevance-ranked search without denormalizing into a shape that's really just reinventing a worse version of a search index by hand.
