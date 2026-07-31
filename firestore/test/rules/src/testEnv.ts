import * as fs from 'node:fs';
import * as path from 'node:path';
import {initializeTestEnvironment, RulesTestEnvironment} from '@firebase/rules-unit-testing';

// Must match .firebaserc's "default" alias / firebase.json's emulator config
// (see docs/FIREBASE.md) so a rules test run behaves the same whether it's
// invoked locally or in CI via `firebase emulators:exec --only firestore ...
// --project tablecrew-dev` (.github/workflows/ci.yml).
const PROJECT_ID = 'tablecrew-dev';

// firestore/test/rules/src/testEnv.ts compiles to firestore/test/rules/lib/
// testEnv.js, so three levels up from the compiled file's directory is
// firestore/ itself, where the real firestore.rules lives.
const RULES_PATH = path.resolve(__dirname, '..', '..', '..', 'firestore.rules');

let sharedEnv: RulesTestEnvironment | null = null;

/**
 * Returns a shared RulesTestEnvironment for the current test process,
 * lazily created on first use. Deliberately shared (not one per test file)
 * so we only pay the cost of loading the real firestore.rules file once per
 * `node --test` invocation, not once per *.rules.test.ts file.
 *
 * Intentionally does not pass firestore.host/firestore.port: when omitted,
 * initializeTestEnvironment reads FIRESTORE_EMULATOR_HOST from the
 * environment, which `firebase emulators:exec` sets automatically for its
 * child process. This means these tests never hardcode a port (firebase.json
 * has already changed the Firestore emulator port once, see CHANGELOG.md),
 * and behave identically locally and in CI.
 */
export async function getTestEnv(): Promise<RulesTestEnvironment> {
  if (!sharedEnv) {
    sharedEnv = await initializeTestEnvironment({
      projectId: PROJECT_ID,
      firestore: {
        rules: fs.readFileSync(RULES_PATH, 'utf8'),
      },
    });
  }
  return sharedEnv;
}

/** Tears down the shared test environment. Call once, after all tests. */
export async function teardownTestEnv(): Promise<void> {
  if (sharedEnv) {
    await sharedEnv.cleanup();
    sharedEnv = null;
  }
}
