/**
 * Derives a residency region (ISO region code, docs/DATABASE.md §3.1's
 * `residencyRegion` field) from a caller's E.164 phone number's country
 * calling code, for `completeAccountSetup` (docs/API_SPEC.md §3.9).
 *
 * This is a small, explicitly-scoped lookup, not exhaustive international
 * coverage — it defaults to "IN" for any unrecognized prefix, a reasoned
 * placeholder appropriate for Foundation/Phase 0's single-market scope
 * (Hyderabad, India, per docs/ROADMAP.md), not a claim that every country's
 * calling code is handled. Revisit as international expansion adds markets
 * (docs/SECURITY.md's Data Privacy Compliance section).
 */

const DEFAULT_REGION = 'IN';

const RAW_CALLING_CODE_TO_REGION: ReadonlyArray<readonly [string, string]> = [
  ['+971', 'AE'],
  ['+91', 'IN'],
  ['+44', 'GB'],
  ['+61', 'AU'],
  ['+65', 'SG'],
  ['+1', 'US'],
];

// Ordered longest-prefix-first so a shorter code already in this table can
// never shadow a more specific, longer one added later (none currently
// collide, but this ordering makes that a structural guarantee rather than
// something a future addition could silently get wrong).
const CALLING_CODE_TO_REGION: ReadonlyArray<readonly [string, string]> =
  [...RAW_CALLING_CODE_TO_REGION].sort((a, b) => b[0].length - a[0].length);

/**
 * Returns the ISO region code for the given E.164 phone number, or
 * `DEFAULT_REGION` ("IN") if no known calling-code prefix matches.
 */
export function deriveResidencyRegion(phoneE164: string): string {
  for (const [prefix, region] of CALLING_CODE_TO_REGION) {
    if (phoneE164.startsWith(prefix)) {
      return region;
    }
  }
  return DEFAULT_REGION;
}
