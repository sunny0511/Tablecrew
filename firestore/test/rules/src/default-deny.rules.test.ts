import {after, before, describe, it} from 'node:test';
import {assertFails, RulesTestEnvironment} from '@firebase/rules-unit-testing';
import {doc, getDoc, setDoc} from 'firebase/firestore';
import {getTestEnv, teardownTestEnv} from './testEnv';

// Verifies the trailing `match /{document=**} { allow read, write: if false; }`
// catch-all in firestore.rules actually holds for every collection that is
// out of Milestone F1's scope (ratings, reports, venues, splitRequests, and
// the duressSignals/locationShares/crew-messages subcollections) - these get
// their own real rules and tests in the milestone that builds the feature
// that needs them (docs/IMPLEMENTATION_PLAN.md F6/F7), not here. This file
// is the regression test that a future milestone adding a real match block
// for one of these collections doesn't need to re-discover the catch-all
// was silently relied upon; it also guards against a future edit
// accidentally making the catch-all itself permissive.
describe('firestore.rules: default-deny catch-all for out-of-F1-scope collections', () => {
  let testEnv: RulesTestEnvironment;

  before(async () => {
    testEnv = await getTestEnv();
  });

  after(async () => {
    await teardownTestEnv();
  });

  it('denies reading a ratings document (Milestone F7 scope, not F1)', async () => {
    const alice = testEnv.authenticatedContext('alice').firestore();
    await assertFails(getDoc(doc(alice, 'ratings/rating-1')));
  });

  it('denies creating a reports document via a direct client write (reports allow only reporterId-scoped create in the eventual real rule, not yet implemented in F1)', async () => {
    const alice = testEnv.authenticatedContext('alice').firestore();
    await assertFails(setDoc(doc(alice, 'reports/report-1'), {reporterId: 'alice', targetType: 'user', targetId: 'bob'}));
  });

  it('denies reading a venues document (Milestone F6+ scope, not F1)', async () => {
    const anon = testEnv.unauthenticatedContext().firestore();
    await assertFails(getDoc(doc(anon, 'venues/venue-1')));
  });

  it('denies reading a splitRequests document (Phase 1 scope, out of Foundation entirely)', async () => {
    const alice = testEnv.authenticatedContext('alice').firestore();
    await assertFails(getDoc(doc(alice, 'splitRequests/split-1')));
  });
});
