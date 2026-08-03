/**
 * Real Firebase Emulator Suite + real local Typesense integration tests for
 * `functions/src/triggers/index.ts`'s `onTableWrittenSyncTypesense` trigger.
 * Separate from `functions/test/integration/`'s suite (and its own
 * `test:integration` script) deliberately: every other integration test
 * only needs the Firebase Emulator Suite, but this one additionally needs
 * a live Typesense server, and requiring that dependency for the entire
 * integration suite would add friction to running the unrelated
 * tables/crews/trust/users tests. Milestone F7.
 *
 * Run via (two things must both be up first):
 *   1. `docker compose up -d typesense` (repo root) — no Typesense Cloud
 *      account needed, this is the local dev container
 *      `docker-compose.yml` defines.
 *   2. `firebase emulators:exec --only auth,firestore,functions \
 *        --project tablecrew-dev "npm --prefix functions run test:integration:typesense"`
 *
 * Firestore triggers fire on any write to the emulator regardless of
 * source (direct Admin SDK writes here, exactly like `endTableEarly`'s own
 * integration test sets `status: 'confirmed'` directly to simulate the
 * not-yet-built scheduled sweep) — this suite writes `tables/{tableId}`
 * directly rather than going through `createTable`, since the trigger
 * itself, not `createTable`'s validation, is what's under test here.
 */

import assert from 'node:assert/strict';
import crypto from 'node:crypto';
import {test, before} from 'node:test';
import {Client as TypesenseClient} from 'typesense';
import {getFirestore, Timestamp} from 'firebase-admin/firestore';
import {ensureAdminApp} from '../integration/emulatorClient';

const TYPESENSE_HOST = process.env.TYPESENSE_HOST ?? 'localhost';
const TYPESENSE_PORT = Number(process.env.TYPESENSE_PORT ?? 8108);
const TYPESENSE_API_KEY = process.env.TYPESENSE_API_KEY ?? 'tablecrew-local-dev-key';

let typesense: TypesenseClient;

before(() => {
  ensureAdminApp();
  typesense = new TypesenseClient({
    nodes: [{host: TYPESENSE_HOST, port: TYPESENSE_PORT, protocol: 'http'}],
    apiKey: TYPESENSE_API_KEY,
    connectionTimeoutSeconds: 5,
  });
});

/** The trigger runs asynchronously relative to the Firestore write that
 * caused it — there's no synchronous signal a test can await, so this
 * polls for the expected Typesense state with a bounded timeout instead of
 * a fixed sleep, the same "poll, don't sleep-and-hope" approach this
 * codebase already uses for `OfflineMutationQueue`'s reconnect tests. */
async function waitFor<T>(
    attempt: () => Promise<T>,
    isDone: (value: T) => boolean,
    {timeoutMs = 10_000, intervalMs = 250} = {},
): Promise<T> {
  const deadline = Date.now() + timeoutMs;
  for (;;) {
    const value = await attempt();
    if (isDone(value)) return value;
    if (Date.now() >= deadline) {
      throw new Error(`waitFor timed out after ${timeoutMs}ms`);
    }
    await new Promise((resolve) => setTimeout(resolve, intervalMs));
  }
}

async function fetchTypesenseDoc(tableId: string): Promise<Record<string, unknown> | null> {
  try {
    return await typesense.collections<Record<string, unknown>>('tables').documents(tableId).retrieve();
  } catch (err) {
    if ((err as {httpStatus?: number}).httpStatus === 404) return null;
    throw err;
  }
}

function baseTableDoc(overrides: Record<string, unknown> = {}) {
  const now = Timestamp.now();
  return {
    hostId: 'itest-ts-host',
    hostDisplayNameSnapshot: 'Alice',
    title: 'Sunday hike',
    interestTag: 'hiking',
    description: null,
    costBand: '$$',
    coverPhotoUrl: null,
    accessibilityNotes: null,
    visibility: 'open',
    status: 'proposed',
    location: {
      geopoint: {latitude: 17.385, longitude: 78.4867},
      venueId: null,
      venueNameSnapshot: 'Golconda Fort',
      address: '123 Fort Rd',
      isTBD: false,
      tbdConfirmBy: null,
    },
    startTime: Timestamp.fromMillis(Date.now() + 60 * 60 * 1000),
    capacity: {min: 2, max: 8, confirmedCount: 2, waitlistCount: 0},
    crewId: null,
    priceSplitEnabled: false,
    reportFlags: {openReportCount: 0, isSuppressed: false},
    createdAt: now,
    updatedAt: now,
    ...overrides,
  };
}

test('onTableWrittenSyncTypesense: an eligible Open Table is upserted into the Typesense index', async () => {
  const db = getFirestore();
  const tableId = `itest-ts-${crypto.randomUUID()}`;

  await db.doc(`tables/${tableId}`).set(baseTableDoc());

  const doc = await waitFor(
      () => fetchTypesenseDoc(tableId),
      (value) => value !== null,
  );

  assert.equal(doc!.id, tableId);
  assert.equal(doc!.title, 'Sunday hike');
  assert.equal(doc!.interestTag, 'hiking');
  assert.equal(doc!.seatsRemaining, 6);
  assert.deepEqual(doc!.location, [17.385, 78.4867]);
});

test('onTableWrittenSyncTypesense: cancelling a previously-indexed Table removes it from the index', async () => {
  const db = getFirestore();
  const tableId = `itest-ts-${crypto.randomUUID()}`;

  await db.doc(`tables/${tableId}`).set(baseTableDoc());
  await waitFor(() => fetchTypesenseDoc(tableId), (value) => value !== null);

  await db.doc(`tables/${tableId}`).update({status: 'cancelled'});

  const doc = await waitFor(
      () => fetchTypesenseDoc(tableId),
      (value) => value === null,
  );
  assert.equal(doc, null);
});

test('onTableWrittenSyncTypesense: a Closed Table is never indexed', async () => {
  const db = getFirestore();
  const tableId = `itest-ts-${crypto.randomUUID()}`;

  await db.doc(`tables/${tableId}`).set(baseTableDoc({visibility: 'closed'}));

  // There's no positive event to wait for here (the trigger should have
  // run and chosen *not* to index it) — a short bounded wait, then assert
  // absence, is the correct shape for a "this should NOT happen" check.
  await new Promise((resolve) => setTimeout(resolve, 2000));
  assert.equal(await fetchTypesenseDoc(tableId), null);
});

test('onTableWrittenSyncTypesense: a Table filling to capacity is removed from the index', async () => {
  const db = getFirestore();
  const tableId = `itest-ts-${crypto.randomUUID()}`;

  await db.doc(`tables/${tableId}`).set(
      baseTableDoc({capacity: {min: 2, max: 2, confirmedCount: 1, waitlistCount: 0}}),
  );
  await waitFor(() => fetchTypesenseDoc(tableId), (value) => value !== null);

  await db.doc(`tables/${tableId}`).update({'capacity.confirmedCount': 2});

  const doc = await waitFor(
      () => fetchTypesenseDoc(tableId),
      (value) => value === null,
  );
  assert.equal(doc, null);
});
