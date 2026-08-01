/**
 * Table domain: createTable, updateTable, requestSeat, confirmAttendee,
 * cancelTable, cancelRsvp, endTableEarly (docs/API_SPEC.md §3.1).
 *
 * Milestone F4 — implemented for real, replacing the F0 scaffold.
 *
 * Scope note, disclosed rather than silently expanded: this milestone is
 * "Core API surface: Tables & Crews" per docs/IMPLEMENTATION_PLAN.md, not
 * Discover/notifications/Trust & Safety. Concretely, that means:
 * - `cancelTable`'s documented "notification fan-out" and "Typesense
 *   index removal via the same trigger path" are NOT implemented here —
 *   neither FCM (Milestone F8) nor Typesense sync (Discover, Phase 1)
 *   exist anywhere in this codebase yet. The Firestore `status` write
 *   itself is real and correct; the two downstream side effects are a
 *   disclosed gap, not a silent omission, tracked in TASKS.md.
 * - `requestSeat`'s blocked-user check ("a blocked user cannot requestSeat
 *   on the blocker's Tables") is NOT implemented — `blockUser` itself is a
 *   Milestone F6 (Trust & Safety) deliverable; `blockedUserIds` exists on
 *   the schema but nothing populates it yet.
 * - `SEAT_REQUEST_CONTENTION` detection (transaction retry-budget
 *   exhaustion) is a best-effort mapping based on the Admin SDK's gRPC
 *   ABORTED status code — unverified against a real emulator, since I
 *   don't have one in my sandbox. Flagged for real verification in this
 *   milestone's integration-test task, not assumed correct.
 *
 * Uses the modular firebase-admin/{app,firestore} imports and the
 * ENFORCE_APP_CHECK/FUNCTIONS_EMULATOR pattern functions/src/users/index.ts
 * established in Milestone F2 — see that file's header for why.
 */

import {
  DocumentData,
  FieldValue,
  GeoPoint,
  Timestamp,
  getFirestore,
} from 'firebase-admin/firestore';
import {HttpsError, onCall} from 'firebase-functions/v2/https';
import {isWellFormedIdempotencyKey} from '../shared';
import {DuplicateRequestInFlightError, IdempotencyKeyOwnedByAnotherUserError, runIdempotent} from '../shared/idempotency';
import {RateLimitExceededError, checkAndIncrementRateLimit} from '../shared/rateLimit';
import {
  isValidCapacity,
  isValidDescription,
  isValidInterestTag,
  isValidLocation,
  isValidStartTime,
  isValidTitle,
  isValidVisibility,
  validateTablePatch,
} from './validation';

const ENFORCE_APP_CHECK = process.env.FUNCTIONS_EMULATOR !== 'true';

const DAY_MS = 24 * 60 * 60 * 1000;
const HOUR_MS = 60 * 60 * 1000;

/** Grpc status code 10 (ABORTED) — how the Admin SDK's Firestore client
 * surfaces a transaction whose retry budget was exhausted under
 * contention. Best-effort; see this file's header disclosure. */
function isTransactionContentionError(err: unknown): boolean {
  return typeof err === 'object' && err !== null && (err as {code?: unknown}).code === 10;
}

/** Shared translation from this file's internal error types to the
 * HttpsError shapes docs/API_SPEC.md documents, so every callable below
 * doesn't repeat the same catch-and-map block. */
function translateSharedErrors(
    err: unknown, contentionCode: string, contentionMessage: string,
): never {
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
  if (isTransactionContentionError(err)) {
    throw new HttpsError('failed-precondition', contentionMessage, {
      code: contentionCode,
      message: contentionMessage,
    });
  }
  throw err;
}

// --- createTable -------------------------------------------------------

interface CreateTableRequest {
  title?: unknown;
  description?: unknown;
  interestTag?: unknown;
  visibility?: unknown;
  location?: unknown;
  startTime?: unknown;
  capacity?: unknown;
  crewId?: unknown;
  idempotencyKey?: unknown;
}

export const createTable = onCall<CreateTableRequest>(
    {enforceAppCheck: ENFORCE_APP_CHECK},
    async (request) => {
      if (!request.auth) {
        throw new HttpsError('unauthenticated', 'Sign-in required.');
      }
      const uid = request.auth.uid;
      const {
        title, description, interestTag, visibility, location,
        startTime, capacity, crewId, idempotencyKey,
      } = request.data ?? {};

      if (!isWellFormedIdempotencyKey(idempotencyKey)) {
        throw new HttpsError('invalid-argument', 'idempotencyKey must be a well-formed UUID v4.');
      }
      if (!isValidTitle(title)) {
        throw new HttpsError('invalid-argument', 'title must be 1-100 characters.');
      }
      if (!isValidDescription(description)) {
        throw new HttpsError('invalid-argument', 'description must be at most 1000 characters.');
      }
      if (!isValidInterestTag(interestTag)) {
        throw new HttpsError('invalid-argument', 'interestTag must be a known interest tag.');
      }
      if (!isValidVisibility(visibility)) {
        throw new HttpsError('invalid-argument', 'visibility must be "open" or "closed".');
      }
      if (!isValidLocation(location)) {
        throw new HttpsError('invalid-argument', 'location is malformed.');
      }
      if (!isValidStartTime(startTime)) {
        throw new HttpsError('invalid-argument', 'startTime must be more than 1 hour from now.');
      }
      if (!isValidCapacity(capacity)) {
        throw new HttpsError('invalid-argument', 'capacity must satisfy 2 <= min <= max <= 8.');
      }
      if (crewId !== undefined && crewId !== null && typeof crewId !== 'string') {
        throw new HttpsError('invalid-argument', 'crewId must be a string or null.');
      }

      const db = getFirestore();

      const privateProfileSnap = await db.doc(`users/${uid}/private/profile`).get();
      const trustSignals = privateProfileSnap.data()?.trustSignals as
        {standingStatus?: string} | undefined;
      if (trustSignals?.standingStatus === 'restricted' || trustSignals?.standingStatus === 'banned') {
        throw new HttpsError('failed-precondition', 'Account standing does not allow creating Tables.', {
          code: 'TRUST_STANDING_RESTRICTED',
          message: 'Your account standing does not currently allow creating new Tables.',
        });
      }

      if (crewId) {
        const crewSnap = await db.doc(`crews/${crewId}`).get();
        const memberIds = crewSnap.data()?.memberIds as string[] | undefined;
        if (!crewSnap.exists || !memberIds?.includes(uid)) {
          throw new HttpsError('permission-denied', 'You are not a member of this Crew.');
        }
      }

      try {
        return await runIdempotent(
            db,
            {key: idempotencyKey, uid, endpoint: 'createTable'},
            async () => {
              await checkAndIncrementRateLimit(db, {
                uid, family: 'createTable', limit: 10, windowMs: DAY_MS,
              });

              const publicProfileSnap = await db.doc(`users/${uid}`).get();
              const publicProfile = publicProfileSnap.data();

              const tableRef = db.collection('tables').doc();
              const now = FieldValue.serverTimestamp();
              const loc = location as
                {geopoint: {lat: number; lng: number}; venueId?: string | null; address: string};

              await tableRef.create({
                hostId: uid,
                hostDisplayNameSnapshot: publicProfile?.displayName ?? '',
                hostPhotoUrlSnapshot: publicProfile?.photoUrl ?? null,
                hostVerificationTierSnapshot: publicProfile?.verificationTierPublic ?? 'phone_verified',
                title,
                interestTag: interestTag ?? null,
                description: description ?? null,
                costBand: null,
                coverPhotoUrl: null,
                accessibilityNotes: null,
                visibility,
                status: 'proposed',
                location: {
                  geopoint: new GeoPoint(loc.geopoint.lat, loc.geopoint.lng),
                  venueId: loc.venueId ?? null,
                  venueNameSnapshot: null,
                  address: loc.address,
                  isTBD: false,
                  tbdConfirmBy: null,
                },
                startTime: Timestamp.fromDate(new Date(startTime as string)),
                capacity: {
                  min: (capacity as {min: number}).min,
                  max: (capacity as {max: number}).max,
                  confirmedCount: 0,
                  waitlistCount: 0,
                },
                crewId: crewId ?? null,
                priceSplitEnabled: false,
                reportFlags: {openReportCount: 0, isSuppressed: false},
                createdAt: now,
                updatedAt: now,
              });

              return {tableId: tableRef.id, status: 'proposed'};
            },
        );
      } catch (err) {
        translateSharedErrors(err, 'INTERNAL', 'Failed to create Table.');
      }
    },
);

// --- updateTable ---------------------------------------------------------

interface UpdateTableRequest {
  tableId?: unknown;
  patch?: unknown;
}

export const updateTable = onCall<UpdateTableRequest>(
    {enforceAppCheck: ENFORCE_APP_CHECK},
    async (request) => {
      if (!request.auth) {
        throw new HttpsError('unauthenticated', 'Sign-in required.');
      }
      const uid = request.auth.uid;
      const {tableId, patch} = request.data ?? {};

      if (typeof tableId !== 'string' || tableId.length === 0) {
        throw new HttpsError('invalid-argument', 'tableId is required.');
      }
      const invalidFields = validateTablePatch(patch);
      if (invalidFields.length > 0) {
        throw new HttpsError('invalid-argument', `Invalid patch fields: ${invalidFields.join(', ')}.`);
      }

      const db = getFirestore();

      try {
        await checkAndIncrementRateLimit(db, {
          uid, family: 'tableMutation', limit: 60, windowMs: HOUR_MS,
        });
      } catch (err) {
        translateSharedErrors(err, 'INTERNAL', 'Failed to check rate limit.');
      }

      const tableRef = db.doc(`tables/${tableId}`);
      const p = patch as Record<string, unknown>;

      try {
        const updatedFields = await db.runTransaction(async (tx) => {
          const snap = await tx.get(tableRef);
          if (!snap.exists) {
            throw new HttpsError('not-found', 'Table not found.');
          }
          const data = snap.data()!;
          if (data.hostId !== uid) {
            throw new HttpsError('permission-denied', 'Only the host may edit this Table.');
          }

          const isConfirmedOrLater = ['confirmed', 'happened', 'rated'].includes(data.status as string);
          if (isConfirmedOrLater && ('capacity' in p || 'startTime' in p)) {
            throw new HttpsError('failed-precondition', 'Cannot edit capacity/startTime after confirmation.', {
              code: 'CANNOT_EDIT_AFTER_CONFIRMED',
              message: 'This Table has already been confirmed; capacity and start time can no longer be changed. Cancel and recreate instead.',
            });
          }

          const updates: Record<string, unknown> = {updatedAt: FieldValue.serverTimestamp()};
          const fieldsChanged: string[] = [];

          if ('title' in p) {
            updates.title = p.title;
            fieldsChanged.push('title');
          }
          if ('description' in p) {
            updates.description = p.description ?? null;
            fieldsChanged.push('description');
          }
          if ('interestTag' in p) {
            updates.interestTag = p.interestTag ?? null;
            fieldsChanged.push('interestTag');
          }
          if ('visibility' in p) {
            updates.visibility = p.visibility;
            fieldsChanged.push('visibility');
          }
          if ('startTime' in p) {
            updates.startTime = Timestamp.fromDate(new Date(p.startTime as string));
            fieldsChanged.push('startTime');
          }
          if ('capacity' in p) {
            const newCapacity = p.capacity as {min: number; max: number};
            updates.capacity = {
              ...(data.capacity as Record<string, unknown>),
              min: newCapacity.min,
              max: newCapacity.max,
            };
            fieldsChanged.push('capacity');
          }
          if ('location' in p) {
            const loc = p.location as
              {geopoint: {lat: number; lng: number}; venueId?: string | null; address: string};
            updates.location = {
              ...(data.location as Record<string, unknown>),
              geopoint: new GeoPoint(loc.geopoint.lat, loc.geopoint.lng),
              venueId: loc.venueId ?? null,
              address: loc.address,
            };
            fieldsChanged.push('location');
          }

          tx.update(tableRef, updates as DocumentData);
          return fieldsChanged;
        });

        return {success: true, updatedFields};
      } catch (err) {
        translateSharedErrors(err, 'INTERNAL', 'Failed to update Table.');
      }
    },
);

// --- requestSeat -----------------------------------------------------------

interface RequestSeatRequest {
  tableId?: unknown;
  idempotencyKey?: unknown;
}

export const requestSeat = onCall<RequestSeatRequest>(
    {enforceAppCheck: ENFORCE_APP_CHECK},
    async (request) => {
      if (!request.auth) {
        throw new HttpsError('unauthenticated', 'Sign-in required.');
      }
      const uid = request.auth.uid;
      const {tableId, idempotencyKey} = request.data ?? {};

      if (typeof tableId !== 'string' || tableId.length === 0) {
        throw new HttpsError('invalid-argument', 'tableId is required.');
      }
      if (!isWellFormedIdempotencyKey(idempotencyKey)) {
        throw new HttpsError('invalid-argument', 'idempotencyKey must be a well-formed UUID v4.');
      }

      const db = getFirestore();

      try {
        return await runIdempotent(
            db,
            {key: idempotencyKey, uid, endpoint: 'requestSeat'},
            async () => {
              await checkAndIncrementRateLimit(db, {
                uid, family: 'requestSeat', limit: 30, windowMs: HOUR_MS,
              });

              const tableRef = db.doc(`tables/${tableId}`);
              const rsvpRef = tableRef.collection('rsvps').doc(uid);
              const publicProfileSnap = await db.doc(`users/${uid}`).get();
              const publicProfile = publicProfileSnap.data();

              return db.runTransaction(async (tx) => {
                const [tableSnap, rsvpSnap] =
                  await Promise.all([tx.get(tableRef), tx.get(rsvpRef)]);
                if (!tableSnap.exists) {
                  throw new HttpsError('not-found', 'Table not found.');
                }
                if (rsvpSnap.exists) {
                  throw new HttpsError('already-exists', 'RSVP already exists.', {
                    code: 'RSVP_ALREADY_EXISTS',
                    message: 'You already have an RSVP on this Table.',
                  });
                }

                const table = tableSnap.data()!;
                if (['happened', 'rated', 'cancelled'].includes(table.status as string)) {
                  throw new HttpsError('failed-precondition', 'Table not accepting RSVPs.', {
                    code: 'TABLE_NOT_ACCEPTING_RSVPS',
                    message: 'This Table is no longer accepting RSVPs.',
                  });
                }

                const capacity = table.capacity as {
                  max: number; confirmedCount: number; waitlistCount: number;
                };
                const now = FieldValue.serverTimestamp();
                const tableUpdates: Record<string, unknown> = {updatedAt: now};
                let rsvpStatus: 'confirmed' | 'waitlisted' | 'requested';

                if (table.visibility === 'closed') {
                  rsvpStatus = 'requested';
                } else if (capacity.confirmedCount < capacity.max) {
                  rsvpStatus = 'confirmed';
                  tableUpdates['capacity.confirmedCount'] = capacity.confirmedCount + 1;
                } else {
                  rsvpStatus = 'waitlisted';
                  tableUpdates['capacity.waitlistCount'] = capacity.waitlistCount + 1;
                }

                tx.create(rsvpRef, {
                  userId: uid,
                  userDisplayNameSnapshot: publicProfile?.displayName ?? '',
                  userPhotoUrlSnapshot: publicProfile?.photoUrl ?? null,
                  status: rsvpStatus,
                  statusHistory: [{status: rsvpStatus, at: new Date()}],
                  respondedAt: now,
                  splitPaymentStatus: 'not_applicable',
                  createdAt: now,
                  updatedAt: now,
                });
                tx.update(tableRef, tableUpdates as DocumentData);

                return {rsvpStatus};
              });
            },
        );
      } catch (err) {
        translateSharedErrors(err, 'SEAT_REQUEST_CONTENTION', 'Too many concurrent requests for this Table — please try again shortly.');
      }
    },
);

// --- confirmAttendee ---------------------------------------------------

interface ConfirmAttendeeRequest {
  tableId?: unknown;
  targetUserId?: unknown;
  idempotencyKey?: unknown;
}

export const confirmAttendee = onCall<ConfirmAttendeeRequest>(
    {enforceAppCheck: ENFORCE_APP_CHECK},
    async (request) => {
      if (!request.auth) {
        throw new HttpsError('unauthenticated', 'Sign-in required.');
      }
      const uid = request.auth.uid;
      const {tableId, targetUserId, idempotencyKey} = request.data ?? {};

      if (typeof tableId !== 'string' || tableId.length === 0) {
        throw new HttpsError('invalid-argument', 'tableId is required.');
      }
      if (typeof targetUserId !== 'string' || targetUserId.length === 0) {
        throw new HttpsError('invalid-argument', 'targetUserId is required.');
      }
      if (!isWellFormedIdempotencyKey(idempotencyKey)) {
        throw new HttpsError('invalid-argument', 'idempotencyKey must be a well-formed UUID v4.');
      }

      const db = getFirestore();

      try {
        return await runIdempotent(
            db,
            {key: idempotencyKey, uid, endpoint: 'confirmAttendee'},
            async () => {
              await checkAndIncrementRateLimit(db, {
                uid, family: 'tableMutation', limit: 60, windowMs: HOUR_MS,
              });

              const tableRef = db.doc(`tables/${tableId}`);
              const rsvpRef = tableRef.collection('rsvps').doc(targetUserId);

              return db.runTransaction(async (tx) => {
                const [tableSnap, rsvpSnap] =
                  await Promise.all([tx.get(tableRef), tx.get(rsvpRef)]);
                if (!tableSnap.exists) {
                  throw new HttpsError('not-found', 'Table not found.');
                }
                const table = tableSnap.data()!;
                if (table.hostId !== uid) {
                  throw new HttpsError('permission-denied', 'Only the host may confirm attendees.');
                }
                if (!rsvpSnap.exists) {
                  throw new HttpsError('not-found', 'No RSVP from targetUserId on this Table.');
                }

                const capacity = table.capacity as {max: number; confirmedCount: number};
                if (capacity.confirmedCount >= capacity.max) {
                  throw new HttpsError('failed-precondition', 'Table is full.', {
                    code: 'TABLE_FULL',
                    message: 'Confirming this attendee would exceed the Table\'s capacity.',
                  });
                }

                const now = FieldValue.serverTimestamp();
                tx.update(rsvpRef, {
                  status: 'confirmed',
                  statusHistory: FieldValue.arrayUnion({status: 'confirmed', at: new Date()}),
                  respondedAt: now,
                  updatedAt: now,
                });
                tx.update(tableRef, {
                  'capacity.confirmedCount': capacity.confirmedCount + 1,
                  'updatedAt': now,
                });

                return {success: true, newStatus: 'confirmed'};
              });
            },
        );
      } catch (err) {
        translateSharedErrors(err, 'SEAT_REQUEST_CONTENTION', 'Too many concurrent requests for this Table — please try again shortly.');
      }
    },
);

// --- cancelTable -----------------------------------------------------------

interface CancelTableRequest {
  tableId?: unknown;
  reason?: unknown;
}

export const cancelTable = onCall<CancelTableRequest>(
    {enforceAppCheck: ENFORCE_APP_CHECK},
    async (request) => {
      if (!request.auth) {
        throw new HttpsError('unauthenticated', 'Sign-in required.');
      }
      const uid = request.auth.uid;
      const {tableId, reason} = request.data ?? {};

      if (typeof tableId !== 'string' || tableId.length === 0) {
        throw new HttpsError('invalid-argument', 'tableId is required.');
      }
      if (reason !== undefined && typeof reason !== 'string') {
        throw new HttpsError('invalid-argument', 'reason must be a string.');
      }

      const db = getFirestore();

      try {
        await checkAndIncrementRateLimit(db, {
          uid, family: 'tableMutation', limit: 60, windowMs: HOUR_MS,
        });
      } catch (err) {
        translateSharedErrors(err, 'INTERNAL', 'Failed to check rate limit.');
      }

      const tableRef = db.doc(`tables/${tableId}`);

      try {
        return await db.runTransaction(async (tx) => {
          const snap = await tx.get(tableRef);
          if (!snap.exists) {
            throw new HttpsError('not-found', 'Table not found.');
          }
          const data = snap.data()!;

          let isCrewAdmin = false;
          if (data.hostId !== uid && data.crewId) {
            const crewSnap = await tx.get(db.doc(`crews/${data.crewId as string}`));
            const members = crewSnap.data()?.members as
              Record<string, {role?: string}> | undefined;
            isCrewAdmin = members?.[uid]?.role === 'admin';
          }
          if (data.hostId !== uid && !isCrewAdmin) {
            throw new HttpsError('permission-denied', 'Only the host or a Crew admin may cancel this Table.');
          }

          if (data.status === 'happened' || data.status === 'rated') {
            throw new HttpsError('failed-precondition', 'Table has already happened.', {
              code: 'ALREADY_HAPPENED',
              message: 'This Table has already happened and cannot be cancelled.',
            });
          }
          if (data.status === 'cancelled') {
            // Idempotent by construction (docs/API_SPEC.md §3.1): a repeat
            // cancel of an already-cancelled Table has no additional effect
            // to double-apply.
            return {success: true};
          }

          tx.update(tableRef, {
            status: 'cancelled',
            cancelReason: reason ?? null,
            updatedAt: FieldValue.serverTimestamp(),
          });

          return {success: true};
        });
      } catch (err) {
        translateSharedErrors(err, 'INTERNAL', 'Failed to cancel Table.');
      }
    },
);

// --- cancelRsvp --------------------------------------------------------

interface CancelRsvpRequest {
  tableId?: unknown;
  idempotencyKey?: unknown;
}

export const cancelRsvp = onCall<CancelRsvpRequest>(
    {enforceAppCheck: ENFORCE_APP_CHECK},
    async (request) => {
      if (!request.auth) {
        throw new HttpsError('unauthenticated', 'Sign-in required.');
      }
      const uid = request.auth.uid;
      const {tableId, idempotencyKey} = request.data ?? {};

      if (typeof tableId !== 'string' || tableId.length === 0) {
        throw new HttpsError('invalid-argument', 'tableId is required.');
      }
      if (!isWellFormedIdempotencyKey(idempotencyKey)) {
        throw new HttpsError('invalid-argument', 'idempotencyKey must be a well-formed UUID v4.');
      }

      const db = getFirestore();

      try {
        return await runIdempotent(
            db,
            {key: idempotencyKey, uid, endpoint: 'cancelRsvp'},
            async () => {
              await checkAndIncrementRateLimit(db, {
                uid, family: 'tableMutation', limit: 60, windowMs: HOUR_MS,
              });

              const tableRef = db.doc(`tables/${tableId}`);
              const rsvpRef = tableRef.collection('rsvps').doc(uid);

              return db.runTransaction(async (tx) => {
                const [tableSnap, rsvpSnap] =
                  await Promise.all([tx.get(tableRef), tx.get(rsvpRef)]);
                if (!tableSnap.exists || !rsvpSnap.exists) {
                  // Idempotent by construction: no RSVP to cancel is treated
                  // the same as "already cancelled," not an error, so a
                  // retried cancel after the first one already succeeded
                  // doesn't fail.
                  return {success: true};
                }

                const table = tableSnap.data()!;
                const rsvp = rsvpSnap.data()!;
                const capacity = table.capacity as {
                  max: number; confirmedCount: number; waitlistCount: number;
                };
                const now = FieldValue.serverTimestamp();
                const tableUpdates: Record<string, unknown> = {updatedAt: now};

                tx.delete(rsvpRef);

                if (rsvp.status === 'confirmed') {
                  tableUpdates['capacity.confirmedCount'] = Math.max(0, capacity.confirmedCount - 1);

                  // Promote the earliest waitlisted RSVP into the freed seat,
                  // per docs/API_SPEC.md §3.1's requirement that this happen
                  // here, not only in the scheduled reconciliation sweep.
                  const waitlistQuery = await tx.get(
                      tableRef.collection('rsvps')
                          .where('status', '==', 'waitlisted')
                          .orderBy('createdAt', 'asc')
                          .limit(1),
                  );
                  if (waitlistQuery.docs[0]) {
                    const promoted = waitlistQuery.docs[0];
                    tx.update(promoted.ref, {
                      status: 'confirmed',
                      statusHistory: FieldValue.arrayUnion({status: 'confirmed', at: new Date()}),
                      respondedAt: now,
                      updatedAt: now,
                    });
                    tableUpdates['capacity.confirmedCount'] = capacity.confirmedCount; // net unchanged: one left, one promoted
                    tableUpdates['capacity.waitlistCount'] = Math.max(0, capacity.waitlistCount - 1);
                  }
                } else if (rsvp.status === 'waitlisted') {
                  tableUpdates['capacity.waitlistCount'] = Math.max(0, capacity.waitlistCount - 1);
                }

                tx.update(tableRef, tableUpdates as DocumentData);
                return {success: true};
              });
            },
        );
      } catch (err) {
        translateSharedErrors(err, 'INTERNAL', 'Failed to cancel RSVP.');
      }
    },
);

// --- endTableEarly -----------------------------------------------------

interface EndTableEarlyRequest {
  tableId?: unknown;
}

export const endTableEarly = onCall<EndTableEarlyRequest>(
    {enforceAppCheck: ENFORCE_APP_CHECK},
    async (request) => {
      if (!request.auth) {
        throw new HttpsError('unauthenticated', 'Sign-in required.');
      }
      const uid = request.auth.uid;
      const {tableId} = request.data ?? {};

      if (typeof tableId !== 'string' || tableId.length === 0) {
        throw new HttpsError('invalid-argument', 'tableId is required.');
      }

      const db = getFirestore();

      try {
        await checkAndIncrementRateLimit(db, {
          uid, family: 'tableMutation', limit: 60, windowMs: HOUR_MS,
        });
      } catch (err) {
        translateSharedErrors(err, 'INTERNAL', 'Failed to check rate limit.');
      }

      const tableRef = db.doc(`tables/${tableId}`);

      try {
        return await db.runTransaction(async (tx) => {
          const snap = await tx.get(tableRef);
          if (!snap.exists) {
            throw new HttpsError('not-found', 'Table not found.');
          }
          const data = snap.data()!;
          if (data.hostId !== uid) {
            throw new HttpsError('permission-denied', 'Only the host may end this Table early.');
          }

          if (data.status === 'happened') {
            // Idempotent by construction (docs/API_SPEC.md §3.1), same
            // treatment as cancelTable above.
            return {success: true};
          }
          if (data.status !== 'confirmed') {
            throw new HttpsError('failed-precondition', 'Table is not live.', {
              code: 'TABLE_NOT_LIVE',
              message: 'This Table is not currently live.',
            });
          }

          tx.update(tableRef, {
            status: 'happened',
            updatedAt: FieldValue.serverTimestamp(),
          });

          return {success: true};
        });
      } catch (err) {
        translateSharedErrors(err, 'INTERNAL', 'Failed to end Table early.');
      }
    },
);
