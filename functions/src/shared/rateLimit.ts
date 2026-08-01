/**
 * The real `rateLimits/{bucketId}` counter described in docs/DATABASE.md
 * §3.9a and docs/API_SPEC.md's per-endpoint "Abuse prevention" notes.
 * Explicitly deferred from Milestone F2 to F4 as a shared mechanism (see
 * TASKS.md's F2 entry) rather than bespoke-built per callable.
 *
 * Fixed-window, not sliding-window or token-bucket: `createTable`'s own
 * spec text describes "a counter keyed by uid+day," and a fixed window is
 * the simplest mechanism that satisfies every limit this milestone's scope
 * needs (day-granularity for `createTable`, hour-granularity for
 * everything else) without a more complex sliding-window structure
 * nothing here calls for. The well-known fixed-window edge case (a burst
 * straddling a window boundary can momentarily allow up to roughly 2x the
 * stated limit) is an accepted tradeoff at this traffic scale — see
 * docs/DATABASE.md §3.9a.
 *
 * Depends on narrow `RateLimitFirestore`/`RateLimitTransaction`
 * interfaces (structurally satisfied by the real `firebase-admin`
 * `Firestore`/`Transaction` types) so the window/count logic can be
 * unit-tested against an in-memory fake without a Firestore emulator, the
 * same pattern `idempotency.ts` established.
 */

export interface RateLimitDocSnapshot {
  readonly exists: boolean;
  data(): Record<string, unknown> | undefined;
}

export interface RateLimitDocRef {
  readonly path: string;
}

export interface RateLimitTransaction {
  get(ref: RateLimitDocRef): Promise<RateLimitDocSnapshot>;
  set(ref: RateLimitDocRef, data: Record<string, unknown>): void;
}

export interface RateLimitFirestore {
  doc(path: string): RateLimitDocRef;
  runTransaction<T>(
    updateFunction: (tx: RateLimitTransaction) => Promise<T>
  ): Promise<T>;
}

/** A short grace buffer added on top of the window length before a bucket
 * document is eligible for TTL cleanup (docs/DATABASE.md §3.9a), so a
 * bucket document isn't deleted out from under a request landing right at
 * the boundary of its window. */
const TTL_GRACE_MS = 5 * 60 * 1000;

/** Thrown when a caller has exceeded their limit for the current window. */
export class RateLimitExceededError extends Error {
  /** Milliseconds until the current window ends and a new one begins. */
  readonly retryAfterMs: number;

  constructor(retryAfterMs: number) {
    super('Rate limit exceeded.');
    this.name = 'RateLimitExceededError';
    this.retryAfterMs = retryAfterMs;
  }
}

export interface RateLimitParams {
  uid: string;
  /** Endpoint-family name, e.g. "createTable", "tableMutation",
   * "crewMutation" — docs/DATABASE.md §3.9a. Endpoints sharing a family
   * (per API_SPEC.md's "shared with other X-mutation endpoints" language)
   * pass the same family string so they count against one combined
   * budget, not independent per-endpoint ones. */
  family: string;
  limit: number;
  windowMs: number;
}

/**
 * Checks [params.uid]'s call count for [params.family] in the current
 * fixed window and, if under [params.limit], atomically increments it.
 * Throws {@link RateLimitExceededError} if the limit is already reached.
 *
 * Safe to call before an endpoint's own business-logic transaction (they
 * don't need to be merged — see this file's header comment and
 * docs/DATABASE.md §3.9a's mechanics note): correctness only requires
 * this bucket document's own read-check-increment to be atomic, which a
 * dedicated transaction on it alone already guarantees.
 */
export async function checkAndIncrementRateLimit(
    db: RateLimitFirestore,
    params: RateLimitParams,
): Promise<void> {
  const {uid, family, limit, windowMs} = params;
  const windowStartMs = Math.floor(Date.now() / windowMs) * windowMs;
  const bucketId = `${uid}_${family}_${windowStartMs}`;
  const ref = db.doc(`rateLimits/${bucketId}`);

  await db.runTransaction(async (tx) => {
    const snapshot = await tx.get(ref);
    const data = snapshot.exists ? snapshot.data() : undefined;
    const count = typeof data?.count === 'number' ? data.count : 0;

    if (count >= limit) {
      throw new RateLimitExceededError(windowStartMs + windowMs - Date.now());
    }

    tx.set(ref, {
      uid,
      family,
      windowStart: new Date(windowStartMs),
      count: count + 1,
      expiresAt: new Date(windowStartMs + windowMs + TTL_GRACE_MS),
    });
  });
}
