/**
 * Firestore/Auth-triggered functions (as opposed to client-callable ones),
 * per docs/ENGINEERING_GUIDELINES.md's separation of triggers from
 * callables.
 *
 * Milestone F7 — the Table→Typesense sync trigger (docs/ARCHITECTURE.md
 * §5.5) is now real, replacing the F0 scaffold's "no triggers implemented
 * yet" placeholder. The scheduled Firestore export job
 * (docs/ARCHITECTURE.md §8) remains unimplemented — a separate, disclosed
 * gap, not silently expanded into this pass.
 */

import {onDocumentWritten} from 'firebase-functions/v2/firestore';
import type {DocumentData} from 'firebase-admin/firestore';
import {RealTypesenseTablesClient, TypesenseTableDocument, TypesenseTablesClient} from '../shared/typesense';

/**
 * Pure eligibility/derivation logic behind the sync trigger below — kept
 * free of any Firestore/Typesense I/O specifically so it's unit-testable
 * without either, the same "pure function extracted from the trigger body"
 * pattern `functions/src/tables/validation.ts`'s validators already
 * establish for callables.
 *
 * Returns `null` if [tableData] isn't currently Discover-eligible (no
 * Typesense document should exist for it — the caller deletes rather than
 * upserts in that case), or the derived document to upsert otherwise.
 * Eligibility, per docs/ARCHITECTURE.md §5.5 ("when a Table leaves the
 * Open/Discover-eligible state (closed, cancelled, full, or past its start
 * time) the trigger deletes it from the index") plus
 * docs/API_SPEC.md §3.4's `reportUser`/`reportTable` behavior
 * ("`reportFlags.isSuppressed: true`... removing it from Discover pending
 * human review", a fifth criterion this section doesn't itself name but
 * that section does):
 * 1. `visibility === 'open'`
 * 2. `status !== 'cancelled'`
 * 3. not full: `capacity.confirmedCount < capacity.max`
 * 4. `startTime` is still in the future relative to [nowMs]
 * 5. `reportFlags.isSuppressed` is not `true`
 */
export function deriveTypesenseDocument(
    tableId: string,
    tableData: DocumentData | undefined,
    nowMs: number,
): TypesenseTableDocument | null {
  if (!tableData) return null;

  const visibility = tableData.visibility as string | undefined;
  const status = tableData.status as string | undefined;
  const capacity = tableData.capacity as
    {max?: number; confirmedCount?: number} | undefined;
  const location = tableData.location as {
    geopoint?: {latitude?: number; longitude?: number} | null;
    venueNameSnapshot?: string | null;
  } | undefined;
  const startTime = tableData.startTime;
  const reportFlags = tableData.reportFlags as {isSuppressed?: boolean} | undefined;

  if (visibility !== 'open') return null;
  if (status === 'cancelled') return null;
  if (reportFlags?.isSuppressed === true) return null;

  const capacityMax = capacity?.max;
  const confirmedCount = capacity?.confirmedCount;
  if (typeof capacityMax !== 'number' || typeof confirmedCount !== 'number') return null;
  if (confirmedCount >= capacityMax) return null;

  // Firestore Timestamps expose toMillis(); the emulator/Admin SDK always
  // returns a real Timestamp for a populated timestamp field, but this is
  // defensive against a malformed/missing value rather than assumed.
  const startTimeMs = typeof startTime?.toMillis === 'function' ? startTime.toMillis() : undefined;
  if (typeof startTimeMs !== 'number' || startTimeMs <= nowMs) return null;

  // A Firestore `GeoPoint` (which is what a real `location.geopoint` field
  // holds — docs/DATABASE.md §3.2) exposes `.latitude`/`.longitude`, not
  // `.lat`/`.lng` — confirmed against the real `firebase-admin/firestore`
  // `GeoPoint` class, not assumed. Reading the wrong property names here
  // was a real bug this trigger's own integration test caught (every
  // Table looked geopoint-less and nothing was ever indexed) that the
  // pure-logic unit tests couldn't, since their fake fixtures happened to
  // use the same wrong names as the code they were testing.
  const geopoint = location?.geopoint;
  if (!geopoint || typeof geopoint.latitude !== 'number' || typeof geopoint.longitude !== 'number') {
    // A Table with no coordinates yet (manual-entry-pending or TBD
    // location, docs/DATABASE.md §3.2's `isTBD`) has nothing for a
    // geo-radius query to filter on — not an error, just not indexable
    // yet. It becomes eligible on the write that finally sets a real
    // geopoint, the same trigger firing again for that update.
    return null;
  }

  return {
    id: tableId,
    title: (tableData.title as string | undefined) ?? '',
    hostDisplayNameSnapshot: (tableData.hostDisplayNameSnapshot as string | undefined) ?? '',
    interestTag: (tableData.interestTag as string | undefined) ?? '',
    location: [geopoint.latitude, geopoint.longitude],
    venueNameSnapshot: location?.venueNameSnapshot ?? '',
    costBand: (tableData.costBand as string | undefined) ?? '',
    startTime: Math.floor(startTimeMs / 1000),
    capacityMax,
    seatsRemaining: capacityMax - confirmedCount,
    createdAt: typeof tableData.createdAt?.toMillis === 'function' ?
      Math.floor(tableData.createdAt.toMillis() / 1000) :
      Math.floor(nowMs / 1000),
  };
}

let sharedTypesenseClient: TypesenseTablesClient | undefined;

function getTypesenseClient(): TypesenseTablesClient {
  if (!sharedTypesenseClient) {
    sharedTypesenseClient = new RealTypesenseTablesClient();
  }
  return sharedTypesenseClient;
}

/**
 * Keeps the Typesense `tables` collection in sync with every write to
 * `tables/{tableId}` — fires on create, update, *and* delete
 * (`onDocumentWritten` covers all three, unlike `onDocumentUpdated`),
 * since a hard-deleted Table (never expected in normal product use, but
 * possible via direct admin/console action per docs/ARCHITECTURE.md §5.2's
 * "an admin correcting data... should still trigger the same
 * denormalization fixups" principle) must also disappear from the index.
 *
 * A Typesense-side failure here never fails the client's original write —
 * this is a trigger, decoupled from the callable that made the Firestore
 * change, per docs/ARCHITECTURE.md §5.2's "a Typesense hiccup should never
 * fail a user's `createTable` call." Errors surface via Cloud Functions'
 * own error reporting (retried automatically per the trigger's default
 * retry policy) rather than being swallowed silently.
 */
export const onTableWrittenSyncTypesense = onDocumentWritten(
    'tables/{tableId}',
    async (event) => {
      const tableId = event.params.tableId;
      const afterData = event.data?.after.exists ? event.data.after.data() : undefined;
      const client = getTypesenseClient();

      const doc = deriveTypesenseDocument(tableId, afterData, Date.now());
      if (doc) {
        await client.upsertTable(doc);
      } else {
        await client.deleteTable(tableId);
      }
    },
);
