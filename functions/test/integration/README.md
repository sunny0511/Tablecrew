# functions/test/integration/

Real Firebase Emulator Suite integration tests — Auth + Firestore + Functions emulators, no mocking. These are separate from `functions/test/`'s other `*.test.ts` files (which are pure-logic unit tests requiring no emulator and run via plain `npm test`) because they need the emulators already running.

## Running

```
firebase emulators:exec --only auth,firestore,functions \
  --project tablecrew-dev "npm --prefix functions run test:integration"
```

This mirrors `firestore/test/rules/`'s `firebase emulators:exec --only firestore ...` pattern, just with `functions` and `auth` added to `--only` since these tests call real deployed callables and sign in real (emulated) Auth users.

## What this covers, and what it doesn't

- Covers: the actual deployed `onCall` wrappers in `functions/src/users/index.ts` — HTTP status codes, error shapes, the `completeAccountSetup` batch-create transaction and its idempotent-on-retry behavior, and `revokeSessions`'s effect on `tokensValidAfterTime` — all against live emulators, not stubs.
- Does not cover: App Check enforcement. This project's `firebase.json` doesn't configure an App Check emulator, and the Functions emulator does not enforce `enforceAppCheck` without one, so these callables' `enforceAppCheck: true` option is inert here. This is a disclosed gap, not an oversight — see `TASKS.md`'s Milestone F2 verification notes.
- Not run in CI yet: `.github/workflows/ci.yml` does not yet invoke `test:integration`. Wiring it in needs the CI runner to have `firebase-tools` and the Java runtime the emulators require, which the current `test-functions`/`build-functions` jobs don't install — tracked as a follow-up, not silently skipped.
