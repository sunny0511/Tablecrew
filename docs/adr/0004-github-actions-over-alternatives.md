# 0004: CI/CD platform — GitHub Actions over CircleCI/Bitrise

**Status:** Accepted (backfilled 2026-08, Milestone F0 — decision itself predates this ADR; see `docs/CI_CD.md` §"Platform Choice: GitHub Actions"; first real workflow implemented this milestone, `.github/workflows/ci.yml`)

## Context

The pipeline needs to run fast, cheap, and low-maintenance checks (lint, unit/widget tests, rules tests, builds) for both a Flutter mobile client and a TypeScript Cloud Functions backend, without a dedicated DevOps hire to operate custom infrastructure.

## Decision

Use GitHub Actions as the CI/CD platform, with Fastlane handling mobile build/signing/store-upload automation and Firebase App Distribution for internal build distribution to testers.

## Consequences

**Makes easier:** zero additional cost or tooling to adopt, since the code already lives on GitHub — no separate CI vendor account, billing relationship, or webhook integration to maintain; native secret-scoping via GitHub's environment protection rules, which `docs/CI_CD.md`'s secrets-management design depends on directly (prod secrets unreachable from PR-triggered jobs); Dependabot integration (also GitHub-native) for dependency updates, consistent with the same "adopt the well-maintained default, don't operate bespoke tooling" philosophy used for the lint preset (`very_good_analysis`) and rules testing (`@firebase/rules-unit-testing`).

**Makes harder:** GitHub-hosted runners are shared infrastructure with less control over build-machine specs than a dedicated CI vendor might offer, meaning build-time optimization has to lean on caching and job parallelization (both already adopted in `.github/workflows/ci.yml`) rather than throwing more dedicated hardware at slow builds; mobile-specific CI needs (iOS builds specifically require macOS runners, which are more expensive per-minute than Linux runners on GitHub Actions) mean iOS build stages cost more than an equivalent CircleCI/Bitrise macOS plan might in some pricing scenarios — accepted as a reasonable tradeoff against the integration and secrets-management simplicity above.

## Alternatives Considered

- **CircleCI.** Mature, flexible, but a separate vendor relationship, billing account, and webhook/secrets integration to stand up and maintain — real overhead for a founding team without dedicated DevOps capacity.
- **Bitrise.** Mobile-specialized and genuinely strong for Fastlane-style mobile pipelines specifically, but weaker as a general-purpose CI for the Cloud Functions/TypeScript side of the monorepo, which would mean operating two different CI systems (one for mobile, one for backend) instead of one pipeline covering both, undermining the monorepo's own "one PR, one CI signal" premise (`docs/ENGINEERING_GUIDELINES.md`'s repository-structure rationale).
