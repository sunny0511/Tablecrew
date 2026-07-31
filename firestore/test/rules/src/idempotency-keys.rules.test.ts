import {after, before, beforeEach, describe, it} from 'node:test';
import {assertFails, RulesTestEnvironment} from '@firebase/rules-unit-testing';
import {doc, deleteDoc, getDoc, setDoc, updateDoc} from 'firebase/firestore';
import {getTestEnv, teardownTestEnv} from './testEnv';
import {buildIdempotencyKeyFixture} from './fixtures';

// Covers docs/DATABASE.md §3.9 / §6: idempotencyKeys/{idempotencyKey} - a
// collection purely internal to Cloud Functions (the create()-then-check-
// status pattern described there). There is no positive case for this
// collection by design: every operation is denied for every client role,
// including the key's own owning uid, since only the Admin SDK ever
// touches it.
describe('firestore.rules: idempotencyKeys/{idempotencyKey}', () => {
  let testEnv: RulesTestEnvironment;

  before(async () => {
    testEnv = await getTestEnv();
  });

  after(async () => {
    await teardownTestEnv();
  });

  beforeEach(async () => {
    await testEnv.clearFirestore();
    await testEnv.withSecurityRulesDisabled(async (context) => {
      const db = context.firestore();
      await setDoc(doc(db, 'idempotencyKeys/key-1'), buildIdempotencyKeyFixture({uid: 'alice'}));
    });
  });

  it('denies the owning user reading their own idempotency key document', async () => {
    const alice = testEnv.authenticatedContext('alice').firestore();
    await assertFails(getDoc(doc(alice, 'idempotencyKeys/key-1')));
  });

  it('denies the owning user creating an idempotency key document directly', async () => {
    const alice = testEnv.authenticatedContext('alice').firestore();
    await assertFails(setDoc(doc(alice, 'idempotencyKeys/key-2'), buildIdempotencyKeyFixture({uid: 'alice'})));
  });

  it('denies the owning user updating their own idempotency key document', async () => {
    const alice = testEnv.authenticatedContext('alice').firestore();
    await assertFails(updateDoc(doc(alice, 'idempotencyKeys/key-1'), {status: 'completed'}));
  });

  it('denies the owning user deleting their own idempotency key document', async () => {
    const alice = testEnv.authenticatedContext('alice').firestore();
    await assertFails(deleteDoc(doc(alice, 'idempotencyKeys/key-1')));
  });
});
