/**
 * The real `idempotencyKeys/{key}` store described in docs/DATABASE.md
 * §3.9 and docs/API_SPEC.md §2 — the first real use since the Milestone F0
 * scaffold note in this directory said it "lands in Milestone F4 alongside
 * the first idempotent callables."
 *
 * Contract (docs/API_SPEC.md §2): "The function's first step is an atomic
 * create() against idempotencyKeys/{idempotencyKey}... a duplicate call
 * with the same key returns the original stored response verbatim instead
 * of re-executing business logic." docs/DATABASE.md §3.9's schema defines
 * exactly two statuses, "in_progress" | "completed" — deliberately no
 * "failed" status. On a failed attempt (the wrapped function throws), this
 * helper deletes the claim rather than leaving it "in_progress" forever or
 * inventing an undocumented third status: a genuinely failed call is
 * always safe to retry with the same key (nothing completed, so there is
 * nothing to double-apply), and per docs/API_SPEC.md §2's own reasoning, a
 * client retrying a dropped/failed request is the normal case this whole
 * mechanism exists for. The one case `delete()` can't reach — process
 * death between `create()` and the `try`/`catch` below completing either
 * branch — is bounded by `expiresAt`'s Firestore TTL policy, the same
 * mechanism docs/DATABASE.md §3.9 already specifies for this collection.
 *
 * Depends on a narrow `IdempotencyFirestore` interface rather than the
 * full `firebase-admin` `Firestore` type (which structurally satisfies it)
 * so the control-flow logic below — claim / replay-on-completed /
 * reject-concurrent-duplicate / release-on-failure — can be unit-tested
 * against a lightweight in-memory fake without a Firestore emulator. The
 * emulator-backed integration tests (Milestone F4, functions/test/) cover
 * what this fake can't: real `create()` atomicity, real transaction
 * interplay with the business logic it wraps, and real TTL expiry.
 */

export interface IdempotencyDocSnapshot {
  readonly exists: boolean;
  data(): Record<string, unknown> | undefined;
}

export interface IdempotencyDocRef {
  create(data: Record<string, unknown>): Promise<unknown>;
  get(): Promise<IdempotencyDocSnapshot>;
  update(data: Record<string, unknown>): Promise<unknown>;
  delete(): Promise<unknown>;
}

export interface IdempotencyFirestore {
  doc(path: string): IdempotencyDocRef;
}

/** docs/DATABASE.md §3.9's own stated example window: "long enough to cover
 * realistic client retry/backoff windows but short enough that this
 * collection doesn't grow unbounded." */
const EXPIRY_WINDOW_MS = 24 * 60 * 60 * 1000;

/**
 * Thrown when a second call with the same idempotency key arrives while
 * the first is still executing (docs/API_SPEC.md's `DUPLICATE_REQUEST_IN_FLIGHT`,
 * documented on `requestSeat`/`createTable`/`createCrew`/etc.). Callers
 * catch this and translate it to `functions.https.HttpsError` themselves
 * rather than this module importing `firebase-functions` — keeps the
 * control-flow logic here framework-agnostic and directly unit-testable.
 */
export class DuplicateRequestInFlightError extends Error {
  constructor() {
    super('A request with this idempotency key is already in progress.');
    this.name = 'DuplicateRequestInFlightError';
  }
}

/**
 * Thrown in the (astronomically unlikely, given UUID v4) case where a
 * caller's idempotency key collides with a key already claimed by a
 * different uid.
 */
export class IdempotencyKeyOwnedByAnotherUserError extends Error {
  constructor() {
    super('This idempotency key is already in use.');
    this.name = 'IdempotencyKeyOwnedByAnotherUserError';
  }
}

/**
 * Runs [fn] under the idempotency-key contract described above.
 *
 * - First call with a given [key]: claims it, runs [fn], stores the result
 *   as the "completed" response, and returns it.
 * - Retry with the same [key] after [fn] already completed successfully:
 *   [fn] is never re-invoked; the original stored response is returned
 *   verbatim.
 * - Retry with the same [key] while the first attempt is still running:
 *   throws {@link DuplicateRequestInFlightError}.
 * - Retry with the same [key] after the first attempt *failed*: the claim
 *   was released on failure, so this is treated as a fresh first attempt.
 *
 * [T] must be plain, Firestore-serializable data (the shape every
 * callable's JSON response already is) — it's persisted verbatim as the
 * stored `response`.
 */
export async function runIdempotent<T>(
    db: IdempotencyFirestore,
    params: {key: string; uid: string; endpoint: string},
    fn: () => Promise<T>,
): Promise<T> {
  const {key, uid, endpoint} = params;
  const ref = db.doc(`idempotencyKeys/${key}`);

  try {
    await ref.create({
      uid,
      endpoint,
      status: 'in_progress',
      response: null,
      createdAt: new Date(),
      expiresAt: new Date(Date.now() + EXPIRY_WINDOW_MS),
    });
  } catch {
    // create() throws because the document already exists — either a
    // genuine retry of the same logical action, a concurrent duplicate
    // still in flight, or a cross-account key collision.
    const existing = await ref.get();
    const data = existing.data();
    if (!existing.exists || !data) {
      throw new Error(
          'Idempotency key claim failed but no existing document was found ' +
          '(unexpected race). Safe to retry with a fresh key.',
      );
    }
    if (data.uid !== uid) {
      throw new IdempotencyKeyOwnedByAnotherUserError();
    }
    if (data.status === 'completed') {
      return data.response as T;
    }
    throw new DuplicateRequestInFlightError();
  }

  try {
    const result = await fn();
    await ref.update({
      status: 'completed',
      response: result,
      updatedAt: new Date(),
    });
    return result;
  } catch (err) {
    await ref.delete();
    throw err;
  }
}
