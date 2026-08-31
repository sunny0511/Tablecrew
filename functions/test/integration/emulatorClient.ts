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
import {getFirestore} from 'firebase-admin/firestore';

export const PROJECT_ID = process.env.GCLOUD_PROJECT || 'tablecrew-dev';
export const REGION = 'us-central1';
export const FUNCTIONS_EMULATOR_ORIGIN = 'http://127.0.0.1:5001';
export const AUTH_EMULATOR_ORIGIN = 'http://127.0.0.1:9099';
/** Default bucket the Functions emulator resolves for this project. */
export const STORAGE_BUCKET = `${PROJECT_ID}.appspot.com`;

let app: App | undefined;

/** Idempotent — safe to call from every test file's `before()` hook. */
export function ensureAdminApp(): App {
  if (!app) {
    app = getApps()[0] ?? initializeApp({
      projectId: PROJECT_ID,
      // Added Milestone F7: identity.integration.test.ts needs to seed and
      // assert on Storage objects, and getStorage().bucket() throws with no
      // default configured. This must name the SAME bucket the Functions
      // emulator resolves from its own FIREBASE_CONFIG, or the function
      // under test will look in a different bucket than the test seeded —
      // see that file's header for the one assumption to check on a first
      // real run.
      storageBucket: STORAGE_BUCKET,
    });
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
export async function getIdTokenForUid(
    uid: string,
    phoneNumber: string,
    developerClaims?: Record<string, unknown>,
): Promise<string> {
  ensureAdminApp();
  try {
    await getAuth().createUser({uid, phoneNumber});
  } catch (err) {
    const code = (err as {code?: string}).code;
    if (code !== 'auth/uid-already-exists') {
      throw err;
    }
  }

  // developerClaims land in the minted ID token's payload, which is how
  // reviewIdentityVerification's `admin` custom-claim check (Milestone F7)
  // is exercised without persisting an admin claim on a test user.
  const customToken = await getAuth().createCustomToken(uid, developerClaims);

  const signInUrl = `${AUTH_EMULATOR_ORIGIN}/identitytoolkit.googleapis.com/v1/` +
    'accounts:signInWithCustomToken?key=fake-api-key';
  const res = await fetch(
      signInUrl,
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
 * Deliberately sends no `X-Firebase-AppCheck` header. An earlier version
 * of this comment assumed the Functions emulator simply doesn't enforce
 * `enforceAppCheck` without a configured App Check emulator — the first
 * real run of this suite proved that assumption wrong: every authenticated
 * request was rejected with a generic `HttpsError('unauthenticated',
 * 'Unauthenticated')`, Firebase's deliberately non-specific error for
 * "either Auth or App Check failed," which for a request with a *valid*
 * Auth token and *no* App Check token can only mean App Check enforcement
 * really was active. Since there is no App Check emulator anywhere in the
 * Firebase Emulator Suite, `functions/src/users/index.ts` now only sets
 * `enforceAppCheck: true` outside the Functions emulator (checked via the
 * framework-set `FUNCTIONS_EMULATOR` env var) — see that file's header
 * comment. That means App Check enforcement itself still isn't exercised
 * by this suite (a genuine, disclosed gap, not an oversight — see
 * TASKS.md's Milestone F2 verification notes), but everything else these
 * callables do now is.
 */
export interface SeedUserProfileOptions {
  displayName?: string;
  standingStatus?: 'good' | 'restricted' | 'banned';
}

/**
 * Writes `users/{uid}` (public) + `users/{uid}/private/profile` directly via
 * the Admin SDK (which bypasses `firestore.rules` entirely, same as every
 * real callable does), rather than going through `completeAccountSetup`.
 * Added Milestone F4: the Tables/Crews integration suites below need
 * precise control over `trustSignals.standingStatus` (to exercise
 * `createTable`'s `TRUST_STANDING_RESTRICTED` check) that
 * `completeAccountSetup`'s own request contract has no field for — that
 * endpoint always creates a fresh account in `standingStatus: "good"`, by
 * design (docs/API_SPEC.md §3.9's `completeAccountSetup` never accepts a
 * caller-supplied trust signal, since a self-reported one would defeat the
 * point). Minimal, schema-shaped per docs/DATABASE.md §3.1 — not a full
 * fixture library, matching the same "just enough to seed for a rules/
 * integration test" scope `firestore/test/rules/src/fixtures.ts` and
 * `scripts/seed_staging.ts` already each keep independently (see
 * TASKS.md's Milestone F1 note on why those three copies aren't
 * consolidated).
 */
export async function seedUserProfile(
    uid: string,
    options: SeedUserProfileOptions = {},
): Promise<void> {
  const db = getFirestore();
  const now = new Date();

  await db.doc(`users/${uid}`).set({
    displayName: options.displayName ?? `Integration User ${uid}`,
    photoUrl: null,
    bio: null,
    interestTags: [],
    verificationTierPublic: 'phone_verified',
    ratingAggregate: {
      averageAsHost: null,
      averageAsAttendee: null,
      ratingCountAsHost: 0,
      ratingCountAsAttendee: 0,
    },
    locale: 'en-IN',
    deletedAt: null,
    createdAt: now,
    updatedAt: now,
  });

  await db.doc(`users/${uid}/private/profile`).set({
    phoneNumberHash: 'itest-hash',
    email: null,
    homeLocation: null,
    residencyRegion: 'IN',
    dateOfBirth: '1990-01-01',
    verification: {
      phoneVerified: true,
      idVerified: false,
      verificationTier: 'phone_verified',
      verifiedAt: now,
    },
    trustSignals: {
      reportCount: 0,
      noShowCount: 0,
      substantiatedBillingDisputeCount: 0,
      standingStatus: options.standingStatus ?? 'good',
    },
    blockedUserIds: [],
    notificationPrefs: {
      categories: {},
      mutedCrewIds: [],
    },
    subscription: {
      tier: 'free',
      status: 'none',
      stripeCustomerId: null,
      stripeSubscriptionId: null,
      currentPeriodEnd: null,
      cancelAtPeriodEnd: false,
      updatedAt: now,
    },
    fcmTokens: [],
    crewMemberships: [],
    createdAt: now,
    updatedAt: now,
  });
}

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
