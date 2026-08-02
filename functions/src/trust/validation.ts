/**
 * Pure field-validation helpers backing the Trust & Safety domain
 * (docs/API_SPEC.md §3.4), same hand-rolled-validator convention
 * `functions/src/tables/validation.ts`/`functions/src/users/validation.ts`
 * established.
 *
 * Safety-gated per docs/ENGINEERING_GUIDELINES.md's Pull Request Review
 * Process: any PR touching `functions/src/trust/` requires two approvals,
 * at least one from an engineer who has previously worked on this surface
 * — see this domain's own `index.ts` header.
 */

const DETAILS_MAX_LENGTH = 1000;

/**
 * docs/DATABASE.md §3.6's full `reasonCode` enum, minus `flagged_media` —
 * that value is written exclusively by the photo-moderation Cloud
 * Function itself (`functions/src/media/index.ts`) via the Admin SDK,
 * with `reporterId: "system:photo-moderation"`, and is deliberately
 * excluded from what a real signed-in caller may submit through
 * `reportUser`/`reportTable`: accepting it here would let any user
 * impersonate the automated-flag path (and its distinct severity/
 * handling) for their own report.
 */
export const CLIENT_REPORT_REASON_CODES: ReadonlySet<string> = new Set([
  'safety_concern',
  'no_show',
  'harassment',
  'fake_profile',
  'off_platform_stalking',
  'other',
]);

/** docs/API_SPEC.md §3.4 `reportUser`/`reportTable`: "unknown reasonCode." */
export function isValidReportReasonCode(value: unknown): value is string {
  return typeof value === 'string' && CLIENT_REPORT_REASON_CODES.has(value);
}

/** docs/DATABASE.md §3.6: `targetType` is `"user" | "table"`. */
export function isValidReportTargetType(value: unknown): value is 'user' | 'table' {
  return value === 'user' || value === 'table';
}

/** docs/API_SPEC.md §3.4 `reportUser`/`reportTable`: `targetId` is required
 * regardless of `targetType` (a uid or a tableId). */
export function isValidTargetId(value: unknown): value is string {
  return typeof value === 'string' && value.trim().length > 0;
}

/**
 * docs/SCREEN_SPECIFICATIONS.md Screen 27's Validation Rules: "If
 * `off_platform_stalking` is selected, the free-text detail field becomes
 * required (not optional), since expedited human review needs enough
 * context to act quickly." Enforced server-side, not just as client UI
 * gating, the same way this codebase enforces every other safety-relevant
 * rule beyond its client-side UX convenience (e.g. `validateAge`'s
 * `completeAccountSetup` re-check).
 */
export function isValidReportDetails(
    reasonCode: string, value: unknown,
): value is string | null | undefined {
  const trimmed = typeof value === 'string' ? value.trim() : '';
  if (reasonCode === 'off_platform_stalking' && trimmed.length === 0) {
    return false;
  }
  if (value === null || value === undefined) return true;
  return typeof value === 'string' && value.length <= DETAILS_MAX_LENGTH;
}

/** docs/API_SPEC.md §3.4 `blockUser`: "invalid-argument (targetUserId
 * equals caller)." */
export function isValidBlockTargetUserId(
    value: unknown, callerUid: string,
): value is string {
  return typeof value === 'string' && value.trim().length > 0 && value !== callerUid;
}

interface DuressLocationInput {
  geopoint?: unknown;
}

/**
 * docs/API_SPEC.md §3.4 `triggerDuressSignal`: "`location` is optional ...
 * a malformed or incomplete payload ... is accepted and processed with
 * whatever data is present" — this endpoint deliberately never rejects a
 * request over a malformed `location`; it treats anything not cleanly
 * shaped as "no location," never throws, matching the endpoint's
 * documented zero-validation-friction design. Returns the valid
 * `{lat, lng}` pair, or `null` if the input isn't one — never throws.
 */
export function extractDuressLocation(
    location: unknown,
): {lat: number; lng: number} | null {
  if (typeof location !== 'object' || location === null) return null;
  const {geopoint} = location as DuressLocationInput;
  if (typeof geopoint !== 'object' || geopoint === null) return null;
  const {lat, lng} = geopoint as {lat?: unknown; lng?: unknown};
  if (typeof lat !== 'number' || lat < -90 || lat > 90) return null;
  if (typeof lng !== 'number' || lng < -180 || lng > 180) return null;
  return {lat, lng};
}
