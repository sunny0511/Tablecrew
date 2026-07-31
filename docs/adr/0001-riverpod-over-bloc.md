# 0001: State management — Riverpod over Bloc

**Status:** Accepted (backfilled 2026-08, Milestone F0 — decision itself predates this ADR; see `docs/ENGINEERING_GUIDELINES.md`'s original "State Management: Riverpod" section)

## Context

The Flutter client needs a state management approach that works for a small founding engineering team shipping quickly, covering everything from trivial local form state to genuinely complex cross-cutting state (Discover's matching/filtering, offline-mutation queues). Business logic — headcount capping, RSVP state transitions, no-show threshold calculations — needs to be unit-testable in isolation, without a Flutter widget tree, so bugs are caught by the compiler and by fast unit tests rather than discovered by a beta tester.

## Decision

Use Riverpod (`flutter_riverpod` + `riverpod_generator`/`@riverpod` code generation) across the client. Repositories are exposed as providers so they're trivially overridable in tests. `AsyncNotifier`/`AsyncValue` is the default shape for anything backed by network/Firestore data. Providers are scoped to the feature that owns them; only genuinely cross-cutting state (current user, auth state, feature flags) lives in `core/`.

## Consequences

**Makes easier:** unit-testing business logic without any Flutter dependency (a `Notifier` can be constructed and tested standalone); consistent loading/error/data handling via `AsyncValue` instead of each screen inventing its own loading-boolean pattern; compile-time provider safety via code generation, catching "provider not found"-class bugs before runtime; low ceremony for the many simple screens in TableCrew that don't need a full event-sourcing state machine.

**Makes harder:** onboarding an engineer who only knows Bloc (Riverpod's mental model — providers, not events/states — takes some initial adjustment); code generation adds a build step (`build_runner`) that must run before code compiles cleanly, which is a small but real tax on local dev loop speed compared to hand-written providers.

## Alternatives Considered

- **Bloc.** Powerful and battle-tested, but every piece of state needs an event class, a state class, and a bloc mapping one to the other — real ceremony we didn't want to pay on every feature, especially simple ones (a Table detail screen watching a document, a form with local validation).
- **Plain `Provider` (pre-Riverpod).** Depends on `BuildContext` for reads, making providers harder to test in isolation and creating subtle bugs around widget-tree position. Riverpod decouples providers from the widget tree entirely, which matters for the amount of pure-business-logic unit testing `docs/TESTING.md` requires.
