# data/

Repositories, Firestore/Cloud Functions client wrappers, and DTOs — the boundary layer where raw Firestore document maps get parsed into typed models, per `docs/ENGINEERING_GUIDELINES.md`'s "no `dynamic` unless interfacing with genuinely dynamic data" rule. Repositories are exposed as Riverpod providers so they're trivially overridable in tests.

**Scaffold note (Milestone F0):** empty. Populated starting in Milestone F1 (core data layer) as the `docs/DATABASE.md` schema (Users, Tables, Crews, RSVPs) is implemented.
