/**
 * Trust & Safety domain: `reportUser`, `reportTable`, `blockUser`,
 * `triggerDuressSignal` (docs/API_SPEC.md §3.4).
 *
 * Per docs/ENGINEERING_GUIDELINES.md, any PR touching this directory
 * requires two approvals, at least one from an engineer who has
 * previously worked on this surface — flagged again here, not just in
 * the process doc, because this file is exactly the code that rule
 * exists to protect.
 *
 * Milestone F6 — implemented for real, replacing the F0 scaffold, per
 * `docs/IMPLEMENTATION_PLAN.md` §4's parallel Trust & Safety track
 * (Recommendation R6: safety infrastructure ships alongside the core
 * Crew-first loop, not after it).
 *
 * **Scope note, disclosed rather than silently narrowed:** this pass
 * covers `reportUser`/`reportTable`/`blockUser`/`triggerDuressSignal`
 * only. `createLocationShare`/`revokeLocationShare` — the other two
 * endpoints this domain's original F0 header named — are deliberately
 * deferred to their own follow-up, for two real reasons rather than a
 * scope cut of convenience: (1) `revokeLocationShare`'s documented
 * request shape, `{ shareId: string }` alone, cannot actually locate a
 * `tables/{tableId}/locationShares/{shareId}` subcollection document
 * without also knowing `tableId` — a genuine spec gap needing its own
 * resolution (most likely a collection-group query keyed by a
 * denormalized `shareId` field, mirroring `rsvps.userId`'s "redundant
 * with doc ID, kept for query convenience" precedent, `docs/DATABASE.md`
 * §3.3), not guessed at inside this pass. (2) `createLocationShare`'s
 * `external_sms` contact path needs an actual SMS-sending vendor, and
 * none has ever been chosen anywhere in this codebase — the same
 * category of real, undecided vendor dependency as the maps/places
 * provider (Venue Picker) and the native-share package (Invite & Share
 * Sheet), both tracked in TASKS.md. `completeIdentityVerification`
 * (Tier 2) remains Phase 1/Milestone F7 scope, unchanged from the F0
 * header this replaces.
 *
 * Uses the modular firebase-admin/{app,firestore} imports and the
 * ENFORCE_APP_CHECK/FUNCTIONS_EMULATOR pattern every other domain in this
 * codebase already established (see `functions/src/users/index.ts`'s
 * header for why).
 */

import {FieldValue, GeoPoint, getFirestore, Query} from 'firebase-admin/firestore';
import {HttpsError, onCall} from 'firebase-functions/v2/https';
import * as logger from 'firebase-functions/logger';
import {RateLimitExceededError, checkAndIncrementRateLimit} from '../shared/rateLimit';
import {
  extractDuressLocation,
  isValidBlockTargetUserId,
  isValidReportDetails,
  isValidReportReasonCode,
  isValidTargetId,
} from './validation';

const ENFORCE_APP_CHECK = process.env.FUNCTIONS_EMULATOR !== 'true';
const DAY_MS = 24 * 60 * 60 * 1000;

/**
 * docs/API_SPEC.md §3.4 `reportUser`/`reportTable`: "if a per-target open-
 * report threshold is crossed ... automatically sets
 * `reportFlags.isSuppressed: true` on a Table ... or flags a user for
 * expedited Trust & Safety queue review." No Remote Config integration
 * exists anywhere in this codebase yet (the same disclosed gap every
 * other "Remote-Config-tunable" spec reference in this domain currently
 * has — see `addMember`'s `CREW_AT_CAPACITY` precedent,
 * `functions/src/crews/index.ts`), so this threshold is a conservative
 * hardcoded constant rather than a guessed-at Remote Config read.
 * Deliberately low, per the spec's own "intentionally conservative,
 * biased toward false positives a reviewer clears quickly" framing.
 */
const OPEN_REPORT_SUPPRESSION_THRESHOLD = 3;

interface ReportRequest {
  targetType?: unknown;
  targetId?: unknown;
  reasonCode?: unknown;
  details?: unknown;
}

/**
 * Shared implementation behind both `reportUser` and `reportTable` —
 * docs/API_SPEC.md §3.4 documents them as one combined request/response/
 * error contract, differing only in which collection `targetId`
 * references; keeping one real implementation avoids the two ever
 * silently drifting apart. [expectedTargetType] is forced from which
 * exported callable was invoked (`docs/SCREEN_SPECIFICATIONS.md` Screen
 * 27: "calls `reportUser` or `reportTable` (context-dependent)") rather
 * than trusted from the request body alone, so a client can't call
 * `reportUser` with `targetType: "table"` and land on the wrong
 * increment path below.
 */
async function handleReport(
    request: {auth?: {uid: string} | null; data?: ReportRequest},
    expectedTargetType: 'user' | 'table',
): Promise<{reportId: string}> {
  if (!request.auth) {
    throw new HttpsError('unauthenticated', 'Sign-in required.');
  }
  const uid = request.auth.uid;
  const {targetType, targetId, reasonCode, details} = request.data ?? {};

  if (targetType !== expectedTargetType) {
    throw new HttpsError(
        'invalid-argument',
        `targetType must be "${expectedTargetType}" for this endpoint.`,
    );
  }
  if (!isValidTargetId(targetId)) {
    throw new HttpsError('invalid-argument', 'targetId is required.');
  }
  if (!isValidReportReasonCode(reasonCode)) {
    throw new HttpsError('invalid-argument', 'reasonCode is not a recognized value.');
  }
  if (!isValidReportDetails(reasonCode, details)) {
    throw new HttpsError(
        'invalid-argument',
        'details is required for the off_platform_stalking reason, and must be at most 1000 characters.',
    );
  }

  const db = getFirestore();

  try {
    await checkAndIncrementRateLimit(db, {
      uid, family: 'report', limit: 10, windowMs: DAY_MS,
    });
  } catch (err) {
    if (err instanceof RateLimitExceededError) {
      throw new HttpsError('resource-exhausted', err.message, {
        code: 'RATE_LIMITED',
        message: 'Too many reports submitted. Please try again tomorrow.',
      });
    }
    throw err;
  }

  // docs/API_SPEC.md §3.4: "already-exists if an identical open report from
  // the same reporter against the same target already exists" — backed by
  // the (reporterId, targetType, targetId, status) composite index added
  // alongside this endpoint (docs/DATABASE.md §5).
  const duplicateQuery: Query = db.collection('reports')
      .where('reporterId', '==', uid)
      .where('targetType', '==', targetType)
      .where('targetId', '==', targetId)
      .where('status', '==', 'open')
      .limit(1);

  const reportRef = db.collection('reports').doc();
  const now = FieldValue.serverTimestamp();
  // off_platform_stalking is "always at least sev2" (SECURITY.md); every
  // other reasonCode is untriaged (null) until a human reviewer sets it.
  const initialSeverity = reasonCode === 'off_platform_stalking' ? 'sev2' : null;

  await db.runTransaction(async (tx) => {
    const duplicateSnap = await tx.get(duplicateQuery);
    if (!duplicateSnap.empty) {
      throw new HttpsError(
          'already-exists',
          'An open report from you against this target already exists.',
      );
    }

    let openReportCount: number | undefined;
    if (expectedTargetType === 'table') {
      const tableRef = db.doc(`tables/${targetId}`);
      const tableSnap = await tx.get(tableRef);
      if (tableSnap.exists) {
        const reportFlags = tableSnap.data()?.reportFlags as
          {openReportCount?: number} | undefined;
        openReportCount = (reportFlags?.openReportCount ?? 0) + 1;
        tx.update(tableRef, {
          'reportFlags.openReportCount': openReportCount,
          'reportFlags.isSuppressed':
            openReportCount >= OPEN_REPORT_SUPPRESSION_THRESHOLD,
        });
      }
    } else {
      const profileRef = db.doc(`users/${targetId}/private/profile`);
      const profileSnap = await tx.get(profileRef);
      if (profileSnap.exists) {
        const trustSignals = profileSnap.data()?.trustSignals as
          {reportCount?: number} | undefined;
        openReportCount = (trustSignals?.reportCount ?? 0) + 1;
        tx.update(profileRef, {'trustSignals.reportCount': openReportCount});
      }
    }

    // "Flags a user for expedited Trust & Safety queue review" (targetType
    // == user) is represented here as escalating this new report's own
    // severity once the threshold is crossed — there is no separate
    // "expedited" field anywhere in docs/DATABASE.md §3.1 for a report to
    // set on the target user document itself.
    const thresholdCrossed = expectedTargetType === 'user' &&
      (openReportCount ?? 0) >= OPEN_REPORT_SUPPRESSION_THRESHOLD;
    const severity = initialSeverity ?? (thresholdCrossed ? 'sev3' : null);

    tx.create(reportRef, {
      reporterId: uid,
      targetType: expectedTargetType,
      targetId,
      reasonCode,
      severity,
      isDuressSignal: false,
      details: details ?? null,
      status: 'open',
      assignedTo: null,
      resolutionNotes: null,
      createdAt: now,
      updatedAt: now,
    });
  });

  return {reportId: reportRef.id};
}

export const reportUser = onCall<ReportRequest>(
    {enforceAppCheck: ENFORCE_APP_CHECK},
    (request) => handleReport(request, 'user'),
);

export const reportTable = onCall<ReportRequest>(
    {enforceAppCheck: ENFORCE_APP_CHECK},
    (request) => handleReport(request, 'table'),
);

// --- blockUser -----------------------------------------------------------

interface BlockUserRequest {
  targetUserId?: unknown;
}

export const blockUser = onCall<BlockUserRequest>(
    {enforceAppCheck: ENFORCE_APP_CHECK},
    async (request) => {
      if (!request.auth) {
        throw new HttpsError('unauthenticated', 'Sign-in required.');
      }
      const uid = request.auth.uid;
      const {targetUserId} = request.data ?? {};

      if (!isValidBlockTargetUserId(targetUserId, uid)) {
        throw new HttpsError('invalid-argument', 'targetUserId is required and must not be the caller.');
      }

      const db = getFirestore();
      // Idempotent by construction (arrayUnion), matching addMember/
      // removeMember's identical no-idempotency-key treatment
      // (docs/API_SPEC.md §3.4) — a retried block of an already-blocked
      // uid is a no-op, not a duplicate-entry bug.
      await db.doc(`users/${uid}/private/profile`).update({
        blockedUserIds: FieldValue.arrayUnion(targetUserId),
        updatedAt: FieldValue.serverTimestamp(),
      });

      return {success: true};
    },
);

// --- triggerDuressSignal ---------------------------------------------------

interface TriggerDuressSignalRequest {
  tableId?: unknown;
  location?: unknown;
}

/**
 * Stands in for actually paging the Trust & Safety on-call rotation
 * (docs/SECURITY.md's Incident Response) — no real paging-tool
 * integration (PagerDuty/Opsgenie/etc.) exists anywhere in this codebase,
 * the same disclosed-vendor-gap pattern as this domain's other deferred
 * pieces. This at minimum guarantees the SEV1 is never silently lost:
 * every real production deploy's Cloud Logging captures this line, so
 * even before a real paging integration exists, the signal is durably
 * recorded and alertable-on via a Cloud Logging-based alert policy.
 */
function pageOnCallForDuressSignal(tableId: string, uid: string, reportId: string): void {
  logger.error('DURESS_SIGNAL_SEV1', {tableId, uid, reportId});
}

export const triggerDuressSignal = onCall<TriggerDuressSignalRequest>(
    {enforceAppCheck: ENFORCE_APP_CHECK},
    async (request) => {
      // docs/API_SPEC.md §3.4: "none of the caller-facing error codes used
      // elsewhere in this document apply by design ... unauthenticated is
      // the only condition that can prevent the call from being processed
      // at all" — deliberately no tableId existence check, no RSVP check,
      // no location-shape validation error. This is not an oversight; a
      // live emergency must never be gated behind a check that could
      // reject it.
      if (!request.auth) {
        throw new HttpsError('unauthenticated', 'Sign-in required.');
      }
      const uid = request.auth.uid;
      const tableId = typeof request.data?.tableId === 'string' ? request.data.tableId : '';
      const location = extractDuressLocation(request.data?.location);

      // Real bug found and fixed here, not just a defensive nicety: an empty
      // (or "/"-containing) tableId makes `tables/${tableId}/duressSignals/…`
      // an invalid Firestore document path, and `db.doc()` throws
      // synchronously on that — which surfaced as an unhandled 500, the
      // opposite of this endpoint's "never rejects a live emergency"
      // contract (a crash is a worse outcome than either accepting or
      // rejecting cleanly). The real Live Table Screen always knows its own
      // tableId, so this only guards a directly-malformed call: when the
      // path can't be formed, the duressSignals subdocument is skipped, but
      // the linked sev1 report (targetId is just a string field, not a path
      // segment, so it has no such constraint) and the on-call page still
      // go out — the signal is never silently dropped even in this case.
      const hasUsableTableId = tableId.length > 0 && !tableId.includes('/');

      const db = getFirestore();
      const reportRef = db.collection('reports').doc();
      const now = FieldValue.serverTimestamp();

      await db.runTransaction(async (tx) => {
        if (hasUsableTableId) {
          const duressRef = db.doc(`tables/${tableId}/duressSignals/${uid}`);
          tx.set(duressRef, {
            triggeredAt: now,
            lastKnownLocation: location ? new GeoPoint(location.lat, location.lng) : null,
            status: 'open',
            linkedReportId: reportRef.id,
            acknowledgedBy: null,
          });
        }
        tx.create(reportRef, {
          reporterId: uid,
          targetType: 'table',
          targetId: tableId,
          reasonCode: 'safety_concern',
          severity: 'sev1',
          isDuressSignal: true,
          details: null,
          status: 'open',
          assignedTo: null,
          resolutionNotes: null,
          createdAt: now,
          updatedAt: now,
        });
      });

      pageOnCallForDuressSignal(tableId, uid, reportRef.id);

      return {acknowledged: true};
    },
);
