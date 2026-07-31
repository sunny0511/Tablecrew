import {after, before, beforeEach, describe, it} from 'node:test';
import {assertFails, assertSucceeds, RulesTestEnvironment} from '@firebase/rules-unit-testing';
import {doc, deleteDoc, getDoc, setDoc, updateDoc} from 'firebase/firestore';
import {getTestEnv, teardownTestEnv} from './testEnv';
import {buildCrewFixture} from './fixtures';

// Covers docs/DATABASE.md §3.4 / §6: crews/{crewId}, per docs/TESTING.md's
// "100% of rules paths, positive and negative case" requirement. Crew
// creation and membership mutation are Functions-only (createCrew/
// addMember/removeMember land in Milestone F4) - this file verifies rules
// deny those paths to a direct client write today, and allow the narrower
// direct-edit surface (name/photo/recurrence) docs/DATABASE.md §6 grants.
describe('firestore.rules: crews/{crewId}', () => {
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
      await setDoc(doc(db, 'crews/crew-1'), buildCrewFixture({memberIds: ['alice', 'bob']}));
    });
  });

  describe('read', () => {
    it('allows a member to read the crew document', async () => {
      const alice = testEnv.authenticatedContext('alice').firestore();
      await assertSucceeds(getDoc(doc(alice, 'crews/crew-1')));
    });

    it('denies a non-member from reading the crew document', async () => {
      const carol = testEnv.authenticatedContext('carol').firestore();
      await assertFails(getDoc(doc(carol, 'crews/crew-1')));
    });
  });

  describe('create', () => {
    it('denies a signed-in user creating a crew document directly', async () => {
      const alice = testEnv.authenticatedContext('alice').firestore();
      await assertFails(setDoc(doc(alice, 'crews/new-crew'), buildCrewFixture({creatorId: 'alice', memberIds: ['alice']})));
    });
  });

  describe('update', () => {
    it('allows a member to update the crew\'s name', async () => {
      const alice = testEnv.authenticatedContext('alice').firestore();
      await assertSucceeds(updateDoc(doc(alice, 'crews/crew-1'), {name: 'Renamed Crew'}));
    });

    it('denies a non-member from updating the crew document', async () => {
      const carol = testEnv.authenticatedContext('carol').firestore();
      await assertFails(updateDoc(doc(carol, 'crews/crew-1'), {name: 'Hijacked'}));
    });

    it('denies a member writing memberIds directly', async () => {
      const alice = testEnv.authenticatedContext('alice').firestore();
      await assertFails(updateDoc(doc(alice, 'crews/crew-1'), {memberIds: ['alice', 'bob', 'carol']}));
    });

    it('denies a member writing the members snapshot map directly', async () => {
      const alice = testEnv.authenticatedContext('alice').firestore();
      await assertFails(updateDoc(doc(alice, 'crews/crew-1'), {'members.carol': {displayNameSnapshot: 'Carol', photoUrlSnapshot: null, role: 'member', joinedAt: Date.now()}}));
    });

    it('denies a member writing tableHistoryCount directly', async () => {
      const alice = testEnv.authenticatedContext('alice').firestore();
      await assertFails(updateDoc(doc(alice, 'crews/crew-1'), {tableHistoryCount: 99}));
    });
  });

  describe('delete', () => {
    it('denies a member deleting the crew document directly', async () => {
      const alice = testEnv.authenticatedContext('alice').firestore();
      await assertFails(deleteDoc(doc(alice, 'crews/crew-1')));
    });
  });
});
