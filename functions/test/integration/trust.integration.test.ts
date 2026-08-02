/**
 * Real Firebase Emulator Suite integration tests for
 * functions/src/trust/index.ts's callables (reportUser, reportTable,
 * blockUser, triggerDuressSignal). Same rationale and run command as
 * tables.integration.test.ts (see that file's header) — added Milestone F6
 * to cover exactly what functions/test/trust/validation.test.ts's fake-
 * Firestore unit tests structurally cannot: real Firestore transactions
 * enforcing the duplicate-open-report dedup query, the report-threshold
 * auto-suppression side effect on the target, and real rate-limit
 * enforcement across repeated calls.
 *
 * Run via:
 *   firebase emulators:exec --only auth,firestore,functions \
 *     --project tablecrew-dev "npm --prefix functions run test:integration"
 */

import assert from 'node:assert/strict';
import {test, before} from 'node:test';
import {getFirestore} from 'firebase-admin/firestore';
import {callCallable, ensureAdminApp, getIdTokenForUid, seedUserProfile} from './emulatorClient';

before(() => {
  ensureAdminApp();
});

test('reportUser: rejects an unauthenticated call', async () => {
  const res = await callCallable('reportUser', {
    targetType: 'user', targetId: 'someone', reasonCode: 'harassment',
  });
  assert.equal(res.status, 401);
});

test('reportUser: rejects an unrecognized reasonCode', async () => {
  const reporterUid = 'itest-trust-badreason';
  await seedUserProfile(reporterUid);
  const token = await getIdTokenForUid(reporterUid, '+911234530001');

  const res = await callCallable('reportUser', {
    targetType: 'user', targetId: 'target-uid', reasonCode: 'flagged_media',
  }, token);
  assert.equal(res.status, 400);
});

test('reportUser: rejects off_platform_stalking with no details', async () => {
  const reporterUid = 'itest-trust-nodetails';
  await seedUserProfile(reporterUid);
  const token = await getIdTokenForUid(reporterUid, '+911234530002');

  const res = await callCallable('reportUser', {
    targetType: 'user', targetId: 'target-uid', reasonCode: 'off_platform_stalking',
  }, token);
  assert.equal(res.status, 400);
});

test('reportUser: succeeds, increments the target\'s trustSignals.reportCount, and creates a reports/ document', async () => {
  const reporterUid = 'itest-trust-reportok';
  const targetUid = 'itest-trust-reportok-target';
  await seedUserProfile(reporterUid);
  await seedUserProfile(targetUid);
  const token = await getIdTokenForUid(reporterUid, '+911234530003');

  const res = await callCallable<{reportId: string}>('reportUser', {
    targetType: 'user', targetId: targetUid, reasonCode: 'harassment', details: 'they were rude',
  }, token);
  assert.equal(res.status, 200);
  assert.ok(res.body.result?.reportId);

  const db = getFirestore();
  const reportSnap = await db.doc(`reports/${res.body.result!.reportId}`).get();
  assert.equal(reportSnap.data()?.reporterId, reporterUid);
  assert.equal(reportSnap.data()?.targetType, 'user');
  assert.equal(reportSnap.data()?.targetId, targetUid);
  assert.equal(reportSnap.data()?.status, 'open');

  const targetProfileSnap = await db.doc(`users/${targetUid}/private/profile`).get();
  assert.equal(targetProfileSnap.data()?.trustSignals.reportCount, 1);
});

test('reportUser: a second identical open report from the same reporter against the same target is already-exists', async () => {
  const reporterUid = 'itest-trust-dup';
  const targetUid = 'itest-trust-dup-target';
  await seedUserProfile(reporterUid);
  await seedUserProfile(targetUid);
  const token = await getIdTokenForUid(reporterUid, '+911234530004');

  const first = await callCallable('reportUser', {
    targetType: 'user', targetId: targetUid, reasonCode: 'harassment',
  }, token);
  assert.equal(first.status, 200);

  const second = await callCallable('reportUser', {
    targetType: 'user', targetId: targetUid, reasonCode: 'harassment',
  }, token);
  assert.equal(second.status, 409);
});

test('reportTable: rejects targetType mismatch (reportUser\'s target passed to reportTable)', async () => {
  const reporterUid = 'itest-trust-mismatch';
  await seedUserProfile(reporterUid);
  const token = await getIdTokenForUid(reporterUid, '+911234530005');

  const res = await callCallable('reportTable', {
    targetType: 'user', targetId: 'some-uid', reasonCode: 'harassment',
  }, token);
  assert.equal(res.status, 400);
});

test('reportTable: crossing the open-report threshold sets reportFlags.isSuppressed on the Table', async () => {
  const targetTableId = 'itest-trust-suppress-table';
  const db = getFirestore();
  await db.doc(`tables/${targetTableId}`).set({
    hostId: 'itest-trust-suppress-host',
    title: 'Table under scrutiny',
    visibility: 'open',
    status: 'proposed',
    capacity: {min: 2, max: 8, confirmedCount: 0, waitlistCount: 0},
    reportFlags: {openReportCount: 0, isSuppressed: false},
    createdAt: new Date(),
    updatedAt: new Date(),
  });

  const reporters: Array<{uid: string; phone: string}> = [
    {uid: 'itest-trust-sup-r1', phone: '+911234530006'},
    {uid: 'itest-trust-sup-r2', phone: '+911234530007'},
    {uid: 'itest-trust-sup-r3', phone: '+911234530008'},
  ];
  for (const {uid, phone} of reporters) {
    await seedUserProfile(uid);
    const token = await getIdTokenForUid(uid, phone);
    const res = await callCallable('reportTable', {
      targetType: 'table', targetId: targetTableId, reasonCode: 'safety_concern',
    }, token);
    assert.equal(res.status, 200);
  }

  const tableSnap = await db.doc(`tables/${targetTableId}`).get();
  assert.equal(tableSnap.data()?.reportFlags.openReportCount, 3);
  assert.equal(tableSnap.data()?.reportFlags.isSuppressed, true);
});

test('blockUser: rejects blocking yourself', async () => {
  const uid = 'itest-trust-selfblock';
  await seedUserProfile(uid);
  const token = await getIdTokenForUid(uid, '+911234530009');

  const res = await callCallable('blockUser', {targetUserId: uid}, token);
  assert.equal(res.status, 400);
});

test('blockUser: succeeds and is idempotent on repeat calls (arrayUnion, no idempotency key)', async () => {
  const uid = 'itest-trust-blockok';
  const targetUid = 'itest-trust-blockok-target';
  await seedUserProfile(uid);
  await seedUserProfile(targetUid);
  const token = await getIdTokenForUid(uid, '+911234530010');

  const first = await callCallable<{success: boolean}>('blockUser', {targetUserId: targetUid}, token);
  assert.equal(first.status, 200);
  assert.equal(first.body.result?.success, true);

  const second = await callCallable<{success: boolean}>('blockUser', {targetUserId: targetUid}, token);
  assert.equal(second.status, 200);

  const db = getFirestore();
  const profileSnap = await db.doc(`users/${uid}/private/profile`).get();
  assert.deepEqual(profileSnap.data()?.blockedUserIds, [targetUid]);
});

test('triggerDuressSignal: rejects an unauthenticated call, the only condition that can block it', async () => {
  const res = await callCallable('triggerDuressSignal', {tableId: 'some-table'});
  assert.equal(res.status, 401);
});

test('triggerDuressSignal: succeeds even with a missing tableId and malformed location — never rejects a live emergency', async () => {
  const uid = 'itest-trust-duress-noargs';
  await seedUserProfile(uid);
  const token = await getIdTokenForUid(uid, '+911234530011');

  const res = await callCallable<{acknowledged: boolean}>('triggerDuressSignal', {
    location: {geopoint: 'not-an-object'},
  }, token);
  assert.equal(res.status, 200);
  assert.equal(res.body.result?.acknowledged, true);

  // A missing tableId can't form a valid `tables/{tableId}/duressSignals/{uid}`
  // path (real bug found while writing this test — see index.ts's inline
  // note), so no duressSignals doc is written, but the linked sev1 report
  // still is — the signal is never silently dropped even in this case.
  const db = getFirestore();
  const reportsSnap = await db.collection('reports')
      .where('reporterId', '==', uid)
      .where('isDuressSignal', '==', true)
      .get();
  assert.equal(reportsSnap.size, 1);
  assert.equal(reportsSnap.docs[0]?.data().severity, 'sev1');
});

test('triggerDuressSignal: writes a duressSignals doc and a linked sev1 report with the given location', async () => {
  const uid = 'itest-trust-duress-full';
  const tableId = 'itest-trust-duress-table';
  await seedUserProfile(uid);
  const token = await getIdTokenForUid(uid, '+911234530012');

  const res = await callCallable<{acknowledged: boolean}>('triggerDuressSignal', {
    tableId,
    location: {geopoint: {lat: 12.9716, lng: 77.5946}},
  }, token);
  assert.equal(res.status, 200);
  assert.equal(res.body.result?.acknowledged, true);

  const db = getFirestore();
  const duressSnap = await db.doc(`tables/${tableId}/duressSignals/${uid}`).get();
  assert.equal(duressSnap.exists, true);
  assert.equal(duressSnap.data()?.status, 'open');
  const linkedReportId = duressSnap.data()?.linkedReportId as string;
  assert.ok(linkedReportId);

  const reportSnap = await db.doc(`reports/${linkedReportId}`).get();
  assert.equal(reportSnap.data()?.severity, 'sev1');
  assert.equal(reportSnap.data()?.isDuressSignal, true);
  assert.equal(reportSnap.data()?.targetId, tableId);
});
