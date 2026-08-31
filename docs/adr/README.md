# Architecture Decision Records

ADRs for decisions with lasting consequences, per `docs/ENGINEERING_GUIDELINES.md`'s "Documentation Standards" section. Format: Context, Decision, Consequences, Alternatives Considered. ADRs are immutable once accepted — a changed decision gets a new ADR that supersedes the old one, not an edit to history.

| # | Title | Status |
|---|---|---|
| [0001](0001-riverpod-over-bloc.md) | State management: Riverpod over Bloc | Accepted |
| [0002](0002-typesense-over-algolia.md) | Discover search: Typesense over Algolia | Accepted |
| [0003](0003-trunk-based-over-git-flow.md) | Branching strategy: trunk-based development over Git Flow | Accepted |
| [0004](0004-github-actions-over-alternatives.md) | CI/CD platform: GitHub Actions over CircleCI/Bitrise | Accepted |
| [0005](0005-persona-over-stripe-identity.md) | Identity verification vendor: Persona over Stripe Identity | Superseded by [0007](0007-manual-identity-verification-for-phase-0.md) |
| [0006](0006-cloud-vision-safesearch-for-photo-moderation.md) | Photo moderation vendor: Google Cloud Vision SafeSearch over AWS Rekognition / a dedicated moderation vendor | Accepted |
| [0007](0007-manual-identity-verification-for-phase-0.md) | Tier 2 identity verification: manual human review for Phase 0 | Accepted (interim) |

**Note on dates:** ADRs 0001–0005 were backfilled in Milestone F0 (2026-08) for decisions that were already made and justified in prose elsewhere in this knowledge base before any ADR existed — see `docs/IMPLEMENTATION_PLAN.md` Recommendation R4. ADR 0006 is the first written at decision time rather than backfilled, per this document's stated going-forward practice.
