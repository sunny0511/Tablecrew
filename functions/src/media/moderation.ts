/**
 * Pure verdict-classification policy for the photo-moderation pipeline
 * (docs/FIREBASE.md §2.5, docs/DATABASE.md §3.1a, ADR 0006). Kept
 * dependency-free and framework-free (no firebase-admin/-functions,
 * no @google-cloud/vision imports) so the actual approve/flag policy is
 * unit-testable without a real Cloud Vision call or Storage/Firestore
 * access, the same separation-of-policy-from-plumbing pattern
 * `users/ageGate.ts`, `tables/validation.ts`, and `crews/validation.ts`
 * already establish. The Storage-triggered wiring (the actual Vision API
 * call, the Storage copy, the Firestore writes) lives in `./index.ts`.
 *
 * Added Milestone F5.
 */

export type SafeSearchLikelihood =
  | 'UNKNOWN'
  | 'VERY_UNLIKELY'
  | 'UNLIKELY'
  | 'POSSIBLE'
  | 'LIKELY'
  | 'VERY_LIKELY';

export interface SafeSearchAnnotation {
  adult?: SafeSearchLikelihood | null;
  violence?: SafeSearchLikelihood | null;
  racy?: SafeSearchLikelihood | null;
  medical?: SafeSearchLikelihood | null;
  spoof?: SafeSearchLikelihood | null;
}

export interface ModerationVerdict {
  status: 'approved' | 'flagged';
  flagReason: string | null;
}

const LIKELIHOOD_RANK: Record<SafeSearchLikelihood, number> = {
  UNKNOWN: 0,
  VERY_UNLIKELY: 1,
  UNLIKELY: 2,
  POSSIBLE: 3,
  LIKELY: 4,
  VERY_LIKELY: 5,
};

function meetsOrExceeds(
    value: SafeSearchLikelihood | null | undefined,
    threshold: SafeSearchLikelihood,
): boolean {
  const rank = LIKELIHOOD_RANK[value ?? 'UNKNOWN'];
  return rank >= LIKELIHOOD_RANK[threshold];
}

/**
 * Threshold policy — a real content-policy decision, disclosed rather than
 * an arbitrary default. `adult`/`violence` flag at `LIKELY` or above (the
 * stricter pair, since these are the two categories that matter most for a
 * stranger-facing profile photo, per docs/SECURITY.md's Content Moderation
 * section). `racy` only flags at `VERY_LIKELY`, the most permissive
 * threshold: profile photos legitimately include beach/gym/swimwear
 * content that SafeSearch's `racy` category routinely scores
 * `POSSIBLE`/`LIKELY` without being genuinely policy-violating, and a
 * tighter threshold would over-flag ordinary photos. `medical`/`spoof` are
 * not gating factors for a profile-photo use case — the threat model here
 * is nudity/explicit-content and violence, not medical imagery or
 * meme-style alteration — so they're not read at all yet. Revisit this
 * policy once real flagged-photo volume exists to check it against actual
 * outcomes, rather than guessing further ahead of any real data.
 */
export function classifySafeSearchVerdict(annotation: SafeSearchAnnotation): ModerationVerdict {
  if (meetsOrExceeds(annotation.adult, 'LIKELY')) {
    return {status: 'flagged', flagReason: `adult:${annotation.adult}`};
  }
  if (meetsOrExceeds(annotation.violence, 'LIKELY')) {
    return {status: 'flagged', flagReason: `violence:${annotation.violence}`};
  }
  if (meetsOrExceeds(annotation.racy, 'VERY_LIKELY')) {
    return {status: 'flagged', flagReason: `racy:${annotation.racy}`};
  }
  return {status: 'approved', flagReason: null};
}

/**
 * Parses the pending-upload Storage object path this pipeline's convention
 * requires (docs/FIREBASE.md §2.5, docs/DATABASE.md §3.1a):
 * `users/{userId}/profile/pending/{uploadId}` (extension-agnostic — the
 * client controls the file name, this pipeline doesn't care). Returns
 * `null` for anything that doesn't match, which the trigger uses to skip
 * objects this pipeline isn't responsible for — most importantly its own
 * `approved/` copies, which would otherwise re-trigger this same function.
 *
 * Scope, disclosed: only the profile-photo path shape is recognized today.
 * Table cover photos (`tables/{tableId}/photos/pending/*`) aren't uploaded
 * anywhere yet (Milestone F6+) — extending this parser with a second
 * branch once that upload flow exists is a small, contained change, not a
 * rewrite of this trigger.
 */
export function parsePendingProfilePhotoPath(
    objectPath: string,
): {userId: string; uploadId: string} | null {
  const match = /^users\/([^/]+)\/profile\/pending\/([^/]+)$/.exec(objectPath);
  if (!match) return null;
  const [, userId, uploadId] = match;
  if (!userId || !uploadId) return null;
  return {userId, uploadId};
}

/** The public, post-moderation object path a clean verdict copies to. */
export function approvedObjectPath(userId: string, uploadId: string): string {
  return `users/${userId}/profile/approved/${uploadId}`;
}
