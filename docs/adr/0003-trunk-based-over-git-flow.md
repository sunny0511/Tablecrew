# 0003: Branching strategy — trunk-based development over Git Flow

**Status:** Accepted (backfilled 2026-08, Milestone F0 — decision itself predates this ADR; see `docs/ENGINEERING_GUIDELINES.md`'s "Git Branching Strategy" section, first exercised for real by this milestone's own commits)

## Context

A small founding engineering team needs a branching model that keeps integration pain low and lets `main` stay releasable at all times, consistent with the "Bias toward shipping, with a rollback plan" value (`docs/VALUES.md`).

## Decision

Trunk-based development: `main` is always releasable, engineers work on short-lived feature branches (target merged within 1-2 days, hard ceiling of a week), no long-lived `develop` or `release` branches. Anything not safe for all users the moment it merges goes behind a Remote Config feature flag. Squash-merge into `main` by default.

## Consequences

**Makes easier:** small, individually low-risk, individually revertible merges; a short, meaningful `main` history (one commit per shipped unit of work); avoiding multi-file merge conflicts that come from branches diverging for weeks.

**Makes harder:** requires real discipline around feature-flagging anything not ready for all users, since there's no `develop` branch to hide work-in-progress behind — a team without that discipline could accidentally ship half-finished features to `main`'s always-deployable state. This milestone's own scaffold commits (F0.1-F0.5, this ADR batch included) were made directly in sequence without a real PR/branch/review cycle, which is a deliberate, disclosed exception for the very first bootstrap commits before any reviewer exists to approve against — every commit from here on should follow the real branch-name/PR/review/squash-merge process this ADR describes.

## Alternatives Considered

- **Git Flow.** Its long-lived `develop` branch and release branches suit infrequent, large releases where a big merge event is acceptable, but they create exactly the integration pain a fast-moving startup can't afford — branches diverging for weeks, risky multi-file-conflict merges, and "when did this actually land" becoming a genuine unanswerable question.
