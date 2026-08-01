import assert from 'node:assert/strict';
import {test} from 'node:test';

import {
  checkAndIncrementRateLimit,
  RateLimitDocRef,
  RateLimitExceededError,
  RateLimitFirestore,
  RateLimitTransaction,
} from '../../src/shared/rateLimit';

/**
 * Minimal in-memory fake satisfying {@link RateLimitFirestore}, the same
 * pattern `idempotency.test.ts` established. `runTransaction` doesn't
 * simulate real optimistic-concurrency retries — there's no real
 * concurrency in a single-threaded unit test — so this exercises the
 * window/count logic itself (bucket increments, limit enforcement, a new
 * window starting a fresh count), not true transactional atomicity under
 * concurrent load, which is left to the Firebase Emulator Suite
 * integration tests (Milestone F4, functions/test/integration/).
 */
class FakeRateLimitFirestore implements RateLimitFirestore {
  private readonly docsByPath = new Map<string, Record<string, unknown>>();

  doc(path: string): RateLimitDocRef {
    return {path};
  }

  async runTransaction<T>(
      updateFunction: (tx: RateLimitTransaction) => Promise<T>,
  ): Promise<T> {
    const tx: RateLimitTransaction = {
      get: async (ref) => {
        const data = this.docsByPath.get(ref.path);
        return {exists: data !== undefined, data: () => data};
      },
      set: (ref, data) => {
        this.docsByPath.set(ref.path, {...data});
      },
    };
    return updateFunction(tx);
  }

  get(path: string): Record<string, unknown> | undefined {
    return this.docsByPath.get(path);
  }
}

test('checkAndIncrementRateLimit: first call under the limit succeeds and starts the count at 1', async () => {
  const db = new FakeRateLimitFirestore();

  await checkAndIncrementRateLimit(db, {
    uid: 'user-1',
    family: 'createTable',
    limit: 10,
    windowMs: 60_000,
  });

  const windowStartMs = Math.floor(Date.now() / 60_000) * 60_000;
  const bucket = db.get(`rateLimits/user-1_createTable_${windowStartMs}`);
  assert.equal(bucket?.count, 1);
});

test('checkAndIncrementRateLimit: repeated calls within the limit keep incrementing', async () => {
  const db = new FakeRateLimitFirestore();
  const params = {uid: 'user-1', family: 'requestSeat', limit: 3, windowMs: 60_000};

  await checkAndIncrementRateLimit(db, params);
  await checkAndIncrementRateLimit(db, params);
  await checkAndIncrementRateLimit(db, params);

  const windowStartMs = Math.floor(Date.now() / 60_000) * 60_000;
  const bucket = db.get(`rateLimits/user-1_requestSeat_${windowStartMs}`);
  assert.equal(bucket?.count, 3);
});

test('checkAndIncrementRateLimit: a call at the limit throws RateLimitExceededError and does not increment further', async () => {
  const db = new FakeRateLimitFirestore();
  const params = {uid: 'user-1', family: 'requestSeat', limit: 2, windowMs: 60_000};

  await checkAndIncrementRateLimit(db, params);
  await checkAndIncrementRateLimit(db, params);

  await assert.rejects(
      checkAndIncrementRateLimit(db, params),
      RateLimitExceededError,
  );

  const windowStartMs = Math.floor(Date.now() / 60_000) * 60_000;
  const bucket = db.get(`rateLimits/user-1_requestSeat_${windowStartMs}`);
  assert.equal(bucket?.count, 2, 'the rejected call must not have incremented the count');
});

test('checkAndIncrementRateLimit: different families for the same uid have independent budgets', async () => {
  const db = new FakeRateLimitFirestore();

  await checkAndIncrementRateLimit(db, {uid: 'user-1', family: 'tableMutation', limit: 1, windowMs: 60_000});

  // A different family for the same uid, same window, is a separate
  // bucket and should not be affected by tableMutation's exhausted budget.
  await checkAndIncrementRateLimit(db, {uid: 'user-1', family: 'crewMutation', limit: 1, windowMs: 60_000});

  const windowStartMs = Math.floor(Date.now() / 60_000) * 60_000;
  assert.equal(db.get(`rateLimits/user-1_tableMutation_${windowStartMs}`)?.count, 1);
  assert.equal(db.get(`rateLimits/user-1_crewMutation_${windowStartMs}`)?.count, 1);
});

test('checkAndIncrementRateLimit: different uids in the same family have independent budgets', async () => {
  const db = new FakeRateLimitFirestore();
  const shared = {family: 'createTable', limit: 1, windowMs: 60_000};

  await checkAndIncrementRateLimit(db, {uid: 'user-1', ...shared});

  // user-1 is now at its limit; user-2 must be unaffected.
  await checkAndIncrementRateLimit(db, {uid: 'user-2', ...shared});

  const windowStartMs = Math.floor(Date.now() / 60_000) * 60_000;
  assert.equal(db.get(`rateLimits/user-1_createTable_${windowStartMs}`)?.count, 1);
  assert.equal(db.get(`rateLimits/user-2_createTable_${windowStartMs}`)?.count, 1);
});

test('checkAndIncrementRateLimit: a pre-seeded bucket in an earlier window does not affect the current window', async () => {
  const db = new FakeRateLimitFirestore();
  const windowMs = 60_000;
  const currentWindowStartMs = Math.floor(Date.now() / windowMs) * windowMs;
  const earlierWindowStartMs = currentWindowStartMs - windowMs;

  // Simulates an exhausted bucket from the *previous* window, seeded
  // directly rather than via checkAndIncrementRateLimit (which always
  // targets the current window).
  await db.runTransaction(async (tx) => {
    tx.set(db.doc(`rateLimits/user-1_createTable_${earlierWindowStartMs}`), {
      uid: 'user-1',
      family: 'createTable',
      count: 999,
    });
  });

  // The current window's bucket is a fresh, independent document — the
  // fixed-window design's whole point (docs/DATABASE.md §3.9a).
  await checkAndIncrementRateLimit(db, {
    uid: 'user-1',
    family: 'createTable',
    limit: 1,
    windowMs,
  });

  assert.equal(
      db.get(`rateLimits/user-1_createTable_${currentWindowStartMs}`)?.count,
      1,
  );
});

test('RateLimitExceededError exposes retryAfterMs as a positive duration', async () => {
  const db = new FakeRateLimitFirestore();
  const params = {uid: 'user-1', family: 'createTable', limit: 0, windowMs: 60_000};

  await assert.rejects(checkAndIncrementRateLimit(db, params), (err: unknown) => {
    assert.ok(err instanceof RateLimitExceededError);
    assert.ok(err.retryAfterMs > 0);
    assert.ok(err.retryAfterMs <= 60_000);
    return true;
  });
});
