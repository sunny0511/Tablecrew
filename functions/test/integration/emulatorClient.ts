/**
 * Thin helper for functions/test/integration/*.integration.test.ts — talks to
 * a *live* Firebase Emulator Suite (Auth + Firestore + Functions), never
 * mocked or stubbed. These tests are not part of `npm test` (see
 * functions/package.json's `test` vs `test:integration` scripts) because
 * they require the emulators to already be running; run them via:
 *
 *   firebase emulators:exec --only auth,firestore,functions \
 *     --project tablecrew-dev "npm --prefix functions run test:integration"
 *
 * per TASKS.md's Milestone F2 verification note. `firebase emulators:exec`
 * sets FIRESTORE_EMULATOR_HOST, FIREBASE_AUTH_EMULATOR_HOST, and
 * GCLOUD_PROJECT automatically, which is all the Admin SDK needs to route
 * to the emulators instead of real GCP. There is no equivalent env var for
 * routing arbitrary HTTP calls to the Functions emulator, so its
 * origin/port below is read from this project's firebase.json
 * (`emulators.functions.port: 5001`) directly rather than duplicated as a
 * guess.
 *
 * Uses the modular firebase-admin/{app,auth} imports (not the old
 * `import * as admin from 'firebase-admin'` namespaced style) — see
 * functions/src/users/index.ts's header comment for why.
 */

import {type App, getApps, initializeApp} from 'firebase-admin/app';
import {getAuth} from 'firebase-admin/auth';

export const PROJECT_ID = process.env.GCLOUD_PROJECT || 'tablecrew-dev';
export const REGION = 'us-central1';
export const FUNCTIONS_EMULATOR_ORIGIN = 'http://127.0.0.1:5001';
export const AUTH_EMULATOR_ORIGIN = 'http://127.0.0.1:9099';

let app: App | undefined;

/** Idempotent — safe to call from every test file's `before()` hook. */
export function ensureAdminApp(): App {
  if (!app) {
    app = getApps()[0] ?? initializeApp({projectId: PROJECT_ID});
  }
  return app;
}

/**
 * Creates (or reuses) an Auth-emulator user with the given phone number and
 * returns a real ID token for it — obtained the same way a client SDK
 * would end up with one after phone/OTP sign-in: mint a custom token with
 * the Admin SDK, then exchange it via the Auth emulator's REST
 * `signInWithCustomToken` endpoint. The emulator accepts any non-empty
 * string as the `key` query parameter; it never calls out to real Google
 * Identity Platform.
 */
export async function getIdTokenForUid(uid: string, phoneNumber: string): Promise<string> {
  ensureAdminApp();
  try {
    await getAuth().createUser({uid, phoneNumber});
  } catch (err) {
    const code = (err as {code?: string}).code;
    if (code !== 'auth/uid-already-exists') {
      throw err;
    }
  }

  const customToken = await getAuth().createCustomToken(uid);

  const res = await fetch(
      `${AUTH_EMULATOR_ORIGIN}/identitytoolkit.googleapis.com/v1/accounts:signInWithCustomToken?key=fake-api-key`,
      {
        method: 'POST',
        headers: {'Content-Type': 'application/json'},
        body: JSON.stringify({token: customToken, returnSecureToken: true}),
      },
  );
  if (!res.ok) {
    throw new Error(`signInWithCustomToken failed: ${res.status} ${await res.text()}`);
  }
  const body = await res.json() as {idToken: string};
  return body.idToken;
}

export interface CallableErrorBody {
  status: string;
  message: string;
  details?: unknown;
}

export interface CallableResult<T> {
  status: number;
  body: {result?: T; error?: CallableErrorBody};
}

/**
 * Invokes a v2 `onCall` function against the Functions emulator using the
 * same wire protocol the Firebase client SDKs use — a POST with a
 * `{"data": ...}` envelope and, when authenticated, a bearer ID token.
 *
 * Deliberately sends no `X-Firebase-AppCheck` header: this project's
 * `firebase.json` doesn't configure an App Check emulator, and the Cloud
 * Functions emulator does not enforce `enforceAppCheck` without one — so
 * these callables' `enforceAppCheck: true` option is inert in this suite.
 * That is a genuine, disclosed gap in what these integration tests can
 * verify (App Check enforcement itself is untested), not an oversight —
 * see TASKS.md's Milestone F2 verification notes.
 */
export async function callCallable<T>(
    name: string,
    data: unknown,
    idToken?: string,
): Promise<CallableResult<T>> {
  const headers: Record<string, string> = {'Content-Type': 'application/json'};
  if (idToken) {
    headers['Authorization'] = `Bearer ${idToken}`;
  }
  const res = await fetch(`${FUNCTIONS_EMULATOR_ORIGIN}/${PROJECT_ID}/${REGION}/${name}`, {
    method: 'POST',
    headers,
    body: JSON.stringify({data}),
  });
  const body = await res.json() as CallableResult<T>['body'];
  if (!res.ok) {
    // Debug aid, not just for this one failing run: HttpsError's own
    // `message` is exactly what distinguishes "our handler's own
    // `if (!request.auth)` guard fired" (message: 'Sign-in required.') from
    // "the Functions Framework itself rejected the ID token before our
    // handler ever ran" (a framework-authored message describing why
    // verification failed) — the bare HTTP status code alone can't tell
    // these apart, and test failures without this are much harder to
    // diagnose from captured output alone.
    console.error(`[callCallable] ${name} -> ${res.status}:`, JSON.stringify(body.error));
  }
  return {status: res.status, body};
}
