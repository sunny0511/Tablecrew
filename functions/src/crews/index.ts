/**
 * Crew domain: createCrew, addMember, removeMember/leaveCrew, updateCrew
 * (docs/API_SPEC.md §3.2).
 *
 * Milestone F4 — implemented for real, replacing the F0 scaffold. Mirrors
 * `functions/src/tables/index.ts`'s conventions (modular firebase-admin
 * imports, ENFORCE_APP_CHECK, `translateSharedErrors`, `runIdempotent`,
 * `checkAndIncrementRateLimit`) rather than inventing a parallel style.
 *
 * Scope note, disclosed rather than silently expanded:
 * - `addMember` only implements the `targetUserId` (admin-direct-add)
 *   request mode. The `inviteToken` (self-accept) mode has no backing
 *   data model anywhere in `docs/DATABASE.md` — no invite/token
 *   subcollection, no issuance endpoint — and building one is a real
 *   design task, not something to improvise inline here. Calling
 *   `addMember` with `inviteToken` throws `not-found`, matching the
 *   documented error for an invalid token. See docs/API_SPEC.md §3.2
 *   `addMember`'s corrected note (Milestone F4) for the full disclosure,
 *   including that this means admin-privileged unilateral add is
 *   currently possible, unlike `createCrew`'s original (now-corrected)
 *   claim that it wasn't.
 * - `CREW_AT_CAPACITY`'s soft cap is a disclosed hard-coded constant
 *   (`CREW_MEMBER_SOFT_CAP`, see `./validation.ts`), not a real Remote
 *   Config read — same treatment as Tables' `KNOWN_INTEREST_TAGS`.
 * - Crew Chat (`crews/{crewId}/messages`) and `tableHistoryCount`/
 *   recurrence fields are untouched here — out of F4's "Core API
 *   surface: Tables & Crews" scope per docs/IMPLEMENTATION_PLAN.md.
 */

import {
  DocumentData,
  FieldValue,
  getFirestore,
} from 'firebase-admin/firestore';
import {HttpsError, onCall} from 'firebase-functions/v2/https';
import {isWellFormedIdempotencyKey} from '../shared';
import {DuplicateRequestInFlightError, IdempotencyKeyOwnedByAnotherUserError, runIdempotent} from '../shared/idempotency';
import {RateLimitExceededError, checkAndIncrementRateLimit} from '../shared/rateLimit';
import {
  CREW_MEMBER_SOFT_CAP,
  isValidCrewName,
  isValidCrewPhotoUrl,
  isValidInitialMemberIds,
  validateCrewPatch,
} from './validation';

const ENFORCE_APP_CHECK = process.env.FUNCTIONS_EMULATOR !== 'true';
const HOUR_MS = 60 * 60 * 1000;

/** Same shared-error translation `tables/index.ts` established — kept as
 * its own copy rather than a cross-domain shared import, since the two
 * files' contention-error semantics differ (Crews has no transaction
 * retry-under-contention scenario analogous to Tables' seat races, so
 * there's no `SEAT_REQUEST_CONTENTION`-equivalent code to parameterize
 * here; a shared helper would need to thread that difference through
 * anyway). */
function translateSharedErrors(err: unknown, genericMessage: string): never {
  if (err instanceof HttpsError) throw err;
  if (err instanceof DuplicateRequestInFlightError) {
    throw new HttpsError('failed-precondition', err.message, {
      code: 'DUPLICATE_REQUEST_IN_FLIGHT',
      message: 'This request is already being processed.',
    });
  }
  if (err instanceof IdempotencyKeyOwnedByAnotherUserError) {
    throw new HttpsError('already-exists', err.message);
  }
  if (err instanceof RateLimitExceededError) {
    throw new HttpsError('resource-exhausted', err.message, {
      code: 'RATE_LIMITED',
      message: 'Too many requests. Please try again later.',
    });
  }
  throw new HttpsError('internal', genericMessage);
}

// --- createCrew ----------------------------------------------------------

interface CreateCrewRequest {
  name?: unknown;
  photoUrl?: unknown;
  initialMemberIds?: unknown;
  idempotencyKey?: unknown;
}

export const createCrew = onCall<CreateCrewRequest>(
    {enforceAppCheck: ENFORCE_APP_CHECK},
    async (request) => {
      if (!request.auth) {
        throw new HttpsError('unauthenticated', 'Sign-in required.');
      }
      const uid = request.auth.uid;
      const {name, photoUrl, initialMemberIds, idempotencyKey} = request.data ?? {};

      if (!isWellFormedIdempotencyKey(idempotencyKey)) {
        throw new HttpsError('invalid-argument', 'idempotencyKey must be a well-formed UUID v4.');
      }
      if (!isValidCrewName(name)) {
        throw new HttpsError('invalid-argument', 'name must be 1-40 characters.');
      }
      if (!isValidCrewPhotoUrl(photoUrl)) {
        throw new HttpsError('invalid-argument', 'photoUrl must be a non-empty string or null.');
      }
      if (!isValidInitialMemberIds(initialMemberIds)) {
        throw new HttpsError('invalid-argument', 'initialMemberIds must be an array of uid strings.');
      }

      const db = getFirestore();

      try {
        return await runIdempotent(
            db,
            {key: idempotencyKey, uid, endpoint: 'createCrew'},
            async () => {
              await checkAndIncrementRateLimit(db, {
                uid, family: 'crewMutation', limit: 60, windowMs: HOUR_MS,
              });

              const publicProfileSnap = await db.doc(`users/${uid}`).get();
              const publicProfile = publicProfileSnap.data();

              const memberIds = Array.from(
                  new Set([uid, ...((initialMemberIds as string[] | undefined) ?? [])]),
              );

              // Denormalized member-snapshot map (docs/DATABASE.md §3.4,
              // §4). Snapshotting every initial member's display
              // name/photo here would require an N-document read fan-out
              // for an arbitrary-length initialMemberIds list before the
              // idempotent create; instead, only the creator (already
              // fetched above) is snapshotted precisely, and every other
              // initial member gets a placeholder snapshot that the same
              // denormalization-refresh trigger docs/DATABASE.md §4
              // describes for `updateCrew` will correct on their next
              // profile read/write. This mirrors createTable's approach
              // of snapshotting only the caller, not every referenced uid.
              const now = new Date();
              const members: Record<string, unknown> = {
                [uid]: {
                  displayNameSnapshot: publicProfile?.displayName ?? '',
                  photoUrlSnapshot: publicProfile?.photoUrl ?? null,
                  role: 'admin',
                  joinedAt: now,
                },
              };
              for (const memberId of memberIds) {
                if (memberId === uid) continue;
                members[memberId] = {
                  displayNameSnapshot: '',
                  photoUrlSnapshot: null,
                  role: 'member',
                  joinedAt: now,
                };
              }

              const crewRef = db.collection('crews').doc();
              const serverNow = FieldValue.serverTimestamp();

              await crewRef.create({
                name,
                photoUrl: photoUrl ?? null,
                creatorId: uid,
                memberIds,
                members,
                tableHistoryCount: 0,
                recurrence: null,
                createdAt: serverNow,
                updatedAt: serverNow,
              });

              return {crewId: crewRef.id};
            },
        );
      } catch (err) {
        translateSharedErrors(err, 'Failed to create Crew.');
      }
    },
);

// --- updateCrew ------------------------------------------------------------

interface UpdateCrewRequest {
  crewId?: unknown;
  patch?: unknown;
}

export const updateCrew = onCall<UpdateCrewRequest>(
    {enforceAppCheck: ENFORCE_APP_CHECK},
    async (request) => {
      if (!request.auth) {
        throw new HttpsError('unauthenticated', 'Sign-in required.');
      }
      const uid = request.auth.uid;
      const {crewId, patch} = request.data ?? {};

      if (typeof crewId !== 'string' || crewId.length === 0) {
        throw new HttpsError('invalid-argument', 'crewId is required.');
      }
      const invalidFields = validateCrewPatch(patch);
      if (invalidFields.length > 0) {
        throw new HttpsError('invalid-argument', `Invalid patch fields: ${invalidFields.join(', ')}.`);
      }

      const db = getFirestore();

      try {
        await checkAndIncrementRateLimit(db, {
          uid, family: 'crewMutation', limit: 60, windowMs: HOUR_MS,
        });
      } catch (err) {
        translateSharedErrors(err, 'Failed to check rate limit.');
      }

      const crewRef = db.doc(`crews/${crewId}`);
      const p = patch as Record<string, unknown>;

      try {
        const updatedFields = await db.runTransaction(async (tx) => {
          const snap = await tx.get(crewRef);
          if (!snap.exists) {
            throw new HttpsError('not-found', 'Crew not found.');
          }
          const data = snap.data()!;
          const members = data.members as Record<string, {role?: string}> | undefined;
          if (members?.[uid]?.role !== 'admin') {
            throw new HttpsError('permission-denied', 'Only a Crew admin may edit this Crew.');
          }

          const updates: Record<string, unknown> = {updatedAt: FieldValue.serverTimestamp()};
          const fieldsChanged: string[] = [];

          if ('name' in p) {
            updates.name = p.name;
            fieldsChanged.push('name');
          }
          if ('photoUrl' in p) {
            updates.photoUrl = p.photoUrl ?? null;
            fieldsChanged.push('photoUrl');
          }

          tx.update(crewRef, updates as DocumentData);
          return fieldsChanged;
        });

        return {success: true, updatedFields};
      } catch (err) {
        translateSharedErrors(err, 'Failed to update Crew.');
      }
    },
);

// --- addMember ---------------------------------------------------------

interface AddMemberRequest {
  crewId?: unknown;
  targetUserId?: unknown;
  inviteToken?: unknown;
}

export const addMember = onCall<AddMemberRequest>(
    {enforceAppCheck: ENFORCE_APP_CHECK},
    async (request) => {
      if (!request.auth) {
        throw new HttpsError('unauthenticated', 'Sign-in required.');
      }
      const uid = request.auth.uid;
      const {crewId, targetUserId, inviteToken} = request.data ?? {};

      if (typeof crewId !== 'string' || crewId.length === 0) {
        throw new HttpsError('invalid-argument', 'crewId is required.');
      }

      // Disclosed scope limit (see this file's header): only the
      // targetUserId (admin-direct-add) request mode is implemented.
      if (inviteToken !== undefined) {
        throw new HttpsError('not-found', 'Invalid or expired inviteToken.', {
          code: 'INVITE_TOKEN_NOT_SUPPORTED',
          message: 'Invite links are not yet available; ask a Crew admin to add you directly.',
        });
      }
      if (typeof targetUserId !== 'string' || targetUserId.length === 0) {
        throw new HttpsError('invalid-argument', 'targetUserId is required.');
      }

      const db = getFirestore();

      try {
        await checkAndIncrementRateLimit(db, {
          uid, family: 'crewMutation', limit: 60, windowMs: HOUR_MS,
        });
      } catch (err) {
        translateSharedErrors(err, 'Failed to check rate limit.');
      }

      const crewRef = db.doc(`crews/${crewId}`);

      try {
        return await db.runTransaction(async (tx) => {
          const crewSnap = await tx.get(crewRef);
          if (!crewSnap.exists) {
            throw new HttpsError('not-found', 'Crew not found.');
          }
          const data = crewSnap.data()!;
          const members = data.members as Record<string, {role?: string}> | undefined;
          if (members?.[uid]?.role !== 'admin') {
            throw new HttpsError('permission-denied', 'Only a Crew admin may add members.');
          }

          const memberIds = (data.memberIds as string[] | undefined) ?? [];

          // Idempotent by construction (docs/API_SPEC.md §3.2): a target
          // already present is a no-op returning the current count.
          if (memberIds.includes(targetUserId)) {
            return {success: true, memberCount: memberIds.length};
          }

          if (memberIds.length >= CREW_MEMBER_SOFT_CAP) {
            throw new HttpsError('failed-precondition', 'Crew is at capacity.', {
              code: 'CREW_AT_CAPACITY',
              message: 'This Crew has reached its member limit.',
            });
          }

          const targetProfileSnap = await tx.get(db.doc(`users/${targetUserId}`));
          if (!targetProfileSnap.exists) {
            throw new HttpsError('not-found', 'targetUserId does not exist.');
          }
          const targetProfile = targetProfileSnap.data();

          const now = FieldValue.serverTimestamp();
          tx.update(crewRef, {
            memberIds: FieldValue.arrayUnion(targetUserId),
            [`members.${targetUserId}`]: {
              displayNameSnapshot: targetProfile?.displayName ?? '',
              photoUrlSnapshot: targetProfile?.photoUrl ?? null,
              role: 'member',
              joinedAt: new Date(),
            },
            updatedAt: now,
          });

          return {success: true, memberCount: memberIds.length + 1};
        });
      } catch (err) {
        translateSharedErrors(err, 'Failed to add member.');
      }
    },
);

// --- removeMember / leaveCrew --------------------------------------------

interface RemoveMemberRequest {
  crewId?: unknown;
  targetUserId?: unknown;
}

export const removeMember = onCall<RemoveMemberRequest>(
    {enforceAppCheck: ENFORCE_APP_CHECK},
    async (request) => {
      if (!request.auth) {
        throw new HttpsError('unauthenticated', 'Sign-in required.');
      }
      const uid = request.auth.uid;
      const {crewId, targetUserId} = request.data ?? {};

      if (typeof crewId !== 'string' || crewId.length === 0) {
        throw new HttpsError('invalid-argument', 'crewId is required.');
      }
      if (targetUserId !== undefined && (typeof targetUserId !== 'string' || targetUserId.length === 0)) {
        throw new HttpsError('invalid-argument', 'targetUserId must be a non-empty string when given.');
      }

      // docs/API_SPEC.md §3.2 removeMember/leaveCrew: "a caller must use
      // the omit-targetUserId leave path to remove themselves, not the
      // admin-remove path."
      if (targetUserId === uid) {
        throw new HttpsError('invalid-argument', 'Use the leave path (omit targetUserId) to remove yourself.', {
          code: 'SELF_REMOVE_NOT_ALLOWED',
          message: 'Omit targetUserId to leave the Crew yourself.',
        });
      }

      const db = getFirestore();

      try {
        await checkAndIncrementRateLimit(db, {
          uid, family: 'crewMutation', limit: 60, windowMs: HOUR_MS,
        });
      } catch (err) {
        translateSharedErrors(err, 'Failed to check rate limit.');
      }

      const crewRef = db.doc(`crews/${crewId}`);
      const removalTarget = (targetUserId as string | undefined) ?? uid;

      try {
        return await db.runTransaction(async (tx) => {
          const snap = await tx.get(crewRef);
          if (!snap.exists) {
            throw new HttpsError('not-found', 'Crew not found.');
          }
          const data = snap.data()!;
          const members = data.members as Record<string, {role?: string}> | undefined;

          if (targetUserId !== undefined && members?.[uid]?.role !== 'admin') {
            throw new HttpsError('permission-denied', 'Only a Crew admin may remove another member.');
          }

          const memberIds = (data.memberIds as string[] | undefined) ?? [];
          if (!memberIds.includes(removalTarget)) {
            throw new HttpsError('not-found', 'targetUserId is not a current member.');
          }

          tx.update(crewRef, {
            memberIds: FieldValue.arrayRemove(removalTarget),
            [`members.${removalTarget}`]: FieldValue.delete(),
            updatedAt: FieldValue.serverTimestamp(),
          });

          return {success: true};
        });
      } catch (err) {
        translateSharedErrors(err, 'Failed to remove member.');
      }
    },
);

/** `leaveCrew` is the same endpoint as `removeMember` with `targetUserId`
 * omitted (docs/API_SPEC.md §3.2 documents them as one endpoint,
 * "removeMember / leaveCrew"); exported under both names so callers can
 * use whichever reads more clearly at the call site, matching how the
 * spec itself refers to it by both names. */
export const leaveCrew = removeMember;
