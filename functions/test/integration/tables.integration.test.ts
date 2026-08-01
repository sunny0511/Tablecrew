/**
 * Real Firebase Emulator Suite integration tests for
 * functions/src/tables/index.ts's 7 callables. Same rationale and
 * run command as users.integration.test.ts (see that file's header) —
 * added Milestone F4 to cover exactly what functions/test/tables/
 * validation.test.ts's fake-Firestore unit tests structurally cannot: real
 * Firestore transactions enforcing the capacity invariant across
 * requestSeat/confirmAttendee/cancelRsvp, the CANNOT_EDIT_AFTER_CONFIRMED
 * freeze, and idempotent-by-construction repeat-call behavior.
 *
 * Run via:
 *   firebase emulators:exec --only auth,firestore,functions \
 *     --project tablecrew-dev "npm --prefix functions run test:integration"
 *
 * Deliberately not exhaustive of every invalid-argument branch — those are
 * functions/src/tables/validation.ts's job and are already unit-tested to
 * 100% line coverage. This suite exercises the transactional/permission
 * logic that only exists inside index.ts's callable bodies.
 */

import assert from 'node:assert/strict';
import crypto from 'node:crypto';
import {test, before} from 'node:test';
import {getFirestore} from 'firebase-admin/firestore';
import {callCallable, ensureAdminApp, getIdTokenForUid, seedUserProfile} from './emulatorClient';

before(() => {
  ensureAdminApp();
});

const startTimeTwoHoursOut = () => new Date(Date.now() + 2 * 60 * 60 * 1000).toISOString();

function baseTablePayload(overrides: Record<string, unknown> = {}) {
  return {
    title: 'Integration Test Table',
    description: null,
    interestTag: 'coffee',
    visibility: 'closed',
    location: {geopoint: {lat: 12.9716, lng: 77.5946}, address: '123 Test St'},
    startTime: startTimeTwoHoursOut(),
    capacity: {min: 2, max: 2},
    crewId: null,
    idempotencyKey: crypto.randomUUID(),
    ...overrides,
  };
}

test('createTable: rejects an unauthenticated call', async () => {
  const res = await callCallable('createTable', baseTablePayload());
  assert.equal(res.status, 401);
});

test('createTable: rejects a caller with restricted trust standing', async () => {
  const uid = 'itest-tbl-restricted';
  await seedUserProfile(uid, {standingStatus: 'restricted'});
  const idToken = await getIdTokenForUid(uid, '+911234510001');

  const res = await callCallable('createTable', baseTablePayload(), idToken);
  assert.equal(res.status, 400);
  const details = res.body.error?.details as {code?: string} | undefined;
  assert.equal(details?.code, 'TRUST_STANDING_RESTRICTED');
});

test('createTable: succeeds and is idempotent on retry with the same key', async () => {
  const uid = 'itest-tbl-create';
  await seedUserProfile(uid);
  const idToken = await getIdTokenForUid(uid, '+911234510002');
  const payload = baseTablePayload();

  const first = await callCallable<{tableId: string; status: string}>('createTable', payload, idToken);
  assert.equal(first.status, 200);
  assert.equal(first.body.result?.status, 'proposed');

  const second = await callCallable<{tableId: string; status: string}>('createTable', payload, idToken);
  assert.equal(second.status, 200);
  assert.equal(second.body.result?.tableId, first.body.result?.tableId);

  const db = getFirestore();
  const snap = await db.doc(`tables/${first.body.result?.tableId}`).get();
  assert.equal(snap.exists, true);
  assert.equal(snap.data()!.hostId, uid);
});

test('requestSeat: an open Table under capacity confirms immediately', async () => {
  const hostUid = 'itest-tbl-open-host';
  const guestUid = 'itest-tbl-open-guest';
  await seedUserProfile(hostUid);
  await seedUserProfile(guestUid);
  const hostToken = await getIdTokenForUid(hostUid, '+911234510003');
  const guestToken = await getIdTokenForUid(guestUid, '+911234510004');

  const created = await callCallable<{tableId: string}>(
      'createTable', baseTablePayload({visibility: 'open', capacity: {min: 2, max: 2}}), hostToken,
  );
  const tableId = created.body.result!.tableId;

  const res = await callCallable<{rsvpStatus: string}>(
      'requestSeat', {tableId, idempotencyKey: crypto.randomUUID()}, guestToken,
  );
  assert.equal(res.status, 200);
  assert.equal(res.body.result?.rsvpStatus, 'confirmed');

  const db = getFirestore();
  const tableSnap = await db.doc(`tables/${tableId}`).get();
  assert.equal(tableSnap.data()!.capacity.confirmedCount, 1);
});

test('requestSeat: a closed Table always lands in "requested", not auto-confirmed', async () => {
  const hostUid = 'itest-tbl-closed-host';
  const guestUid = 'itest-tbl-closed-guest';
  await seedUserProfile(hostUid);
  await seedUserProfile(guestUid);
  const hostToken = await getIdTokenForUid(hostUid, '+911234510005');
  const guestToken = await getIdTokenForUid(guestUid, '+911234510006');

  const created = await callCallable<{tableId: string}>(
      'createTable', baseTablePayload({visibility: 'closed'}), hostToken,
  );
  const tableId = created.body.result!.tableId;

  const res = await callCallable<{rsvpStatus: string}>(
      'requestSeat', {tableId, idempotencyKey: crypto.randomUUID()}, guestToken,
  );
  assert.equal(res.status, 200);
  assert.equal(res.body.result?.rsvpStatus, 'requested');

  const db = getFirestore();
  const tableSnap = await db.doc(`tables/${tableId}`).get();
  assert.equal(tableSnap.data()!.capacity.confirmedCount, 0);
});

test('requestSeat: a full open Table waitlists the next requester', async () => {
  const hostUid = 'itest-tbl-full-host';
  const guest1 = 'itest-tbl-full-g1';
  const guest2 = 'itest-tbl-full-g2';
  await seedUserProfile(hostUid);
  await seedUserProfile(guest1);
  await seedUserProfile(guest2);
  const hostToken = await getIdTokenForUid(hostUid, '+911234510007');
  const g1Token = await getIdTokenForUid(guest1, '+911234510008');
  const g2Token = await getIdTokenForUid(guest2, '+911234510009');

  const created = await callCallable<{tableId: string}>(
      'createTable', baseTablePayload({visibility: 'open', capacity: {min: 2, max: 1}}), hostToken,
  );
  const tableId = created.body.result!.tableId;

  const first = await callCallable<{rsvpStatus: string}>(
      'requestSeat', {tableId, idempotencyKey: crypto.randomUUID()}, g1Token,
  );
  assert.equal(first.body.result?.rsvpStatus, 'confirmed');

  const second = await callCallable<{rsvpStatus: string}>(
      'requestSeat', {tableId, idempotencyKey: crypto.randomUUID()}, g2Token,
  );
  assert.equal(second.body.result?.rsvpStatus, 'waitlisted');

  const db = getFirestore();
  const tableSnap = await db.doc(`tables/${tableId}`).get();
  assert.equal(tableSnap.data()!.capacity.confirmedCount, 1);
  assert.equal(tableSnap.data()!.capacity.waitlistCount, 1);
});

test('confirmAttendee: host confirms a "requested" RSVP; TABLE_FULL once capacity is reached', async () => {
  const hostUid = 'itest-tbl-confirm-host';
  const guest1 = 'itest-tbl-confirm-g1';
  const guest2 = 'itest-tbl-confirm-g2';
  await seedUserProfile(hostUid);
  await seedUserProfile(guest1);
  await seedUserProfile(guest2);
  const hostToken = await getIdTokenForUid(hostUid, '+911234510010');
  const g1Token = await getIdTokenForUid(guest1, '+911234510011');
  const g2Token = await getIdTokenForUid(guest2, '+911234510012');

  const created = await callCallable<{tableId: string}>(
      'createTable', baseTablePayload({visibility: 'closed', capacity: {min: 2, max: 1}}), hostToken,
  );
  const tableId = created.body.result!.tableId;

  await callCallable('requestSeat', {tableId, idempotencyKey: crypto.randomUUID()}, g1Token);
  await callCallable('requestSeat', {tableId, idempotencyKey: crypto.randomUUID()}, g2Token);

  const confirmed = await callCallable<{success: boolean; newStatus: string}>(
      'confirmAttendee', {tableId, targetUserId: guest1, idempotencyKey: crypto.randomUUID()}, hostToken,
  );
  assert.equal(confirmed.status, 200);
  assert.equal(confirmed.body.result?.newStatus, 'confirmed');

  const overCapacity = await callCallable(
      'confirmAttendee', {tableId, targetUserId: guest2, idempotencyKey: crypto.randomUUID()}, hostToken,
  );
  assert.equal(overCapacity.status, 400);
  const details = overCapacity.body.error?.details as {code?: string} | undefined;
  assert.equal(details?.code, 'TABLE_FULL');
});

test('cancelRsvp: cancelling a confirmed RSVP promotes the earliest waitlisted RSVP', async () => {
  const hostUid = 'itest-tbl-promote-host';
  const guest1 = 'itest-tbl-promote-g1';
  const guest2 = 'itest-tbl-promote-g2';
  await seedUserProfile(hostUid);
  await seedUserProfile(guest1);
  await seedUserProfile(guest2);
  const hostToken = await getIdTokenForUid(hostUid, '+911234510013');
  const g1Token = await getIdTokenForUid(guest1, '+911234510014');
  const g2Token = await getIdTokenForUid(guest2, '+911234510015');

  const created = await callCallable<{tableId: string}>(
      'createTable', baseTablePayload({visibility: 'open', capacity: {min: 2, max: 1}}), hostToken,
  );
  const tableId = created.body.result!.tableId;

  await callCallable('requestSeat', {tableId, idempotencyKey: crypto.randomUUID()}, g1Token); // confirmed
  await callCallable('requestSeat', {tableId, idempotencyKey: crypto.randomUUID()}, g2Token); // waitlisted

  const cancelRes = await callCallable(
      'cancelRsvp', {tableId, idempotencyKey: crypto.randomUUID()}, g1Token,
  );
  assert.equal(cancelRes.status, 200);

  const db = getFirestore();
  const g2Rsvp = await db.doc(`tables/${tableId}/rsvps/${guest2}`).get();
  assert.equal(g2Rsvp.data()!.status, 'confirmed');

  const tableSnap = await db.doc(`tables/${tableId}`).get();
  assert.equal(tableSnap.data()!.capacity.confirmedCount, 1);
  assert.equal(tableSnap.data()!.capacity.waitlistCount, 0);
});

test('cancelTable: host cancels; a repeat call is an idempotent-by-construction no-op', async () => {
  const hostUid = 'itest-tbl-cancel-host';
  await seedUserProfile(hostUid);
  const hostToken = await getIdTokenForUid(hostUid, '+911234510016');

  const created = await callCallable<{tableId: string}>('createTable', baseTablePayload(), hostToken);
  const tableId = created.body.result!.tableId;

  const first = await callCallable<{success: boolean}>('cancelTable', {tableId}, hostToken);
  assert.equal(first.status, 200);
  assert.equal(first.body.result?.success, true);

  const second = await callCallable<{success: boolean}>('cancelTable', {tableId}, hostToken);
  assert.equal(second.status, 200);
  assert.equal(second.body.result?.success, true);

  const db = getFirestore();
  const snap = await db.doc(`tables/${tableId}`).get();
  assert.equal(snap.data()!.status, 'cancelled');
});

test('cancelTable: a non-host, non-Crew-admin caller is denied', async () => {
  const hostUid = 'itest-tbl-cancelperm-host';
  const strangerUid = 'itest-tbl-cancelperm-stranger';
  await seedUserProfile(hostUid);
  await seedUserProfile(strangerUid);
  const hostToken = await getIdTokenForUid(hostUid, '+911234510017');
  const strangerToken = await getIdTokenForUid(strangerUid, '+911234510018');

  const created = await callCallable<{tableId: string}>('createTable', baseTablePayload(), hostToken);
  const tableId = created.body.result!.tableId;

  const res = await callCallable('cancelTable', {tableId}, strangerToken);
  assert.equal(res.status, 403);
});

test('endTableEarly: TABLE_NOT_LIVE when the Table hasn\'t reached confirmed', async () => {
  const hostUid = 'itest-tbl-endearly-host';
  await seedUserProfile(hostUid);
  const hostToken = await getIdTokenForUid(hostUid, '+911234510019');

  const created = await callCallable<{tableId: string}>('createTable', baseTablePayload(), hostToken);
  const tableId = created.body.result!.tableId;

  const res = await callCallable('endTableEarly', {tableId}, hostToken);
  assert.equal(res.status, 400);
  const details = res.body.error?.details as {code?: string} | undefined;
  assert.equal(details?.code, 'TABLE_NOT_LIVE');
});

test('endTableEarly: sets status to "happened" once the Table is confirmed', async () => {
  const hostUid = 'itest-tbl-endearly2-host';
  await seedUserProfile(hostUid);
  const hostToken = await getIdTokenForUid(hostUid, '+911234510020');

  const created = await callCallable<{tableId: string}>('createTable', baseTablePayload(), hostToken);
  const tableId = created.body.result!.tableId;

  // No callable moves a Table to "confirmed" directly (that's the scheduled
  // sweep, docs/ARCHITECTURE.md §5.3, out of F4's scope) — set it directly
  // via the Admin SDK, the same bypass every real trigger uses.
  const db = getFirestore();
  await db.doc(`tables/${tableId}`).update({status: 'confirmed'});

  const res = await callCallable<{success: boolean}>('endTableEarly', {tableId}, hostToken);
  assert.equal(res.status, 200);

  const snap = await db.doc(`tables/${tableId}`).get();
  assert.equal(snap.data()!.status, 'happened');
});

test('updateTable: CANNOT_EDIT_AFTER_CONFIRMED blocks capacity/startTime changes once confirmed', async () => {
  const hostUid = 'itest-tbl-freeze-host';
  await seedUserProfile(hostUid);
  const hostToken = await getIdTokenForUid(hostUid, '+911234510021');

  const created = await callCallable<{tableId: string}>('createTable', baseTablePayload(), hostToken);
  const tableId = created.body.result!.tableId;

  const db = getFirestore();
  await db.doc(`tables/${tableId}`).update({status: 'confirmed'});

  const blocked = await callCallable(
      'updateTable', {tableId, patch: {capacity: {min: 2, max: 4}}}, hostToken,
  );
  assert.equal(blocked.status, 400);
  const details = blocked.body.error?.details as {code?: string} | undefined;
  assert.equal(details?.code, 'CANNOT_EDIT_AFTER_CONFIRMED');

  // Title is not subject to the freeze — should still succeed.
  const allowed = await callCallable<{success: boolean; updatedFields: string[]}>(
      'updateTable', {tableId, patch: {title: 'Renamed after confirmation'}}, hostToken,
  );
  assert.equal(allowed.status, 200);
  assert.deepEqual(allowed.body.result?.updatedFields, ['title']);
});
