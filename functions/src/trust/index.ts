/**
 * Trust & Safety domain: reportUser, reportTable, blockUser,
 * triggerDuressSignal, createLocationShare, revokeLocationShare,
 * completeIdentityVerification (see docs/API_SPEC.md §3.4, §3.7).
 *
 * Scaffold note (Milestone F0): no endpoints implemented yet.
 * Per docs/ROADMAP.md and docs/IMPLEMENTATION_PLAN.md Recommendation R6,
 * the reporting/blocking/duress subset of this domain is in Foundation
 * scope (Milestone F6) even though Discover is not — safety infrastructure
 * ships alongside the core Crew-first loop, not after it.
 * `completeIdentityVerification` (Tier 2) is Phase 1 only.
 *
 * Per docs/ENGINEERING_GUIDELINES.md, any PR touching this directory
 * requires two approvals, at least one from an engineer who has previously
 * worked on this surface.
 */

export {};
