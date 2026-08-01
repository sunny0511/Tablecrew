import assert from 'node:assert/strict';
import {test} from 'node:test';

import {
  DuplicateRequestInFlightError,
  IdempotencyDocRef,
  IdempotencyFirestore,
  IdempotencyKeyOwnedByAnotherUserError,
  runIdempotent,
} from '../../src/shared/idempotency';

/**
 * Minimal in-memory fake satisfying {@link IdempotencyFirestore}, standing
 * in for a real Firestore emulator so this file can exercise
 * `runIdempotent`'s control-flow branches (claim / replay / reject-
 * concurrent-duplicate / release-on-failure) as fast, dependency-free unit
 * tests. Real `create()` atomicity and TTL expiry are covered separately
 * by the Firebase Emulator Suite integration tests (Milestone F4,
 * functions/test/integration/), not this fake.
 */
class FakeIdempotencyFirestore implements IdempotencyFirestore {
  private readonly docsByPath = new Map<string, Record<string, unknown>>();

  doc(path: string): IdempotencyDocRef {
    return {
      create: async (data) => {
        if (this.docsByPath.has(path)) {
          throw new Error('ALREADY_EXISTS');
        }
        this.docsByPath.set(path, {...data});
      },
      get: async () => {
        const data = this.docsByPath.get(path);
        return {
          exists: data !== undefined,
          data: () => data,
        };
      },
      update: async (data) => {
        const existing = this.docsByPath.get(path);
        if (!existing) throw new Error('NOT_FOUND');
        this.docsByPath.set(path, {...existing, ...data});
      },
      delete: async () => {
        this.docsByPath.delete(path);
      },
    };
  }

  /** Test-only helper for pre-seeding a claim, simulating a concurrent or
   * prior call's state without going through `runIdempotent` itself. */
  seed(path: string, data: Record<string, unknown>): void {
    this.docsByPath.set(path, data);
  }
}

test('runIdempotent: first call claims the key, runs fn once, returns its result', async () => {
  const db = new FakeIdempotencyFirestore();
  let callCount = 0;

  const result = await runIdempotent(
      db,
      {key: 'key-1', uid: 'user-1', endpoint: 'createTable'},
      async () => {
        callCount += 1;
        return {tableId: 'table-1'};
      },
  );

  assert.deepEqual(result, {tableId: 'table-1'});
  assert.equal(callCount, 1);
});

test('runIdempotent: retry after success replays the stored response without re-running fn', async () => {
  const db = new FakeIdempotencyFirestore();
  let callCount = 0;

  const params = {key: 'key-2', uid: 'user-1', endpoint: 'createTable'};
  const first = await runIdempotent(db, params, async () => {
    callCount += 1;
    return {tableId: `table-${callCount}`};
  });
  const second = await runIdempotent(db, params, async () => {
    callCount += 1;
    return {tableId: `table-${callCount}`};
  });

  assert.deepEqual(first, {tableId: 'table-1'});
  // Replays the FIRST call's response verbatim, not a second, different
  // result from fn actually running again.
  assert.deepEqual(second, {tableId: 'table-1'});
  assert.equal(callCount, 1);
});

test('runIdempotent: a second call while the first is still in flight throws DuplicateRequestInFlightError', async () => {
  const db = new FakeIdempotencyFirestore();
  db.seed('idempotencyKeys/key-3', {
    uid: 'user-1',
    endpoint: 'requestSeat',
    status: 'in_progress',
    response: null,
  });

  await assert.rejects(
      runIdempotent(
          db,
          {key: 'key-3', uid: 'user-1', endpoint: 'requestSeat'},
          async () => ({rsvpStatus: 'confirmed'}),
      ),
      DuplicateRequestInFlightError,
  );
});

test('runIdempotent: a key claimed by a different uid throws IdempotencyKeyOwnedByAnotherUserError', async () => {
  const db = new FakeIdempotencyFirestore();
  db.seed('idempotencyKeys/key-4', {
    uid: 'user-1',
    endpoint: 'createTable',
    status: 'completed',
    response: {tableId: 'table-1'},
  });

  await assert.rejects(
      runIdempotent(
          db,
          {key: 'key-4', uid: 'user-2', endpoint: 'createTable'},
          async () => ({tableId: 'table-2'}),
      ),
      IdempotencyKeyOwnedByAnotherUserError,
  );
});

test('runIdempotent: a failed attempt releases the claim, so the same key can be retried fresh', async () => {
  const db = new FakeIdempotencyFirestore();
  let attempt = 0;
  const params = {key: 'key-5', uid: 'user-1', endpoint: 'requestSeat'};

  await assert.rejects(
      runIdempotent(db, params, async () => {
        attempt += 1;
        throw new Error('TABLE_FULL');
      }),
      /TABLE_FULL/,
  );
  assert.equal(attempt, 1);

  // Retrying with the same key after the failure is treated as a fresh
  // first attempt — fn runs again and can now succeed.
  const result = await runIdempotent(db, params, async () => {
    attempt += 1;
    return {rsvpStatus: 'confirmed'};
  });

  assert.deepEqual(result, {rsvpStatus: 'confirmed'});
  assert.equal(attempt, 2);
});

test('runIdempotent: create() failing with no existing document found surfaces as a plain error, not a false replay', async () => {
  // Simulates the narrow theoretical race the implementation's own comment
  // describes: create() fails (doc exists at that instant) but a get()
  // moments later finds nothing (e.g. a concurrent failed attempt's own
  // cleanup deleted it in between). Exercised directly via a custom fake
  // doc ref rather than FakeIdempotencyFirestore's map, since that map
  // can't represent "existed for create(), gone for get()" cleanly.
  const db: IdempotencyFirestore = {
    doc: () => ({
      create: async () => {
        throw new Error('ALREADY_EXISTS');
      },
      get: async () => ({exists: false, data: () => undefined}),
      update: async () => undefined,
      delete: async () => undefined,
    }),
  };

  await assert.rejects(
      runIdempotent(
          db,
          {key: 'key-7', uid: 'user-1', endpoint: 'createTable'},
          async () => ({tableId: 'table-1'}),
      ),
      /unexpected race/,
  );
});

test('runIdempotent: an existing claim with a status other than "completed" is treated as in-flight, not replayed', async () => {
  const db = new FakeIdempotencyFirestore();
  db.seed('idempotencyKeys/key-6', {
    uid: 'user-1',
    endpoint: 'createTable',
    status: 'in_progress',
    response: null,
  });

  // Guards against a future refactor accidentally treating "any existing
  // claim" as replayable — only "completed" should ever short-circuit
  // fn, per docs/DATABASE.md §3.9's explicit two-status contract.
  await assert.rejects(
      runIdempotent(
          db,
          {key: 'key-6', uid: 'user-1', endpoint: 'createTable'},
          async () => ({tableId: 'table-new'}),
      ),
      DuplicateRequestInFlightError,
  );
});
