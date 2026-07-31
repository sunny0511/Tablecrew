# Engineering Guidelines

These are the practices that define how the TableCrew engineering team writes, reviews, and ships code. They exist so that a team of a handful of engineers can move fast without stepping on each other, and so that a new hire's first commit looks like it was written by someone who's been here a year. If you find yourself doing something these guidelines don't cover, write it down and propose an addition — this document is a living artifact of the team, not a mandate from above.

This document assumes you've read `VALUES.md`. Two values shape almost every decision below: "Bias toward shipping, with a rollback plan" (favor small, reversible changes over big-bang launches) and "Safety is a feature, not a department" (safety-relevant code on the Discover surface gets extra review scrutiny, not an afterthought).

## Repository Structure

TableCrew uses a single monorepo containing the Flutter client and the Cloud Functions backend. We considered splitting these into separate repos (client repo + functions repo) and rejected it. With a founding team of a handful of engineers, most meaningful features touch both the client and the backend in the same pull request — a new RSVP flow needs a Cloud Function endpoint and a Flutter screen calling it, often written by the same person in the same sitting. Splitting them would mean coordinating two PRs, two review cycles, and two merge times for every feature, plus the ever-present risk of a client shipping against a backend contract that hasn't landed yet (or vice versa). A monorepo lets one PR contain the full vertical slice of a change, keeps commit history coherent ("add no-show reporting" is one commit, not two), and lets CI validate that client and backend are compatible before merge. We'll revisit this if the team grows past ~15 engineers and functions/client become genuinely independent release trains, but that's a problem for a later stage of the company.

Top-level layout:

```
tablecrew/
├── app/                        # Flutter client
│   ├── lib/
│   │   ├── main.dart
│   │   ├── app.dart             # MaterialApp, routing, top-level providers
│   │   ├── core/                # cross-cutting: theming, env config, error handling, analytics wrapper
│   │   ├── features/            # one directory per feature, see below
│   │   ├── data/                # repositories, Firestore/Functions client wrappers, DTOs
│   │   ├── l10n/                # ARB files and generated localization
│   │   └── widgets/              # shared, feature-agnostic UI components (design system consumers)
│   ├── test/                     # unit + widget tests, mirrors lib/ structure
│   ├── integration_test/         # end-to-end tests (see TESTING.md)
│   └── pubspec.yaml
├── functions/                   # Cloud Functions (TypeScript)
│   ├── src/
│   │   ├── index.ts             # function exports
│   │   ├── tables/               # one directory per domain, mirrors Firestore collections
│   │   ├── crews/
│   │   ├── discover/
│   │   ├── trust/                # verification, reports, no-show accountability
│   │   ├── shared/               # auth middleware, validation, Stripe client, logging
│   │   └── triggers/             # Firestore/Auth-triggered functions, separated from callable ones
│   ├── test/                     # unit tests + emulator-based integration tests
│   └── package.json
├── firestore/
│   ├── firestore.rules
│   └── firestore.indexes.json
├── docs/                         # this knowledge base
├── scripts/                      # one-off ops scripts, data migrations, seed scripts
└── .github/workflows/            # CI/CD, see CI_CD.md
```

Inside `app/lib/features/`, each feature (e.g., `tables/`, `crews/`, `discover/`, `profile/`, `trust_safety/`) is a self-contained vertical: its own `presentation/` (screens, widgets), `application/` (Riverpod providers/notifiers), and references into `data/` for repositories. This keeps a feature's code discoverable in one place rather than scattered across horizontal layers named after their type. A new engineer working on Discover matching should be able to `cd` into `features/discover/` and find nearly everything relevant.

The `functions/src/` structure mirrors the Firestore collections described in `DATABASE.md` (Users, Tables, Crews, RSVPs, Ratings, Reports, Venues) so that "where does the code for X live" always has an obvious answer.

## Dart/Flutter Code Style

We use `very_good_analysis` as our lint package, layered on top of the Dart core lints. It's stricter than the default `flutter_lints` package (which is intentionally lightweight so as not to scare off Flutter beginners), enforcing things like mandatory trailing commas, explicit type annotations in public APIs, sorted constructor arguments, and no `print` in production code. We chose it over hand-rolling our own `analysis_options.yaml` from `effective_dart` because it's maintained by Very Good Ventures (a Flutter consultancy with a strong open-source track record), is actively updated for new Dart/Flutter releases, and gives us a defensible, externally-documented baseline rather than a bespoke rule set that only the founding engineers understand and that decays as the team grows. For a small team without a dedicated tooling owner, "adopt the well-maintained strict preset" beats "roll your own and let it rot."

Practical rules that follow from this:
- `dart format` runs on save (configure your editor) and is enforced in CI; a PR with unformatted code fails lint, no exceptions and no debate about style in review.
- Public functions, classes, and non-trivial parameters get dartdoc (`///`) comments. Private helpers don't need them unless the logic is non-obvious.
- No `dynamic` unless interfacing with genuinely dynamic data (e.g., raw Firestore document maps before they're parsed into a typed model) — and even then, parse into a typed class at the boundary as soon as possible rather than passing maps deeper into the app.
- Widgets are `const`-constructed wherever possible; the linter enforces `prefer_const_constructors`, which also happens to be a meaningful performance win in Flutter's rebuild model.
- File and class naming follows standard Dart convention (`snake_case.dart` files, `UpperCamelCase` classes, `lowerCamelCase` members) — very_good_analysis enforces this so it's not a matter of taste.

## State Management: Riverpod

We use Riverpod for state management across the Flutter client, and it's a deliberate choice over both Bloc and plain Provider.

Bloc is powerful and battle-tested, but it comes with real ceremony: every piece of state gets an event class, a state class, and a bloc that maps one to the other. For a small team shipping quickly, that boilerplate is a tax we don't want to pay on every feature, especially for the many simple screens in TableCrew (a Table detail screen watching a document, a form with local validation state) that don't need full event-sourcing-style state machines. Riverpod lets those stay simple (a `FutureProvider` or a small `Notifier`) while still scaling up to Bloc-like complexity for the few screens that genuinely need it (Discover's matching/filtering state, for instance).

Plain `Provider` (the package, pre-Riverpod) has a real weakness for us specifically: it depends on `BuildContext` for reads, which makes providers harder to test in isolation and creates subtle bugs around widget tree position. Riverpod decouples providers from the widget tree entirely — a `Notifier` can be constructed and tested with zero Flutter dependencies, which matters a lot for TableCrew's business logic (headcount capping, RSVP state transitions, no-show threshold calculations) that we want to unit test thoroughly per `TESTING.md`. Riverpod's compile-time safety (no more "provider not found" runtime exceptions if you use the code-generation flavor) is also a meaningful win for a team without dedicated QA — we want classes of bugs caught by the compiler, not by a beta tester.

Conventions:
- Use `riverpod_generator` (`@riverpod` annotations) rather than hand-written `StateNotifierProvider` boilerplate — less code, consistent patterns across the team.
- Repositories (Firestore/Functions access) are exposed as providers so they're trivially overridable in tests (swap in a fake repository, never hit the emulator or production for a unit test).
- Prefer `AsyncNotifier`/`AsyncValue` for anything backed by network/Firestore data so loading/error/data states are handled uniformly across the app rather than each screen inventing its own loading-boolean pattern.
- Providers are scoped to the feature that owns them; only genuinely cross-cutting state (current user, auth state, feature flags from Remote Config) lives in `core/`.

## Git Branching Strategy

We use trunk-based development: `main` is always releasable, engineers work on short-lived feature branches (target: merged within 1–2 days, hard ceiling of a week), and there are no long-lived `develop` or `release` branches accumulating drift.

We explicitly rejected Git Flow. Git Flow's long-lived `develop` branch and release branches make sense for software with infrequent, large releases where a big merge event is acceptable — but they create exactly the kind of integration pain a fast-moving startup can't afford: branches diverge for weeks, merges become risky multi-file conflicts, and "when did this land" becomes a genuine question. Trunk-based development, combined with feature flags for anything not ready for all users (see `DEPLOYMENT.md` for the flag lifecycle), lets us merge continuously into `main` while still controlling what's actually visible to users. This is the direct engineering expression of "bias toward shipping, with a rollback plan": small merges are individually low-risk and individually revertible; a three-week release branch is not.

Practical rules:
- Branch names: `<initials>/<short-description>`, e.g., `ks/discover-block-flow`. No ticket-number-only branch names — a human should be able to tell what a branch does from its name alone.
- Rebase onto `main` before opening a PR and before merging if `main` has moved significantly; we prefer a clean, linear-ish history over a tangle of merge commits, though we don't obsess over it.
- Squash-merge PRs into `main` by default, so `main`'s history is one commit per shipped unit of work with a meaningful message, while the PR itself preserves the full review conversation on GitHub.
- Anything that isn't safe for all users the moment it merges goes behind a feature flag (Remote Config), full stop — this is what makes trunk-based development safe at TableCrew's pace.

## Pull Request Review Process

Every PR requires at least one approval before merge; PRs touching Firestore security rules, the Cloud Functions `trust/` directory, or anything on the Discover verification/reporting/blocking path require two approvals, at least one from an engineer who has previously worked on that surface. This tiering reflects "safety is a feature, not a department" concretely: the code that keeps people safe on Discover gets more eyes, not the same eyes, before it ships.

A good PR description includes:
- **What and why** — one or two sentences on the problem being solved, not just the mechanical change ("Add phone re-verification prompt after 2 failed no-show disputes" rather than "update trust_service.dart").
- **How to test it** — concrete steps a reviewer can follow, including any emulator setup or seed data needed.
- **Screenshots or screen recordings** for any UI change — non-negotiable, since reviewing Flutter UI diffs as text is close to useless.
- **Rollout plan** — which feature flag gates this (or "no flag, this is a pure bugfix/internal tooling change" with justification), and what the rollback path is if it misbehaves in production.
- **Linked issue** from `TASKS.md` or GitHub Issues for traceability.

Size limits: we target PRs under ~400 lines of diff (excluding generated code and tests, which don't count against the limit). Larger changes get broken into a stack of smaller PRs behind a flag — this is almost always possible, and when an engineer says "this one genuinely can't be split," that's a flag for a design conversation, not an automatic exception. Small PRs get reviewed faster and more carefully; a 2,000-line PR gets a rubber stamp, which defeats the purpose of review.

Reviewers are expected to respond within one business day. If you're blocked waiting on a review, ping the team channel — don't silently wait multiple days on a stale PR.

## Documentation Standards

Public classes, functions, and non-obvious business logic (headcount math, no-show threshold calculations, verification tier gating) get doc comments (`///` in Dart, JSDoc in TypeScript) explaining intent, not just restating the signature. Comments explain *why*, not *what* — the code already says what it does.

For decisions with lasting consequences — choosing Riverpod over Bloc, Persona over Stripe Identity for verification, trunk-based over Git Flow, Typesense over Algolia — we write an Architecture Decision Record (ADR). ADRs live in `docs/adr/NNNN-title.md`, numbered sequentially, and follow a short fixed format: Context (what problem forced this decision), Decision (what we chose), Consequences (what this makes easier and what it makes harder), and Alternatives Considered (what we rejected and why). ADRs are immutable once accepted — if a decision changes later, write a new ADR that supersedes the old one rather than editing history. This matters more than it sounds: six months from now, when someone asks "why don't we use Bloc," the answer should be a link, not a Slack archaeology expedition. Every decision justified with a "we chose X over Y because Z" in this knowledge base is a candidate for an ADR if it wasn't already written as one at decision time. **The first five qualifying decisions were backfilled as ADRs in Milestone F0 (2026-08) — see `docs/adr/README.md` for the index — since they predated this document's own ADR requirement; going forward, an ADR is written at decision time, not backfilled.**

## Dependency Management

For Flutter/Dart packages (`pubspec.yaml`) and Node packages (`functions/package.json`), we pin exact versions for direct dependencies rather than using caret ranges, and rely on `pubspec.lock` / `package-lock.json` (both committed to the repo) for full reproducibility. Automatic minor/patch bumps sound convenient until a transitive dependency update silently breaks a Cloud Function in production; for a team without dedicated dependency-management tooling, "changes are always the result of an explicit PR" is safer than "changes happen automatically and get discovered when something breaks."

We run Dependabot (GitHub-native, zero additional cost or tooling — consistent with the CI/CD platform choice in `CI_CD.md`) on a weekly schedule for both `pubspec.yaml` and `package.json`. Dependabot PRs are reviewed like any other PR: CI must pass, and a human skims the changelog for anything security- or behavior-relevant before merging. Security patches (flagged by GitHub's Dependabot alerts) are treated as high priority and merged within 48 hours of the CI passing, ahead of the normal PR queue if needed. New dependencies (not upgrades) require a brief justification in the PR description — what problem it solves, and why we're not solving it with something already in the dependency tree — since every dependency is a maintenance and security-surface liability we're taking on indefinitely.

## Onboarding Checklist: A New Engineer's First Week

Day 1:
- Get access: GitHub org, Firebase console (dev project only, per `FIREBASE.md`'s environment separation), Slack, this documentation repo.
- Clone the monorepo, run the Flutter app against the **dev** Firebase project and the Firebase Emulator Suite locally (never point a local dev environment at staging or prod — see `FIREBASE.md` and `SECURITY.md`).
- Read, in order: `MISSION.md`, `VALUES.md`, `PRODUCT.md`, `PRD.md`. Understanding *why* TableCrew exists and what it explicitly won't do matters before touching code.

Days 2–3:
- Read `ARCHITECTURE.md` and `DATABASE.md` end to end — these describe the Firestore data model (Users/Tables/Crews/RSVPs/Ratings/Reports/Venues) and how Cloud Functions serve as the API layer. Don't skim; the data model is the shape of the whole app.
- Read this document (`ENGINEERING_GUIDELINES.md`) and `TESTING.md` fully.
- Set up the Firebase Emulator Suite locally and successfully run the existing test suite (`flutter test`, `npm test` in `functions/`, and the Firestore rules tests) end to end on your machine. If anything doesn't work first try, that's useful signal for us to fix onboarding, not just a personal problem to work around — flag it.

Days 4–5:
- Read `SECURITY.md` in full, even if you're not initially working on Discover — every engineer needs to understand the verification tiers, reporting/blocking requirements, and the safety-gate checklist, because any feature you build might need to pass it.
- Skim `CI_CD.md` and `DEPLOYMENT.md` so you understand what happens when your PR merges and how a release actually reaches a user's phone.
- Pick a small, well-scoped starter task (your onboarding buddy will have one queued in `TASKS.md`) and open your first PR. It should be small enough to merge within your first week — the goal is to get you through the full loop (branch → PR → review → merge → deploy to dev/staging) once, successfully, before you take on anything bigger.

By the end of week one, you should be able to run the full stack locally, understand where a given piece of logic belongs (client feature module vs. Cloud Function vs. Firestore rule), and have shipped something, however small, through the real process described above.
