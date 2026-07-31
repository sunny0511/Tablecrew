# firestore/test/rules/

Firestore security rules tests using `@firebase/rules-unit-testing` against the Firestore emulator — one test file per collection (`users.rules.test.ts`, `tables.rules.test.ts`, `reports.rules.test.ts`, etc.), per `docs/TESTING.md`'s "Testing Firestore Security Rules" section.

**Scaffold note (Milestone F0):** empty — there are no real rules yet (`firestore/firestore.rules` is a default-deny stub). Real rules and their corresponding tests are written together, collection by collection, in Milestone F1, per `docs/TESTING.md`'s requirement that every PR modifying `firestore.rules` includes corresponding test changes in the same PR.
