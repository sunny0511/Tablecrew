import {after, before, beforeEach, describe, it} from 'node:test';
import {assertFails, assertSucceeds, RulesTestEnvironment} from '@firebase/rules-unit-testing';
import {
  collection,
  deleteDoc,
  doc,
  getDoc,
  getDocs,
  query,
  setDoc,
  updateDoc,
  where,
} from 'firebase/firestore';
import {getTestEnv, teardownTestEnv} from './testEnv';
import {buildIdentityVerificationFixture} from './fixtures';

// Covers docs/DATABASE.md §3.10/§6 (Milestone F7, ADR 0007): manual Tier 2
// identity verification. Unlike reports/duressSignals — which have no
// positive case at all — this collection has exactly one: the submitting
// user reading the single submission whose id they were just handed, which
// is what Screen 8's status listener does.
//
// The list-denial tests below are the ones worth reading carefully. They are
// not redundant with the get tests: Firestore evaluates a list() against the
// *query*, not against the documents it would return, so `allow get` and
// `allow list` are genuinely separate grants and a rule written as `allow
// read` would silently grant both. A test suite that only exercised get
// would pass identically against the wrong rule.
describe('firestore.rules: identityVerifications (manual Tier 2, Milestone F7)', () => {
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
      await setDoc(
          doc(db, 'identityVerifications/submission-alice'),
          buildIdentityVerificationFixture({userId: 'alice'}),
      );
      await setDoc(
          doc(db, 'identityVerifications/submission-bob'),
          buildIdentityVerificationFixture({
            userId: 'bob',
            idDocumentPath: 'identity-verifications/bob/id-1',
            selfiePath: 'identity-verifications/bob/selfie-1',
          }),
      );
    });
  });

  describe('reads', () => {
    it('allows the submitting user to get their own submission', async () => {
      const alice = testEnv.authenticatedContext('alice').firestore();
      await assertSucceeds(getDoc(doc(alice, 'identityVerifications/submission-alice')));
    });

    it("denies a user getting another user's submission", async () => {
      const alice = testEnv.authenticatedContext('alice').firestore();
      await assertFails(getDoc(doc(alice, 'identityVerifications/submission-bob')));
    });

    it('denies an unauthenticated get', async () => {
      const anon = testEnv.unauthenticatedContext().firestore();
      await assertFails(getDoc(doc(anon, 'identityVerifications/submission-alice')));
    });

    it('denies listing the collection even when filtered to your own uid', async () => {
      // The narrow case: this query returns only documents the caller is
      // allowed to get(), so it would succeed under `allow read`. It must
      // still fail, because the review queue is deliberately not
      // enumerable by any client — see the rule's own comment.
      const alice = testEnv.authenticatedContext('alice').firestore();
      await assertFails(getDocs(query(
          collection(alice, 'identityVerifications'),
          where('userId', '==', 'alice'),
      )));
    });

    it('denies an unfiltered list of the collection', async () => {
      const alice = testEnv.authenticatedContext('alice').firestore();
      await assertFails(getDocs(collection(alice, 'identityVerifications')));
    });
  });

  describe('writes — every one of them Functions-only', () => {
    it('denies a user creating their own submission directly', async () => {
      // The bypass this blocks: creating a submission client-side skips the
      // rate limit, the one-open-submission precondition, and the check
      // that the referenced Storage objects actually exist.
      const alice = testEnv.authenticatedContext('alice').firestore();
      await assertFails(setDoc(
          doc(alice, 'identityVerifications/forged'),
          buildIdentityVerificationFixture({userId: 'alice'}),
      ));
    });

    it('denies a user updating their own submission to approved', async () => {
      // The bypass this blocks is the serious one: a client that could
      // write status here would grant itself Discover access, which is
      // exactly the self-elevation docs/SECURITY.md forbids.
      const alice = testEnv.authenticatedContext('alice').firestore();
      await assertFails(updateDoc(
          doc(alice, 'identityVerifications/submission-alice'),
          {status: 'approved', dobMatchesId: true},
      ));
    });

    it('denies a user deleting their own submission', async () => {
      // Deletion would let a user destroy the audit record of a rejection
      // and resubmit as if new.
      const alice = testEnv.authenticatedContext('alice').firestore();
      await assertFails(deleteDoc(doc(alice, 'identityVerifications/submission-alice')));
    });

    it("denies a user writing to another user's submission", async () => {
      const alice = testEnv.authenticatedContext('alice').firestore();
      await assertFails(updateDoc(
          doc(alice, 'identityVerifications/submission-bob'),
          {status: 'rejected'},
      ));
    });
  });
});
