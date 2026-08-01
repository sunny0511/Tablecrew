/**
 * Pure field-validation helpers backing the Crews domain (docs/API_SPEC.md
 * §3.2), same hand-rolled-validator convention `functions/src/tables/validation.ts`
 * and `functions/src/users/validation.ts` established.
 */

const NAME_MIN_LENGTH = 1;
const NAME_MAX_LENGTH = 40;

/** docs/API_SPEC.md §3.2 `createCrew`: "name empty or over 40 chars" is the
 * documented `invalid-argument` condition, so valid names are 1-40 chars. */
export function isValidCrewName(value: unknown): value is string {
  if (typeof value !== 'string') return false;
  const trimmed = value.trim();
  return trimmed.length >= NAME_MIN_LENGTH && value.length <= NAME_MAX_LENGTH;
}

/** docs/DATABASE.md §3.4: `photoUrl: string | null`. Optional on both
 * `createCrew` and `updateCrew`'s patch surface. */
export function isValidCrewPhotoUrl(value: unknown): value is string | null | undefined {
  if (value === null || value === undefined) return true;
  return typeof value === 'string' && value.length > 0;
}

/** docs/API_SPEC.md §3.2 `createCrew`'s `initialMemberIds?: string[]`. */
export function isValidInitialMemberIds(value: unknown): value is string[] | undefined {
  if (value === undefined) return true;
  if (!Array.isArray(value)) return false;
  return value.every((id) => typeof id === 'string' && id.length > 0);
}

/**
 * docs/API_SPEC.md §3.2 `updateCrew`'s documented patch surface:
 * `Partial<{ name, photoUrl }>`. Validates only the keys actually present
 * in `patch`, same "Partial contract" convention `tables/validation.ts`'s
 * `validateTablePatch` established. Returns the list of invalid field
 * names (empty if the whole patch is valid).
 */
export function validateCrewPatch(patch: unknown): string[] {
  if (typeof patch !== 'object' || patch === null) {
    return ['patch'];
  }
  const invalid: string[] = [];
  const p = patch as Record<string, unknown>;

  if ('name' in p && !isValidCrewName(p.name)) invalid.push('name');
  if ('photoUrl' in p && !isValidCrewPhotoUrl(p.photoUrl)) invalid.push('photoUrl');

  return invalid;
}

/**
 * `CREW_AT_CAPACITY` (docs/API_SPEC.md §3.2 `addMember`): "Crews have a
 * soft cap enforced here to keep chat/coordination usable, configurable
 * via Remote Config." No numeric default is named anywhere in
 * `docs/PRODUCT.md`, `docs/DATABASE.md`, or `docs/FIREBASE.md` — the same
 * kind of undocumented-magic-number gap `tables/validation.ts`'s
 * `KNOWN_INTEREST_TAGS` disclosure describes for the interest-tag
 * taxonomy. **Disclosed gap, not a silent decision:** this hard-codes a
 * reasoned default (20 — well above the largest realistic friend-group/
 * book-club/former-roommates Crew docs/PRODUCT.md's examples describe,
 * while still keeping a single Crew Chat thread usable) rather than
 * wiring a real Remote Config read from a Cloud Function (a separate,
 * heavier integration — Remote Config's Admin SDK surface is a server
 * *template-management* API, not a low-latency per-request value fetch,
 * so a real implementation would need its own caching/refresh design, not
 * a one-line fetch call inline in `addMember`). Tracked in TASKS.md as a
 * follow-up once product actually needs this to be tunable without a
 * redeploy.
 */
export const CREW_MEMBER_SOFT_CAP = 20;
