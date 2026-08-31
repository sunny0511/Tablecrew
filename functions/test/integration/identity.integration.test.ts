/**
 * Real Firebase Emulator Suite integration tests for
 * functions/src/identity/index.ts (submitIdentityVerification,
 * reviewIdentityVerification) — Milestone F7, ADR 0007.
 *
 * Covers what functions/test/identity/validation.test.ts structurally
 * cannot: the admin custom-claim gate, the Storage existence check, the
 * one-open-submission precondition against real Firestore, the open-report
 * re-check at apply time, and the real tier write across two documents.
 *
 * **This suite needs the Storage emulator**, unlike every other file in
 * this directory. Run it via:
 *
 *   firebase emulators:exec --only auth,firestore,functions,storage \
 *     --project tablecrew-dev "npm --prefix functions run test:integration"
 *
 * Note the added `storage` — the command in tables/crews/trust's headers
 * omits it and will fail here.
 *
 * **The one unverified assumption in this file, stated plainly because it
 * is the most likely cause of a confusing first-run failure:** the tests
 * seed Storage objects through the Admin SDK's default bucket
 * (`emulatorClient.STORAGE_BUCKET`, `<projectId>.appspot.com`), while the
 * function under test reads `getStorage().bucket()`, whose default comes
 * from the Functions emulator's own FIREBASE_CONFIG. These are believed to
 * be the same bucket but that has not been confirmed against a running
 * emulator — no environment available when this was written could download
 * the emulator JAR. If the UPLOAD_NOT_FOUND tests below fail on a happy
 * path, check that first: log the bucket name from inside the function and
 * compare, rather than assuming the existence check itself is broken.
 *
 * Phone numbers use the +911234540xxx block. Every integration file shares
 * one emulator session, and F6 lost a run to a collision between two files'
 * ranges (see TASKS.md), so this block is deliberately distinct from
 * trust's +911234530xxx.
 */

import assert from 'node:assert/strict';
import {test, before} from 'node:test';
import {getFirestore} from 'firebase-admin/firestore';
import {getStorage} from 'firebase-admin/storage';
import {
  callCallable,
  ensureAdminApp,
  getIdTokenForUid,
  logStorageBucket,
  seedUserProfile,
} from './emulatorClient';

before(() => {
  ensureAdminApp();
  // Makes a bucket mismatch self-diagnosing — see emulatorClient's
  // resolveStorageBucket() for why this suite cares.
  logStorageBucket();
});

/**
 * Asserts a callable succeeded and returns its result.
 *
 * Exists because of how this suite first failed: one submit returning 404
 * produced a single real assertion failure plus four `Cannot read
 * properties of undefined (reading 'submissionId')` TypeErrors in
 * downstream tests, which read like four separate bugs and were one. This
 * turns each of those into a message naming the actual status and error
 * code at the point it happened.
 */
function expectOk<T>(
    res: {status: number; body: {result?: T; error?: {status?: string; details?: unknown}}},
    what: string,
): T {
  if (res.status !== 200 || !res.body.result) {
    const code = (res.body.error?.details as {code?: string} | undefined)?.code;
    throw new Error(
        `${what} failed: HTTP ${res.status}` +
      `${code ? ` (${code})` : ''}. If this is UPLOAD_NOT_FOUND on a test ` +
      'that seeded its uploads, the seeded bucket and the bucket the ' +
      'function reads have diverged — check the [emulatorClient] line above.',
    );
  }
  return res.body.result;
}

/**
 * `CallableErrorBody.details` is `unknown` by design in emulatorClient —
 * narrowed here rather than loosening the shared type for one suite.
 */
function errCode(res: {body: {error?: {details?: unknown}}}): string | undefined {
  return (res.body.error?.details as {code?: string} | undefined)?.code;
}


/** Puts a real object at the path submitIdentityVerification will check. */
async function seedUpload(uid: string, uploadId: string): Promise<void> {
  await getStorage()
      .bucket()
      .file(`identity-verifications/${uid}/${uploadId}`)
      .save(Buffer.from('fake-image-bytes'), {contentType: 'image/jpeg'});
}

async function uploadExists(uid: string, uploadId: string): Promise<boolean> {
  const [exists] = await getStorage()
      .bucket()
      .file(`identity-verifications/${uid}/${uploadId}`)
      .exists();
  return exists;
}

async function adminToken(uid: string, phone: string): Promise<string> {
  return getIdTokenForUid(uid, phone, {admin: true});
}

test('submitIdentityVerification: rejects an unauthenticated call', async () => {
  const res = await callCallable('submitIdentityVerification', {
    idDocumentUploadId: 'id-1', selfieUploadId: 'selfie-1', documentType: 'passport',
  });
  assert.equal(res.status, 401);
});

test('submitIdentityVerification: rejects an upload id that would escape the caller prefix', async () => {
  const uid = 'itest-identity-escape';
  await seedUserProfile(uid);
  const token = await getIdTokenForUid(uid, '+911234540001');

  const res = await callCallable('submitIdentityVerification', {
    idDocumentUploadId: '../someone-else/id-1',
    selfieUploadId: 'selfie-1',
    documentType: 'passport',
  }, token);

  assert.equal(res.status, 400);
});

test('submitIdentityVerification: rejects an unrecognized documentType', async () => {
  const uid = 'itest-identity-badtype';
  await seedUserProfile(uid);
  const token = await getIdTokenForUid(uid, '+911234540002');

  const res = await callCallable('submitIdentityVerification', {
    idDocumentUploadId: 'id-1', selfieUploadId: 'selfie-1', documentType: 'aadhaar',
  }, token);

  assert.equal(res.status, 400);
});

test('submitIdentityVerification: UPLOAD_NOT_FOUND when the objects were never uploaded', async () => {
  const uid = 'itest-identity-noupload';
  await seedUserProfile(uid);
  const token = await getIdTokenForUid(uid, '+911234540003');

  const res = await callCallable('submitIdentityVerification', {
    idDocumentUploadId: 'missing-id', selfieUploadId: 'missing-selfie', documentType: 'passport',
  }, token);

  assert.equal(res.status, 404);
  assert.equal(errCode(res), 'UPLOAD_NOT_FOUND');
});

test('submitIdentityVerification: creates a pending submission, then refuses a second one', async () => {
  const uid = 'itest-identity-pending';
  await seedUserProfile(uid);
  const token = await getIdTokenForUid(uid, '+911234540004');
  await seedUpload(uid, 'id-1');
  await seedUpload(uid, 'selfie-1');

  const first = expectOk(await callCallable<{submissionId: string; status: string}>(
      'submitIdentityVerification',
      {idDocumentUploadId: 'id-1', selfieUploadId: 'selfie-1', documentType: 'aadhaar_offline'},
      token,
  ), 'submitIdentityVerification');
  assert.equal(first.status, 'pending_review');

  const doc = await getFirestore()
      .doc(`identityVerifications/${first.submissionId}`)
      .get();
  assert.equal(doc.data()?.userId, uid);
  assert.equal(doc.data()?.status, 'pending_review');
  // Nothing ID-derived is persisted (docs/DATABASE.md §3.10).
  assert.equal(doc.data()?.dobMatchesId, null);
  assert.equal(doc.data()?.reviewedBy, null);

  // The pointer that makes this submission rediscoverable after an app
  // restart — without it, a client that lost the id has no way back to a
  // pending review, since `list` is denied on this collection.
  const profileAfterSubmit = await getFirestore()
      .doc(`users/${uid}/private/profile`).get();
  assert.equal(
      profileAfterSubmit.data()?.verification?.pendingSubmissionId,
      first.submissionId,
  );

  const second = await callCallable('submitIdentityVerification', {
    idDocumentUploadId: 'id-1', selfieUploadId: 'selfie-1', documentType: 'aadhaar_offline',
  }, token);
  assert.equal(second.status, 400);
  assert.equal(errCode(second), 'REVIEW_ALREADY_PENDING');
});

test('reviewIdentityVerification: a non-admin caller is refused', async () => {
  const uid = 'itest-identity-nonadmin';
  await seedUserProfile(uid);
  const token = await getIdTokenForUid(uid, '+911234540005');

  const res = await callCallable('reviewIdentityVerification', {
    submissionId: 'anything', decision: 'approve', dobMatchesId: true,
  }, token);

  assert.equal(res.status, 403);
  assert.equal(errCode(res), 'ADMIN_ONLY');
});

test('reviewIdentityVerification: an approve without the DOB attestation never grants the tier', async () => {
  const uid = 'itest-identity-nodob';
  await seedUserProfile(uid);
  const userToken = await getIdTokenForUid(uid, '+911234540006');
  await seedUpload(uid, 'id-1');
  await seedUpload(uid, 'selfie-1');
  const submitted = expectOk(await callCallable<{submissionId: string}>(
      'submitIdentityVerification',
      {idDocumentUploadId: 'id-1', selfieUploadId: 'selfie-1', documentType: 'passport'},
      userToken,
  ), 'submitIdentityVerification');

  const admin = await adminToken('itest-identity-admin1', '+911234540090');
  const res = await callCallable('reviewIdentityVerification', {
    submissionId: submitted.submissionId, decision: 'approve', dobMatchesId: false,
  }, admin);

  assert.equal(res.status, 400);
  assert.equal(errCode(res), 'DOB_ATTESTATION_REQUIRED');

  const profile = await getFirestore().doc(`users/${uid}/private/profile`).get();
  assert.notEqual(profile.data()?.verification?.verificationTier, 'id_verified');
});

test('reviewIdentityVerification: a reject with no reason is refused', async () => {
  const uid = 'itest-identity-noreason';
  await seedUserProfile(uid);
  const userToken = await getIdTokenForUid(uid, '+911234540007');
  await seedUpload(uid, 'id-1');
  await seedUpload(uid, 'selfie-1');
  const submitted = expectOk(await callCallable<{submissionId: string}>(
      'submitIdentityVerification',
      {idDocumentUploadId: 'id-1', selfieUploadId: 'selfie-1', documentType: 'passport'},
      userToken,
  ), 'submitIdentityVerification');

  const admin = await adminToken('itest-identity-admin2', '+911234540091');
  const res = await callCallable('reviewIdentityVerification', {
    submissionId: submitted.submissionId, decision: 'reject', dobMatchesId: false,
  }, admin);

  assert.equal(res.status, 400);
  assert.equal(errCode(res), 'REJECTION_REASON_REQUIRED');
});

test('reviewIdentityVerification: a clean approve grants the tier on both documents and deletes the images', async () => {
  const uid = 'itest-identity-approve';
  await seedUserProfile(uid);
  const userToken = await getIdTokenForUid(uid, '+911234540008');
  await seedUpload(uid, 'id-1');
  await seedUpload(uid, 'selfie-1');
  const submitted = expectOk(await callCallable<{submissionId: string}>(
      'submitIdentityVerification',
      {idDocumentUploadId: 'id-1', selfieUploadId: 'selfie-1', documentType: 'aadhaar_offline'},
      userToken,
  ), 'submitIdentityVerification');
  const submissionId = submitted.submissionId;

  const admin = await adminToken('itest-identity-admin3', '+911234540092');
  const res = await callCallable<{status: string; verificationTier: string}>(
      'reviewIdentityVerification',
      {submissionId, decision: 'approve', dobMatchesId: true},
      admin,
  );
  assert.equal(res.status, 200);
  assert.equal(res.body.result?.status, 'approved');
  assert.equal(res.body.result?.verificationTier, 'id_verified');

  const db = getFirestore();
  const profile = await db.doc(`users/${uid}/private/profile`).get();
  assert.equal(profile.data()?.verification?.verificationTier, 'id_verified');
  assert.equal(profile.data()?.verification?.idVerified, true);

  // The public badge is written in the same batch — there is no
  // denormalization trigger for it (see functions/src/identity/index.ts).
  const publicDoc = await db.doc(`users/${uid}`).get();
  assert.equal(publicDoc.data()?.verificationTierPublic, 'id_verified');

  // Cleared once decided — a stale pointer would send Screen 8 back to a
  // finished submission instead of letting the user move on.
  assert.equal(profile.data()?.verification?.pendingSubmissionId, null);

  const submission = await db.doc(`identityVerifications/${submissionId}`).get();
  assert.equal(submission.data()?.status, 'approved');
  assert.equal(submission.data()?.reviewedBy, 'itest-identity-admin3');
  assert.equal(submission.data()?.idDocumentPath, null);
  assert.equal(submission.data()?.selfiePath, null);

  // ADR 0007's data-minimization consequence, asserted rather than assumed.
  assert.equal(await uploadExists(uid, 'id-1'), false);
  assert.equal(await uploadExists(uid, 'selfie-1'), false);

  // A second decision on the same submission is refused.
  const again = await callCallable('reviewIdentityVerification', {
    submissionId, decision: 'reject', dobMatchesId: false, rejectionReason: 'changed my mind',
  }, admin);
  assert.equal(again.status, 400);
  assert.equal(errCode(again), 'ALREADY_REVIEWED');

  // And the now-verified user cannot open a fresh submission.
  await seedUpload(uid, 'id-2');
  await seedUpload(uid, 'selfie-2');
  const resubmit = await callCallable('submitIdentityVerification', {
    idDocumentUploadId: 'id-2', selfieUploadId: 'selfie-2', documentType: 'passport',
  }, userToken);
  assert.equal(resubmit.status, 400);
  assert.equal(errCode(resubmit), 'ALREADY_VERIFIED');
});

test('reviewIdentityVerification: an open report at apply time holds the grant', async () => {
  const uid = 'itest-identity-reported';
  await seedUserProfile(uid);
  const userToken = await getIdTokenForUid(uid, '+911234540009');
  await seedUpload(uid, 'id-1');
  await seedUpload(uid, 'selfie-1');
  const submitted = expectOk(await callCallable<{submissionId: string}>(
      'submitIdentityVerification',
      {idDocumentUploadId: 'id-1', selfieUploadId: 'selfie-1', documentType: 'passport'},
      userToken,
  ), 'submitIdentityVerification');

  // Filed AFTER submission — the exact ordering docs/SECURITY.md's
  // report-filed-mid-verification rule exists to handle.
  await getFirestore().collection('reports').add({
    reporterId: 'someone-else',
    targetType: 'user',
    targetId: uid,
    status: 'open',
    reasonCode: 'safety_concern',
    createdAt: new Date(),
  });

  const admin = await adminToken('itest-identity-admin4', '+911234540093');
  const res = await callCallable<{status: string; verificationTier: string}>(
      'reviewIdentityVerification',
      {submissionId: submitted.submissionId, decision: 'approve', dobMatchesId: true},
      admin,
  );

  assert.equal(res.status, 200);
  assert.equal(res.body.result?.status, 'held_for_review');
  assert.notEqual(res.body.result?.verificationTier, 'id_verified');

  const profile = await getFirestore().doc(`users/${uid}/private/profile`).get();
  assert.notEqual(profile.data()?.verification?.verificationTier, 'id_verified');
  // Cleared on a held outcome too, not only on approval.
  assert.equal(profile.data()?.verification?.pendingSubmissionId, null);
});
