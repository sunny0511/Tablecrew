import {after, before, beforeEach, describe, it} from 'node:test';
import {assertFails, RulesTestEnvironment} from '@firebase/rules-unit-testing';
import {deleteDoc, doc, getDoc, setDoc, updateDoc} from 'firebase/firestore';
import {getTestEnv, teardownTestEnv} from './testEnv';
import {buildDuressSignalFixture, buildReportFixture, buildTableFixture} from './fixtures';

// Covers docs/DATABASE.md §3.3a/§3.6/§6 (Milestone F6): reports/{reportId}
// and tables/{tableId}/duressSignals/{userId} — both structurally
// Functions-only, per docs/TESTING.md's "100% of rules paths, positive and
// negative case" requirement. There is no positive case for either
// collection: every actor, including the reporter/triggering user
// themselves, is denied every operation, since all real writes go through
// functions/src/trust/index.ts via the Admin SDK, which bypasses these rules
// entirely.
describe('firestore.rules: reports and duressSignals (Trust & Safety, Milestone F6)', () => {
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
      await setDoc(doc(db, 'reports/report-1'), buildReportFixture({reporterId: 'alice', targetId: 'bob'}));
      await setDoc(
          doc(db, 'tables/closed-table/duressSignals/alice'),
          buildDuressSignalFixture(),
      );
    });
  });

  describe('reports/{reportId}', () => {
    it('denies the reporter reading their own report', async () => {
      const alice = testEnv.authenticatedContext('alice').firestore();
      await assertFails(getDoc(doc(alice, 'reports/report-1')));
    });

    it('denies the reported party reading the report against them', async () => {
      const bob = testEnv.authenticatedContext('bob').firestore();
      await assertFails(getDoc(doc(bob, 'reports/report-1')));
    });

    it('denies an unrelated signed-in user reading a report', async () => {
      const carol = testEnv.authenticatedContext('carol').firestore();
      await assertFails(getDoc(doc(carol, 'reports/report-1')));
    });

    it('denies a signed-in user creating a report directly (Functions-only: reportUser/reportTable)', async () => {
      const alice = testEnv.authenticatedContext('alice').firestore();
      await assertFails(setDoc(doc(alice, 'reports/new-report'), buildReportFixture({reporterId: 'alice'})));
    });

    it('denies the reporter updating their own report directly', async () => {
      const alice = testEnv.authenticatedContext('alice').firestore();
      await assertFails(updateDoc(doc(alice, 'reports/report-1'), {status: 'resolved_no_action'}));
    });

    it('denies deleting a report directly', async () => {
      const alice = testEnv.authenticatedContext('alice').firestore();
      await assertFails(deleteDoc(doc(alice, 'reports/report-1')));
    });
  });

  describe('tables/{tableId}/duressSignals/{userId}', () => {
    it('denies the triggering user reading their own duress signal', async () => {
      const alice = testEnv.authenticatedContext('alice').firestore();
      await assertFails(getDoc(doc(alice, 'tables/closed-table/duressSignals/alice')));
    });

    it('denies the table host reading an attendee\'s duress signal', async () => {
      const alice = testEnv.authenticatedContext('alice').firestore();
      await assertFails(getDoc(doc(alice, 'tables/closed-table/duressSignals/alice')));
    });

    it('denies a signed-in user creating a duress signal directly (Functions-only: triggerDuressSignal)', async () => {
      const bob = testEnv.authenticatedContext('bob').firestore();
      await assertFails(setDoc(doc(bob, 'tables/closed-table/duressSignals/bob'), buildDuressSignalFixture()));
    });

    it('denies updating a duress signal directly', async () => {
      const alice = testEnv.authenticatedContext('alice').firestore();
      await assertFails(updateDoc(doc(alice, 'tables/closed-table/duressSignals/alice'), {status: 'acknowledged'}));
    });
  });
});
