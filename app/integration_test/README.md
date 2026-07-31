# integration_test/

End-to-end tests using Flutter's `integration_test` package, run against the Firebase Emulator Suite — per `docs/TESTING.md`'s testing pyramid. Reserved for the handful of critical journeys named there (sign-up + phone verification, create Table → RSVP → confirm → rate, Crew creation and invite, report + block flow, no-show recording), not exhaustive per-screen coverage.

**Scaffold note (Milestone F0):** empty. The first integration tests land in Milestone F8 (hardening), once enough of the core loop (Milestones F4–F7) exists to have a real journey to test end to end.
