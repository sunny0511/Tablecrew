/**
 * Shared infrastructure: auth middleware, request validation, the
 * idempotency-key store (docs/DATABASE.md §3.9, mechanism described in
 * docs/API_SPEC.md §2), logging, and the Stripe client wrapper (Phase 1,
 * not needed for Foundation).
 *
 * Corrected in Milestone F2: this file previously cited "docs/API_SPEC.md
 * §3.9" for the idempotency-key store, which was already imprecise (the
 * `idempotencyKeys/{idempotencyKey}` collection itself is specified in
 * docs/DATABASE.md §3.9, not API_SPEC.md — API_SPEC.md §2 describes the
 * mechanism that uses it) and became actively wrong once Milestone F2 added
 * an unrelated "Account Creation & Signup" domain at API_SPEC.md §3.9.
 *
 * Scaffold note (Milestone F0): the real idempotency-key store (Firestore-
 * backed, per docs/DATABASE.md §3.9) lands in Milestone F4 alongside the
 * first idempotent callables. `isWellFormedIdempotencyKey` below is a
 * minimal, dependency-free pure function included now only to give the
 * Milestone F0 CI pipeline (lint → unit test → build) something real to
 * exercise end to end before any actual endpoint exists.
 */

/**
 * Checks that a client-supplied idempotency key is a non-empty string in
 * the UUID-v4 shape docs/API_SPEC.md §2 requires. This does not check
 * uniqueness or persistence — that's the Firestore-backed store
 * (docs/DATABASE.md §3.9) landing in Milestone F4.
 */
export function isWellFormedIdempotencyKey(key: unknown): key is string {
  if (typeof key !== 'string') return false;
  const uuidV4Pattern =
    /^[0-9a-f]{8}-[0-9a-f]{4}-4[0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$/i;
  return uuidV4Pattern.test(key);
}
