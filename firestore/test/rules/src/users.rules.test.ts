import {after, before, beforeEach, describe, it} from 'node:test';
import {assertFails, assertSucceeds, RulesTestEnvironment} from '@firebase/rules-unit-testing';
import {deleteDoc, doc, getDoc, setDoc, updateDoc} from 'firebase/firestore';
import {getTestEnv, teardownTestEnv} from './testEnv';
import {buildUserPrivateProfileFixture, buildUserPublicFixture} from './fixtures';

// Covers docs/DATABASE.md §3.1 / §6: users/{userId} (public) and
// users/{userId}/private/profile (owner-only), per docs/TESTING.md's
// "100% of rules paths, positive and negative case" requirement.
describe('firestore.rules: users/{userId} and private/profile', () => {
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
      await setDoc(doc(db, 'users/alice'), buildUserPublicFixture());
      await setDoc(doc(db, 'users/alice/private/profile'), buildUserPrivateProfileFixture());
    });
  });

  describe('public document: read', () => {
    it('allows any signed-in user to read another user\'s public profile', async () => {
      const bob = testEnv.authenticatedContext('bob').firestore();
      await assertSucceeds(getDoc(doc(bob, 'users/alice')));
    });

    it('denies an unauthenticated user from reading a public profile', async () => {
      const anon = testEnv.unauthenticatedContext().firestore();
      await assertFails(getDoc(doc(anon, 'users/alice')));
    });
  });

  describe('public document: create', () => {
    it('allows a user to create their own public profile document', async () => {
      const bob = testEnv.authenticatedContext('bob').firestore();
      await assertSucceeds(setDoc(doc(bob, 'users/bob'), buildUserPublicFixture()));
    });

    it('denies a user creating a public profile document for someone else', async () => {
      const bob = testEnv.authenticatedContext('bob').firestore();
      await assertFails(setDoc(doc(bob, 'users/carol'), buildUserPublicFixture()));
    });
  });

  describe('public document: update', () => {
    it('allows the owner to update their own display name', async () => {
      const alice = testEnv.authenticatedContext('alice').firestore();
      await assertSucceeds(updateDoc(doc(alice, 'users/alice'), {displayName: 'Alice Updated'}));
    });

    it('denies a non-owner from updating another user\'s public profile', async () => {
      const bob = testEnv.authenticatedContext('bob').firestore();
      await assertFails(updateDoc(doc(bob, 'users/alice'), {displayName: 'Hacked'}));
    });

    it('denies the owner self-elevating their own verificationTierPublic', async () => {
      const alice = testEnv.authenticatedContext('alice').firestore();
      await assertFails(updateDoc(doc(alice, 'users/alice'), {verificationTierPublic: 'id_verified'}));
    });

    it('denies the owner writing their own ratingAggregate', async () => {
      const alice = testEnv.authenticatedContext('alice').firestore();
      await assertFails(updateDoc(doc(alice, 'users/alice'), {
        ratingAggregate: {averageAsHost: 5, averageAsAttendee: null, ratingCountAsHost: 1, ratingCountAsAttendee: 0},
      }));
    });

    it('denies the owner clearing their own deletedAt tombstone', async () => {
      const alice = testEnv.authenticatedContext('alice').firestore();
      await assertFails(updateDoc(doc(alice, 'users/alice'), {deletedAt: null}));
    });
  });

  describe('public document: delete', () => {
    it('denies the owner deleting their own public profile directly', async () => {
      const alice = testEnv.authenticatedContext('alice').firestore();
      await assertFails(deleteDoc(doc(alice, 'users/alice')));
    });
  });

  describe('private/profile: read', () => {
    it('allows the owner to read their own private profile', async () => {
      const alice = testEnv.authenticatedContext('alice').firestore();
      await assertSucceeds(getDoc(doc(alice, 'users/alice/private/profile')));
    });

    it('denies another user reading someone else\'s private profile', async () => {
      const bob = testEnv.authenticatedContext('bob').firestore();
      await assertFails(getDoc(doc(bob, 'users/alice/private/profile')));
    });
  });

  describe('private/profile: create', () => {
    it('allows a user to create their own private profile document', async () => {
      const bob = testEnv.authenticatedContext('bob').firestore();
      await assertSucceeds(setDoc(doc(bob, 'users/bob/private/profile'), buildUserPrivateProfileFixture()));
    });

    it('denies a user creating a private profile document for someone else', async () => {
      const bob = testEnv.authenticatedContext('bob').firestore();
      await assertFails(setDoc(doc(bob, 'users/carol/private/profile'), buildUserPrivateProfileFixture()));
    });
  });

  describe('private/profile: update', () => {
    it('allows the owner to update their own notificationPrefs', async () => {
      const alice = testEnv.authenticatedContext('alice').firestore();
      await assertSucceeds(updateDoc(doc(alice, 'users/alice/private/profile'), {
        'notificationPrefs.mutedCrewIds': ['crew-1'],
      }));
    });

    it('denies a non-owner updating someone else\'s private profile', async () => {
      const bob = testEnv.authenticatedContext('bob').firestore();
      await assertFails(updateDoc(doc(bob, 'users/alice/private/profile'), {
        'notificationPrefs.mutedCrewIds': ['crew-1'],
      }));
    });

    it('denies the owner writing their own trustSignals directly', async () => {
      const alice = testEnv.authenticatedContext('alice').firestore();
      await assertFails(updateDoc(doc(alice, 'users/alice/private/profile'), {
        trustSignals: {reportCount: 0, noShowCount: 0, substantiatedBillingDisputeCount: 0, standingStatus: 'restricted'},
      }));
    });

    it('denies the owner writing their own blockedUserIds directly', async () => {
      const alice = testEnv.authenticatedContext('alice').firestore();
      await assertFails(updateDoc(doc(alice, 'users/alice/private/profile'), {blockedUserIds: ['bob']}));
    });

    it('denies the owner writing their own subscription state directly', async () => {
      const alice = testEnv.authenticatedContext('alice').firestore();
      await assertFails(updateDoc(doc(alice, 'users/alice/private/profile'), {
        'subscription.tier': 'tablecrew_plus',
      }));
    });
  });

  describe('private/profile: delete', () => {
    it('denies the owner deleting their own private profile directly', async () => {
      const alice = testEnv.authenticatedContext('alice').firestore();
      await assertFails(deleteDoc(doc(alice, 'users/alice/private/profile')));
    });
  });
});
