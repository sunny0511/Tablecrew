/**
 * Discover search sync (docs/ARCHITECTURE.md §5.5, docs/DATABASE.md §8):
 * the derived Typesense `tables` document a Table becomes when it's Open/
 * Discover-eligible, plus the thin client that writes it. Firestore
 * remains the document of record — this collection is fully derived and
 * rebuildable, never authoritative (see this module's own
 * `TABLES_COLLECTION_SCHEMA` and the trigger that calls it,
 * `functions/src/triggers/index.ts`).
 *
 * Milestone F7. Closes the "Typesense has no local/CI emulation story" gap
 * docs/IMPLEMENTATION_PLAN.md §2.2 names as a real Foundation blocker —
 * this module talks to whatever Typesense instance its env vars point at,
 * which in dev/CI is the official `typesense/typesense` Docker image
 * (`docker-compose.yml` at the repo root) and in staging/prod is a real
 * Typesense Cloud cluster, per docs/adr/0002-typesense-over-algolia.md.
 * No real Typesense Cloud account is needed to build or test this file.
 *
 * Split into a narrow `TypesenseTablesClient` interface + a real
 * implementation, the same "interface behind a real impl" pattern
 * `functions/src/shared/rateLimit.ts`/`idempotency.ts` already established
 * — lets the trigger's own pure eligibility logic
 * (`deriveTypesenseDocument`) be unit-tested without any real Typesense
 * server, while `RealTypesenseTablesClient` is exercised by a real-server
 * integration test instead (`functions/test/integration/typesense.integration.test.ts`).
 */

import {Client as TypesenseClient} from 'typesense';
import type {CollectionFieldSchema} from 'typesense/lib/Typesense/Collection';

/** The `tables` Typesense collection's document shape. Every field here is
 * either directly copied from `tables/{tableId}` (docs/DATABASE.md §3.2)
 * or derived from it — nothing here is independently authored data. */
export interface TypesenseTableDocument {
  /** Typesense's own document id — set to the Firestore `tableId`, so
   * upsert/delete both key off the same value with no separate mapping. */
  id: string;
  title: string;
  hostDisplayNameSnapshot: string;
  interestTag: string;
  /** `[lat, lng]` — Typesense's own geopoint field shape (not an object). */
  location: [number, number];
  venueNameSnapshot: string;
  costBand: string;
  /** Unix seconds — Typesense has no native timestamp type. */
  startTime: number;
  capacityMax: number;
  /** `capacityMax - confirmedCount`, precomputed here rather than in the
   * client, since "how many seats remain" is exactly the kind of derived
   * fact this collection exists to make cheaply queryable/sortable. */
  seatsRemaining: number;
  /** Unix seconds, for a recency fallback sort. */
  createdAt: number;
}

/** Typesense collection schema for `TypesenseTableDocument`, created once
 * (idempotently — see `RealTypesenseTablesClient.ensureCollection`) against
 * whichever Typesense instance this environment points at. Field types per
 * docs/ARCHITECTURE.md §5.5's stated query needs: geo-radius filtering on
 * `location`, facet/equality filtering on `interestTag`, range filtering
 * and sorting on `startTime`/`seatsRemaining`. */
const TABLES_COLLECTION_NAME = 'tables';

const TABLES_COLLECTION_FIELDS: CollectionFieldSchema[] = [
  {name: 'title', type: 'string'},
  {name: 'hostDisplayNameSnapshot', type: 'string'},
  {name: 'interestTag', type: 'string', facet: true},
  {name: 'location', type: 'geopoint'},
  {name: 'venueNameSnapshot', type: 'string', optional: true},
  {name: 'costBand', type: 'string', facet: true, optional: true},
  {name: 'startTime', type: 'int64'},
  {name: 'capacityMax', type: 'int32'},
  {name: 'seatsRemaining', type: 'int32'},
  {name: 'createdAt', type: 'int64'},
];

/** The narrow surface `functions/src/triggers/index.ts`'s sync trigger
 * needs — upsert an eligible Table, or delete one that's left the
 * Discover-eligible state. */
export interface TypesenseTablesClient {
  upsertTable(doc: TypesenseTableDocument): Promise<void>;
  deleteTable(tableId: string): Promise<void>;
}

/**
 * Reads Typesense connection config from the environment. In the Functions
 * emulator (`FUNCTIONS_EMULATOR === 'true'`) and in CI, this defaults to
 * the local Docker container's fixed dev credentials (`docker-compose.yml`)
 * so no secrets are needed for dev/test. In a real deploy, these must come
 * from Firebase Functions secrets (`firebase functions:secrets:set
 * TYPESENSE_HOST` / `TYPESENSE_API_KEY`) — never hardcoded or committed —
 * which is why the non-emulator branch has no fallback default at all.
 */
function readTypesenseConfig(): {host: string; port: number; protocol: string; apiKey: string} {
  const isEmulator = process.env.FUNCTIONS_EMULATOR === 'true';
  const host = process.env.TYPESENSE_HOST ?? (isEmulator ? 'localhost' : undefined);
  const apiKey = process.env.TYPESENSE_API_KEY ?? (isEmulator ? 'tablecrew-local-dev-key' : undefined);
  if (!host || !apiKey) {
    throw new Error(
        'TYPESENSE_HOST/TYPESENSE_API_KEY are not set. Outside the Functions ' +
        'emulator, these must come from Firebase Functions secrets, never a ' +
        'hardcoded default.',
    );
  }
  return {
    host,
    port: Number(process.env.TYPESENSE_PORT ?? 8108),
    protocol: process.env.TYPESENSE_PROTOCOL ?? 'http',
    apiKey,
  };
}

let cachedClient: TypesenseClient | undefined;

/** Lazily-created, process-lifetime-cached Typesense client — mirrors how
 * `getFirestore()` is called freely throughout this codebase rather than
 * threaded as a parameter; Cloud Functions Gen 2 reuses warm instances
 * across invocations, so a module-level cache avoids reconnecting on every
 * call within the same instance. */
function getTypesenseClient(): TypesenseClient {
  if (!cachedClient) {
    const config = readTypesenseConfig();
    cachedClient = new TypesenseClient({
      nodes: [{host: config.host, port: config.port, protocol: config.protocol}],
      apiKey: config.apiKey,
      connectionTimeoutSeconds: 5,
    });
  }
  return cachedClient;
}

/** The real, Typesense-server-backed [TypesenseTablesClient]. */
export class RealTypesenseTablesClient implements TypesenseTablesClient {
  /** Creates the `tables` collection if it doesn't already exist. Safe to
   * call on every cold start — Typesense's own "already exists" error is
   * swallowed, the same idempotent-setup treatment a real deploy needs
   * since there's no separate one-time migration step in this codebase's
   * deploy process yet. Also what `docker-compose.yml`'s local dev
   * instance and CI's fresh-per-run container both rely on, since neither
   * pre-creates the collection some other way. */
  async ensureCollection(): Promise<void> {
    const client = getTypesenseClient();
    try {
      await client.collections().create({
        name: TABLES_COLLECTION_NAME,
        fields: TABLES_COLLECTION_FIELDS,
        default_sorting_field: 'startTime',
      });
    } catch (err) {
      if (!isAlreadyExistsError(err)) throw err;
    }
  }

  async upsertTable(doc: TypesenseTableDocument): Promise<void> {
    await this.ensureCollection();
    await getTypesenseClient()
        .collections<TypesenseTableDocument>(TABLES_COLLECTION_NAME)
        .documents()
        .upsert(doc);
  }

  async deleteTable(tableId: string): Promise<void> {
    await this.ensureCollection();
    try {
      await getTypesenseClient()
          .collections<TypesenseTableDocument>(TABLES_COLLECTION_NAME)
          .documents(tableId)
          .delete();
    } catch (err) {
      // A Table leaving the eligible state (e.g., cancelled) when it was
      // never eligible in the first place (e.g., cancelled before ever
      // becoming Open) has nothing to delete — a 404 here is an expected
      // no-op, not a real failure.
      if (!isNotFoundError(err)) throw err;
    }
  }
}

function isAlreadyExistsError(err: unknown): boolean {
  return typeof err === 'object' && err !== null && (err as {httpStatus?: number}).httpStatus === 409;
}

function isNotFoundError(err: unknown): boolean {
  return typeof err === 'object' && err !== null && (err as {httpStatus?: number}).httpStatus === 404;
}
