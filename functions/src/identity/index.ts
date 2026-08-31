/**
 * Identity domain: manual Tier 2 verification (docs/API_SPEC.md §3.7,
 * docs/DATABASE.md §3.10, ADR 0007).
 *
 * Added Milestone F7. This directory replaces what ADR 0005 assumed would
 * be a Persona SDK integration living in `trust/`. There is no vendor in
 * this flow at all: a user submits a government ID and a selfie, a human
 * reviews them, and an admin-only callable applies the decision.
 *
 * The security property that carried the old design carries this one
 * unchanged, and is the thing to protect in any future edit here: **no
 * client ever supplies a pass/fail signal, and no client can write its own
 * verification tier.** Under ADR 0005 that was enforced by fetching the
 * result from Persona's API server-side; here it is enforced by an `admin`
 * custom claim on the reviewing caller. `firestore.rules` denies every
 * client write to `identityVerifications` and to the `verification` map on
 * `users/{uid}/private/profile`, so these two callables are the only path.
 *
 * Two deliberate choices worth naming, because both look like omissions:
 *
 * 1. **No idempotency key on either callable.** `submitIdentityVerification`
 *    is idempotent by construction via the REVIEW_ALREADY_PENDING
 *    precondition, and `reviewIdentityVerification` via ALREADY_REVIEWED —
 *    the same treatment `addMember`/`blockUser` already get, rather than
 *    dragging in the generic `idempotencyKeys` store for endpoints whose
 *    own state machine already rejects a replay.
 * 2. **Images are deleted outside the Firestore transaction.** A Storage
 *    delete cannot participate in a Firestore transaction, and the
 *    ordering that matters is that the decision is durable *before* the
 *    evidence goes away. So the write commits first and deletion follows
 *    best-effort; a failed delete leaves a non-null path on a terminal
 *    status, which docs/DATABASE.md §3.10 names as the exact signal to
 *    alert on rather than something to paper over here.
 */

import {getFirestore, FieldValue, Timestamp} from 'firebase-admin/firestore';
import {getStorage} from 'firebase-admin/storage';
import {HttpsError, onCall} from 'firebase-functions/v2/https';
import * as logger from 'firebase-functions/logger';
import {RateLimitExceededError, checkAndIncrementRateLimit} from '../shared/rateLimit';
import {
  buildIdentityUploadPath,
  isValidDecision,
  isValidDocumentType,
  isValidUploadId,
  resolveReviewOutcome,
} from './validation';

/** See users/index.ts's header for why this is not a bare `true`. */
const ENFORCE_APP_CHECK = process.env.FUNCTIONS_EMULATOR !== 'true';

/**
 * 3 submissions per rolling 24h, inherited from Screen 8's existing retry
 * cap rather than a second, different number invented here. Under manual
 * review this limit is doing a different job than it was written for — it
 * now bounds human reviewer load, not vendor capture cost — which
 * docs/SCREEN_SPECIFICATIONS.md Screen 8 flags as worth re-deriving once
 * real submission volume exists.
 */
const SUBMISSION_LIMIT = 3;
const SUBMISSION_WINDOW_MS = 24 * 60 * 60 * 1000;

interface SubmitRequest {
  idDocumentUploadId?: unknown;
  selfieUploadId?: unknown;
  documentType?: unknown;
}

/** docs/API_SPEC.md §3.7 — `submitIdentityVerification`. */
export const submitIdentityVerification = onCall<SubmitRequest>(
    {enforceAppCheck: ENFORCE_APP_CHECK},
    async (request) => {
      if (!request.auth) {
        throw new HttpsError('unauthenticated', 'Sign-in required.');
      }
      const uid = request.auth.uid;
      const {idDocumentUploadId, selfieUploadId, documentType} = request.data ?? {};

      if (!isValidUploadId(idDocumentUploadId) || !isValidUploadId(selfieUploadId)) {
        throw new HttpsError(
            'invalid-argument',
            'idDocumentUploadId and selfieUploadId must be valid upload identifiers.',
        );
      }
      if (!isValidDocumentType(documentType)) {
        throw new HttpsError('invalid-argument', 'documentType is not a recognized value.');
      }

      const db = getFirestore();

      try {
        await checkAndIncrementRateLimit(db, {
          uid,
          family: 'identityVerification',
          limit: SUBMISSION_LIMIT,
          windowMs: SUBMISSION_WINDOW_MS,
        });
      } catch (err) {
        if (err instanceof RateLimitExceededError) {
          throw new HttpsError('resource-exhausted', err.message, {
            code: 'RATE_LIMITED',
            message: 'You have reached the verification attempt limit. Please try again later.',
            retryAfterMs: err.retryAfterMs,
          });
        }
        throw err;
      }

      const profileSnap = await db.doc(`users/${uid}/private/profile`).get();
      const verification = profileSnap.data()?.verification as
        {verificationTier?: string} | undefined;
      if (verification?.verificationTier === 'id_verified') {
        // Matches the superseded contract's treatment of the same case:
        // re-entering the flow after already passing is a precondition
        // failure, not a second review for a human to work through.
        throw new HttpsError('failed-precondition', 'Already verified.', {
          code: 'ALREADY_VERIFIED',
        });
      }

      const pending = await db.collection('identityVerifications')
          .where('userId', '==', uid)
          .where('status', '==', 'pending_review')
          .limit(1)
          .get();
      if (!pending.empty) {
        throw new HttpsError('failed-precondition', 'A review is already pending.', {
          code: 'REVIEW_ALREADY_PENDING',
        });
      }

      // The uid in both paths comes from context.auth, never the request —
      // a caller cannot reference another user's upload because it cannot
      // influence the prefix these are built from.
      const idDocumentPath = buildIdentityUploadPath(uid, idDocumentUploadId);
      const selfiePath = buildIdentityUploadPath(uid, selfieUploadId);

      const bucket = getStorage().bucket();
      const [idExists] = await bucket.file(idDocumentPath).exists();
      const [selfieExists] = await bucket.file(selfiePath).exists();
      if (!idExists || !selfieExists) {
        // Guards against a submission whose images never actually landed —
        // otherwise a reviewer opens an empty queue item and has no way to
        // tell a failed upload from a malicious one.
        throw new HttpsError('not-found', 'Uploaded documents were not found.', {
          code: 'UPLOAD_NOT_FOUND',
        });
      }

      const ref = db.collection('identityVerifications').doc();
      const batch = db.batch();
      batch.set(ref, {
        userId: uid,
        status: 'pending_review',
        documentType,
        idDocumentPath,
        selfiePath,
        dobMatchesId: null,
        reviewedBy: null,
        reviewedAt: null,
        decisionReason: null,
        createdAt: FieldValue.serverTimestamp(),
        updatedAt: FieldValue.serverTimestamp(),
      });

      // A deterministic pointer to the open submission, on a document the
      // owner can already read. Without it the client has no way to
      // rediscover its own pending review after an app restart: this
      // callable returns the id exactly once, and `firestore.rules`
      // deliberately denies `list` on identityVerifications so the
      // collection cannot be queried. A user who reinstalled mid-review
      // would then be permanently stuck — unable to see the pending
      // status, and blocked from resubmitting by REVIEW_ALREADY_PENDING
      // until a human intervened by hand.
      //
      // Deliberately a single pointer rather than a relaxed `list` rule:
      // it answers "what am I waiting on" without making the collection
      // enumerable, needs no index, and adds no readable history.
      batch.set(db.doc(`users/${uid}/private/profile`), {
        verification: {pendingSubmissionId: ref.id},
      }, {merge: true});

      await batch.commit();

      return {submissionId: ref.id, status: 'pending_review'};
    },
);

interface ReviewRequest {
  submissionId?: unknown;
  decision?: unknown;
  dobMatchesId?: unknown;
  rejectionReason?: unknown;
}

/**
 * docs/API_SPEC.md §3.7 — `reviewIdentityVerification`, admin-only.
 *
 * The only endpoint in this API surface that grants
 * `verificationTier: "id_verified"`.
 */
export const reviewIdentityVerification = onCall<ReviewRequest>(
    // App Check is deliberately NOT enforced here, unlike every other
    // callable in this codebase. App Check attests that a request came from
    // a genuine instance of *your app*. Nothing about this endpoint is
    // called from the app: there is no admin UI (an organization console is
    // Phase 4 per docs/ROADMAP.md), and the only caller is an operator
    // running scripts/review_identity.ts. Requiring app attestation from a
    // caller that is not an app is a category error — and in practice it
    // made the endpoint uncallable, which meant ADR 0007's one required
    // human step had no working client at all.
    //
    // This weakens nothing that was actually protecting the endpoint. App
    // Check does not authenticate a *user*; authorization here is the
    // `admin` custom claim, which only the Admin SDK can set
    // (scripts/grant_admin.ts) and which no client can grant itself. A
    // caller still needs a Firebase ID token carrying that claim, and the
    // claim remains unreachable from any client. What is lost is a bot
    // deterrent on an endpoint whose entire audience is one operator.
    //
    // If an admin console is ever built as a real Firebase app, turn this
    // back on: at that point the caller *is* an app, and attestation starts
    // meaning something again.
    {enforceAppCheck: false},
    async (request) => {
      if (!request.auth) {
        throw new HttpsError('unauthenticated', 'Sign-in required.');
      }
      // A custom claim, deliberately — not a Firestore field. A field would
      // be one compromised write away from self-granted admin authority,
      // and rules cannot protect a document from the Admin SDK.
      if (request.auth.token?.admin !== true) {
        throw new HttpsError('permission-denied', 'Administrator access required.', {
          code: 'ADMIN_ONLY',
        });
      }

      const {submissionId, decision, dobMatchesId, rejectionReason} = request.data ?? {};
      if (typeof submissionId !== 'string' || submissionId.length === 0) {
        throw new HttpsError('invalid-argument', 'submissionId is required.');
      }
      if (!isValidDecision(decision)) {
        throw new HttpsError('invalid-argument', 'decision must be "approve" or "reject".');
      }
      if (typeof dobMatchesId !== 'boolean') {
        throw new HttpsError('invalid-argument', 'dobMatchesId must be a boolean attestation.');
      }

      const db = getFirestore();
      const ref = db.doc(`identityVerifications/${submissionId}`);
      const snap = await ref.get();
      if (!snap.exists) {
        throw new HttpsError('not-found', 'Submission not found.');
      }
      const submission = snap.data() as {
        userId: string;
        status: string;
        idDocumentPath: string | null;
        selfiePath: string | null;
      };
      if (submission.status !== 'pending_review') {
        throw new HttpsError('failed-precondition', 'Submission already reviewed.', {
          code: 'ALREADY_REVIEWED',
        });
      }

      // Re-checked HERE, at apply time — not at submission time. See
      // docs/SECURITY.md's report-filed-mid-verification ordering rule.
      const openReports = await db.collection('reports')
          .where('targetType', '==', 'user')
          .where('targetId', '==', submission.userId)
          .where('status', '==', 'open')
          .limit(1)
          .get();

      const outcome = resolveReviewOutcome({
        decision,
        dobMatchesId,
        rejectionReason,
        hasOpenReport: !openReports.empty,
      });

      if (outcome.kind === 'invalid') {
        throw new HttpsError(
            'invalid-argument',
            outcome.code === 'REJECTION_REASON_REQUIRED' ?
              'A rejection requires a reason the user can act on.' :
              'An approval requires the reviewer to attest the ID date of birth matches.',
            {code: outcome.code},
        );
      }

      const now = Timestamp.now();
      const batch = db.batch();

      if (outcome.kind === 'approved') {
        // Both documents are written explicitly rather than relying on a
        // denormalization trigger. docs/DATABASE.md §4 describes
        // verificationTierPublic as trigger-maintained, but no such trigger
        // exists in functions/src/triggers/ — the only trigger in this
        // codebase syncs Tables to Typesense. completeAccountSetup already
        // writes this field directly for the same reason. Disclosed in
        // TASKS.md rather than left as a silent dependency on code that
        // isn't there.
        batch.set(db.doc(`users/${submission.userId}/private/profile`), {
          verification: {
            phoneVerified: true,
            idVerified: true,
            verificationTier: 'id_verified',
            verifiedAt: now,
            pendingSubmissionId: null,
          },
        }, {merge: true});
        batch.set(db.doc(`users/${submission.userId}`), {
          verificationTierPublic: 'id_verified',
          updatedAt: now,
        }, {merge: true});
      }

      const terminalStatus = outcome.kind === 'approved' ? 'approved' :
        outcome.kind === 'rejected' ? 'rejected' : 'held_for_review';

      // Cleared on every terminal outcome, not just approval — a rejected
      // or held submission is no longer the thing the user is waiting on,
      // and leaving a stale pointer would send Screen 8 back to a decided
      // submission instead of letting them start a new one.
      if (outcome.kind !== 'approved') {
        batch.set(db.doc(`users/${submission.userId}/private/profile`), {
          verification: {pendingSubmissionId: null},
        }, {merge: true});
      }

      batch.update(ref, {
        status: terminalStatus,
        dobMatchesId,
        reviewedBy: request.auth.uid,
        reviewedAt: now,
        decisionReason: outcome.kind === 'rejected' ? outcome.reason : null,
        // Nulled here, objects deleted below. A non-null path on a terminal
        // status means deletion failed — see this file's header.
        idDocumentPath: null,
        selfiePath: null,
        updatedAt: now,
      });

      await batch.commit();

      await deleteSubmittedDocuments([submission.idDocumentPath, submission.selfiePath]);

      return {
        submissionId,
        status: terminalStatus,
        verificationTier: outcome.kind === 'approved' ? 'id_verified' : 'phone_verified',
      };
    },
);

/**
 * Best-effort deletion of the reviewed images (ADR 0007's data-minimization
 * consequence — the images exist only for the duration of a review).
 *
 * Deliberately never throws: the decision is already committed by the time
 * this runs, and failing the callable here would tell the reviewer their
 * decision did not apply when it did. A failure is logged loudly instead,
 * and leaves the non-null-path-on-terminal-status signal behind.
 */
async function deleteSubmittedDocuments(paths: Array<string | null>): Promise<void> {
  const bucket = getStorage().bucket();
  for (const path of paths) {
    if (!path) continue;
    try {
      await bucket.file(path).delete();
    } catch (err) {
      logger.error('IDENTITY_DOCUMENT_DELETE_FAILED', {path, err});
    }
  }
}
