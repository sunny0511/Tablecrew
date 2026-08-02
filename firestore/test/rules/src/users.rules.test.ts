import {after, before, beforeEach, describe, it} from 'node:test';
import {assertFails, assertSucceeds, RulesTestEnvironment} from '@firebase/rules-unit-testing';
import {deleteDoc, doc, getDoc, setDoc, updateDoc} from 'firebase/firestore';
import {getTestEnv, teardownTestEnv} from './testEnv';
import {
  buildPhotoModerationFixture,
  buildUserPrivateProfileFixture,
  buildUserPublicFixture,
} from './fixtures';

// Covers docs/DATABASE.md §3.1 / §3.1a / §6: users/{userId} (public),
// users/{userId}/private/profile (owner-only), and
// users/{userId}/photoModeration/{uploadId} (owner-read, Functions-only
// write - Milestone F5 task #97), per docs/TESTING.md's "100% of rules
// paths, positive and negative case" requirement.
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
      await setDoc(doc(db, 'users/alice/photoModeration/upload-1'), buildPhotoModerationFixture());
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
    // Milestone F2: direct client create is now denied for everyone,
    // including the document's own owner - account creation is exclusively
    // via the completeAccountSetup callable (functions/src/users/), which
    // is what makes the server-side 18+ age gate actually enforceable (a
    // rule can't reject a create() based on computed age; a callable can).
    // See docs/DATABASE.md §6 for the full before/after rationale.
    it('denies a user creating their own public profile document directly', async () => {
      const bob = testEnv.authenticatedContext('bob').firestore();
      await assertFails(setDoc(doc(bob, 'users/bob'), buildUserPublicFixture()));
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
      // Fixture defaults deletedAt to null, so first seed a genuinely
      // non-null tombstone (simulating an already-soft-deleted account) via
      // the rules bypass - asserting against a real value change, not a
      // null-to-null no-op Firestore's diff() wouldn't flag as affected.
      await testEnv.withSecurityRulesDisabled(async (context) => {
        await updateDoc(doc(context.firestore(), 'users/alice'), {deletedAt: Date.now()});
      });
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
    // Same Milestone F2 correction as the public document above - exclusively
    // created by completeAccountSetup now, never a direct client create.
    it('denies a user creating their own private profile document directly', async () => {
      const bob = testEnv.authenticatedContext('bob').firestore();
      await assertFails(setDoc(doc(bob, 'users/bob/private/profile'), buildUserPrivateProfileFixture()));
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

    it('denies the owner writing their own dateOfBirth directly', async () => {
      // Milestone F2: dateOfBirth gates a safety/legal requirement (the 18+
      // age gate) and must not be editable by the account it belongs to
      // once set at completeAccountSetup time, same reasoning as
      // `verification`. Fixture's dateOfBirth is fixed; asserting a
      // genuinely different value.
      const alice = testEnv.authenticatedContext('alice').firestore();
      await assertFails(updateDoc(doc(alice, 'users/alice/private/profile'), {dateOfBirth: '1990-01-01'}));
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

  // Milestone F5 task #97, docs/DATABASE.md §3.1a: the moderation-verdict
  // document Screen 5 (Profile Setup) listens to. Owner-read only; every
  // write is Functions/Admin-SDK-only - a client that could write its own
  // verdict could self-approve a photo the SafeSearch check flagged.
  describe('photoModeration: read', () => {
    it('allows the owner to read their own upload\'s moderation verdict', async () => {
      const alice = testEnv.authenticatedContext('alice').firestore();
      await assertSucceeds(getDoc(doc(alice, 'users/alice/photoModeration/upload-1')));
    });

    it('denies another user reading someone else\'s moderation verdict', async () => {
      const bob = testEnv.authenticatedContext('bob').firestore();
      await assertFails(getDoc(doc(bob, 'users/alice/photoModeration/upload-1')));
    });

    it('denies an unauthenticated user reading a moderation verdict', async () => {
      const anon = testEnv.unauthenticatedContext().firestore();
      await assertFails(getDoc(doc(anon, 'users/alice/photoModeration/upload-1')));
    });
  });

  describe('photoModeration: write', () => {
    it('denies the owner creating a moderation verdict for their own upload', async () => {
      const alice = testEnv.authenticatedContext('alice').firestore();
      await assertFails(setDoc(
          doc(alice, 'users/alice/photoModeration/upload-2'),
          buildPhotoModerationFixture(),
      ));
    });

    it('denies the owner self-approving a flagged upload', async () => {
      // The exact escalation the write: false rule exists to block - first
      // seed a genuinely flagged verdict via the rules bypass, then attempt
      // the owner flipping it to approved.
      await testEnv.withSecurityRulesDisabled(async (context) => {
        await setDoc(
            doc(context.firestore(), 'users/alice/photoModeration/upload-3'),
            buildPhotoModerationFixture({
              status: 'flagged',
              approvedUrl: null,
              flagReason: 'adult:VERY_LIKELY',
            }),
        );
      });
      const alice = testEnv.authenticatedContext('alice').firestore();
      await assertFails(updateDoc(doc(alice, 'users/alice/photoModeration/upload-3'), {
        status: 'approved',
        approvedUrl: 'https://example.com/self-approved.jpg',
      }));
    });

    it('denies the owner deleting their own moderation verdict', async () => {
      const alice = testEnv.authenticatedContext('alice').firestore();
      await assertFails(deleteDoc(doc(alice, 'users/alice/photoModeration/upload-1')));
    });
  });
});
