/**
 * Pure validation and decision policy for manual Tier 2 identity
 * verification (docs/API_SPEC.md §3.7, docs/DATABASE.md §3.10, ADR 0007).
 *
 * Kept separate from index.ts for the same reason every other domain in
 * this codebase does it: the rules here are the part worth unit-testing
 * exhaustively without a Firestore, and the part a future vendor ADR is
 * most likely to keep unchanged when it replaces *how* a decision is
 * reached. Hand-rolled per-field validators, not Zod — this codebase has
 * never adopted Zod, and docs/API_SPEC.md was corrected in Milestone F4
 * for claiming otherwise.
 */

/**
 * Self-declared document type. A reviewer aid only — never treated as
 * evidence of anything, since the reviewer confirms the real document type
 * by looking at the image (docs/DATABASE.md §3.10).
 */
export const KNOWN_DOCUMENT_TYPES = [
  'aadhaar_offline',
  'passport',
  'drivers_license',
  'voter_id',
  'other',
] as const;

export type DocumentType = (typeof KNOWN_DOCUMENT_TYPES)[number];

export function isValidDocumentType(value: unknown): value is DocumentType {
  return typeof value === 'string' &&
    (KNOWN_DOCUMENT_TYPES as readonly string[]).includes(value);
}

/**
 * An upload id is used as a Cloud Storage path *segment*, so the checks
 * here are path-safety checks first and format checks second.
 *
 * This is deliberately stricter than "is it a non-empty string," because
 * Milestone F6 already shipped a real crash of exactly this shape:
 * `triggerDuressSignal` built a Firestore path from an unvalidated
 * `tableId`, and `db.doc()` threw synchronously on the malformed result,
 * surfacing as an unhandled 500 on a safety-critical endpoint. A `/` or a
 * `..` here would let a caller address an object outside their own prefix,
 * which is a materially worse version of the same bug — so this rejects
 * any separator, any dot segment, and anything outside a conservative
 * charset rather than trying to sanitize.
 */
export function isValidUploadId(value: unknown): value is string {
  if (typeof value !== 'string') return false;
  if (value.length === 0 || value.length > 128) return false;
  if (value === '.' || value === '..') return false;
  return /^[A-Za-z0-9._-]+$/.test(value) && !value.includes('..');
}

/**
 * The Storage prefix for a user's in-review documents. `uid` is always
 * taken from `context.auth` server-side and never from the request body —
 * that is what makes it impossible for a caller to reference another
 * user's upload, so this function exists partly to keep that single
 * source of the uid visible in one place.
 */
export function buildIdentityUploadPath(uid: string, uploadId: string): string {
  return `identity-verifications/${uid}/${uploadId}`;
}

export type ReviewDecision = 'approve' | 'reject';

export function isValidDecision(value: unknown): value is ReviewDecision {
  return value === 'approve' || value === 'reject';
}

export function isValidRejectionReason(value: unknown): value is string {
  return typeof value === 'string' &&
    value.trim().length > 0 &&
    value.length <= 500;
}

export type ReviewOutcome =
  | {kind: 'approved'}
  | {kind: 'rejected'; reason: string}
  | {kind: 'held_for_review'}
  | {kind: 'invalid'; code: 'REJECTION_REASON_REQUIRED' | 'DOB_ATTESTATION_REQUIRED'};

export interface ResolveReviewOutcomeParams {
  decision: ReviewDecision;
  /**
   * The reviewer's attestation that the ID's date of birth matches the
   * self-reported one (docs/SECURITY.md's age cross-check). Under ADR 0007
   * no OCR runs, so this is a human assertion rather than an extracted
   * value — which is precisely why an approve is refused without it,
   * instead of the check being quietly skippable by omission.
   */
  dobMatchesId: boolean;
  rejectionReason?: unknown;
  /**
   * Whether an open report exists against the submitting user *right now*,
   * evaluated at the moment the grant is about to apply rather than at
   * submission time. docs/SECURITY.md requires this ordering so a report
   * filed mid-review is never outrun by the verification completing.
   */
  hasOpenReport: boolean;
}

/**
 * The whole decision policy, in one pure function. Every branch below is
 * a requirement stated somewhere else in the knowledge base rather than an
 * invention of this module — see each comment for where.
 */
export function resolveReviewOutcome(
    params: ResolveReviewOutcomeParams,
): ReviewOutcome {
  const {decision, dobMatchesId, rejectionReason, hasOpenReport} = params;

  if (decision === 'reject') {
    // docs/API_SPEC.md §3.7 REJECTION_REASON_REQUIRED. A rejection has to
    // be actionable: Screen 8 shows this string to the user, and under
    // manual review the most common cause is a fixable one (unreadable
    // photo), so a reasonless rejection would strand someone who could
    // simply have retaken it.
    if (!isValidRejectionReason(rejectionReason)) {
      return {kind: 'invalid', code: 'REJECTION_REASON_REQUIRED'};
    }
    return {kind: 'rejected', reason: (rejectionReason as string).trim()};
  }

  // docs/API_SPEC.md §3.7 DOB_ATTESTATION_REQUIRED. Checked before the
  // open-report branch on purpose: a missing attestation means the
  // reviewer did not complete the check at all, which is a malformed
  // decision rather than a legitimate decision that happens to be held.
  if (!dobMatchesId) {
    return {kind: 'invalid', code: 'DOB_ATTESTATION_REQUIRED'};
  }

  // docs/SECURITY.md: an account under active Trust & Safety review does
  // not pass through this gate on timing luck.
  if (hasOpenReport) {
    return {kind: 'held_for_review'};
  }

  return {kind: 'approved'};
}
