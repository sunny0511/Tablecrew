/**
 * Real Firebase Emulator Suite integration tests for
 * functions/src/crews/index.ts's 4 callables. Same rationale and run
 * command as users.integration.test.ts / tables.integration.test.ts (see
 * those files' headers) — added Milestone F4 to cover exactly what
 * functions/test/crews/validation.test.ts's fake-Firestore unit tests
 * structurally cannot: real Firestore transactions enforcing the
 * admin-only permission checks and the memberIds/members map invariant.
 *
 * Run via:
 *   firebase emulators:exec --only auth,firestore,functions \
 *     --project tablecrew-dev "npm --prefix functions run test:integration"
 */

import assert from 'node:assert/strict';
import crypto from 'node:crypto';
import {test, before} from 'node:test';
import {getFirestore} from 'firebase-admin/firestore';
import {callCallable, ensureAdminApp, getIdTokenForUid, seedUserProfile} from './emulatorClient';

before(() => {
  ensureAdminApp();
});

test('createCrew: rejects an unauthenticated call', async () => {
  const res = await callCallable('createCrew', {name: 'Test Crew', idempotencyKey: crypto.randomUUID()});
  assert.equal(res.status, 401);
});

test('createCrew: creates the Crew with the caller as admin; idempotent on retry', async () => {
  const uid = 'itest-crew-create';
  await seedUserProfile(uid, {displayName: 'Crew Creator'});
  const idToken = await getIdTokenForUid(uid, '+911234520001');
  const payload = {name: 'Sunday Hike Crew', idempotencyKey: crypto.randomUUID()};

  const first = await callCallable<{crewId: string}>('createCrew', payload, idToken);
  assert.equal(first.status, 200);

  const db = getFirestore();
  const snap = await db.doc(`crews/${first.body.result?.crewId}`).get();
  assert.equal(snap.exists, true);
  assert.equal(snap.data()!.creatorId, uid);
  assert.deepEqual(snap.data()!.memberIds, [uid]);
  assert.equal(snap.data()!.members[uid].role, 'admin');
  assert.equal(snap.data()!.members[uid].displayNameSnapshot, 'Crew Creator');

  const second = await callCallable<{crewId: string}>('createCrew', payload, idToken);
  assert.equal(second.status, 200);
  assert.equal(second.body.result?.crewId, first.body.result?.crewId);
});

test('createCrew: initialMemberIds are added immediately as members', async () => {
  const adminUid = 'itest-crew-initadmin';
  const memberUid = 'itest-crew-initmember';
  await seedUserProfile(adminUid);
  await seedUserProfile(memberUid, {displayName: 'Initial Member'});
  const idToken = await getIdTokenForUid(adminUid, '+911234520002');

  const res = await callCallable<{crewId: string}>('createCrew', {
    name: 'Book Club',
    initialMemberIds: [memberUid],
    idempotencyKey: crypto.randomUUID(),
  }, idToken);
  assert.equal(res.status, 200);

  const db = getFirestore();
  const snap = await db.doc(`crews/${res.body.result?.crewId}`).get();
  assert.ok(snap.data()!.memberIds.includes(memberUid));
  assert.equal(snap.data()!.members[memberUid].role, 'member');
});

test('updateCrew: admin can rename; a non-admin member is denied', async () => {
  const adminUid = 'itest-crew-upd-admin';
  const memberUid = 'itest-crew-upd-member';
  await seedUserProfile(adminUid);
  await seedUserProfile(memberUid);
  const adminToken = await getIdTokenForUid(adminUid, '+911234520003');
  const memberToken = await getIdTokenForUid(memberUid, '+911234520004');

  const created = await callCallable<{crewId: string}>('createCrew', {
    name: 'Original Name',
    initialMemberIds: [memberUid],
    idempotencyKey: crypto.randomUUID(),
  }, adminToken);
  const crewId = created.body.result!.crewId;

  const adminUpdate = await callCallable<{success: boolean; updatedFields: string[]}>(
      'updateCrew', {crewId, patch: {name: 'Renamed Crew'}}, adminToken,
  );
  assert.equal(adminUpdate.status, 200);
  assert.deepEqual(adminUpdate.body.result?.updatedFields, ['name']);

  const memberUpdate = await callCallable(
      'updateCrew', {crewId, patch: {name: 'Hijacked'}}, memberToken,
  );
  assert.equal(memberUpdate.status, 403);

  const db = getFirestore();
  const snap = await db.doc(`crews/${crewId}`).get();
  assert.equal(snap.data()!.name, 'Renamed Crew');
});

test('addMember: admin adds a new member; retry for an existing member is idempotent', async () => {
  const adminUid = 'itest-crew-add-admin';
  const targetUid = 'itest-crew-add-target';
  await seedUserProfile(adminUid);
  await seedUserProfile(targetUid, {displayName: 'New Member'});
  const adminToken = await getIdTokenForUid(adminUid, '+911234520005');

  const created = await callCallable<{crewId: string}>(
      'createCrew', {name: 'Add Member Crew', idempotencyKey: crypto.randomUUID()}, adminToken,
  );
  const crewId = created.body.result!.crewId;

  const first = await callCallable<{success: boolean; memberCount: number}>(
      'addMember', {crewId, targetUserId: targetUid}, adminToken,
  );
  assert.equal(first.status, 200);
  assert.equal(first.body.result?.memberCount, 2);

  const second = await callCallable<{success: boolean; memberCount: number}>(
      'addMember', {crewId, targetUserId: targetUid}, adminToken,
  );
  assert.equal(second.status, 200);
  assert.equal(second.body.result?.memberCount, 2, 'a repeat add of an existing member is a no-op');

  const db = getFirestore();
  const snap = await db.doc(`crews/${crewId}`).get();
  assert.equal(snap.data()!.members[targetUid].displayNameSnapshot, 'New Member');
});

test('addMember: a non-admin caller is denied', async () => {
  const adminUid = 'itest-crew-addperm-admin';
  const memberUid = 'itest-crew-addperm-member';
  const targetUid = 'itest-crew-addperm-target';
  await seedUserProfile(adminUid);
  await seedUserProfile(memberUid);
  await seedUserProfile(targetUid);
  const adminToken = await getIdTokenForUid(adminUid, '+911234520006');
  const memberToken = await getIdTokenForUid(memberUid, '+911234520007');

  const created = await callCallable<{crewId: string}>('createCrew', {
    name: 'Perm Test Crew',
    initialMemberIds: [memberUid],
    idempotencyKey: crypto.randomUUID(),
  }, adminToken);
  const crewId = created.body.result!.crewId;

  const res = await callCallable('addMember', {crewId, targetUserId: targetUid}, memberToken);
  assert.equal(res.status, 403);
});

test('addMember: inviteToken mode is not yet supported and throws not-found', async () => {
  const adminUid = 'itest-crew-invite-admin';
  await seedUserProfile(adminUid);
  const adminToken = await getIdTokenForUid(adminUid, '+911234520008');

  const created = await callCallable<{crewId: string}>(
      'createCrew', {name: 'Invite Test Crew', idempotencyKey: crypto.randomUUID()}, adminToken,
  );
  const crewId = created.body.result!.crewId;

  const res = await callCallable('addMember', {crewId, inviteToken: 'some-token'}, adminToken);
  assert.equal(res.status, 404);
  const details = res.body.error?.details as {code?: string} | undefined;
  assert.equal(details?.code, 'INVITE_TOKEN_NOT_SUPPORTED');
});

test('removeMember: admin removes another member', async () => {
  const adminUid = 'itest-crew-rm-admin';
  const memberUid = 'itest-crew-rm-member';
  await seedUserProfile(adminUid);
  await seedUserProfile(memberUid);
  const adminToken = await getIdTokenForUid(adminUid, '+911234520009');

  const created = await callCallable<{crewId: string}>('createCrew', {
    name: 'Remove Test Crew',
    initialMemberIds: [memberUid],
    idempotencyKey: crypto.randomUUID(),
  }, adminToken);
  const crewId = created.body.result!.crewId;

  const res = await callCallable<{success: boolean}>(
      'removeMember', {crewId, targetUserId: memberUid}, adminToken,
  );
  assert.equal(res.status, 200);

  const db = getFirestore();
  const snap = await db.doc(`crews/${crewId}`).get();
  assert.ok(!snap.data()!.memberIds.includes(memberUid));
  assert.equal(snap.data()!.members[memberUid], undefined);
});

test('removeMember: SELF_REMOVE_NOT_ALLOWED when targetUserId equals the caller', async () => {
  const adminUid = 'itest-crew-selfremove';
  await seedUserProfile(adminUid);
  const adminToken = await getIdTokenForUid(adminUid, '+911234520010');

  const created = await callCallable<{crewId: string}>(
      'createCrew', {name: 'Self Remove Crew', idempotencyKey: crypto.randomUUID()}, adminToken,
  );
  const crewId = created.body.result!.crewId;

  const res = await callCallable('removeMember', {crewId, targetUserId: adminUid}, adminToken);
  assert.equal(res.status, 400);
  const details = res.body.error?.details as {code?: string} | undefined;
  assert.equal(details?.code, 'SELF_REMOVE_NOT_ALLOWED');
});

test('leaveCrew (removeMember with targetUserId omitted): a member can remove themselves', async () => {
  const adminUid = 'itest-crew-leave-admin';
  const memberUid = 'itest-crew-leave-member';
  await seedUserProfile(adminUid);
  await seedUserProfile(memberUid);
  const adminToken = await getIdTokenForUid(adminUid, '+911234520011');
  const memberToken = await getIdTokenForUid(memberUid, '+911234520012');

  const created = await callCallable<{crewId: string}>('createCrew', {
    name: 'Leave Test Crew',
    initialMemberIds: [memberUid],
    idempotencyKey: crypto.randomUUID(),
  }, adminToken);
  const crewId = created.body.result!.crewId;

  const res = await callCallable<{success: boolean}>('leaveCrew', {crewId}, memberToken);
  assert.equal(res.status, 200);

  const db = getFirestore();
  const snap = await db.doc(`crews/${crewId}`).get();
  assert.ok(!snap.data()!.memberIds.includes(memberUid));
});
