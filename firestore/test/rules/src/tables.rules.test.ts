import {after, before, beforeEach, describe, it} from 'node:test';
import {assertFails, assertSucceeds, RulesTestEnvironment} from '@firebase/rules-unit-testing';
import {doc, deleteDoc, getDoc, setDoc, updateDoc} from 'firebase/firestore';
import {getTestEnv, teardownTestEnv} from './testEnv';
import {buildRsvpFixture, buildTableFixture} from './fixtures';

// Covers docs/DATABASE.md §3.2/§3.3 / §6: tables/{tableId} and the
// tables/{tableId}/rsvps/{userId} subcollection, per docs/TESTING.md's
// "100% of rules paths, positive and negative case" requirement.
describe('firestore.rules: tables/{tableId} and rsvps subcollection', () => {
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
      await setDoc(doc(db, 'tables/closed-table'), buildTableFixture({hostId: 'alice', visibility: 'closed'}));
      await setDoc(doc(db, 'tables/open-table'), buildTableFixture({hostId: 'alice', visibility: 'open'}));
      await setDoc(doc(db, 'tables/closed-table/rsvps/bob'), buildRsvpFixture({userId: 'bob'}));
    });
  });

  describe('read', () => {
    it('allows an unauthenticated user to read an open table', async () => {
      const anon = testEnv.unauthenticatedContext().firestore();
      await assertSucceeds(getDoc(doc(anon, 'tables/open-table')));
    });

    it('allows the host to read their own closed table', async () => {
      const alice = testEnv.authenticatedContext('alice').firestore();
      await assertSucceeds(getDoc(doc(alice, 'tables/closed-table')));
    });

    it('allows a user with an rsvp to read a closed table', async () => {
      const bob = testEnv.authenticatedContext('bob').firestore();
      await assertSucceeds(getDoc(doc(bob, 'tables/closed-table')));
    });

    it('denies a signed-in user with no rsvp and no host relationship from reading a closed table', async () => {
      const carol = testEnv.authenticatedContext('carol').firestore();
      await assertFails(getDoc(doc(carol, 'tables/closed-table')));
    });

    it('denies an unauthenticated user from reading a closed table', async () => {
      const anon = testEnv.unauthenticatedContext().firestore();
      await assertFails(getDoc(doc(anon, 'tables/closed-table')));
    });
  });

  describe('create', () => {
    it('allows a signed-in user to create a table they host', async () => {
      const alice = testEnv.authenticatedContext('alice').firestore();
      await assertSucceeds(setDoc(doc(alice, 'tables/new-table'), buildTableFixture({hostId: 'alice'})));
    });

    it('denies a user creating a table hosted by someone else', async () => {
      const bob = testEnv.authenticatedContext('bob').firestore();
      await assertFails(setDoc(doc(bob, 'tables/new-table'), buildTableFixture({hostId: 'alice'})));
    });
  });

  describe('update', () => {
    it('allows the host to update a benign field', async () => {
      const alice = testEnv.authenticatedContext('alice').firestore();
      await assertSucceeds(updateDoc(doc(alice, 'tables/closed-table'), {title: 'New Title'}));
    });

    it('denies a non-host from updating the table', async () => {
      const bob = testEnv.authenticatedContext('bob').firestore();
      await assertFails(updateDoc(doc(bob, 'tables/closed-table'), {title: 'Hacked'}));
    });

    it('denies the host writing capacity directly', async () => {
      const alice = testEnv.authenticatedContext('alice').firestore();
      await assertFails(updateDoc(doc(alice, 'tables/closed-table'), {'capacity.confirmedCount': 99}));
    });

    it('denies the host writing reportFlags directly', async () => {
      // Fixture defaults reportFlags.isSuppressed to false - assert against
      // `true` (a genuine value change), not `false` (a no-op write that
      // Firestore's diff() correctly wouldn't flag as an affected key, which
      // would make this test pass even with a broken rule).
      const alice = testEnv.authenticatedContext('alice').firestore();
      await assertFails(updateDoc(doc(alice, 'tables/closed-table'), {'reportFlags.isSuppressed': true}));
    });
  });

  describe('delete', () => {
    it('denies the host deleting a table directly', async () => {
      const alice = testEnv.authenticatedContext('alice').firestore();
      await assertFails(deleteDoc(doc(alice, 'tables/closed-table')));
    });
  });

  describe('rsvps subcollection: read', () => {
    it('allows a user to read their own rsvp', async () => {
      const bob = testEnv.authenticatedContext('bob').firestore();
      await assertSucceeds(getDoc(doc(bob, 'tables/closed-table/rsvps/bob')));
    });

    it('allows the table host to read any attendee\'s rsvp', async () => {
      const alice = testEnv.authenticatedContext('alice').firestore();
      await assertSucceeds(getDoc(doc(alice, 'tables/closed-table/rsvps/bob')));
    });

    it('denies a different non-host user from reading someone else\'s rsvp', async () => {
      const carol = testEnv.authenticatedContext('carol').firestore();
      await assertFails(getDoc(doc(carol, 'tables/closed-table/rsvps/bob')));
    });
  });

  describe('rsvps subcollection: write', () => {
    it('denies a user creating their own rsvp document directly', async () => {
      const carol = testEnv.authenticatedContext('carol').firestore();
      await assertFails(setDoc(doc(carol, 'tables/closed-table/rsvps/carol'), buildRsvpFixture({userId: 'carol'})));
    });

    it('denies a user updating their own rsvp document directly', async () => {
      const bob = testEnv.authenticatedContext('bob').firestore();
      await assertFails(updateDoc(doc(bob, 'tables/closed-table/rsvps/bob'), {status: 'declined'}));
    });

    it('denies the host updating an attendee\'s rsvp document directly', async () => {
      const alice = testEnv.authenticatedContext('alice').firestore();
      await assertFails(updateDoc(doc(alice, 'tables/closed-table/rsvps/bob'), {status: 'confirmed'}));
    });
  });
});
