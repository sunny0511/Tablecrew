/**
 * Real Firebase Emulator Suite integration tests for
 * functions/src/users/index.ts's three callables. Unlike
 * functions/test/users/*.test.ts (pure-logic unit tests, run via plain
 * `npm test`, no emulator required), these exercise the actual deployed
 * `onCall` wrappers over the network against live Auth/Firestore/Functions
 * emulators — the batch-create transaction, the idempotency
 * pre-check/re-check, and `admin.auth().revokeRefreshTokens()` included.
 *
 * Run via:
 *   firebase emulators:exec --only auth,firestore,functions \
 *     --project tablecrew-dev "npm --prefix functions run test:integration"
 *
 * Added Milestone F2, closing a disclosed gap: the callables' actual
 * runtime behavior had previously been verified only via tsc/eslint on the
 * wrapper code plus unit tests on the pure logic (ageGate/residency/
 * validation) they call, never against a live emulator. See TASKS.md.
 */

import assert from 'node:assert/strict';
import {test, before} from 'node:test';
import * as admin from 'firebase-admin';
import {callCallable, ensureAdminApp, getIdTokenForUid} from './emulatorClient';

before(() => {
  ensureAdminApp();
});

test('validateAge: rejects an unauthenticated call', async () => {
  const res = await callCallable('validateAge', {dateOfBirth: '2000-01-01'});
  assert.equal(res.status, 401);
  assert.equal(res.body.error?.status, 'UNAUTHENTICATED');
});

test('validateAge: eligible for a 25-year-old', async () => {
  const idToken = await getIdTokenForUid('itest-validate-eligible', '+911234500001');
  const res = await callCallable<{eligible: boolean}>(
      'validateAge', {dateOfBirth: '2001-01-01'}, idToken,
  );
  assert.equal(res.status, 200);
  assert.equal(res.body.result?.eligible, true);
});

test('validateAge: ineligible for a 10-year-old', async () => {
  const idToken = await getIdTokenForUid('itest-validate-ineligible', '+911234500002');
  const res = await callCallable<{eligible: boolean}>(
      'validateAge', {dateOfBirth: '2016-01-01'}, idToken,
  );
  assert.equal(res.status, 200);
  assert.equal(res.body.result?.eligible, false);
});

test('validateAge: rejects a malformed dateOfBirth', async () => {
  const idToken = await getIdTokenForUid('itest-validate-malformed', '+911234500003');
  const res = await callCallable('validateAge', {dateOfBirth: 'not-a-date'}, idToken);
  assert.equal(res.status, 400);
  assert.equal(res.body.error?.status, 'INVALID_ARGUMENT');
});

test('completeAccountSetup: rejects an under-18 date of birth', async () => {
  const idToken = await getIdTokenForUid('itest-setup-under18', '+911234500004');
  const res = await callCallable('completeAccountSetup', {
    dateOfBirth: '2015-01-01',
    displayName: 'Too Young',
    interestTags: ['coffee', 'hiking', 'board_games'],
    locale: 'en-IN',
  }, idToken);
  assert.equal(res.status, 400);
  assert.equal(res.body.error?.status, 'FAILED_PRECONDITION');
  const details = res.body.error?.details as {code?: string} | undefined;
  assert.equal(details?.code, 'UNDER_MINIMUM_AGE');
});

test('completeAccountSetup: rejects an invalid displayName', async () => {
  const idToken = await getIdTokenForUid('itest-setup-baddisplay', '+911234500005');
  const res = await callCallable('completeAccountSetup', {
    dateOfBirth: '1990-01-01',
    displayName: '',
    interestTags: ['coffee', 'hiking', 'board_games'],
    locale: 'en-IN',
  }, idToken);
  assert.equal(res.status, 400);
  assert.equal(res.body.error?.status, 'INVALID_ARGUMENT');
});

test(
    'completeAccountSetup: creates users/{uid} + private/profile, derives ' +
    'residencyRegion from phone, and is idempotent on retry',
    async () => {
      const uid = 'itest-setup-success';
      const idToken = await getIdTokenForUid(uid, '+447700900123');

      const payload = {
        dateOfBirth: '1990-06-15',
        displayName: 'Integration Tester',
        bio: 'Testing account setup end to end.',
        interestTags: ['coffee', 'hiking', 'board_games'],
        locale: 'en-GB',
      };

      const first = await callCallable<{uid: string; verificationTierPublic: string}>(
          'completeAccountSetup', payload, idToken,
      );
      assert.equal(first.status, 200);
      assert.equal(first.body.result?.uid, uid);
      assert.equal(first.body.result?.verificationTierPublic, 'phone_verified');

      const db = admin.firestore();
      const publicSnap = await db.doc(`users/${uid}`).get();
      const privateSnap = await db.doc(`users/${uid}/private/profile`).get();
      assert.equal(publicSnap.exists, true);
      assert.equal(privateSnap.exists, true);

      const publicData = publicSnap.data()!;
      assert.equal(publicData.displayName, 'Integration Tester');
      assert.equal(publicData.verificationTierPublic, 'phone_verified');
      assert.equal(publicData.deletedAt, null);

      const privateData = privateSnap.data()!;
      assert.equal(privateData.dateOfBirth, '1990-06-15');
      assert.equal(privateData.residencyRegion, 'GB');
      assert.equal(privateData.verification.phoneVerified, true);
      assert.equal(privateData.verification.verificationTier, 'phone_verified');
      assert.match(privateData.phoneNumberHash, /^[0-9a-f]{64}$/);

      const createdAtFirst = publicData.createdAt;

      // Retry — idempotent by construction (no idempotencyKeys entry
      // involved; see docs/API_SPEC.md §3.9). Must return the same result
      // and must NOT rewrite the existing documents.
      const second = await callCallable<{uid: string; verificationTierPublic: string}>(
          'completeAccountSetup', payload, idToken,
      );
      assert.equal(second.status, 200);
      assert.deepEqual(second.body.result, first.body.result);

      const publicSnapAfterRetry = await db.doc(`users/${uid}`).get();
      assert.deepEqual(publicSnapAfterRetry.data()!.createdAt, createdAtFirst);
    },
);

test("revokeSessions: advances the user's tokensValidAfterTime", async () => {
  const uid = 'itest-revoke';
  const idToken = await getIdTokenForUid(uid, '+911234500006');

  const beforeUser = await admin.auth().getUser(uid);
  const beforeTime = beforeUser.tokensValidAfterTime;

  const res = await callCallable<{success: boolean; revokedAt: string}>(
      'revokeSessions', {}, idToken,
  );
  assert.equal(res.status, 200);
  assert.equal(res.body.result?.success, true);

  const afterUser = await admin.auth().getUser(uid);
  assert.notEqual(afterUser.tokensValidAfterTime, beforeTime);
});
